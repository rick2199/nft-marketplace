import "@nomiclabs/hardhat-waffle";
import "dotenv/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-solhint";
import "@typechain/hardhat";
import { HardhatUserConfig } from "hardhat/config";

const projectId = process.env.PROJECT_ID as string;
const secret = process.env.SECRET_ACCOUNT as string;

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      chainId: 1337,
    },
    mumbai: {
      url: `https://polygon-mumbai.infura.io/v3/${projectId}`,
      accounts: [secret],
    },
    mainnet: {
      url: `https://polygon-mainnet.infura.io/v3/${projectId}`,
      accounts: [secret],
    },
  },
  typechain: {
    outDir: "./__generated__",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
  solidity: "0.8.4",
};

export default config;
