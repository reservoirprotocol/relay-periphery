// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

struct WithdrawRequest {
    address token;
    uint256 amount;
    address to;
}

/// @title  RelayCredit
/// @author Reservoir
contract RelayCredit {
    using SafeTransferLib for address;
    using SignatureCheckerLib for address;

    error InvalidAllocator();

    error InvalidSignature();

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
        token.safeTransferFrom(msg.sender, address(this), amount);

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
        token.safeTransferFrom(from, address(this), amount);

        // Emit the Deposit event
        emit Deposit(token, amount, id);
    }

    /// @notice Withdraw tokens from the contract with a signed WithdrawRequest from the Allocator
    /// @param request The WithdrawRequest struct
    /// @param signature The signature from the Allocator
    function withdraw(
        WithdrawRequest calldata request,
        bytes memory signature
    ) external {
        // Get the request hash
        bytes32 requestHash = keccak256(
            abi.encode(request.token, request.amount, request.to)
        );

        // Validate the allocator signature
        if (!allocator.isValidSignatureNow(requestHash, signature)) {
            revert InvalidSignature();
        }

        // If the token is native, transfer ETH to the recipient
        if (request.token == address(0)) {
            request.to.safeTransferETH(request.amount);
        } else {
            // Transfer the ERC20 tokens to the recipient
            request.token.safeTransfer(request.to, request.amount);
        }
    }
}
