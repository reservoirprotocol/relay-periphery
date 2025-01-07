// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title  RelayDepositorV1
/// @author Reservoir
contract Relay {
    using SafeERC20 for IERC20;

    error InvalidAllocator();

    /// @notice Revert if native transfer failed
    error NativeTransferFailed();

    /// @notice Emit event when a deposit is made
    event Deposit(address indexed token, uint256 value, bytes32 id);

    address public allocator;

    // Emit a Deposit event when native tokens are received
    receive() external payable {
        emit Deposit(address(0), msg.value, msg.data);
    }

    constructor(address _allocator) {
        allocator = _allocator;
    }

    /// @notice Set the allocator address
    /// @param _allocator The new allocator address
    function setAllocator(address _allocator) external onlyOwner {
        if (_allocator == address(0)) {
            revert InvalidAllocator();
        }
        allocator = _allocator;
    }

    /// @notice Deposit native tokens to the contract and emit a Deposit event
    /// @param id The id associated with the transfer
    function depositNative(bytes32 id) external payable {
        // Emit the Deposit event
        emit Deposit(address(0), msg.value, id);
    }

    /// @notice Deposit ERC20 token from msg.sender to the contract and emit a Deposit event
    /// @param token The ERC20 token to transfer
    /// @param amount The amount to transfer
    /// @param id The id associated with the transfer
    function depositErc20(address token, uint256 amount, bytes32 id) external {
        // Transfer the tokens to the contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Emit the Deposit event
        emit Deposit(token, amount, id);
    }

    /// @notice Deposit ERC20 token from a specific address to the contract and emit a Deposit event
    /// @dev This function can be called by anyone; users should only approve the exact amount to be transferred to the contract
    /// @param token The ERC20 token to transfer
    /// @param from The address to transfer tokens from
    /// @param amount The amount to transfer
    /// @param id The id associated with the transfer
    function depositErc20From(
        address token,
        address from,
        uint256 amount,
        bytes32 id
    ) external {
        // Transfer the tokens to the contract
        IERC20(token).safeTransferFrom(from, address(this), amount);

        // Emit the Deposit event
        emit Deposit(token, amount, id);
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
