/* eslint-disable @typescript-eslint/no-unused-vars */
import { BigNumber, BigNumberish } from "ethers";

export type DeployConfig = {
  gatewayAddress: string;
}

const toTokenAmount = (amount: BigNumberish, tokenDecimal: BigNumberish) => {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(tokenDecimal))
}

const config: { [key: string]: DeployConfig } = {
  'rinkeby': {
    gatewayAddress: '0xFfE41F21961B75cb96C833d34164b1463A167EF0'
  }
}

export default config;
