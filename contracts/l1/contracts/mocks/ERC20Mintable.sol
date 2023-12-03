//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mintable is ERC20 {
    uint8 _decimals;

    constructor(
        string memory name,
        string memory symbol,
        uint8 decimals_,
        uint256 initial_supply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initial_supply);
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}
