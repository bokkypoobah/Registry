require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("hardhat-gas-reporter");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.19",
    settings: {
      viaIR: false,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
      hardhat: {
          blockGasLimit: 30_000_000,
      },
  },
  gasReporter: {
    enabled: true,
    // enabled: process.env.REPORT_GAS ? true : false,
  }
};
