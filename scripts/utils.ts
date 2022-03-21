/* eslint-disable @typescript-eslint/explicit-module-boundary-types */
/* eslint-disable @typescript-eslint/no-var-requires */
import hre from 'hardhat';
import { BigNumber, Contract, ContractTransaction, Signer } from 'ethers';
import { DeployResult } from 'hardhat-deploy/types';
import fs from 'fs';
import path from 'path';

import { GAS_LIMIT } from './constants';
import { getContractForEnvironment } from '../test/utils/getContractForEnvironment';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { ParadiseBridge } from '../typechain/ParadiseBridge';

import {
  ContractList,
  IMPL_PREFIX,
  PROXY_CONTRACTS,
  UPBEACON_PREFIX,
  UPGRADEABLE_CONTRACTS,
  ZERO_ADDRESS,
} from './constants';

import NETWORK_DEPLOY_CONFIG, { DeployConfig } from '../deploy.config';

require('dotenv').config();
const prompts = require('prompts');

const { deploy: _dep } = hre.deployments;

let __DEPLOY_CONFIG: DeployConfig;
export function deployConfig() {
  if (__DEPLOY_CONFIG) return __DEPLOY_CONFIG;
  __DEPLOY_CONFIG = NETWORK_DEPLOY_CONFIG[hre.network.name];
  if (!__DEPLOY_CONFIG) {
    throw new Error(`Unconfigured network: "${hre.network.name}"`);
  }
  return __DEPLOY_CONFIG;
}

export type DeployFunction = (
  deployName: string,
  contractName: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  args?: string[] | any[]
) => Promise<DeployResult>;
export type Deployments = { [key: string]: DeployResult };

export async function setup(): Promise<{
  accounts: SignerWithAddress[];
  deployer: SignerWithAddress;
  deploy: (
    deployName: string,
    contractName: string,
    args?: string[]
  ) => Promise<DeployResult>;
}> {
  const accounts = await hre.ethers.getSigners();
  const deployer = accounts[0];
  console.log('Network:', hre.network.name);
  console.log('Signer:', deployer.address);
  console.log(
    'Signer balance:',
    hre.ethers.utils.formatEther(await deployer.getBalance()).toString(),
    'ETH'
  );

  return {
    accounts,
    deployer,
    deploy: async (
      deployName: string,
      contractName: string,
      args: string[] = []
    ): Promise<DeployResult> => {
      console.log(
        `\n>> Deploying contract "${deployName}" ("${contractName}")...`
      );
      const deployResult = await _dep(deployName, {
        contract: contractName,
        args: args,
        log: true,
        skipIfAlreadyDeployed: false,
        gasLimit: GAS_LIMIT,
        from: deployer.address,
      });
      console.log(
        `${deployResult.newlyDeployed ? '[New]' : '[Reused]'
        } contract "${deployName}" ("${contractName}") deployed at "${deployResult.address
        }" \n - tx: "${deployResult.transactionHash}" \n - gas: ${deployResult.receipt?.gasUsed
        } \n - deployer: "${deployer.address}"`
      );
      return deployResult;
    },
  };
}

export function waitContractCall(
  transcation: ContractTransaction
): Promise<void> {
  return new Promise<void>((resolve) => {
    transcation.wait().then((receipt) => {
      console.log(
        `Waiting transcation: "${receipt.transactionHash}" (block: ${receipt.blockNumber} gasUsed: ${receipt.gasUsed})`
      );
      if (receipt.status === 1) {
        return resolve();
      }
    });
  });
}

export async function tryGetContractForEnvironment<T extends Contract>(
  contractName: string,
  deployer: Signer
): Promise<{ err: any; contract: T | undefined }> {
  const result: { err: any; contract: T | undefined } = {
    err: undefined,
    contract: undefined,
  };
  try {
    result.contract = (await getContractForEnvironment(
      hre,
      contractName as any,
      deployer
    )) as T;
    return result;
  } catch (err) {
    result.err = err;
  }
  try {
    const basePath = `./deployments/${hre.network.name}`;
    const deployment = JSON.parse(
      fs.readFileSync(path.join(basePath, `${contractName}.json`)).toString()
    );
    result.contract = (await hre.ethers.getContractAt(
      deployment.abi,
      deployment.address,
      deployer
    )) as unknown as T;
    return result;
  } catch (err2) {
    result.err = err2;
  }
  return result;
}

export async function getContractAt<T extends Contract>(
  contractName: string,
  address: string,
  signer?: string | Signer | undefined
): Promise<T> {
  const realSigner =
    typeof signer === 'string' ? await hre.ethers.getSigner(signer) : signer;
  try {
    const contract = await hre.deployments.get(contractName);
    return hre.ethers.getContractAt(
      contract.abi,
      address,
      realSigner
    ) as Promise<T>;
  } catch (err) {
    return hre.ethers.getContractAt(
      contractName,
      address,
      realSigner
    ) as Promise<T>;
  }
}

export async function getContractFromEnvOrPrompts<T extends Contract>(
  {
    contractNameEnv,
    contractName,
  }: { contractNameEnv: string; contractName?: string },
  deployer: Signer
): Promise<T> {
  console.log(`\nGetting contract "${contractNameEnv}"...`);
  const { contract, err } = await tryGetContractForEnvironment<T>(
    contractNameEnv,
    deployer
  );
  if (!contract) {
    const { contractAddress } = await prompts({
      type: 'text',
      name: 'contractAddress',
      message:
        'Unable to find the contract from the environment, please enter the address manually:',
    });
    return await getContractAt<T>(
      contractName || contractNameEnv,
      contractAddress,
      deployer
    );
  }
  return contract;
}

export function nullOrDeployer(
  address: string | undefined | null,
  deployer: SignerWithAddress
): string {
  if (!address || address === 'deployer') return deployer.address;
  return address;
}

export async function deployImpl(
  deploy: DeployFunction,
  contracts: ContractList
) {
  const results: Deployments = {};
  for (const i of contracts) {
    const key = typeof i !== 'string' ? Object.keys(i)[0] : i;
    const n = `Impl${key}`;
    results[n] = await deploy(n, key);
  }
  return results;
}

export async function deployUpBeacon(
  deploy: DeployFunction,
  contracts: ContractList,
  implDeployments: Deployments
) {
  const results: Deployments = {};
  for (const i of contracts) {
    const key = typeof i !== 'string' ? Object.keys(i)[0] : i;
    if (typeof i !== 'string') {
      for (const child of i[key]) {
        const n = `${UPBEACON_PREFIX}${child}`;
        results[n] = await deploy(n, 'UpgradeableBeacon', [
          implDeployments[`${IMPL_PREFIX}${key}`].address,
        ]);
      }
    } else {
      const n = `${UPBEACON_PREFIX}${key}`;
      results[n] = await deploy(n, 'UpgradeableBeacon', [
        implDeployments[`${IMPL_PREFIX}${key}`].address,
      ]);
    }
  }
  return results;
}

export async function deployBeaconProxy(
  deploy: DeployFunction,
  contracts: ContractList,
  upBeaconDeployments: Deployments
) {
  const results: Deployments = {};
  for (const i of contracts) {
    const key = typeof i !== 'string' ? Object.keys(i)[0] : i;
    if (typeof i !== 'string') {
      for (const child of i[key]) {
        const n = `${child}Proxy`;
        results[n] = await deploy(n, 'BeaconProxy', [
          upBeaconDeployments[`${UPBEACON_PREFIX}${key}`].address,
          [],
        ]);
      }
    } else {
      const n = `${key}Proxy`;
      results[n] = await deploy(n, 'BeaconProxy', [
        upBeaconDeployments[`${UPBEACON_PREFIX}${key}`].address,
        [],
      ]);
    }
  }
  return results;
}

export async function getDeployedContracts(deployer: SignerWithAddress) {
  console.log('\n>>>>>>>>> Getting deployed contracts...\n');
  const ParadiseBridge = await getContractForEnvironment<ParadiseBridge>(
    hre,
    'ParadiseBridge',
    deployer
  );

  return { ParadiseBridge };
}

export async function deployContractsEthereumSide(deploy: DeployFunction) {
  console.log('\n>>>>>>>>> Deploying contracts EthereumSide...\n');

  const TestPDTDepResult = await deploy('TestPDT', 'TestPDT');
  const ParadiseBridgeDepResult = await deploy(
    'ParadiseBridge',
    'ParadiseBridge',
    [true]
  );


  return {
    TestPDTDepResult,
    ParadiseBridgeDepResult,
  };
}



const NETWORK_DEPLOYS = {
  rinkeby: deployAndSetupContractsEthereumSide,
  paradise: deployAndSetupContractsParadiseSide,
  bsctest: deployAndSetupContractsBSCSide
};

export async function deployAndSetupContracts() {
  const deployFunction = (NETWORK_DEPLOYS as any)[hre.network.name];
  if (!deployFunction) throw new Error(`Invalid network ${hre.network.name}`);
  await deployFunction();
}

async function deployAndSetupContractsEthereumSide() {
  console.log('<deployAndSetupContractsEthereumSide>');
  const { deployer, deploy } = await setup();
  const deployments = await deployContractsEthereumSide(deploy);
  const deployedContracts = await getDeployedContracts(deployer);
  const { ParadiseBridge } = deployedContracts;
  console.log('addBridgeableTokens...');
  await waitContractCall(
    await ParadiseBridge.addBridgeableTokens(
      [deployments.TestPDTDepResult.address],
      [
        {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: BigNumber.from(
            '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
          ),
          bridgeFee: 0,
        },
      ]
    )
  );
  console.log('>>> CONTRACTS SETUP DONE <<<');
}

export async function deployContractsParadiseSide(deploy: DeployFunction) {
  console.log('\n>>>>>>>>> Deploying contracts ParadiseSide...\n');

  const ParadiseBridgeDepResult = await deploy(
    'ParadiseBridge',
    'ParadiseBridge',
    [true]
  );

  return {
    ParadiseBridgeDepResult,
  };
}

async function deployAndSetupContractsParadiseSide() {
  console.log('<deployAndSetupContractsParadiseSide>');
  const { deployer, deploy } = await setup();
  const deployments = await deployContractsParadiseSide(deploy);
  const deployedContracts = await getDeployedContracts(deployer);
  const { ParadiseBridge } = deployedContracts;
  console.log('setBridgeToNativeApprovalStatus...');
  await waitContractCall(
    await ParadiseBridge.setBridgeToNativeApprovalStatus(true)
  );

  console.log('grantRole...');
  const approverRole = await ParadiseBridge.BRIDGE_APPROVER_ROLE();
  await waitContractCall(
    await ParadiseBridge.grantRole(approverRole, deployer.address)
  );

  console.log('setNativeTokensBridgeConfig...');
  await waitContractCall(
    await ParadiseBridge.setNativeTokensBridgeConfig({
      enabled: true,
      burn: false,
      minBridgeAmount: 0,
      maxBridgeAmount: BigNumber.from(
        '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
      ),
      bridgeFee: 0,
    })
  );

  console.log('deposit paradise...');
  await waitContractCall(
    await ParadiseBridge.depositNativeTokens({
      value: BigNumber.from(100_0000).mul(BigNumber.from(10).pow(18)),
    })
  );
  console.log('>>> CONTRACTS SETUP DONE <<<');
}


export async function deployContractsBSCSide(deploy: DeployFunction) {
  console.log('\n>>>>>>>>> Deploying contracts BSC side...\n');

  const ParadiseBridgeDepResult = await deploy(
    'ParadiseBridge',
    'ParadiseBridge',
    [true]
  );
  const TestPDTDepResult = await deploy('BridgeERC20', 'BridgeERC20', [
    'BridgePDT',
    'BPDT',
    18,
    BigNumber.from(1000_0000).mul(BigNumber.from(10).pow(18)),
    ParadiseBridgeDepResult.address,
  ]);

  return {
    TestPDTDepResult,
    ParadiseBridgeDepResult,
  };
}


async function deployAndSetupContractsBSCSide() {
  console.log('<deployAndSetupContractsBSCSide>');
  const { deployer, deploy } = await setup();
  const deployments = await deployContractsBSCSide(deploy);
  const deployedContracts = await getDeployedContracts(deployer);
  const { ParadiseBridge } = deployedContracts;
  console.log('addBridgeableTokens...');
  await waitContractCall(
    await ParadiseBridge.addBridgeableTokens(
      [deployments.TestPDTDepResult.address],
      [
        {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: BigNumber.from(
            '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
          ),
          bridgeFee: 0,
        },
      ]
    )
  );
  console.log('>>> CONTRACTS SETUP DONE <<<');
}
