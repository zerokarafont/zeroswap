import { expect } from 'chai'
import { waffle, ethers } from 'hardhat'
import { pairFixture } from './shared/fixtures'
import {
  ZeroswapERC20,
  ZeroswapPair,
  ZeroswapFactory
} from '../typechain-types/contracts'

const { provider, createFixtureLoader } = waffle
const { Contract, BigNumber } = ethers
const { parseUnits } = ethers.utils
const { AddressZero } = ethers.constants

const MINIMUM_LIQUIDITY = BigNumber.from(10).pow(3)

const overrides = {
  gasLimit: 9999999
}

describe('ZeroswapPair', () => {
  const [wallet, other] = provider.getWallets()
  const loadFixture = createFixtureLoader([wallet], provider)

  let factory: ZeroswapFactory
  let token0: InstanceType<typeof Contract>
  let token1: InstanceType<typeof Contract>
  let pair: ZeroswapPair
  beforeEach(async () => {
    const fixture = await loadFixture(pairFixture)
    factory = fixture.factory as ZeroswapFactory
    token0 = fixture.token0
    token1 = fixture.token1
    pair = fixture.pair as ZeroswapPair
  })

  it('mint', async () => {
    const token0Amount = parseUnits('1', 18)
    const token1Amount = parseUnits('4', 18)
    await token0.transfer(pair.address, token0Amount)
    await token1.transfer(pair.address, token1Amount)

    const expectedLiquidity = parseUnits('2', 18)
    await expect(pair.mint(wallet.address, overrides))
      .to.emit(pair, 'Transfer')
      .withArgs(AddressZero, AddressZero, MINIMUM_LIQUIDITY)
      .to.emit(pair, 'Transfer')
      .withArgs(AddressZero, wallet.address, expectedLiquidity.sub(MINIMUM_LIQUIDITY))
      .to.emit(pair, 'Sync')
      .withArgs(token0Amount, token1Amount)
      .to.emit(pair, 'Mint')
      .withArgs(wallet.address, token0Amount, token1Amount)

    // expect(await pair.totalSupply()).to.eq(expectedLiquidity)
    // expect(await pair.balanceOf(wallet.address)).to.eq(expectedLiquidity.sub(MINIMUM_LIQUIDITY))
    // expect(await token0.balanceOf(pair.address)).to.eq(token0Amount)
    // expect(await token1.balanceOf(pair.address)).to.eq(token1Amount)
    // const reserves = await pair.getReserves()
    // expect(reserves[0]).to.eq(token0Amount)
    // expect(reserves[1]).to.eq(token1Amount)
  })
})