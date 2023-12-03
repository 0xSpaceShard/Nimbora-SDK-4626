//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    uint constant _initial_supply = 1000 * (10 ** 18);

    receive() external payable {}

    fallback() external payable {}

    constructor() ERC20("Wrapped ETH", "WETH") {
        _mint(msg.sender, _initial_supply);
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external {
        _burn(msg.sender, value);
        (bool success, ) = msg.sender.call{value: value}("");
        require(success, "WETH: ETH transfer failed");
    }
}
