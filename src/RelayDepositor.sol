// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPermit2} from "permit2-relay/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  DepositRouter
/// @author Reservoir
/// @notice A public router contract for linking onchain deposits to Relay requestIds.
///         Verifiers can listen to emitted Deposit events to link a deposit to its
///         corresponding order.
contract DepositRouter {
    using SafeERC20 for IERC20;

    /// @notice Revert if native transfer failed
    error NativeTransferFailed();

    /// @notice Emit event when deposit is made
    event Deposit(
        address indexed to,
        address indexed token,
        uint256 value,
        bytes32 commitmentId
    );

    IPermit2 private immutable PERMIT2;

    bytes32 public constant _EIP_712_DEPOSITOR_WITNESS_TYPEHASH =
        keccak256("DepositorWitness(bytes32 commitmentId)");
    string public constant _DEPOSITOR_WITNESS_TYPESTRING =
        "DepositorWitness witness)DepositorWitness(bytes32 commitmentId)TokenPermissions(address token,uint256 amount)";

    constructor(address permit2) {
        PERMIT2 = IPermit2(permit2);
    }

    /// @notice Transfer native tokens to `address to` and emit a Deposit event
    /// @param to The recipient address
    /// @param commitmentId The commitmentId associated with the order
    function transferNative(address to, bytes32 commitmentId) external payable {
        // Transfer the funds to the recipient
        _send(to, msg.value);

        // Emit the Deposit event
        emit Deposit(to, address(0), msg.value, commitmentId);
    }

    /// @notice Pull ERC20 tokens from `address from` and emit a Deposit event
    /// @param from The address to transfer tokens from
    /// @param permit The permit to consume
    /// @param commitmentId The commitmentId associated with the order
    /// @param permitSignature The signature for the permit
    function permitTransferErc20(
        address from,
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 commitmentId,
        bytes memory permitSignature
    ) external {
        // Create the witness that should be signed over
        bytes32 witness = keccak256(
            abi.encode(_EIP_712_DEPOSITOR_WITNESS_TYPEHASH, commitmentId)
        );

        // Get the token being transferred from the permit
        address token = permit.permitted.token;

        // Get the amount being transferred from the permit
        uint256 amount = permit.permitted.amount;

        // Create the SignatureTransferDetails
        ISignatureTransfer.SignatureTransferDetails
            memory signatureTransferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount
                });

        PERMIT2.permitWitnessTransferFrom(
            permit,
            signatureTransferDetails,
            from,
            witness,
            _DEPOSITOR_WITNESS_TYPESTRING,
            permitSignature
        );

        // Emit the Deposit event
        emit Deposit(msg.sender, token, amount, commitmentId);
    }

    function approvalTransferErc20(
        address from,
        address token,
        uint256 amount,
        bytes32 commitmentId
    ) external {
        // Transfer the ERC20 tokens to msg.sender
        IERC20(token).safeTransfer(from, msg.sender, amount);

        // Emit the Deposit event
        emit Deposit(msg.sender, token, amount, commitmentId);
    }

    /// @notice Internal function for transferring ETH
    /// @param to The recipient address
    /// @param value The value to send
    function _send(address to, uint256 value) internal {
        bool success;
        assembly {
            // Save gas by avoiding copying the return data to memory.
            // Provide at most 100k gas to the internal call, which is
            // more than enough to cover common use-cases of logic for
            // receiving native tokens (eg. SCW payable fallbacks).
            success := call(100000, to, value, 0, 0, 0, 0)
        }

        if (!success) {
            revert NativeTransferFailed();
        }
    }
}
