import {providers, Wallet} from 'ethers';
import {address as PARADISE_BRIDGE_ADDRESS} from '../deployments/bscTestnet/ParadiseBridgeProxy.json';
import {ParadiseBridge__factory} from '../typechain/factories/ParadiseBridge__factory';

const main = async () => {
  const provider = new providers.JsonRpcProvider(
    process.env.ETH_NODE_URI_RINKEBY
  );

  const signer = new Wallet(process.env.PRIV_KEYS_RINKEBY, provider);
  const ParadiseBridge = ParadiseBridge__factory.connect(
    PARADISE_BRIDGE_ADDRESS,
    signer
  );

  const tx = await ParadiseBridge.setGlobalFeeStatus(true);
  console.log(tx);
  const recipient = await tx.wait();
  console.log(recipient);
};

main()
  .then(() => {})
  .catch((err) => {
    console.error(err);
  });
