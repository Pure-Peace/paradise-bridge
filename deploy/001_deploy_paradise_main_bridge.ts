import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { genGetContractWith } from '../test/utils/genHelpers';
import { ParadiseBridge } from '../typechain/ParadiseBridge';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  const mainBridgeDeployments = await deploy('ParadiseBridge', {
    from: deployer,
    contract: 'ParadiseBridge',
    args: [],
    log: true,
    skipIfAlreadyDeployed: false,
    gasLimit: 5500000,
  });
  const { getContractAt } = genGetContractWith(hre);
  const mainBridge = await getContractAt<ParadiseBridge>(
    'ParadiseBridge',
    mainBridgeDeployments.address,
    deployer
  );
};
export default func;
func.id = 'deploy_paradise_main_bridge';
func.tags = ['ParadiseBridge'];
