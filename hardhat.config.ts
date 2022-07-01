import 'dotenv/config';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-etherscan';
import 'hardhat-contract-sizer';
/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: '0.8.6',
        settings: {
          // Hardhat Network can work with smart contracts compiled with optimizations,
          // but this may lead to your stack traces' line numbers being a little off.
          // We recommend compiling without optimizations when testing and debugging your contracts
          optimizer: {
            enabled: true,
            runs: 99999,
          },
        },
      },
      // {
      //   version: "0.6.7",
      //   settings: {},
      // },
    ],
  },
  defaultNetwork: 'hardhat',
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: true,
    only: ['ZeroswapFactory', 'ZeroswapRouter'],
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  mocha: {
    timeout: 12000,
    // parallel: true,
  },
  networks: {
    hardhat: {
      forking: {
        url: `https://eth-mainnet.alchemyapi.io/v2/${process.env.ALCHEMY_MAINNET_KEY}`,
        blockNumber: 4719568, // WETH blocknumber on Mainnet
      },
      mining: {
        auto: true,
        // if auto is false, a new block will be mined after a random delay of between 3 and 6 seconds
        // interval: [3000, 6000]
      },
      accounts: [
        { privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', balance: '10000000000000000000000' },
        { privateKey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', balance: '10000000000000000000000' }
      ]
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
