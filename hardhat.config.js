require('dotenv').config();
require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.6',
      },
      // {
      //   version: "0.6.7",
      //   settings: {},
      // },
    ],
  },
  defaultNetwork: 'hardhat',
  settings: {
    // Hardhat Network can work with smart contracts compiled with optimizations,
    // but this may lead to your stack traces' line numbers being a little off.
    // We recommend compiling without optimizations when testing and debugging your contracts
    optimizer: {
      enabled: true,
      runs: 200,
    },
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 40000,
    // parallel: true
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_MAINNET_KEY}`,
        blockNumber: 10000835, // Uniswap V2 factory blocknumber on Mainnet
      },
      mining: {
        auto: true,
        // if auto is false, a new block will be mined after a random delay of between 3 and 6 seconds
        // interval: [3000, 6000]
      },
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_MAINNET_KEY}`,
      accounts: [],
    },
    rinkeby: {
      url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_RINKEBY_KEY}`,
      accounts: [],
    },
  },
};
