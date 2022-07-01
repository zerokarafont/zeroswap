import { waffle, ethers } from 'hardhat';
import { expect } from 'chai';
import { createFixtureLoader } from 'ethereum-waffle';
import { factoryFixture } from './shared/fixtures';
import { getPairCreate2Address } from './shared/utilities';

import ZeroswapPairJSON from '../artifacts/contracts/ZeroswapPair.sol/ZeroswapPair.json';
import { ZeroswapFactory, ZeroswapPair } from '../typechain-types';

const { deployContract, provider }  = waffle;
const { AddressZero } = ethers.constants;
const { BigNumber, Contract } = ethers;

const MOCK_TOKEN_ADDRESSES: [string, string] = [
  '0x1000000000000000000000000000000000000000',
  '0x2000000000000000000000000000000000000000'
]

const overrides = {
  gasLimit: 9999999
}

describe('ZeroswapFactory', () => {
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet, other], provider)

  let factory: ZeroswapFactory
  beforeEach(async () => {
    const fixture = await loadFixture(factoryFixture)
    factory = fixture.factory as ZeroswapFactory
  })

  it('feeTo, feeToSetter, allPairsLength', async () => {
    expect(await factory.feeTo()).to.eq(AddressZero)
    expect(await factory.feeToSetter()).to.eq(wallet.address)
    expect(await factory.allPairsLength()).to.eq(0)
  })

  async function createPair(tokens: [string, string]) {
    const bytecode = ZeroswapPairJSON.bytecode
    const create2Address = getPairCreate2Address(factory.address, tokens, bytecode)

    await expect(factory.createPair(...tokens, overrides))
    .to.emit(factory, 'PairCreated')
    .withArgs(MOCK_TOKEN_ADDRESSES[0], MOCK_TOKEN_ADDRESSES[1], create2Address, BigNumber.from(1))

    await expect(factory.createPair(...tokens, overrides)).to.be.reverted
    await expect(factory.createPair(tokens[1], tokens[0], overrides)).to.be.reverted
    expect(await factory.getPair(...tokens)).to.eq(create2Address)
    expect(await factory.getPair(tokens[1], tokens[0])).to.eq(create2Address)
    expect(await factory.allPairs(0)).to.eq(create2Address)
    expect(await factory.allPairsLength()).to.eq(1)

    const pair = new Contract(create2Address, ZeroswapPairJSON.abi, provider) as ZeroswapPair
    expect(await pair.factory()).to.eq(factory.address)
    expect(await pair.token0()).to.eq(MOCK_TOKEN_ADDRESSES[0])
    expect(await pair.token1()).to.eq(MOCK_TOKEN_ADDRESSES[1])
  }

  it('createPair', async () => {
    await createPair(MOCK_TOKEN_ADDRESSES)
  })

  it('createPair:reverse', async () => {
    await createPair(MOCK_TOKEN_ADDRESSES.slice().reverse() as [string, string])
  })

  it('createPair:gas', async () => {
    const tx = await factory.createPair(...MOCK_TOKEN_ADDRESSES)
    const receipt = await tx.wait()
    expect(receipt.gasUsed).to.eq(3267627)
  })

  it('setFeeTo', async () => {
    await expect(factory.connect(other).setFeeto(other.address)).to.be.revertedWith('Zeroswap: FORBIDDEN')
    await factory.setFeeto(wallet.address)
    expect(await factory.feeTo()).to.eq(wallet.address)
  })

  it('setFeeToSetter', async () => {
    await expect(factory.connect(other).setFeeToSetter(other.address)).to.be.revertedWith('Zeroswap: FORBIDDEN')
    await factory.setFeeToSetter(other.address)
    expect(await factory.feeToSetter()).to.eq(other.address)
    await expect(factory.setFeeToSetter(wallet.address)).to.be.revertedWith('Zeroswap: FORBIDDEN')
  })
})