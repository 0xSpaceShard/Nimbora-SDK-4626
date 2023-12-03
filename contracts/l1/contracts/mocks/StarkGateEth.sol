//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StarkGateEth {
    constructor() {}

    receive() external payable {}

    fallback() external payable {}

    function withdraw(uint256 amount, address receiver) external {
        (bool success, ) = receiver.call{value: amount}("");
        require(success, "ETH transfer failed");
    }
}
