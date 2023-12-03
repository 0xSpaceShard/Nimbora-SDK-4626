//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StarkGate {
    address public _erc20;

    constructor(address erc20) {
        _erc20 = erc20;
    }

    function withdraw(uint256 amount, address receiver) external {
        IERC20(_erc20).transfer(receiver, amount);
    }
}
