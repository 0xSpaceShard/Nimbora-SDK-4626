// SPDX-License-Identifier: Apache-2.0.
pragma solidity ^0.8.0;

interface IStarknetMessaging {
    /// @notice Consumes a message that was sent from an L2 contract. Returns the hash of the message.
    function consumeMessageFromL2(
        uint256 fromAddress,
        uint256[] calldata payload
    ) external returns (bytes32);

    /// @notice Execute a function call on L2
    function sendMessageToL2(
        uint256 toAddress,
        uint256 selector,
        uint256[] calldata payload
    ) external payable returns (bytes32, uint256);

    function l2ToL1Messages(bytes32 msgHash) external view returns (uint256);
}
