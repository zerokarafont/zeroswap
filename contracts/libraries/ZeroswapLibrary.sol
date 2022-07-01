// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "../interfaces/IZeroswapPair.sol";

library ZeroswapLibrary {
	// returns sorted token addresses, used to handle return values from pairs sorted in this order
	function sortTokens(address tokenA, address tokenB)
		internal
		pure
		returns (address token0, address token1)
	{
		require(tokenA != tokenB, "ZeroswapLibrary: IDENTICAL_ADDRESSES");
		(token0, token1) = tokenA < tokenB
			? (tokenA, tokenB)
			: (tokenB, tokenA);
		require(token0 != address(0), "ZeroswapLibrary: ZERO_ADDRESS");
	}

	// calculates the CREATE2 address for a pair without making any external calls
	function pairFor(
		address factory,
		address tokenA,
		address tokenB
	) internal pure returns (address pair) {
		(address token0, address token1) = sortTokens(tokenA, tokenB);
		pair = address(
			uint160(
				uint256(
					keccak256(
						abi.encodePacked(
							hex"ff",
							factory,
							keccak256(abi.encodePacked(token0, token1)),
							hex"96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f" // init code hash
						)
					)
				)
			)
		);
	}

	// fetches and sorts the reserves for a pair
	function getReserves(
		address factory,
		address tokenA,
		address tokenB
	) internal view returns (uint256 reserveA, uint256 reserveB) {
		(address token0, ) = sortTokens(tokenA, tokenB);
		(uint256 reserve0, uint256 reserve1, ) = IZeroswapPair(
			pairFor(factory, tokenA, tokenB)
		).getReserves();
		(reserveA, reserveB) = tokenA == token0
			? (reserve0, reserve1)
			: (reserve1, reserve0);
	}

	/**
	 * @dev 添加流动性时，计算最优的数量
	 * @notice 此方法是给添加流动性用的，不是要保持K为常量
	   按比例计算应该添加到流动性池中的数量
		 amountA   reserveA
		 ------- = -------- 
		 amountB   reserveB
	 *
	 */
	// given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) internal pure returns (uint256 amountB) {
		require(amountA > 0, "ZeroswapLibrary: INSUFFICIENT_AMOUNT");
		require(
			reserveA > 0 && reserveB > 0,
			"ZeroswapLibrary: INSUFFICIENT_LIQUIDITY"
		);
		amountB = (amountA * reserveB) / reserveA;
	}

	/**
		* @dev 公式 (A + ∆A)(B - ∆B) = AB
		* 即 ∆B = B * ∆A / (A + ∆A)
	 */
	// given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure returns (uint256 amountOut) {
		require(amountIn > 0, "ZeroswapLibrary: INSUFFICIENT_INPUT_AMOUNT");
		require(
			reserveIn > 0 && reserveOut > 0,
			"ZeroswapLibrary: INSUFFICIENT_LIQUIDITY"
		);
		// 0.3%的流动性提供者Fee会按比例分配给 Lp Provider
		// 每次交换完，K值会微小的增加
		uint256 amountInWithFee = amountIn * 997;

		uint256 numerator = amountInWithFee * reserveOut;

		uint256 denominator = reserveIn * 1000 + amountInWithFee;
		// 实际换出的数量会少一点，利益偏向了 LP Provider
		amountOut = numerator / denominator; // 四舍五入默认都是向下取整
	}

	/**
		* @dev 公式 (A + ∆A)(B - ∆B) = AB
		* 即 ∆A = A * ∆B / (B - ∆B)
	 */
	// given an output amount of an asset and pair reserves, returns a required input amount of the other asset
	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) internal pure returns (uint256 amountIn) {
		require(amountOut > 0, "ZeroswapLibrary: INSUFFICIENT_OUTPUT_AMOUNT");
		require(
			reserveIn > 0 && reserveOut > 0,
			"ZeroswapLibrary: INSUFFICIENT_LIQUIDITY"
		);

		uint256 numerator = reserveIn * amountOut * 1000;

		uint256 denominator = (reserveOut - amountOut) * 997;
		// 要求实际的输入数量要多一点， 利益偏向了LP Provider
		amountIn = (numerator / denominator) + 1; // 四舍五入手动向上取整
	}

	// performs chained getAmountOut calculations on any number of pairs
	function getAmountsOut(
		address factory,
		uint256 amountIn,
		address[] memory path
	) internal view returns (uint256[] memory amounts) {
		require(path.length >= 2, "ZeroswapLibrary: INVALID_PATH");
		amounts = new uint256[](path.length);
		amounts[0] = amountIn;
		for (uint256 i; i < path.length - 1; i++) {
			(uint256 reserveIn, uint256 reserveOut) = getReserves(
				factory,
				path[i],
				path[i + 1]
			);
			amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
		}
	}

	// performs chained getAmountIn calculations on any number of pairs
	function getAmountsIn(
		address factory,
		uint256 amountOut,
		address[] memory path
	) internal view returns (uint256[] memory amounts) {
		require(path.length >= 2, "ZeroswapLibrary: INVALID_PATH");
		amounts = new uint256[](path.length);
		amounts[amounts.length - 1] = amountOut;
		for (uint256 i = path.length - 1; i > 0; i--) {
			(uint256 reserveIn, uint256 reserveOut) = getReserves(
				factory,
				path[i - 1],
				path[i]
			);
			amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
		}
	}
}
