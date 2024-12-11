// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {IRelayEscrowManager} from "./interfaces/IRelayEscrowManager.sol";
import {ClaimStatus} from "./utils/RelayStructs.sol";

/// @title RelayEscrow v1
/// @notice RelayEscrowManager holds Relayer collateral and allows Users
///         to initiate claims against unfilled or incorrectly filled orders.
/// @author Reservoir0x
contract EscrowManager is IRelayEscrowManager, Ownable {
    using SignatureCheckerLib for address;

    event ClaimInitiated(address user, address relayer, bytes32 claimId);
    event ClaimSettled(bytes32 claimId, ClaimStatus claimStatus);
    event ClaimCancelled(bytes32 claimId);

    error InvalidSignature(address expectedSigner);
    error InvalidClaimStatus(
        bytes32 claimId,
        ClaimStatus expectedStatus,
        ClaimStatus actualStatus
    );
    error InsufficientFunds(uint256 amountAvailable, uint256 amountRequested);
    error ClaimAlreadyInitiated(bytes32 claimId);
    error ClaimAlreadySettled(bytes32 claimId);
    error ClaimNotInitiated(bytes32 orderHash);
    error ClaimWindowExpired(uint256 blockTimestamp, uint256 expiration);
    error EtherReturnTransferFailed(
        address recipient,
        uint256 amount,
        bytes data
    );

    uint96 public claimWindow;
    uint96 public responseWindow;

    /// @notice Mapping of relayer balances
    mapping(address => uint256) public balances;

    /// @notice Mapping of order hashes to claim statuses
    mapping(bytes32 => ClaimStatus) public claimStatus;

    constructor() {
        _initializeOwner(msg.sender);
    }

    receive() external payable {}

    /// @notice Deposit collateral on behalf of a relayer
    function depositEscrow(address relayer) public payable {
        // Increment the relayer's total balance
        balances[relayer] += msg.value;
    }

    /// @notice Withdraw collateral from the escrow contract
    /// @param amount The amount to withdraw
    function withdrawEscrow(uint256 amount) public {
        // Revert if amount exceeds withdrawable balance
        if (amount > balances[msg.sender])
            revert InsufficientFunds(balances[msg.sender], amount);

        unchecked {
            // Decrement the sender's total balance
            balances[msg.sender] -= amount;
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
    ) public returns (bytes32 orderHash) {
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

        // Emit an OrderInitiated event
        emit OrderInitiated(order.user, order.relayer, orderHash);
    }

    /// @notice Settle an order
    /// @param orderHash The hash of the order to settle
    /// @param salt The salt used to create the intentCommit
    /// @param validatorSig The validator's signature
    /// @param commitData The intentCommit data
    function settleOrder(
        bytes32 orderHash,
        uint256 salt,
        bytes memory validatorSig,
        bytes memory commitData
    ) public {
        Order memory order = orders[orderHash];

        // Check that the order status is initiated
        if (orderStatus[orderHash] != OrderStatus.Initiated)
            revert OrderNotInitiated(orderHash);

        // Check that hash of commitData matches commitment
        if (order.intentCommit != keccak256(abi.encode(commitData, salt)))
            revert InvalidCommitData(order.intentCommit, commitData, salt);

        // Validate the validator's signature and get the verdict
        Verdict verdict = _getVerdict(orderHash, validatorSig);

        // Decode the commitData
        (, TokenTransfer[] memory outputs) = abi.decode(
            commitData,
            (TokenTransfer[], TokenTransfer[])
        );

        // Settle the order's balances
        _settleBalances(order, outputs, verdict);

        emit OrderSettled(orderHash, verdict);
    }

    /// @notice Allows an order to be cancelled.
    ///         Validator can cancel the order if they determine the User
    ///         has not transferred to the Relayer by the order expiration.
    function cancelOrder(bytes32 orderHash, bytes memory validatorSig) public {
        Order memory order = orders[orderHash];

        // Check that the order status is initiated
        if (orderStatus[orderHash] != OrderStatus.Initiated)
            revert OrderNotInitiated(orderHash);

        // Validate the signature
        if (!order.validator.isValidSignatureNow(orderHash, validatorSig))
            revert InvalidSignature(order.validator);

        // Set the order status to cancelled
        orderStatus[orderHash] = OrderStatus.Cancelled;

        // Update the relayer's outstanding balance
        unchecked {
            balances[order.relayer].outstandingBalance -= order
                .collateralAmount;
        }

        // Emit an OrderCancelled event
        emit OrderCancelled(order.user, order.relayer, orderHash);
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

    /// @notice Internal function to initiate an order
    /// @param order The order to initiate
    /// @param orderHash The hash of the order
    function _initiateOrder(Order memory order, bytes32 orderHash) internal {
        // Check that the order status is NotInitiated
        if (orderStatus[orderHash] != OrderStatus.NotInitiated)
            revert OrderAlreadyInitiated(orderHash);

        // Check that the order has not expired
        if (order.expiration != 0 && block.timestamp > order.expiration)
            revert OrderExpired(block.timestamp, order.expiration);

        // Add the order to the orders mapping
        orders[orderHash] = order;

        // Set the order status to initiated
        orderStatus[orderHash] = OrderStatus.Initiated;

        // Update the relayer's outstanding balance
        balances[order.relayer].outstandingBalance += order.collateralAmount;

        // Add the order to the relayer's allocated orders
        relayerOrders[order.relayer].push(order);
    }

    /// @notice Internal function to validate the validator's signature,
    ///         update the order status and return the verdict
    /// @param orderHash The hash of the order
    /// @param validatorSig The validator's signature
    function _getVerdict(
        bytes32 orderHash,
        bytes memory validatorSig
    ) internal returns (Verdict verdict) {
        Order memory order = orders[orderHash];

        // Store the hash the validator must sign for a FulfilledPrimary verdict
        bytes32 fulfilledPrimaryVerdictHash = keccak256(
            abi.encodePacked(orderHash, Verdict.FulfilledPrimary)
        );

        // Store the hash the validator must sign for a FulfilledSecondary verdict
        bytes32 fulfilledSecondaryVerdictHash = keccak256(
            abi.encodePacked(orderHash, Verdict.FulfilledSecondary)
        );

        // Store the hash the validator must sign to refund collateral to the user
        bytes32 refundVerdictHash = keccak256(
            abi.encodePacked(orderHash, Verdict.Refund)
        );

        // If the validator signed a FulfilledPrimary verdict, set the orderStatus to
        // Settled__FulfilledPrimary and return a FulfilledPrimary verdict
        if (
            order.validator.isValidSignatureNow(
                fulfilledPrimaryVerdictHash,
                validatorSig
            )
        ) {
            orderStatus[orderHash] = OrderStatus.Settled__FulfilledPrimary;
            verdict = Verdict.FulfilledPrimary;
        } else if (
            // If the validator signed a FulfilledSecondary verdict, set the orderStatus to
            // Settled__FulfilledSecondary and return a FulfilledSecondary verdict
            order.validator.isValidSignatureNow(
                fulfilledSecondaryVerdictHash,
                validatorSig
            )
        ) {
            orderStatus[orderHash] = OrderStatus.Settled__FulfilledSecondary;
            verdict = Verdict.FulfilledSecondary;
        } else if (
            // If the validator signed a Refund verdict, set the orderStatus to
            // Settled__Refund and return a Refund verdict
            order.validator.isValidSignatureNow(refundVerdictHash, validatorSig)
        ) {
            orderStatus[orderHash] = OrderStatus.Settled__Refund;
            verdict = Verdict.Refund;
        } else {
            // Revert if the signature did not resolve to a valid verdict
            revert InvalidSignature(order.validator);
        }
    }
}
