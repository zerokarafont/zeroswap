const hre = require('hardhat');
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const constructorArguments = require('./contractArgs');

async function main() {
  const [owner] = await hre.ethers.getSigners();
  const NFT = await hre.ethers.getContractFactory("NFT");
  const nft = await NFT.deploy(...constructorArguments);

  await nft.deployed();
  console.log("Contract deployed to: ", nft.address);

  const envPath = join(__dirname, '../', '.env');
  const envFile = readFileSync(envPath, { encoding: 'utf-8' });
  const appendLine = `CONTRACT_ADDRESS = ${nft.address}`;
  const newFile = envFile.replace(/CONTRACT_ADDRESS = .*/, appendLine);
  writeFileSync(envPath, newFile, { flag: 'w' });
  console.log("Contract address appended to .env");

  // const txn = await nft.mint(owner.address, 2);
  // await txn.wait();
  // console.log("Sucessfully mint 2 nft");
};

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});