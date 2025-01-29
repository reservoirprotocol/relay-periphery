// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {EIP712} from "solady/src/utils/EIP712.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {Multicall3} from "./utils/Multicall3.sol";

/// @title  CreditMaster
/// @author Reservoir
contract CreditMaster is Multicall3, Ownable, EIP712 {
    struct CallRequest {
        Multicall3.Call3Value[] call3Values;
        uint256 nonce;
    }
    using SafeTransferLib for address;
    using SignatureCheckerLib for address;

    /// @notice Revert if the allocator address is invalid
    error InvalidAllocator();

    /// @notice Revert if the signature is invalid
    error InvalidSignature();

    /// @notice Revert if the call request has already been used
    error CallRequestAlreadyUsed();

    /// @notice Emit event when a deposit is made
    event Deposit(address depositor, address token, uint256 value, bytes32 id);

    /// @notice Emit event when a call request is executed
    event CallRequestExecuted(bytes32 digest);

    /// @notice The EIP-712 typehash for the Call3Value struct
    bytes32 public constant _CALL3VALUE_TYPEHASH =
        keccak256(
            "Call3Value(address target,bool allowFailure,uint256 value,bytes callData)"
        );

    /// @notice The EIP-712 typehash for the Calls struct
    bytes32 public constant _CALLS_TYPEHASH =
        keccak256(
            "Calls(Call3Value[] calls,uint256 nonce)Call3Value(address target,bool allowFailure,uint256 value,bytes callData)"
        );

    /// @notice Mapping from withdrawal request digests to boolean values
    mapping(bytes32 => bool) public callRequests;

    /// @notice The allocator address
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

    /// @notice Execute a set of calls with a signed Calls struct from the Allocator
    /// @param calls The Calls struct
    /// @param signature The signature from the Allocator
    function execute(Calls calldata calls, bytes memory signature) external {
        bytes32[] memory call3ValuesHashes = new bytes32[](
            calls.call3Values.length
        );

        // Hash the call3Values
        for (uint256 i = 0; i < calls.call3Values.length; i++) {
            call3ValuesHashes[i] = _hashTypedData(
                keccak256(
                    abi.encode(
                        _CALL3VALUE_TYPEHASH,
                        calls.call3Values[i].target,
                        calls.call3Values[i].allowFailure,
                        calls.call3Values[i].value,
                        calls.call3Values[i].callData
                    )
                )
            );
        }

        // Get the EIP-712 digest to be signed
        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _CALLS_TYPEHASH,
                    keccak256(abi.encodePacked(call3ValuesHashes)),
                    calls.nonce
                )
            )
        );

        // Validate the allocator signature
        if (!allocator.isValidSignatureNow(digest, signature)) {
            revert InvalidSignature();
        }

        // Revert if the withdrawal request has already been used
        if (callRequests[digest]) {
            revert CallRequestAlreadyUsed();
        }

        // Mark the withdrawal request as used
        callRequests[digest] = true;

        // Execute the calls
        _aggregate3Value(calls.call3Values);

        emit CallRequestExecuted(digest);
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
