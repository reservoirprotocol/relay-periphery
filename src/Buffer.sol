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
