const chalk = require('chalk');
const hre = require('hardhat');
const { readFileSync, writeFileSync } = require('fs');
const { join } = require('path');
const constructorArguments = require('./contractArgs');

const rewriteEnv = (contract, name) => {
  const envPath = join(__dirname, '../', '.env');
  const envFile = readFileSync(envPath, { encoding: 'utf-8' });
  const appendLine = `${name} = ${contract.address}`;
  const reg = new RegExp(`${name} = .*`);
  const newFile = envFile.replace(reg, appendLine);
  writeFileSync(envPath, newFile, { flag: 'w' });
  console.log(chalk.blue(`${name} appended to .env`));
}

async function main() {
  const [owner] = await hre.ethers.getSigners();
  const ownerAccount = await owner.getAddress();

  // 部署工厂合约
  const Factory = await hre.ethers.getContractFactory("ZeroswapFactory");
  const factory = await Factory.deploy(ownerAccount);

  await factory.deployed();
  console.log(chalk.green("Factory Contract successfully deployed to: "), chalk.yellow(factory.address));

  rewriteEnv(factory, "FACTORY_ADDRESS");

  // 部署路由合约
  const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'; // fork主网环境上的WETH地址
  const Router = await hre.ethers.getContractFactory("ZeroswapRouter");
  const router = await Router.deploy(factory.address, WETH);

  await router.deployed();
  console.log(chalk.green("Router Contract successfully deployed to: "), chalk.yellow(router.address));

  rewriteEnv(router, "ROUTER_ADDRESS");

  console.log(chalk.magentaBright("deploy done."));
};

main()
.then(() => process.exit(0))
.catch((error) => {
  console.error(error);
  process.exit(1);
});