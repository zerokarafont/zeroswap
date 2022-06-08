require('dotenv').config();
const hre = require('hardhat');
const constructorArguments = require('./contractArgs');

(async() => {
  await hre.run("verify:verify", {
    address: process.env.CONTRACT_ADDRESS,
    constructorArguments
  });
})();