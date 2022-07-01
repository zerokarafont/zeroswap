import 'dotenv/config';
import { waffle, ethers } from 'hardhat';
import { Web3Provider } from '@ethersproject/providers';

import ERC20 from '@openzeppelin/contracts/build/contracts/ERC20PresetFixedSupply.json';
import ZeroswapFactoryJSON from '../../artifacts/contracts/ZeroswapFactory.sol/ZeroswapFactory.json';
import ZeroswapPairJSON from '../../artifacts/contracts/ZeroswapPair.sol/ZeroswapPair.json';

const { deployContract } = waffle;
const { Contract, Wallet } = ethers

type ContractType = InstanceType<typeof Contract>
type WalletType = InstanceType<typeof Wallet>

interface FactoryFixture {
  factory: ContractType
}

const overrides = {
  gasLimit: 9999999
}

export async function factoryFixture([wallet]: WalletType[], _: Web3Provider, ): Promise<FactoryFixture> {
  const factory = await deployContract(wallet, ZeroswapFactoryJSON, [wallet.address], overrides);
  return { factory };
}

interface PairFixture extends FactoryFixture {
  token0: ContractType
  token1: ContractType
  pair: ContractType
}

export async function pairFixture([wallet]: WalletType[], provider: Web3Provider): Promise<PairFixture> {
  const { factory } = await factoryFixture([wallet], provider)
  console.log('walletAddress', wallet.address)

  const tokenA = await deployContract(wallet, ERC20, [
    'tokenA',
    'TOKEN_A',
    ethers.utils.parseUnits('10000', 18),
    wallet.address
  ], overrides)
  const tokenB = await deployContract(wallet, ERC20, [
    'tokenB',
    'TOKEN_B',
    ethers.utils.parseUnits('10000', 18),
    wallet.address
  ], overrides)

  await factory.createPair(tokenA.address, tokenB.address, overrides)
  const pairAddress = await factory.getPair(tokenA.address, tokenB.address)
  const pair = new Contract(pairAddress, ZeroswapPairJSON.abi, provider).connect(wallet)

  const token0Address = await pair.token0()
  const token0 = tokenA.address === token0Address ? tokenA : tokenB
  const token1 = tokenA.address === token0Address ? tokenB : tokenA

  return { factory, token0, token1, pair }
}