require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("@nomiclabs/hardhat-ethers");
require("hardhat-contract-sizer");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.4",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
    outputSelection: {
      "*": {
        "*": ["evm.bytecode", "evm.deployedBytecode", "abi"],
      },
    },
  },
  networks: {
    localhost: {
      url: process.env.LOCAL_URL || "",
      accounts:
        process.env.LOCAL_PRIVATE_KEY !== undefined
          ? [process.env.LOCAL_PRIVATE_KEY]
          : [],
    },
    bscTestnet: {
      url: "https://speedy-nodes-nyc.moralis.io/36aa7f475186f430dae80641/bsc/testnet",
      network_id: 97,
      confirmations: 10,
      timeoutBlocks: 200,
      skipDryRun: true,
      accounts: { mnemonic: process.env.MNEMONIC },
    },
    ropsten: {
      url: `https://speedy-nodes-nyc.moralis.io/86519729daec0d9c5cb0fd8f/eth/ropsten`,
      accounts: [
        "b2823d774710b99f4c887d1e71b0ce15eee0d32b3d4bde71fbaa6f27fac3406d",
      ],
    },
    mainnet: {
      url: "https://speedy-nodes-nyc.moralis.io/36aa7f475186f430dae80641/bsc/mainnet",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: { mnemonic: process.env.PRODUCTION_MNEMONIC },
    },
  },
  gasReporter: {
    enabled: process.env.GAS_REPORTER_COIN_MARKET_CAP_API_KEY !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      ropsten: process.env.BLOCK_EXPLORER_API_KEY,
      bsc: process.env.BLOCK_EXPLORER_API_KEY,
    },
  },
};
