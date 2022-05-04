require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

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
  // defaultNetwork: "matic",
  // networks: {
  //   hardhat: {
  //   },
  //   matic: {
  //     url: "https://rpc-mumbai.maticvigil.com",
  //     accounts: [process.env.PRIVATE_KEY]
  //   }
  // },
  // etherscan: {
  //   apiKey: process.env.POLYGONSCAN_API_KEY
  // },
  defaultNetwork: "hardhat",
  gasReporter: {
    currency: "USD",
    enabled: true,
    excludeContracts: [],
    src: "./contracts",
  },
  networks: {
    hardhat: {
      gasPrice: "auto",
      gasMultiplier: 2,
      chainId: 1337,
      allowUnlimitedContractSize: true
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.5.16"
      },
      {
        version: "0.8.0"
      },
      {
        version: "0.6.6"
      },
      {
        version: "0.6.12"
      }
    ]
  }
};
