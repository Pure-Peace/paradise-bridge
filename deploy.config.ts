/* eslint-disable @typescript-eslint/no-unused-vars */
import { BigNumber, BigNumberish } from 'ethers';
import { ZERO_ADDRESS } from './scripts/constants';
import {
  BridgeableTokensConfigStruct,
  BridgeApprovalConfigStruct,
} from './typechain/ParadiseBridge';

export type BridgeableToken = {
  token: string;
  targetChainId: BigNumberish;
  config: BridgeableTokensConfigStruct;
};

export type BridgeApprovalConfig = {
  token: string;
  config: BridgeApprovalConfigStruct;
};

export type BridgeERC20DeployConfig = {
  name: string;
  symbol: string;
  decimals: number;
  totalSupplyWithDecimals: number;
};

export type DeployConfig = {
  bridgeRunningStatus: boolean;
  globalFeeStatus: boolean;
  feeRecipient: string;
  bridgeApprovers: string[];
  bridgeableTokens: BridgeableToken[];
  bridgeApprovalConfigs: BridgeApprovalConfig[];
  bridgeERC20DeployConfigs: BridgeERC20DeployConfig[];
  depositNativeTokensAmountEther?: number;
};

const toTokenAmount = (amount: BigNumberish, tokenDecimal: BigNumberish) => {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(tokenDecimal));
};

const NATIVE_TOKEN = ZERO_ADDRESS;
const PARADISE_CHAIN_ID = 8648888;

// Mainnet
const PARADISE_BRIDGE_FEE_RECIPIENT_BSC_PARADISE = '0x4C9407df1aD4119916882dc40d50F729969972dB'
const MAINNET_CHAIN_ID = 1;
const BSC_CHAIN_ID = 56;
const BSC_APPROVER = '0x19bCDB09AF94F85124Cd55B7B5ef31A34c3993D1'
const PARADISE_APPROVER = '0x041eAAa15e6Cb9f290CB1f95e566C7542FD79F46'
const PARADISE_TOKEN_MAINNET = '0xcDE07F2d976b2687944Ad2c70E2Cec9A7034b75B'


// Testnet
const BSC_TESTNET_CHAIN_ID = 97;
const RINKEBY_CHAIN_ID = 4;
const PARADISE_TOKEN_RINKEBY = '0xc526f065c6a9Fc54A9495861B3807F58aA63565d';
const PARADISE_BRIDGE_FEE_RECIPIENT_TESTNET =
  '0x686E797117ba23b30aA07AAdF82ba8A0B329948b';


const configTestnet: { [key: string]: DeployConfig } = {
  rinkeby: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_TESTNET,
    bridgeApprovers: ['deployer'],
    bridgeableTokens: [
      {
        token: PARADISE_TOKEN_RINKEBY,
        targetChainId: PARADISE_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
      {
        token: PARADISE_TOKEN_RINKEBY,
        targetChainId: BSC_TESTNET_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
    ],
    bridgeApprovalConfigs: [
      {
        token: PARADISE_TOKEN_RINKEBY,
        config: {
          enabled: true,
          transfer: true,
        },
      },
    ],
    bridgeERC20DeployConfigs: [],
    depositNativeTokensAmountEther: 0,
  },
  paradiseTestnet: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_TESTNET,
    bridgeApprovers: ['deployer'],
    bridgeableTokens: [
      {
        token: NATIVE_TOKEN,
        targetChainId: BSC_TESTNET_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
      {
        token: NATIVE_TOKEN,
        targetChainId: RINKEBY_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
    ],
    bridgeApprovalConfigs: [
      {
        token: NATIVE_TOKEN,
        config: {
          enabled: true,
          transfer: true,
        },
      },
    ],
    bridgeERC20DeployConfigs: [],
    depositNativeTokensAmountEther: 1_000_000,
  },
  bscTestnet: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_TESTNET,
    bridgeApprovers: ['deployer'],
    bridgeableTokens: [
      {
        token: 'BridgePDT',
        targetChainId: PARADISE_CHAIN_ID,
        config: {
          enabled: true,
          burn: true,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
      {
        token: 'BridgePDT',
        targetChainId: RINKEBY_CHAIN_ID,
        config: {
          enabled: true,
          burn: true,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      },
    ],
    bridgeApprovalConfigs: [
      {
        token: 'BridgePDT',
        config: {
          enabled: true,
          transfer: false,
        },
      },
    ],
    bridgeERC20DeployConfigs: [
      {
        name: 'BridgePDT',
        symbol: 'bPDT',
        decimals: 18,
        totalSupplyWithDecimals: 10_000_000,
      },
    ],
    depositNativeTokensAmountEther: 0,
  },
};

const config: { [key: string]: DeployConfig } = {
  mainnet: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_BSC_PARADISE,
    bridgeApprovers: [],
    bridgeableTokens: [
      {
        token: PARADISE_TOKEN_MAINNET,
        targetChainId: PARADISE_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      }
    ],
    bridgeApprovalConfigs: [],
    bridgeERC20DeployConfigs: [],
    depositNativeTokensAmountEther: 0,
  },
  paradise: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_BSC_PARADISE,
    bridgeApprovers: [PARADISE_APPROVER],
    bridgeableTokens: [
      {
        token: NATIVE_TOKEN,
        targetChainId: BSC_CHAIN_ID,
        config: {
          enabled: true,
          burn: false,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      }
    ],
    bridgeApprovalConfigs: [
      {
        token: NATIVE_TOKEN,
        config: {
          enabled: true,
          transfer: true,
        },
      },
    ],
    bridgeERC20DeployConfigs: [],
    depositNativeTokensAmountEther: 9999998,
  },
  bsc: {
    bridgeRunningStatus: true,
    globalFeeStatus: true,
    feeRecipient: PARADISE_BRIDGE_FEE_RECIPIENT_BSC_PARADISE,
    bridgeApprovers: [BSC_APPROVER],
    bridgeableTokens: [
      {
        token: 'ParadiseToken',
        targetChainId: PARADISE_CHAIN_ID,
        config: {
          enabled: true,
          burn: true,
          minBridgeAmount: 0,
          maxBridgeAmount: 0,
          bridgeFee: 0,
        },
      }
    ],
    bridgeApprovalConfigs: [
      {
        token: 'ParadiseToken',
        config: {
          enabled: true,
          transfer: false,
        },
      },
    ],
    bridgeERC20DeployConfigs: [
      {
        name: 'ParadiseToken',
        symbol: 'PDT',
        decimals: 18,
        totalSupplyWithDecimals: 10_000_000,
      },
    ],
    depositNativeTokensAmountEther: 0,
  },
};


export default config;
