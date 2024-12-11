// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {IRelayEscrowManager} from "./interfaces/IRelayEscrowManager.sol";
import {ClaimContext, ClaimStatus} from "./utils/RelayStructs.sol";

/// @title RelayEscrow v1
/// @notice RelayEscrowManager holds Relayer collateral and allows Users
///         to initiate claims against unfilled or incorrectly filled orders.
/// @author Reservoir0x
contract EscrowManager is IRelayEscrowManager, Ownable {
    using SignatureCheckerLib for address;

    event ClaimInitiated(address user, address relayer, bytes32 commitmentId);
    event ClaimSettled(bytes32 commitmentId, ClaimStatus claimStatus);
    event ClaimCancelled(bytes32 commitmentId);

    error InvalidSignature(address expectedSigner);
    error InvalidClaimStatus(
        bytes32 commitmentId,
        ClaimStatus expectedStatus,
        ClaimStatus actualStatus
    );
    error InvalidDisputeBond(uint256 expectedDisputeBond, uint256 msgValue);
    error ClaimAlreadyInitiated(bytes32 commitmentId);
    error ClaimAlreadySettled(bytes32 commitmentId);
    error ClaimNotInitiated(bytes32 orderHash);
    error ClaimWindowExpired(uint256 blockTimestamp, uint256 expiration);
    error EtherReturnTransferFailed(
        address recipient,
        uint256 amount,
        bytes data
    );

    uint96 public claimWindow;
    uint96 public responseWindow;
    uint96 public arbitrationWindow;

    uint256 public disputeBond;

    /// @notice Mapping of relayer balances
    mapping(address => uint256) public balances;

    /// @notice Mapping of commitmentId to claim context
    mapping(bytes32 => ClaimStatus) public claimContext;

    constructor() {
        _initializeOwner(msg.sender);
    }

    receive() external payable {}

    /// @notice Deposit collateral on behalf of a relayer
    function depositEscrow(address relayer) public payable {
        // Increment the relayer's total balance
        balances[relayer].totalBalance += msg.value;
    }

    /// @notice Withdraw collateral from the escrow contract
    /// @param amount The amount to withdraw
    function withdrawEscrow(uint256 amount) public {
        uint256 withdrawableBalance = balances[msg.sender].totalBalance -
            balances[msg.sender].outstandingBalance;

        // Revert if amount exceeds withdrawable balance
        if (amount > withdrawableBalance)
            revert InsufficientFunds(withdrawableBalance, amount);

        unchecked {
            // Decrement the sender's total balance
            balances[msg.sender].totalBalance -= amount;
        }

        // Transfer the amount to the relayer
        (bool success, bytes memory data) = payable(msg.sender).call{
            value: amount
        }("");

        // Revert with an error if the ether transfer failed.
        if (!success) {
            revert EtherReturnTransferFailed(msg.sender, amount, data);
        }
    }

    /// @notice Initiate a new order
    /// @param order The order to initiate
    /// @param relayerSig The relayer's signature
    /// @return orderHash The hash of the initiated order
    function initiateClaim(
        Commitment commitment,
        bytes32 depositTxHash,
        bytes memory relayerSig
    ) public payable returns (bytes32 orderHash) {
        // Generate the commitment hash
        bytes32 commitmentHash = _getCommitmentHash(commitment);

        // Validate the relayer signature
        _validateRelayerSignature(
            commitment.relayer,
            commitmentHash,
            relayerSig
        );

        // Validate that the claim has not already been initiated
        _validateClaimStatus(commitment.commitmentId, ClaimStatus.NotInitiated);

        // Validate that the claim window has not expired
        _validateClaimWindow(commitment.quoteExpiration);

        // Validate the bond amount
        _validateBond();

        // Set the claim status to initiated
        _initiateClaim(commitment.commitmentId);

        // Emit a ClaimInitated event
        emit OrderInitiated(order.user, order.relayer, orderHash);
    }

    // /// @notice Allows an order to be cancelled.
    // ///         Validator can cancel the order if they determine the User
    // ///         has not transferred to the Relayer by the order expiration.
    // function cancelOrder(bytes32 orderHash, bytes memory validatorSig) public {
    //     Order memory order = orders[orderHash];

    //     // Check that the order status is initiated
    //     if (orderStatus[orderHash] != OrderStatus.Initiated)
    //         revert OrderNotInitiated(orderHash);

    //     // Validate the signature
    //     if (!order.validator.isValidSignatureNow(orderHash, validatorSig))
    //         revert InvalidSignature(order.validator);

    //     // Set the order status to cancelled
    //     orderStatus[orderHash] = OrderStatus.Cancelled;

    //     // Update the relayer's outstanding balance
    //     unchecked {
    //         balances[order.relayer].outstandingBalance -= order
    //             .collateralAmount;
    //     }

    //     // Emit an OrderCancelled event
    //     emit OrderCancelled(order.user, order.relayer, orderHash);
    // }

    function _initiateClaim(bytes32 commitmentId) internal {
        // Set the claim status to initiated
        claimStatus[commitmentId] = ClaimStatus
            .Initiated__awaitingRelayerResponse;

        // Set the response deadline
        claimContext[commitmentId].responseDeadline =
            block.timestamp +
            responseWindow;

        // Lock msg.sender's dispute bond
        balances[msg.sender].outstandingBalance += msg.value;

        // Update msg.sender's total balance
        balances[msg.sender].totalBalance += msg.value;
    }

    function _validateDisputeBond() internal {
        // Validate the dispute bond amount
        if (msg.value != disputeBond) {
            revert InvalidDisputeBond(disputeBond, msg.value);
        }
    }

    function _validateRelayerSignature(
        address relayer,
        bytes32 commitmentHash,
        bytes relayerSig
    ) internal view {
        // Validate the relayer's signature
        if (!relayer.isValidSignatureNow(commitmentHash, relayerSig))
            revert InvalidSignature(relayer);
    }

    function _validateClaimStatus(
        bytes32 commitmentId,
        ClaimStatus expectedStatus
    ) internal view {
        // Validate the claim status
        if (claimStatus[commitmentId] != expectedStatus)
            revert InvalidClaimStatus(
                commitmentId,
                expectedStatus,
                claimStatus[commitmentId]
            );
    }

    function _validateClaimWindow(uint256 quoteExpiration) internal view {
        // Calculate the claim window expiration
        uint256 claimWindowExpiration = quoteExpiration + claimWindow;

        // Validate that the claim window has not expired
        if (block.timestamp > claimWindowExpiration) {
            revert ClaimWindowExpired(block.timestamp, claimWindowExpiration);
        }
    }

    /// @notice Internal function to settle an order's balances by updating
    ///         the relayer's outstanding collateral balance and crediting
    ///         output fees
    /// @param order The order to settle
    /// @param outputs The outputs to settle
    /// @param verdict A boolean indicating whether the order was fulfilled
    function _settleBalances(
        Order memory order,
        TokenTransfer[] memory outputs,
        Verdict verdict
    ) internal {
        // Update the relayer's outstanding balanceg
        balances[order.relayer].outstandingBalance -= order.collateralAmount;

        // If the verdict was Refund, refund the collateral to the user
        if (verdict == Verdict.Refund) {
            // Subtract the collateral amount from the relayer's totalCollateralBalance
            balances[order.relayer].totalBalance -= order.collateralAmount;

            // Add the collateral amount to the user's relayEthBalance
            balances[order.user].relayEthBalance += order.collateralAmount;
        }

        // Iterate over outputs to check if balances need to be updated
        for (uint256 i = 0; i < outputs.length; i++) {
            TokenTransfer memory output = outputs[i];

            // If chainId is 0, deduct from `from` and add to `to`
            if (output.token == address(0) && output.chainId == 0) {
                // Revert if the `from` address does not have enough relayEthBalance
                if (output.amount > balances[output.from].relayEthBalance) {
                    revert InsufficientFunds(
                        balances[output.from].relayEthBalance,
                        output.amount
                    );
                }

                // Deduct the amount from the `from` address
                balances[output.from].relayEthBalance -= output.amount;

                // Add the amount to the `to` address
                balances[output.to].relayEthBalance += output.amount;
            }
        }
    }
}
