import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "hardhat-gas-reporter";
import { config as dotenvConfig } from "dotenv";
import "hardhat-deploy";

dotenvConfig();

const private_key: string = process.env.PRIVATE_KEY || "";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.18',
        settings: {
          optimizer: {
            enabled: true,
            runs: parseInt(process.env.OPTIMIZER_RUNS || '1000'),
            details: {
              yul: true,
            },
          },
        },
      },
    ],
  },
  // networks: {
  //   goerli: {
  //     url: `https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
  //     accounts: [private_key],
  //   },
  //   mainnet: {
  //     url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`,
  //     accounts: [private_key],
  //   },
  // },

  // etherscan: {
  //   apiKey: {
  //     goerli: `${process.env.ETHERSCAN_API_KEY}`,
  //     mainnet: `${process.env.ETHERSCAN_API_KEY}`,
  //   },
  // },

  gasReporter: {
    currency: 'ETH',
    enabled: true,
    outputFile: "gas_report.json",
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
};

export default config;
