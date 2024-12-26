// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {IRelayEscrowManager} from "./interfaces/IRelayEscrowManager.sol";
import {ClaimContext, ClaimStatus} from "./utils/RelayStructs.sol";
import {GaslessCrossChainOrder, ResolvedCrossChainOrder, Output, RelayInput, RelayOrderData, RelayOutput, WithdrawalRequest} from "./utils/ERC7683Structs.sol";

/// @title RelayEscrow v1
/// @notice RelayEscrowManager holds Relayer collateral and allows Users
///         to initiate claims against unfilled or incorrectly filled orders.
/// @author Reservoir0x
contract EscrowManager is IRelayEscrowManager, Ownable {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ClaimInitiated(address user, address relayer, bytes32 commitmentId);
    event ClaimResponseReceived(
        bytes32 commitmentId,
        bytes32 fillTxHash,
        ClaimStatus newClaimStatus
    );
    event ClaimSettled(bytes32 commitmentId, ClaimStatus claimStatus);
    event ClaimCancelled(bytes32 commitmentId);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error InsufficientBalance(
        uint256 requestedAmount,
        uint256 withdrawableBalance
    );
    error InvalidSignature(address expectedSigner);
    error InvalidClaimStatus(
        bytes32 commitmentId,
        ClaimStatus expectedStatus,
        ClaimStatus actualStatus
    );
    error InvalidDisputeBond(uint256 expectedDisputeBond, uint256 msgValue);
    error InvalidResponse(Response response);
    error ClaimWindowExpired(uint256 blockTimestamp, uint256 expiration);
    error EtherReturnTransferFailed(
        address recipient,
        uint256 amount,
        bytes data
    );

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint24 public claimWindow;
    uint24 public responseWindow;
    uint24 public arbitrationWindow;
    uint24 public withdrawalLockDuration;

    uint256 public disputeBond;

    /// @notice Mapping from address to EscrowBalance:
    mapping(address => EscrowBalance) public escrowBalances;

    /// @notice Mapping from address to WithdrawalRequest:
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    /// @notice Mapping of commitmentId to claim context
    mapping(bytes32 => ClaimContext) public claimContext;

    constructor(
        uint24 _claimWindow,
        uint24 _responseWindow,
        uint24 _arbitrationWindow,
        uint24 _withdrawalLockDuration,
        uint256 _disputeBond
    ) {
        _initializeOwner(msg.sender);
        claimWindow = _claimWindow;
        responseWindow = _responseWindow;
        arbitrationWindow = _arbitrationWindow;
        withdrawalLockDuration = _withdrawalLockDuration;
        disputeBond = _disputeBond;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                            OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setClaimWindow(uint24 _claimWindow) public onlyOwner {
        claimWindow = _claimWindow;
    }

    function setResponseWindow(uint24 _responseWindow) public onlyOwner {
        responseWindow = _responseWindow;
    }

    function setArbitrationWindow(uint24 _arbitrationWindow) public onlyOwner {
        arbitrationWindow = _arbitrationWindow;
    }

    function setDisputeBond(uint256 _disputeBond) public onlyOwner {
        disputeBond = _disputeBond;
    }

    function setWithdrawalLockDuration(
        uint24 _withdrawalLockDuration
    ) public onlyOwner {
        withdrawalLockDuration = _withdrawalLockDuration;
    }

    /*//////////////////////////////////////////////////////////////
                                CORE LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice Deposit collateral on behalf of a relayer
    /// @param relayer The address of the relayer
    function depositEscrow(address relayer) public payable {
        // Increment the relayer's total balance
        escrowBalances[relayer].totalBalance += msg.value;
    }

    /// @notice Withdraw collateral from the escrow contract
    function withdrawEscrow() public {
        uint256 amount = withdrawalRequests[msg.sender].amount;
        uint256 timelockExpiration = withdrawalRequests[msg.sender]
            .timelockExpiration;

        // Revert if withdrawal timelock has not expired yet
        if (timelockExpiration > block.timestamp) {
            revert TooSoon();
        }

        uint256 withdrawableBalance = escrowBalances[msg.sender].totalBalance -
            escrowBalances[msg.sender].outstandingBalance;

        // Revert if withdrawal amount exceeds withdrawable balance
        if (amount > withdrawableBalance)
            revert InsufficientFunds(withdrawableBalance, amount);

        unchecked {
            // Decrement the sender's total balance
            escrowBalances[msg.sender].totalBalance -= amount;
        }

        // Reset the sender's withdrawal request
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: 0,
            timelockExpiration: 0
        });

        // Transfer the amount to the relayer
        (bool success, bytes memory data) = payable(msg.sender).call{
            value: amount
        }("");

        // Revert with an error if the ether transfer failed.
        if (!success) {
            revert EtherReturnTransferFailed(msg.sender, amount, data);
        }
    }

    /// @notice Initiate a withdrawal request
    /// @param amount The amount to withdraw
    function initiateWithdrawal(uint256 amount) external {
        // Validate that the withdrawal amount is less than the user's withdrawable balance
        uint256 withdrawableBalance = escrowBalances[msg.sender].totalBalance -
            escrowBalances[msg.sender].lockedBalance;

        // Revert if the withdrawal amount exceeds the user's withdrawable balance
        if (amount > withdrawableBalance) {
            revert InsufficientBalance(amount, withdrawableBalance);
        }

        // Revert if the user has already initiated a withdrawal
        if (withdrawalRequests[msg.sender].timelockExpiration > 0) {
            revert WithdrawalAlreadyInitiated();
        }

        // Set the withdrawal request
        withdrawalRequests[msg.sender] = WithdrawalRequest({
            amount: amount,
            timelockExpiration: block.timestamp + withdrawalLockDuration
        });
    }

    /// @notice Initiate a new claim
    /// @param order The cross chain order
    /// @param depositTxHash The hash of the deposit transaction
    /// @param relayerSig The relayer's signature
    /// @return resolvedOrder The resolved cross chain order
    /// @return commitmentId The commitmentId of the claim
    function initiateClaim(
        GaslessCrossChainOrder order,
        bytes32 depositTxHash,
        bytes memory relayerSig
    )
        public
        payable
        returns (ResolvedCrossChainOrder resolvedOrder, bytes32 commitmentId)
    {
        // Decode the commitmentId, bond, and salt from the orderData
        (bytes32 commitmentId, uint256 bond, bytes32 salt) = abi.decode(
            order.orderData,
            (bytes32, uint256, bytes32)
        );

        // Generate the order hash
        bytes32 orderHash = _getOrderHash(order);

        // Validate the relayer signature
        _validateRelayerSignature(order.relayer, orderHash, relayerSig);

        // Validate that the claim has not already been initiated
        _validateClaimStatus(order.commitmentId, ClaimStatus.NotInitiated);

        // Validate that the claim window has not expired
        _validateClaimWindow(order.fillDeadline);

        // Validate the bond amount and update the user's balance
        _validateDisputeBond();

        // Resolve the order to a ResolvedCrossChainOrder
        resolvedOrder = _resolveOrder(order);

        // Set the claim status to initiated
        _initiateClaim(commitment.commitmentId);

        // Emit a ClaimInitated event
        emit ClaimInitiated(
            commitment.user,
            commitment.relayer,
            commitment.commitmentId
        );

        return commitment.commitmentId;
    }

    function respondToClaim__relayer(
        bytes32 commitmentId,
        bytes32 fillTxHash,
        Response response
    ) public returns (bytes32 commitmentId) {
        // Validate the claim status
        _validateClaimStatus(
            commitmentId,
            ClaimStatus.Initiated__awaitingRelayerResponse
        );

        // Validate that the response window has not expired
        _validateResponseDeadline(commitmentId);

        // Set the claim status based on the Relayer's response
        _validateRelayerResponse(Response);

        // Emit a ClaimResponseReceived event
        emit ClaimResponseReceived(
            commitmentId,
            fillTxHash,
            ClaimStatus.Initiated__awaitingUserResponse
        );
    }

    function respondToClaim__user(
        bytes32 commitmentId,
        Response response
    ) public {}

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function _getOrderHash(
        GaslessCrossChainOrder order
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    order.originSettler,
                    order.user,
                    order.nonce,
                    order.originChainId,
                    order.openDeadline,
                    order.fillDeadline,
                    order.orderDataType,
                    order.orderData
                )
            );
    }

    function _validateRelayerResponse(
        Response response,
        bytes32 commitmentId
    ) internal view {
        // Revert if response is not a Relayer response
        if (
            response != Response.Relayer__settle ||
            response != Response.Relayer__dispute
        ) {
            revert InvalidResponse(response);
        }

        // If Relayer wishes to settle, set the claim status
        if (response == Response.Relayer__settle) {
            claimContext[commitmentId].status = ClaimStatus
                .Initiated__relayerSettle__awaitingUserResponse;
        }
    }

    function _resolveOrder(
        GaslessCrossChainOrder order
    ) internal view returns (ResolvedCrossChainOrder resolvedOrder) {
        // Decode the RelayOrderData from orderData
        RelayOrderData orderData = abi.decode(
            order.orderData,
            (RelayOrderData)
        );

        Output[] memory maxSpent = new Output[](1);

        // Convert RelayOutput to maxSpent
        maxSpent[0] = Output({
            token: orderData.output.token,
            amount: orderData.output.amount,
            recipient: orderData.output.to,
            chainId: orderData.output.chainId
        });

        Output[] memory minReceived = new Output[](orderData.inputs.length);

        // Convert RelayInput to minReceived
        for (uint256 i = 0; i < orderData.inputs.length; i++) {
            minReceived[i] = Output({
                token: orderData.inputs[i].token,
                amount: orderData.inputs[i].amount,
                recipient: orderData.inputs[i].to,
                chainId: orderData.inputs[i].chainId
            });
        }

        // Create the ResolvedCrossChainOrder
        resolvedOrder = ResolvedCrossChainOrder({
            user: order.user,
            originChainId: order.originChainId,
            openDeadline: order.openDeadline,
            fillDeadline: order.fillDeadline,
            orderId: orderData.commitmentId,
            maxSpent: maxSpent, // TODO: come back to fillInstructions
            minReceived: minReceived,
            fillInstructions: orderData.fillInstructions
        });
    }

    function _initiateClaim(bytes32 commitmentId) internal {
        // Set the claim status to initiated
        claimContext[commitmentId] = ClaimStatus
            .Initiated__awaitingRelayerResponse;

        // Set the response deadline
        claimContext[commitmentId].responseDeadline =
            block.timestamp +
            responseWindow;

        // Lock msg.sender's dispute bond
        escrowBalances[msg.sender].locked += msg.value;

        // Update msg.sender's total balance
        escrowBalances[msg.sender].totalBalance += msg.value;
    }

    function _validateDisputeBond() internal {
        // Validate the dispute bond amount
        if (msg.value != disputeBond) {
            revert InvalidDisputeBond(disputeBond, msg.value);
        }

        // Update the user's locked balance
        escrowBalances[msg.sender].lockedBalance += msg.value;

        // Update the user's total balance
        escrowBalances[msg.sender].totalBalance += msg.value;
    }

    function _validateRelayerSignature(
        address relayer,
        bytes32 orderHash,
        bytes relayerSig
    ) internal view {
        // Validate the relayer's signature
        if (!relayer.isValidSignatureNow(orderHash, relayerSig))
            revert InvalidSignature(relayer);
    }

    function _validateClaimStatus(
        bytes32 commitmentId,
        ClaimStatus expectedStatus
    ) internal view {
        // Validate the claim status
        if (claimContext[commitmentId] != expectedStatus)
            revert InvalidClaimStatus(
                commitmentId,
                expectedStatus,
                claimContext[commitmentId]
            );
    }

    function _validateClaimWindow(uint256 fillDeadline) internal view {
        // Calculate the claim window expiration
        uint256 claimInitiationDeadline = fillDeadline + claimWindow;

        // Validate that the claim window has not expired
        if (block.timestamp > claimInitiationDeadline) {
            revert ClaimWindowExpired(block.timestamp, claimInitiationDeadline);
        }
    }

    function _validateResponseDeadline(bytes32 commitmentId) internal view {
        // Determine if the claim is awaiting a relayer response or user response
        bool awaitingRelayer = claimContext[commitmentId].status ==
            ClaimStatus.Initiated__awaitingRelayerResponse
            ? true
            : false;

        // If awaiting relayer response, validate that the relayer response deadline has not expired
        if (
            awaitingRelayer &&
            block.timestamp > claimContext[commitmentId].relayerResponseDeadline
        ) {
            revert ClaimWindowExpired(
                block.timestamp,
                claimContext[commitmentId].relayerResponseDeadline
            );
            // If awaiting user response, validate that the user response deadline has not expired
        } else if (
            !awaitingRelayer &&
            block.timestamp > claimContext[commitmentId].userResponseDeadline
        ) {
            revert ClaimWindowExpired(
                block.timestamp,
                claimContext[commitmentId].userResponseDeadline
            );
        }
    }
}
