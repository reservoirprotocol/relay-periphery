// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EIP712} from "solady/src/utils/EIP712.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

struct WithdrawRequest {
    address token;
    uint256 amount;
    address to;
}

/// @title  CreditMaster
/// @author Reservoir
contract CreditMaster is Ownable, EIP712 {
    using SafeTransferLib for address;
    using SignatureCheckerLib for address;

    error InvalidAllocator();

    error InvalidSignature();

    /// @notice Revert if native transfer failed
    error NativeTransferFailed();

    /// @notice Emit event when a deposit is made
    event Deposit(address depositor, address token, uint256 value, bytes32 id);

    /// @notice Emit event when a withdrawal is made
    event Withdrawal(address token, uint256 amount, address to, bytes32 digest);

    bytes32 public constant _WITHDRAW_REQUEST_TYPEHASH =
        keccak256("WithdrawRequest(address token,uint256 amount,address to)");

    address public allocator;

    constructor(address _allocator) {
        allocator = _allocator;
        _initializeOwner(msg.sender);
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
    /// @param depositor The address of the depositor to credit. Set to address(0) to credit msg.sender
    /// @param id The id associated with the transfer
    function depositNative(address depositor, bytes32 id) external payable {
        address depositorAddress = depositor == address(0)
            ? msg.sender
            : depositor;

        // Emit the Deposit event
        emit Deposit(depositorAddress, address(0), msg.value, id);
    }

    /// @notice Deposit ERC20 token from msg.sender to the contract and emit a Deposit event
    /// @param depositor The address of the depositor to credit. Set to address(0) to credit msg.sender
    /// @param token The ERC20 token to transfer
    /// @param amount The amount to transfer
    /// @param id The id associated with the transfer
    function depositErc20(
        address depositor,
        address token,
        uint256 amount,
        bytes32 id
    ) external {
        // Transfer the tokens to the contract
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Get the depositor address
        address depositorAddress = depositor == address(0)
            ? msg.sender
            : depositor;

        // Emit the Deposit event
        emit Deposit(depositorAddress, token, amount, id);
    }

    /// @notice Withdraw tokens from the contract with a signed WithdrawRequest from the Allocator
    /// @param request The WithdrawRequest struct
    /// @param signature The signature from the Allocator
    function withdraw(
        WithdrawRequest calldata request,
        bytes memory signature
    ) external {
        // Get the EIP-712 digest to be signed
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _WITHDRAW_REQUEST_TYPEHASH,
                    request.token,
                    request.amount,
                    request.to
                )
            )
        );

        // Validate the allocator signature
        if (!allocator.isValidSignatureNow(digest, signature)) {
            revert InvalidSignature();
        }

        // If the token is native, transfer ETH to the recipient
        if (request.token == address(0)) {
            request.to.safeTransferETH(request.amount);
        } else {
            // Transfer the ERC20 tokens to the recipient
            request.token.safeTransfer(request.to, request.amount);
        }

        emit Withdrawal(request.token, request.amount, request.to, digest);
    }

    function _domainNameAndVersion()
        internal
        pure
        override
        returns (string memory name, string memory version)
    {
        name = "CreditMaster";
        version = "1";
    }
}
