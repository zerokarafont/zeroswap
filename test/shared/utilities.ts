import { ethers, network } from 'hardhat';

const { Contract, BigNumber } = ethers;
const { Web3Provider } = ethers.providers;
const { 
  getCreate2Address,
  keccak256, 
  defaultAbiCoder, 
  toUtf8Bytes, 
  solidityPack,
} = ethers.utils;

const PERMIT_TYPEHASH = keccak256(
  toUtf8Bytes('Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)')
)

export function expandTo18Decimals(n: number): InstanceType<typeof BigNumber> {
  return BigNumber.from(n).mul(BigNumber.from(10).pow(18))
}

function getDomainSeparator(name: string, tokenAddress: string) {
  const chainId = network.config.chainId;
  console.log("chainId", chainId)
  return keccak256(
    defaultAbiCoder.encode(
      ['bytes32', 'bytes32', 'bytes32', 'uint256', 'address'],
      [
        keccak256(toUtf8Bytes('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)')),
        keccak256(toUtf8Bytes(name)),
        keccak256(toUtf8Bytes('1')),
        chainId,
        tokenAddress
      ]
    )
  )
}

export function getPairCreate2Address(
  factoryAddress: string,
  [tokenA, tokenB]: [string, string],
  bytecode: string
) {
  const [token0, token1] = tokenA < tokenB ? [tokenA, tokenB] : [tokenB, tokenA]
  const salt = keccak256(solidityPack(['address', 'address'], [token0, token1]))
  const codehash = keccak256(bytecode)

  return getCreate2Address(factoryAddress, salt, codehash)
}

export async function getApprovalDigest(
  token: InstanceType<typeof Contract>,
  approve: {
    owner: string,
    spender: string,
    value: InstanceType<typeof BigNumber>
  },
  nonce: InstanceType<typeof BigNumber>,
  deadline: InstanceType<typeof BigNumber>
) {
  const name = await token.name()
  const DOMAIN_SEPARATOR = getDomainSeparator(name, token.address)
  return keccak256(
    solidityPack(
      ['bytes1', 'bytes1', 'bytes32', 'bytes32'],
      [
        '0x19',
        '0x01',
        DOMAIN_SEPARATOR,
        keccak256(
          defaultAbiCoder.encode(
            ['bytes32', 'address', 'address', 'uint256', 'uint256', 'uint256'],
            [PERMIT_TYPEHASH, approve.owner, approve.spender, approve.value, nonce, deadline]
          )
        )
      ]
    )
  )
}

export function encodePrice(reserve0: InstanceType<typeof BigNumber>, reserve1: InstanceType<typeof BigNumber>) {
  return [reserve1.mul(BigNumber.from(2).pow(112)).div(reserve0), reserve0.mul(BigNumber.from(2).pow(112)).div(reserve1)]
}