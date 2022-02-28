import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function ({
  getNamedAccounts,
  deployments,
  network,
}: HardhatRuntimeEnvironment) {
  const { deployer } = await getNamedAccounts();
  console.log({ network });
  let nftMarketAddress = "";
  const nftMarket = await deployments.deploy("NFTMarket", {
    from: deployer,
    log: true,
  });
  nftMarketAddress = nftMarket.address;
  await deployments.deploy("NFT", {
    from: deployer,
    log: true,
    args: [nftMarketAddress],
  });
};

func.id = "deploy_nft_market";
func.tags = ["NFTMarket", "NFT"];
export default func;
