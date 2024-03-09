import "@nomicfoundation/hardhat-toolbox";
import "hardhat-contract-sizer";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: [],
  },
  solidity: {
    compilers: [
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
      {
        version: "0.8.18",
        settings: {
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
      {
        version: "0.6.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
      {
        version: "0.5.16",
        settings: {
          optimizer: {
            enabled: true,
            runs: 10,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      gasPrice: 470000000000,
      chainId: 43112,
    },
    avash: {
      url: "http://localhost:9650/ext/bc/C/rpc",
      gasPrice: 470000000000,
      chainId: 43112,
      accounts: [],
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      gasPrice: "auto",
      chainId: 43113,
      accounts: [],
    },
    mainnet: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      gasPrice: 470000000000,
      chainId: 43114,
      accounts: [],
    },
  },
  typechain: {
    outDir: "types",
    target: "ethers-v6",
  },
};

export default config;
