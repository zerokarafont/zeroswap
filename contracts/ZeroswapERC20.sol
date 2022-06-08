// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract ZeroswapERC20 is ERC20, ERC20Permit {
	constructor() ERC20("Zeroswap", "ZERO") ERC20Permit("Zeroswap") {}
}
