// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "./ZeroswapERC20.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/Math.sol";
import "./interfaces/IZeroswapCallee.sol";
import "./interfaces/IZeroswapPair.sol";
import "./interfaces/IZeroswapFactory.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ZeroswapPair is IZeroswapPair, ZeroswapERC20, ReentrancyGuard {
	using UQ112x112 for uint224;

	uint112 private constant UINT112_MAX = type(uint112).max;
	uint256 public constant override MINIMUM_LIQUIDITY = 10**3;
	bytes4 private constant SELECTOR =
		bytes4(keccak256(bytes("transfer(address,uint256)")));

	address public immutable override factory;
	address public override token0;
	address public override token1;

	uint112 private reserve0;
	uint112 private reserve1;
	uint32 private blockTimestampLast;

	uint256 public override price0CumulativeLast;
	uint256 public override price1CumulativeLast;
	uint256 public override kLast;

	function getReserves()
		public
		view
		override
		returns (
			uint112 _reserve0,
			uint112 _reserve1,
			uint32 _blockTimestampLast
		)
	{
		_reserve0 = reserve0;
		_reserve1 = reserve1;
		_blockTimestampLast = blockTimestampLast;
	}

	constructor() {
		factory = msg.sender;
	}

	function initialize(address _token0, address _token1) external override {
		require(msg.sender == factory, "Zeroswap: FORBIDDEN");
		token0 = _token0;
		token1 = _token1;
	}

	function _update(
		uint256 balance0,
		uint256 balance1,
		uint112 _reserve0,
		uint112 _reserve1
	) private {
		require(balance0 <= UINT112_MAX, "Zeroswap: OVERFLOW");

		uint32 blockTimestamp = uint32(block.timestamp % 2**32);
		uint32 timeElapsed = blockTimestamp - blockTimestampLast;
		if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
			price0CumulativeLast +=
				uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) *
				timeElapsed;
			price1CumulativeLast +=
				uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) *
				timeElapsed;
		}
		reserve0 = uint112(balance0);
		reserve1 = uint112(balance1);
		blockTimestampLast = blockTimestamp;
		emit Sync(reserve0, reserve1);
	}

	function _mintFee(uint112 _reserve0, uint112 _reserve1)
		private
		returns (bool feeOn)
	{
		// 收税地址
		address feeTo = IZeroswapFactory(factory).feeTo();
		feeOn = feeTo != address(0);
		uint256 _kLast = kLast; // gas savings
		if (feeOn) {
			if (_kLast != 0) {
				uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
				// 计算K值的平方根
				uint256 rootKLast = Math.sqrt(_kLast);
				if (rootK > rootKLast) {
					//分子 = LP erc20总量 * (rootK - rootKLast)
					uint256 numerator = totalSupply() - (rootK - rootKLast);
					//分母 = rootK * 5 + rootKLast
					uint256 denominator = rootK * 5 + rootKLast;
					//流动性 = 分子 / 分母
					uint256 liquidity = numerator / denominator;
					// 如果流动性 > 0 将流动性铸造给feeTo地址
					// TODO: 这里是铸造了LP token ?
					if (liquidity > 0) _mint(feeTo, liquidity);
				}
			}
		} else if (_kLast != 0) {
			kLast = 0;
		}
	}

	function mint(address to)
		external
		override
		nonReentrant
		returns (uint256 liquidity)
	{
		(uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
		// 在更新储备量之前，uniswap的周边合约会先调用 addLiquidity removeLiquidity swap等方法修改pair合约中token0 token1的数量
		uint256 balance0 = IERC20(token0).balanceOf(address(this));
		uint256 balance1 = IERC20(token1).balanceOf(address(this));
		// TODO: 这里不会溢出吗? 如果是移除流动性的情况
		// 获取用户增加的token0数量
		uint256 amount0 = balance0 - _reserve0;
		// 获取用户增加的token1数量
		uint256 amount1 = balance1 - _reserve1;

		bool feeOn = _mintFee(_reserve0, _reserve1);
		uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
		if (_totalSupply == 0) {
			// TODO: 在uniswap v1中，初始流动性份额LP Share设置为存入以太坊(wei)的数量，取决于最初存入流动资金的比率，因为V1都是ETH/token 对,  ...
			// 但是在v2中支持任意的ERC20对, 而且存在路由功能，所以V1那种和ETH挂钩的方式不适用了，我们需要一个计算LP Share的公式保证任何时候流动性份额的价值基本上和最初存入流动性资金的比率无关
			// 需要MINIMUM_LIQUIDITY的原因https://learnblockchain.cn/article/3004
			// 这里的sub是SafeMath， 是有溢出检查的，总之最小的LP Supply要大于等于10**3
			// https://rskswap.com/audit.html#orgc7f8ae1
			liquidity = Math.sqrt(amount0 * amount1 - MINIMUM_LIQUIDITY);
			//
			_mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
		} else {
			liquidity = Math.min(
				(amount0 * _totalSupply) / _reserve0,
				(amount1 * _totalSupply) / _reserve1
			);
		}
		require(liquidity > 0, "Zeroswap: INSUFFICIENT_LIQUIDITY_MINTED");
		_mint(to, liquidity);

		// 记录区块时间 更新储备量
		_update(balance0, balance1, _reserve0, _reserve1);
		// 存入流动性时收取费用, 需要更新K值
		if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
		emit Mint(msg.sender, amount0, amount1);
	}

	// this low-level function should be called from a contract which performs important safety checks
	function burn(address to)
		external
		override
		nonReentrant
		returns (uint256 amount0, uint256 amount1)
	{
		(uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
		address _token0 = token0; // gas savings
		address _token1 = token1; // gas savings
		uint256 balance0 = IERC20(_token0).balanceOf(address(this));
		uint256 balance1 = IERC20(_token1).balanceOf(address(this));
		// 获取当前pair合约的LP token
		uint256 liquidity = balanceOf(address(this));

		bool feeOn = _mintFee(_reserve0, _reserve1);
		// LP 总量
		uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
		amount0 = (liquidity * balance0) / _totalSupply; // using balances ensures pro-rata distribution
		amount1 = (liquidity * balance1) / _totalSupply; // using balances ensures pro-rata distribution
		require(
			amount0 > 0 && amount1 > 0,
			"Zeroswap: INSUFFICIENT_LIQUIDITY_BURNED"
		);
		_burn(address(this), liquidity);
		SafeERC20.safeTransfer(IERC20(_token0), to, amount0);
		SafeERC20.safeTransfer(IERC20(_token1), to, amount1);
		balance0 = IERC20(_token0).balanceOf(address(this));
		balance1 = IERC20(_token1).balanceOf(address(this));
		// 更新储备量
		_update(balance0, balance1, _reserve0, _reserve1);
		// 撤销流动性时收取费用，需要更新K值
		if (feeOn) kLast = uint256(reserve0) * reserve1; // reserve0 and reserve1 are up-to-date
		emit Burn(msg.sender, amount0, amount1, to);
	}

	function swap(
		uint256 amount0Out,
		uint256 amount1Out,
		address to,
		bytes calldata data
	) external override nonReentrant {
		require(
			amount0Out > 0 || amount1Out > 0,
			"ZeroswapV2: INSUFFICIENT_OUTPUT_AMOUNT"
		);
		(uint112 _reserve0, uint112 _reserve1, ) = getReserves(); // gas savings
		require(
			amount0Out < _reserve0 && amount1Out < _reserve1,
			"ZeroswapV2: INSUFFICIENT_LIQUIDITY"
		);

		uint256 balance0;
		uint256 balance1;
		{
			// scope for _token{0,1}, avoids stack too deep errors
			address _token0 = token0;
			address _token1 = token1;
			require(to != _token0 && to != _token1, "UniswapV2: INVALID_TO");
			if (amount0Out > 0)
				SafeERC20.safeTransfer(IERC20(_token0), to, amount0Out); // optimistically transfer tokens
			if (amount1Out > 0)
				SafeERC20.safeTransfer(IERC20(_token1), to, amount1Out); // optimistically transfer tokens
			// 对使用data参数。具体来说，如果data.length等于 0，则合约假设已经收到付款，并简单地将代币转移到该to地址。
			// 但是，如果data.length大于 0，说明to地址是个合约地址，然后在to地址上调用以下函数实行闪兑
			// TODO:
			if (data.length > 0)
				IZeroswapCallee(to).zeroswapCall(
					msg.sender,
					amount0Out,
					amount1Out,
					data
				);
			balance0 = IERC20(_token0).balanceOf(address(this));
			balance1 = IERC20(_token1).balanceOf(address(this));
		}
		// 取出的amount0和amount1有一个为0

		uint256 amount0In = balance0 > _reserve0 - amount0Out
			? balance0 - (_reserve0 - amount0Out)
			: 0;
		uint256 amount1In = balance1 > _reserve1 - amount1Out
			? balance1 - (_reserve1 - amount1Out)
			: 0;
		require(
			amount0In > 0 || amount1In > 0,
			"UniswapV2: INSUFFICIENT_INPUT_AMOUNT"
		);
		{
			// scope for reserve{0,1}Adjusted, avoids stack too deep errors
			uint256 balance0Adjusted = balance0 * 1000 - amount0In * 3;
			uint256 balance1Adjusted = balance1 * 1000 - amount1In * 3;
			// 确认路由合约收过税
			require(
				balance0Adjusted * balance1Adjusted >=
					uint256(_reserve0) * _reserve1 * (1000**2),
				"Zeroswap: K"
			);
		}

		_update(balance0, balance1, _reserve0, _reserve1);
		emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
	}

	function skim(address to) external override nonReentrant {
		address _token0 = token0; // gas savings
		address _token1 = token1; // gas savings
		SafeERC20.safeTransfer(
			IERC20(_token0),
			to,
			IERC20(_token0).balanceOf(address(this)) - reserve0
		);
		SafeERC20.safeTransfer(
			IERC20(_token1),
			to,
			IERC20(_token1).balanceOf(address(this)) - reserve1
		);
	}

	function sync() external override nonReentrant {
		_update(
			IERC20(token0).balanceOf(address(this)),
			IERC20(token1).balanceOf(address(this)),
			reserve0,
			reserve1
		);
	}
}
