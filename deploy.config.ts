/* eslint-disable @typescript-eslint/no-unused-vars */
import { BigNumber, BigNumberish } from "ethers";

export type DeployConfig = {
}

const toTokenAmount = (amount: BigNumberish, tokenDecimal: BigNumberish) => {
  return BigNumber.from(amount).mul(BigNumber.from(10).pow(tokenDecimal))
}

const config: { [key: string]: DeployConfig } = {

}

export default config;
