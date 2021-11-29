import "dotenv/config";

import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-truffle5";
import "@nomiclabs/hardhat-web3";
import "@typechain/hardhat";

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      initialBaseFeePerGas: 0, // workaround from https://github.com/sc-forks/solidity-coverage/issues/652#issuecomment-896330136 . Remove when that issue is closed.
      accounts: {
        mnemonic: "test test test test test test test test test test test test",
        count: 10,
        accountsBalance: "100000000000000000000000000",
      },
      forking: {
        url: process.env.MAINNET_URL || "",
      },
      chainId: 1,
    },
  },
  typechain: {
    target: "truffle-v5",
    alwaysGenerateOverloads: true,
  },
};

export default config;
