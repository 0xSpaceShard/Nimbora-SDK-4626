// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC4626 is ERC4626 {
    constructor(
        ERC20 asset
    ) ERC4626(asset) ERC20("Mock ERC4626 Token", "MERC4626") {}

    // Implement other abstract methods if any
}
