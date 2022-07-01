// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./interfaces/IZeroswapFactory.sol";
import "./ZeroswapPair.sol";
import "@openzeppelin/contracts/utils/Create2.sol";

contract ZeroswapFactory is IZeroswapFactory {
	address public override feeTo; // 收税地址
	address public override feeToSetter; // 拥有设置收税地址权限的(管理员)地址

	mapping(address => mapping(address => address)) public override getPair;
	address[] public override allPairs;

	constructor(address _feeToSetter) {
		feeToSetter = _feeToSetter;
	}

	function allPairsLength() external view override returns (uint256) {
		return allPairs.length;
	}

	function createPair(address tokenA, address tokenB)
		external
		override
		returns (address pair)
	{
		require(tokenA != tokenB, "Zeroswap: IDENTICAL_ADDRESSES");
		// 约定一个从小到大的排序
		(address token0, address token1) = tokenA < tokenB
			? (tokenA, tokenB)
			: (tokenB, tokenA);
		require(token0 != address(0), "Zeroswap: ZERO_ADDRESS");
		// 这里只检查单一方向即可，因为创建的时候是双向创建映射的
		require(getPair[token0][token1] == address(0), "Zeroswap: PAIR_EXISTS");

		bytes32 salt = keccak256(abi.encodePacked(token0, token1));
		bytes memory bytecode = type(ZeroswapPair).creationCode;
		pair = Create2.deploy(0, salt, bytecode);
		IZeroswapPair(pair).initialize(token0, token1);
		getPair[token0][token1] = pair;
		getPair[token1][token0] = pair;
		allPairs.push(pair);
		emit PairCreated(token0, token1, pair, allPairs.length);
	}

	/**
     @dev 设置收税地址
   */
	function setFeeto(address _feeTo) external override {
		require(msg.sender == feeToSetter, "Zeroswap: FORBIDDEN");
		feeTo = _feeTo;
	}

	/**
    @dev 设置管理员地址
   */
	function setFeeToSetter(address _feeToSetter) external override {
		require(msg.sender == feeToSetter, "Zeroswap: FORBIDDEN");
		feeToSetter = _feeToSetter;
	}
}
