// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IPermit2} from "permit2-relay/src/interfaces/IPermit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  RelayDepositorV1
/// @author Reservoir
/// @notice A public utility contract for linking deposit transfers to a reference
contract RelayDepositorV1 {
    using SafeERC20 for IERC20;

    /// @notice Revert if native transfer failed
    error NativeTransferFailed();

    /// @notice Emit event when a deposit is made
    event Deposit(
        address indexed to,
        address indexed token,
        uint256 value,
        bytes32 id
    );

    IPermit2 private immutable PERMIT2;

    bytes32 public constant _EIP_712_DEPOSITOR_WITNESS_TYPEHASH =
        keccak256("DepositorWitness(address to,bytes32 id)");
    string public constant _DEPOSITOR_WITNESS_TYPESTRING =
        "DepositorWitness witness)DepositorWitness(address to,bytes32 id)TokenPermissions(address token,uint256 amount)";

    constructor(address permit2) {
        PERMIT2 = IPermit2(permit2);
    }

    /// @notice Transfer native tokens to `address to` and emit a Deposit event
    /// @param to The recipient address
    /// @param id The id associated with the transfer
    function transferNative(address to, bytes32 id) external payable {
        // Transfer the funds to the recipient
        _send(to, msg.value);

        // Emit the Deposit event
        emit Deposit(to, address(0), msg.value, id);
    }

    /// @notice Pull ERC20 tokens using a permit from `address from` and emit a Deposit event
    /// @param from The address to transfer tokens from
    /// @param to The recipient address
    /// @param permit The permit to consume
    /// @param id The id associated with the transfer
    /// @param permitSignature The signature for the permit
    function permitTransferErc20(
        address from,
        ISignatureTransfer.PermitTransferFrom memory permit,
        bytes32 id,
        bytes memory permitSignature
    ) external {
        // Create the witness that should be signed over
        bytes32 witness = keccak256(
            abi.encode(_EIP_712_DEPOSITOR_WITNESS_TYPEHASH, msg.sender, id)
        );

        // Get the token being transferred from the permit
        address token = permit.permitted.token;

        // Get the amount being transferred from the permit
        uint256 amount = permit.permitted.amount;

        // Create the SignatureTransferDetails
        ISignatureTransfer.SignatureTransferDetails
            memory signatureTransferDetails = ISignatureTransfer
                .SignatureTransferDetails({
                    to: msg.sender,
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
        emit Deposit(msg.sender, token, amount, id);
    }

    /// @notice Pull ERC20 tokens from `msg.sender` and emit a Deposit event
    /// @param to The recipient address
    /// @param token The ERC20 token to transfer
    /// @param amount The amount to transfer
    /// @param id The id associated with the transfer
    function approvalTransferErc20(
        address to,
        address token,
        uint256 amount,
        bytes32 id
    ) external {
        // Transfer the ERC20 tokens to the recipient
        IERC20(token).safeTransferFrom(msg.sender, to, amount);

        // Emit the Deposit event
        emit Deposit(to, token, amount, id);
    }

    /// @notice Transfer ERC20 tokens available in the contract and emit a Deposit event
    /// @param to The recipient address
    /// @param token The ERC20 token to transfer
    /// @param id The id associated with the transfer
    function transferErc20(address to, address token, bytes32 id) external {
        uint256 amount = IERC20(token).balanceOf(address(this));

        // Transfer the ERC20 tokens to the recipient
        IERC20(token).transfer(to, amount);

        // Emit the Deposit event
        emit Deposit(to, token, amount, id);
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
