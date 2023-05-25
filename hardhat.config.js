import { task } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-verify";
import "dotenv/config";

export default {
  solidity: "0.8.17",
  networks: {
    goerli: {
      url: process.env.QUICKNODE_URL,
      accounts: {
        mnemonic: process.env.METAMASK_PRIVATE_KEY,
      },
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};