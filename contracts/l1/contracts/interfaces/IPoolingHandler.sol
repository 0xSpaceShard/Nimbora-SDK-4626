// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IPoolingHandler {
    /// @notice RequestPayload
    /// @param nonce the batch nonce.
    /// @param amountUnder amount of underlying
    /// @param amountYield amount of yield
    struct RequestPayload {
        uint256 nonce;
        uint256 amountUnder;
        uint256 amountYield;
    }

    enum VaultAction {
        MINT,
        REDEEM,
        NONE
    }

    event BatchProcessed(
        uint256 nonce,
        uint256 amountUnderOut,
        uint256 amountYieldOut
    );
}
