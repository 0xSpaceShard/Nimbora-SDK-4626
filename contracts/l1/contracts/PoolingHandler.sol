// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./lib/Messaging.sol";
import {IPoolingHandler} from "./interfaces/IPoolingHandler.sol";
import {ErrorLib} from "./lib/ErrorLib.sol";

/// @author Spaceshard team 2023.
contract PoolingHandler is
    IPoolingHandler,
    Ownable,
    Pausable,
    ReentrancyGuard,
    Messaging
{
    /// @notice The function selector we have to call on L2 to consume the L1 message.
    uint256 public constant L2_HANDLER_SELECTOR =
        0x10e13e50cb99b6b3c8270ec6e16acfccbe1164a629d74b43549567a77593aff;

    /// @notice The yearn L2 pooling contract address.
    uint256 public l2Pooling;

    /// @notice vault address.
    IERC4626 public yield;

    /// @notice vault underlying address.
    IERC20 internal underlying;

    /// @notice StarkGate yield l1 address.
    address public l1YieldBridge;

    /// @notice Starknet Underlying bridge address.
    address public l1UnderlyingBridge;

    /// @notice The L2 Eth contract.
    uint256 public l2YieldBridge;

    /// @notice The L2 Underlying contract.
    uint256 public l2UnderlyingBridge;

    /// @notice Execute batches one by one.
    uint256 public batchCounter;

    /// @notice a constructor for the contract
    /// @param _yield Address of the Yield contract (IERC4626 interface)
    /// @param _starknetCore Address of the StarkNet core contract
    /// @param _l1YieldBridge Address of the L1 yield bridge contract
    /// @param _l1UnderlyingBridge Address of the L1 underlying asset bridge contract
    /// @param _l2YieldBridge L2 yield bridge identifier (likely a StarkNet address or identifier)
    /// @param _l2UnderlyingBridge L2 underlying asset bridge identifier
    constructor(
        address _yield,
        address _starknetCore,
        address _l1YieldBridge,
        address _l1UnderlyingBridge,
        uint256 _l2YieldBridge,
        uint256 _l2UnderlyingBridge
    ) Ownable() Pausable() {
        initializeMessaging(_starknetCore);
        yield = IERC4626(_yield);
        underlying = IERC20(yield.asset());
        yield.approve(_l1YieldBridge, type(uint256).max);
        underlying.approve(_l1UnderlyingBridge, type(uint256).max);
        l1UnderlyingBridge = _l1UnderlyingBridge;
        l1YieldBridge = _l1YieldBridge;
        l2YieldBridge = _l2YieldBridge;
        l2UnderlyingBridge = _l2UnderlyingBridge;
    }

    /// @notice execute a batch.
    /// @param _payload the payload data.
    /// @param _l2BridgeFee fee to handle bridge on L2.
    /// @param _l2MessagingFee fee to handle message on L2.
    function executeBatch(
        RequestPayload calldata _payload,
        uint256 _l2BridgeFee,
        uint256 _l2MessagingFee
    ) external payable nonReentrant whenNotPaused {
        // Check right batch
        if (batchCounter + 1 != _payload.nonce)
            revert ErrorLib.InvalidBatchNonce();

        // Check msg value correspond to fees
        if (msg.value == 2 * _l2BridgeFee + _l2MessagingFee)
            revert ErrorLib.InvalidFees();

        // Check calldata validity regarding the message sent from the L2 trove.
        _consumeL2Message(l2Pooling, _getRequestMessageData(_payload));

        // Calculate which action should be performed
        (VaultAction action, uint256 actionInput) = getActionInputs(
            _payload.amountUnder,
            _payload.amountYield
        );

        uint256 amountUnderOut;
        uint256 amountYieldOut;

        if (action == VaultAction.MINT) {
            uint256 underAmountUsed = yield.mint(actionInput, address(this));
            amountUnderOut = _payload.amountUnder - underAmountUsed;
            amountYieldOut = actionInput + _payload.amountYield;
        } else if (action == VaultAction.REDEEM) {
            uint256 assetsObtained = yield.redeem(
                actionInput,
                address(this),
                address(this)
            );
            amountUnderOut = _payload.amountUnder + assetsObtained;
            amountYieldOut = _payload.amountYield - actionInput;
        } else {
            amountUnderOut = _payload.amountUnder;
            amountYieldOut = _payload.amountYield;
        }

        if (amountUnderOut > 0) {
            depositToBridgeToken(
                l1UnderlyingBridge,
                l2Pooling,
                amountUnderOut,
                _l2BridgeFee
            );
        }

        if (amountYieldOut > 0) {
            depositToBridgeToken(
                l1YieldBridge,
                l2Pooling,
                amountYieldOut,
                _l2BridgeFee
            );
        }

        _sendMessageToL2(
            l2Pooling,
            L2_HANDLER_SELECTOR,
            _getRequestMessageData(
                RequestPayload({
                    nonce: _payload.nonce,
                    amountUnder: amountUnderOut,
                    amountYield: amountYieldOut
                })
            ),
            msg.value
        );

        batchCounter++;

        emit BatchProcessed(_payload.nonce, amountUnderOut, amountYieldOut);
    }

    /// @notice Admin function used to recover tokens that where accidentiliy transferred to this address.
    /// @param _token The address of the token to recover.
    /// @param _to The address to send the tokens to.
    function recoverTokens(address _token, address _to) external onlyOwner {
        if (_token == address(0)) {
            payable(_to).transfer(address(this).balance);
        } else {
            IERC20(_token).transfer(
                _to,
                IERC20(_token).balanceOf(address(this))
            );
        }
    }

    /// @notice Admin function used to pause the contract in the case of an emergency.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Admin function used to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice set bridge yield addresses.
    /// @param _l1YieldBridge The yield bridge on L1.
    /// @param _l2YieldBridge The yield bridge on L2.
    function setYieldBridge(
        address _l1YieldBridge,
        uint256 _l2YieldBridge
    ) external onlyOwner {
        l1YieldBridge = _l1YieldBridge;
        l2YieldBridge = _l2YieldBridge;
    }

    /// @notice set bridge underlying addresses.
    /// @param _l1UnderlyingBridge The yield bridge on L1.
    /// @param _l2UnderlyingBridge The yield bridge on L2.
    function setUndelyingBridge(
        address _l1UnderlyingBridge,
        uint256 _l2UnderlyingBridge
    ) external onlyOwner {
        l1UnderlyingBridge = _l1UnderlyingBridge;
        l2UnderlyingBridge = _l2UnderlyingBridge;
    }

    /// @title A utility function for processing RequestPayload data
    /// @dev This function splits each field of the RequestPayload into two uint256 integers.
    /// @param _payload The RequestPayload struct containing nonce, amountUnder, and amountYield
    /// @return data An array of uint256 representing the split values of the payload's fields
    function _getRequestMessageData(
        RequestPayload memory _payload
    ) internal pure returns (uint256[] memory data) {
        (uint256 lowNonce, uint256 highNonce) = u256(_payload.nonce);
        (uint256 lowAmountUnder, uint256 highAmountUnder) = u256(
            _payload.amountUnder
        );
        (uint256 lowAmountYield, uint256 highAmountYield) = u256(
            _payload.amountYield
        );
        data = new uint256[](6);
        data[0] = lowNonce;
        data[1] = highNonce;
        data[2] = lowAmountUnder;
        data[3] = highAmountUnder;
        data[4] = lowAmountYield;
        data[5] = highAmountYield;
    }

    /// @notice Helper to calculate which action we have to call `mint` or `redeem` after netting
    /// @param _amountUnder amount underlying
    /// @param _amountYield amount yield
    function getActionInputs(
        uint256 _amountUnder,
        uint256 _amountYield
    ) public returns (VaultAction action, uint256 actionAmountInput) {
        uint256 underlyingToShare = yield.previewDeposit(_amountUnder);
        if (underlyingToShare > _amountYield) {
            action = VaultAction.MINT;
            actionAmountInput = underlyingToShare - _amountYield;
        } else {
            if (underlyingToShare < _amountYield) {
                action = VaultAction.REDEEM;
                actionAmountInput = _amountYield - underlyingToShare;
            } else {
                action = VaultAction.NONE;
                actionAmountInput = 0;
            }
        }
    }
}
