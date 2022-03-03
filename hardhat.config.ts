import "@nomiclabs/hardhat-waffle";
import "tsconfig-paths/register";
import "dotenv/config";
import "@openzeppelin/hardhat-upgrades";
import "@nomiclabs/hardhat-solhint";
import "@typechain/hardhat";
import "@typechain/ethers-v5";
import "hardhat-deploy-ethers";
import "hardhat-deploy";
import "@symfoni/hardhat-react";
import { HardhatUserConfig, task } from "hardhat/config";

const projectId = process.env.PROJECT_ID as string;
const secret = process.env.SECRET_ACCOUNT as string;

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(await account.address);
  }
});

const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      chainId: 1337,
    },
    // mumbai: {
    //   url: `https://polygon-mumbai.infura.io/v3/${projectId}`,
    //   accounts: [secret],
    // },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: { mnemonic: secret },
    },
    // mainnet: {
    //   url: `https://polygon-mainnet.infura.io/v3/${projectId}`,
    //   accounts: [secret],
    // },
  },
  typechain: {
    outDir: "./__generated__",
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
  react: {
    providerPriority: ["web3modal", "hardhat"],
  },
  paths: {
    react: "./context/__generated__",
    deploy: "./deploy",
    tests: "./tests",
  },
  solidity: "0.8.4",
  namedAccounts: {
    deployer: 0,
    user1: 1,
    user2: 2,
    user3: 3,
    user4: 4,
    user5: 5,
    user6: 6,
    user7: 7,
    user8: 8,
    user9: 9,
    user10: 10,
    proxyOwner: 19,
  },
};

export default config;
