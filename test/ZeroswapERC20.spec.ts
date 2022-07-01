import 'dotenv/config'
import { expect } from 'chai'
import { ecsign } from 'ethereumjs-util'
import { waffle, ethers, network } from 'hardhat'
import { ZeroswapERC20 } from '../typechain-types/contracts/ZeroswapERC20'

const { 
  parseUnits,
  keccak256,
  hexlify,
  defaultAbiCoder,
  toUtf8Bytes
 } = ethers.utils
 const { BigNumber } = ethers
 const { MaxUint256 } = ethers.constants
 const { deployContract, provider } = waffle

 import ERC20JSON from '../artifacts/contracts/ZeroswapERC20.sol/ZeroswapERC20.json'
import { getApprovalDigest } from './shared/utilities'

 const TOTAL_SUPPLY = parseUnits('10000', 18)
 const TEST_AMOUNT = parseUnits('10', 18)

 describe('ZeroswapERC20', () => {
   const [wallet, other] = provider.getWallets()

   let token: ZeroswapERC20
   beforeEach(async () => {
     token = await deployContract(wallet, ERC20JSON) as ZeroswapERC20
     await token.initialSupply(wallet.address, TOTAL_SUPPLY)
   })

   it('name, symbol, decimals, totalSupply, balanceOf, DOMAIN_SEPERATOR, PERMIT_TYPEHASH', async () => {
      const chainId = network.config.chainId
      console.log("chainId", chainId)
      const name = await token.name()
      expect(name).to.be.eq(process.env.NAME)
      expect(await token.symbol()).to.be.eq(process.env.SYMBOL)
      expect(await token.decimals()).to.be.eq(18)
      expect(await token.totalSupply()).to.be.eq(TOTAL_SUPPLY)
      expect(await token.DOMAIN_SEPARATOR()).to.eq(
        keccak256(
          defaultAbiCoder.encode(
            ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
            [
              keccak256(
                toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')
              ),
              keccak256(toUtf8Bytes(name)),
              keccak256(toUtf8Bytes('1')),
              chainId,
              token.address
            ]
          )
        )
      )
   })

   it('approve', async () => {
    await expect(token.approve(other.address, TEST_AMOUNT))
      .to.emit(token, 'Approval')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
   })

   it('transfer', async () => {
    await expect(token.transfer(other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('transfer:fail', async () => {
    await expect(token.transfer(other.address, TOTAL_SUPPLY.add(1))).to.be.reverted // ds-math-sub-underflow
    await expect(token.connect(other).transfer(wallet.address, 1)).to.be.reverted // ds-math-sub-underflow
  })

  it('transferFrom', async () => {
    await token.approve(other.address, TEST_AMOUNT)
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(0)
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('transferFrom:max', async () => {
    await token.approve(other.address, MaxUint256)
    await expect(token.connect(other).transferFrom(wallet.address, other.address, TEST_AMOUNT))
      .to.emit(token, 'Transfer')
      .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(MaxUint256)
    expect(await token.balanceOf(wallet.address)).to.eq(TOTAL_SUPPLY.sub(TEST_AMOUNT))
    expect(await token.balanceOf(other.address)).to.eq(TEST_AMOUNT)
  })

  it('permit', async () => {
    const nonce = await token.nonces(wallet.address)
    const deadline = MaxUint256
    const digest = await getApprovalDigest(
      token,
      { owner: wallet.address, spender: other.address, value: TEST_AMOUNT },
      nonce,
      deadline
    )

    const { v, r, s } = ecsign(Buffer.from(digest.slice(2), 'hex'), Buffer.from(wallet.privateKey.slice(2), 'hex'))
    await expect(token.permit(wallet.address, other.address, TEST_AMOUNT, deadline, v, hexlify(r), hexlify(s)))
    .to.emit(token, 'Approval')
    .withArgs(wallet.address, other.address, TEST_AMOUNT)
    expect(await token.allowance(wallet.address, other.address)).to.eq(TEST_AMOUNT)
    expect(await token.nonces(wallet.address)).to.eq(BigNumber.from(1))
  })
 })
