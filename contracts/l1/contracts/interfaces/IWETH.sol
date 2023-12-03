// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.8.0;

interface IWETH {
    function deposit() external payable;

    function approve(address guy, uint wad) external returns (bool);

    function withdraw(uint256 wad) external;
}
