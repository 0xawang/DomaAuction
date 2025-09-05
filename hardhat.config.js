require('dotenv').config();
require("@nomicfoundation/hardhat-ethers")
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-verify");
require("hardhat-contract-sizer");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true
    }
  },
  networks: {
    doma: {
      url: "https://rpc-testnet.doma.xyz",
      chainId: 97476,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : []
    }
  },
  etherscan: {
    apiKey: {
      'doma': 'empty'
    },
    customChains: [
      {
        network: "doma",
        chainId: 97476,
        urls: {
          apiURL: "https://explorer-doma-dev-ix58nm4rnd.t.conduit.xyz/api",
          browserURL: "https://explorer-doma-dev-ix58nm4rnd.t.conduit.xyz:443"
        }
      }
    ]
  }
};