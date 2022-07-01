// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "./interfaces/IZeroswapFactory.sol";

import "./interfaces/IWETH.sol";
import "./interfaces/IZeroswapPair.sol";
import "./interfaces/IZeroswapRouter.sol";
import "./libraries/ZeroswapLibrary.sol";
import "./libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ZeroswapRouter is IZeroswapRouter {
	uint256 private constant UINT256_MAX = type(uint256).max;
	address public immutable override factory;
	address public immutable override WETH;

	modifier ensure(uint256 deadline) {
		require(deadline >= block.timestamp, "ZeroswapRouter: EXPIRED");
		_;
	}

	constructor(address _factory, address _WETH) {
		factory = _factory;
		WETH = _WETH;
	}

	receive() external payable {
		assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
	}

	// **** ADD LIQUIDITY ****
	function _addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin
	) internal virtual returns (uint256 amountA, uint256 amountB) {
		// create the pair if it doesn't exist yet
		if (IZeroswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
			IZeroswapFactory(factory).createPair(tokenA, tokenB);
		}
		(uint256 reserveA, uint256 reserveB) = ZeroswapLibrary.getReserves(
			factory,
			tokenA,
			tokenB
		);
		if (reserveA == 0 && reserveB == 0) {
			(amountA, amountB) = (amountADesired, amountBDesired);
		} else {
			uint256 amountBOptimal = ZeroswapLibrary.quote(
				amountADesired,
				reserveA,
				reserveB
			);
			if (amountBOptimal <= amountBDesired) {
				require(
					amountBOptimal >= amountBMin,
					"UniswapV2Router: INSUFFICIENT_B_AMOUNT"
				);
				(amountA, amountB) = (amountADesired, amountBOptimal);
			} else {
				uint256 amountAOptimal = ZeroswapLibrary.quote(
					amountBDesired,
					reserveB,
					reserveA
				);
				assert(amountAOptimal <= amountADesired);
				require(
					amountAOptimal >= amountAMin,
					"UniswapV2Router: INSUFFICIENT_A_AMOUNT"
				);
				(amountA, amountB) = (amountAOptimal, amountBDesired);
			}
		}
	}

	function addLiquidity(
		address tokenA,
		address tokenB,
		uint256 amountADesired,
		uint256 amountBDesired,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (
			uint256 amountA,
			uint256 amountB,
			uint256 liquidity
		)
	{
		(amountA, amountB) = _addLiquidity(
			tokenA,
			tokenB,
			amountADesired,
			amountBDesired,
			amountAMin,
			amountBMin
		);
		address pair = ZeroswapLibrary.pairFor(factory, tokenA, tokenB);
		SafeERC20.safeTransferFrom(IERC20(tokenA), msg.sender, pair, amountA);
		SafeERC20.safeTransferFrom(IERC20(tokenB), msg.sender, pair, amountB);
		liquidity = IZeroswapPair(pair).mint(to);
	}

	function addLiquidityETH(
		address token,
		uint256 amountTokenDesired,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	)
		external
		payable
		virtual
		override
		ensure(deadline)
		returns (
			uint256 amountToken,
			uint256 amountETH,
			uint256 liquidity
		)
	{
		(amountToken, amountETH) = _addLiquidity(
			token,
			WETH,
			amountTokenDesired,
			msg.value,
			amountTokenMin,
			amountETHMin
		);
		address pair = ZeroswapLibrary.pairFor(factory, token, WETH);
		SafeERC20.safeTransferFrom(
			IERC20(token),
			msg.sender,
			pair,
			amountToken
		);
		IWETH(WETH).deposit{ value: amountETH }();
		assert(IWETH(WETH).transfer(pair, amountETH));
		liquidity = IZeroswapPair(pair).mint(to);
		// refund dust eth, if any
		if (msg.value > amountETH)
			TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
	}

	// **** REMOVE LIQUIDITY ****
	function removeLiquidity(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline
	)
		public
		virtual
		override
		ensure(deadline)
		returns (uint256 amountA, uint256 amountB)
	{
		// create2计算出对应的pair合约地址
		address pair = ZeroswapLibrary.pairFor(factory, tokenA, tokenB);
		// 归还流动性token
		IZeroswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
		// 销毁LP Token，返还对应比例的 tokenA tokenB
		(uint256 amount0, uint256 amount1) = IZeroswapPair(pair).burn(to);
		(address token0, ) = ZeroswapLibrary.sortTokens(tokenA, tokenB);
		(amountA, amountB) = tokenA == token0
			? (amount0, amount1)
			: (amount1, amount0);
		require(amountA >= amountAMin, "ZeroswapRouter: INSUFFICIENT_A_AMOUNT");
		require(amountB >= amountBMin, "ZeroswapRouter: INSUFFICIENT_B_AMOUNT");
	}

	function removeLiquidityETH(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	)
		public
		virtual
		override
		ensure(deadline)
		returns (uint256 amountToken, uint256 amountETH)
	{
		(amountToken, amountETH) = removeLiquidity(
			token,
			WETH,
			liquidity,
			amountTokenMin,
			amountETHMin,
			address(this),
			deadline
		);
		TransferHelper.safeTransfer(token, to, amountToken);
		IWETH(WETH).withdraw(amountETH);
		TransferHelper.safeTransferETH(to, amountETH);
	}

	function removeLiquidityWithPermit(
		address tokenA,
		address tokenB,
		uint256 liquidity,
		uint256 amountAMin,
		uint256 amountBMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external virtual override returns (uint256 amountA, uint256 amountB) {
		address pair = ZeroswapLibrary.pairFor(factory, tokenA, tokenB);
		uint256 value = approveMax ? UINT256_MAX : liquidity;
		IZeroswapPair(pair).permit(
			msg.sender,
			address(this),
			value,
			deadline,
			v,
			r,
			s
		);
		(amountA, amountB) = removeLiquidity(
			tokenA,
			tokenB,
			liquidity,
			amountAMin,
			amountBMin,
			to,
			deadline
		);
	}

	function removeLiquidityETHWithPermit(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	)
		external
		virtual
		override
		returns (uint256 amountToken, uint256 amountETH)
	{
		address pair = ZeroswapLibrary.pairFor(factory, token, WETH);
		uint256 value = approveMax ? UINT256_MAX : liquidity;
		IZeroswapPair(pair).permit(
			msg.sender,
			address(this),
			value,
			deadline,
			v,
			r,
			s
		);
		(amountToken, amountETH) = removeLiquidityETH(
			token,
			liquidity,
			amountTokenMin,
			amountETHMin,
			to,
			deadline
		);
	}

	// **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
	function removeLiquidityETHSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline
	) public virtual override ensure(deadline) returns (uint256 amountETH) {
		(, amountETH) = removeLiquidity(
			token,
			WETH,
			liquidity,
			amountTokenMin,
			amountETHMin,
			address(this),
			deadline
		);
		TransferHelper.safeTransfer(
			token,
			to,
			IERC20(token).balanceOf(address(this))
		);
		IWETH(WETH).withdraw(amountETH);
		TransferHelper.safeTransferETH(to, amountETH);
	}

	function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
		address token,
		uint256 liquidity,
		uint256 amountTokenMin,
		uint256 amountETHMin,
		address to,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external virtual override returns (uint256 amountETH) {
		address pair = ZeroswapLibrary.pairFor(factory, token, WETH);
		uint256 value = approveMax ? UINT256_MAX : liquidity;
		IZeroswapPair(pair).permit(
			msg.sender,
			address(this),
			value,
			deadline,
			v,
			r,
			s
		);
		amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
			token,
			liquidity,
			amountTokenMin,
			amountETHMin,
			to,
			deadline
		);
	}

	// **** SWAP ****
	// requires the initial amount to have already been sent to the first pair
	/**
	 * @dev 从Pair合约转出对应的数量给_to地址
	 * @param amounts 路由路径中每一个pair对能兑换出的数量
	 	 比如 TokenA -> USDT -> TokenB , 得到 [amountsInTokenA, amountsOutUSDT(同时也是下一个对的输入), amountsOutTokenB]
	 * @param path 路由对
	 * @param _to 接受者地址
	 */
	function _swap(
		uint256[] memory amounts,
		address[] memory path,
		address _to
	) internal virtual {
		for (uint256 i; i < path.length - 1; i++) {
			// 获取路由路径上的每一个交易对
			(address input, address output) = (path[i], path[i + 1]);
			// 排序得知当时在Pair合约创建交易对时哪个是token0
			(address token0, ) = ZeroswapLibrary.sortTokens(input, output);
			// 获取每个对的输出数量
			uint256 amountOut = amounts[i + 1];
			// 判断对应到Pair合约中token0 token1 哪一个是正确的需要被转出的一方
			(uint256 amount0Out, uint256 amount1Out) = input == token0
				? (uint256(0), amountOut)
				: (amountOut, uint256(0));
			address to = i < path.length - 2
				? ZeroswapLibrary.pairFor(factory, output, path[i + 2]) // 如果路由不止一对，先转给下一个Pair对
				: _to; // 如果路由只有一对，直接转给接收者
			IZeroswapPair(ZeroswapLibrary.pairFor(factory, input, output)).swap(
					amount0Out,
					amount1Out,
					to,
					new bytes(0)
				);
		}
	}

  /**
	 * @dev 沿着路由路径将精确输入数量换成尽可能多输出数量
	 * @notice msg.sender 应该已经在Input Token上批准给了路由至少amountIn的数量
	 * @param amountIn 输入Token的数量
	 * @param amountOutMin 至少获得的输出数量 否则交易回滚
	 * @param path 路由路径 可能有中间对 比如 TokenA -> USDC -> TokenB
	 * @param to 接受者
	 * @param deadline 截止时间
	 * @return amounts 返回 [输入数量, 输出数量]
	 */
	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		amounts = ZeroswapLibrary.getAmountsOut(factory, amountIn, path);
		require(
			amounts[amounts.length - 1] >= amountOutMin,
			"ZeroswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
		// 将token path[0]从msg.sender 转给Pair合约 amounts[0]个
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, to);
	}

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		amounts = ZeroswapLibrary.getAmountsIn(factory, amountOut, path);
		require(
			amounts[0] <= amountInMax,
			"ZeroswapRouter: EXCESSIVE_INPUT_AMOUNT"
		);
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, to);
	}

	function swapExactETHForTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		payable
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		require(path[0] == WETH, "ZeroswapRouter: INVALID_PATH");
		amounts = ZeroswapLibrary.getAmountsOut(factory, msg.value, path);
		require(
			amounts[amounts.length - 1] >= amountOutMin,
			"ZeroswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
		IWETH(WETH).deposit{ value: amounts[0] }();
		assert(
			IWETH(WETH).transfer(
				ZeroswapLibrary.pairFor(factory, path[0], path[1]),
				amounts[0]
			)
		);
		_swap(amounts, path, to);
	}

	function swapTokensForExactETH(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		require(path[path.length - 1] == WETH, "ZeroswapRouter: INVALID_PATH");
		amounts = ZeroswapLibrary.getAmountsIn(factory, amountOut, path);
		require(
			amounts[0] <= amountInMax,
			"ZeroswapRouter: EXCESSIVE_INPUT_AMOUNT"
		);
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, address(this));
		IWETH(WETH).withdraw(amounts[amounts.length - 1]);
		TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
	}

	function swapExactTokensForETH(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		require(path[path.length - 1] == WETH, "ZeroswapRouter: INVALID_PATH");
		amounts = ZeroswapLibrary.getAmountsOut(factory, amountIn, path);
		require(
			amounts[amounts.length - 1] >= amountOutMin,
			"ZeroswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, address(this));
		IWETH(WETH).withdraw(amounts[amounts.length - 1]);
		TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
	}

	function swapETHForExactTokens(
		uint256 amountOut,
		address[] calldata path,
		address to,
		uint256 deadline
	)
		external
		payable
		virtual
		override
		ensure(deadline)
		returns (uint256[] memory amounts)
	{
		require(path[0] == WETH, "ZeroswapRouter: INVALID_PATH");
		amounts = ZeroswapLibrary.getAmountsIn(factory, amountOut, path);
		require(
			amounts[0] <= msg.value,
			"ZeroswapRouter: EXCESSIVE_INPUT_AMOUNT"
		);
		IWETH(WETH).deposit{ value: amounts[0] }();
		assert(
			IWETH(WETH).transfer(
				ZeroswapLibrary.pairFor(factory, path[0], path[1]),
				amounts[0]
			)
		);
		_swap(amounts, path, to);
		// refund dust eth, if any
		if (msg.value > amounts[0])
			TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
	}

	// **** SWAP (supporting fee-on-transfer tokens) ****
	// requires the initial amount to have already been sent to the first pair
	function _swapSupportingFeeOnTransferTokens(
		address[] memory path,
		address _to
	) internal virtual {
		for (uint256 i; i < path.length - 1; i++) {
			(address input, address output) = (path[i], path[i + 1]);
			(address token0, ) = ZeroswapLibrary.sortTokens(input, output);
			IZeroswapPair pair = IZeroswapPair(
				ZeroswapLibrary.pairFor(factory, input, output)
			);
			uint256 amountInput;
			uint256 amountOutput;
			{
				// scope to avoid stack too deep errors
				(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
				(uint256 reserveInput, uint256 reserveOutput) = input == token0
					? (reserve0, reserve1)
					: (reserve1, reserve0);
				amountInput =
					IERC20(input).balanceOf(address(pair)) -
					reserveInput;
				amountOutput = ZeroswapLibrary.getAmountOut(
					amountInput,
					reserveInput,
					reserveOutput
				);
			}
			(uint256 amount0Out, uint256 amount1Out) = input == token0
				? (uint256(0), amountOutput)
				: (amountOutput, uint256(0));
			address to = i < path.length - 2
				? ZeroswapLibrary.pairFor(factory, output, path[i + 2])
				: _to;
			pair.swap(amount0Out, amount1Out, to, new bytes(0));
		}
	}

	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external virtual override ensure(deadline) {
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amountIn
		);
		uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
		_swapSupportingFeeOnTransferTokens(path, to);
		require(
			IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >=
				amountOutMin,
			"ZerowapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
	}

	function swapExactETHForTokensSupportingFeeOnTransferTokens(
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external payable virtual override ensure(deadline) {
		require(path[0] == WETH, "ZeroswapRouter: INVALID_PATH");
		uint256 amountIn = msg.value;
		IWETH(WETH).deposit{ value: amountIn }();
		assert(
			IWETH(WETH).transfer(
				ZeroswapLibrary.pairFor(factory, path[0], path[1]),
				amountIn
			)
		);
		uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
		_swapSupportingFeeOnTransferTokens(path, to);
		require(
			IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >=
				amountOutMin,
			"ZeroswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
	}

	function swapExactTokensForETHSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external virtual override ensure(deadline) {
		require(path[path.length - 1] == WETH, "ZeroswapRouter: INVALID_PATH");
		TransferHelper.safeTransferFrom(
			path[0],
			msg.sender,
			ZeroswapLibrary.pairFor(factory, path[0], path[1]),
			amountIn
		);
		_swapSupportingFeeOnTransferTokens(path, address(this));
		uint256 amountOut = IERC20(WETH).balanceOf(address(this));
		require(
			amountOut >= amountOutMin,
			"ZeroswapRouter: INSUFFICIENT_OUTPUT_AMOUNT"
		);
		IWETH(WETH).withdraw(amountOut);
		TransferHelper.safeTransferETH(to, amountOut);
	}

	// **** LIBRARY FUNCTIONS ****
	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) public pure virtual override returns (uint256 amountB) {
		return ZeroswapLibrary.quote(amountA, reserveA, reserveB);
	}

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) public pure virtual override returns (uint256 amountOut) {
		return ZeroswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
	}

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) public pure virtual override returns (uint256 amountIn) {
		return ZeroswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
	}

	function getAmountsOut(uint256 amountIn, address[] memory path)
		public
		view
		virtual
		override
		returns (uint256[] memory amounts)
	{
		return ZeroswapLibrary.getAmountsOut(factory, amountIn, path);
	}

	function getAmountsIn(uint256 amountOut, address[] memory path)
		public
		view
		virtual
		override
		returns (uint256[] memory amounts)
	{
		return ZeroswapLibrary.getAmountsIn(factory, amountOut, path);
	}
}
