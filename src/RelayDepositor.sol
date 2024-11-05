// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title  DepositRouter
/// @author Reservoir
/// @notice A public router contract for linking onchain deposits to Relay requestIds.
///         Verifiers can listen to emitted Deposit events to link a deposit to its
///         corresponding order.
contract DepositRouter {
    /// @notice Revert if native transfer failed
    error NativeTransferFailed();

    /// @notice Emit event when deposit is made
    event Deposit(address indexed to, address indexed token, uint256 value, bytes4 indexed requestId);

    constructor() {}

    /// @dev There is no receive() hook since funds must be sent with msg.data
    // containing the recipient address and requestId. The requestId should be
    // followed by the recipient address.
    fallback() external payable {
        // Decode the recipient address and requestId from msg.data
        (bytes4 requestId, address to) = abi.decode(msg.data, (bytes4, address));

        // Transfer the funds to the recipient
        _send(to, msg.value);

        // Emit the Deposit event
        emit Deposit(to, address(0), msg.value, requestId);
    }

    /// @notice Transfer native tokens to `address to` and emit a Deposit event
    /// @param to The recipient address
    /// @param requestId The requestId associated with the order
    function transferNative(address to, bytes4 requestId) external payable {
        // Transfer the funds to the recipient
        send(to, msg.value);

        // Emit the Deposit event
        emit Deposit(to, address(0), msg.value, requestId);
    }

    /// @notice Pull ERC20 tokens from `address from` and emit a Deposit event
    /// @param token The ERC20 token to transfer
    /// @param from The address to transfer tokens from
    /// @param amount The amount of tokens to transfer
    /// @param requestId The requestId associated with the order
    function transferErc20(address token, address from, uint256 amount, bytes4 requestId) external {
        // Transfer the ERC20 tokens to msg.sender
        IERC20(token).safeTransferFrom(from, msg.sender, amount);

        // Emit the Deposit event
        emit Deposit(to, token, amount, requestId);
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
