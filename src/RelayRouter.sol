// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Tstorish} from "tstorish/src/Tstorish.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "permit2-relay/src/interfaces/IPermit2.sol";
import {Multicall3} from "./utils/Multicall3.sol";

struct RelayerWitness {
    address relayer;
}

contract RelayRouter is Multicall3, Tstorish {
    using SafeERC20 for IERC20;

    // --- Errors --- //
    /// @notice Revert if this contract is set as the recipient
    error InvalidRecipient(address recipient);

    /// @notice Revert if the target is invalid
    error InvalidTarget(address target);

    /// @notice Revert if the native transfer failed
    error NativeTransferFailed();

    /// @notice Revert if no recipient is set
    error NoRecipientSet();

    /// @notice Revert if the array lengths do not match
    error ArrayLengthsMismatch();

    uint256 RECIPIENT_STORAGE_SLOT =
        uint256(keccak256("ERC20Router.recipient"));

    IPermit2 private immutable PERMIT2;
    address private immutable MULTICALLER;

    string public constant _RELAYER_WITNESS_TYPE_STRING =
        "RelayerWitness witness)RelayerWitness(address relayer)TokenPermissions(address token,uint256 amount)";
    bytes32 public constant _EIP_712_RELAYER_WITNESS_TYPE_HASH =
        keccak256("RelayerWitness(address relayer)");

    constructor(address permit2) Tstorish() {
        // Set the address of the Permit2 contract
        PERMIT2 = IPermit2(permit2);
    }

    /// @notice Withdraw function in case funds get stuck in contract
    /// @dev Any account can call this function to withdraw the contract's balance
    function withdraw() public {
        _send(msg.sender, address(this).balance);
    }

    /// @notice Pull user ERC20 tokens through a signed batch permit
    ///         and perform an arbitrary multicall. Pass in an empty
    ///         permitSignature to only perform the multicall.
    /// @dev msg.value will persist across all calls in the multicall
    /// @param user The address of the user
    /// @param permit The permit details
    /// @param calls The calls to perform
    /// @param permitSignature The signature for the permit
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        Call3Value[] calldata calls,
        bytes memory permitSignature
    ) external payable returns (Result[] memory returnData) {
        if (permitSignature.length != 0) {
            // Use permit to transfer tokens from user to router
            _handlePermitBatch(user, permit, permitSignature);
        }

        // Perform the multicall and send leftover to refundTo
        returnData = _aggregate3Value(calls);
    }

    /// @notice Call the Multicaller with a delegatecall to set the ERC20Router as the
    ///         sender of the calls to the targets.
    /// @dev    If a multicall is expecting to mint ERC721s or ERC1155s, the recipient must be explicitly set
    ///         All calls to ERC721s and ERC1155s in the multicall will have the same recipient set in recipient
    ///         Be sure to transfer ERC20s or ETH out of the router as part of the multicall
    /// @param calls The calls to perform
    /// @param nftRecipient The address to set as recipient of ERC721/ERC1155 mints
    function multicall(
        Call3Value[] calldata calls,
        address nftRecipient
    ) external payable returns (Result[] memory returnData) {
        // Set the NFT recipient if provided
        if (nftRecipient != address(0)) {
            _setRecipient(nftRecipient);
        }

        // Perform the multicall
        returnData = _aggregate3Value(calls);

        // Clear the recipient in storage
        _clearRecipient();

        // Refund any leftover ETH to the sender
        if (address(this).balance > 0) {
            _send(msg.sender, address(this).balance);
        }
    }

    /// @notice Send leftover ERC20 tokens to the refundTo address
    /// @dev Should be included in the multicall if the router is expecting to receive tokens
    /// @param tokens The addresses of the ERC20 tokens
    /// @param recipients The addresses to refund the tokens to
    function cleanupErc20s(
        address[] calldata tokens,
        address[] calldata recipients
    ) public {
        // Revert if array lengths do not match
        if (tokens.length != recipients.length) {
            revert ArrayLengthsMismatch();
        }

        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            address recipient = recipients[i];

            // Check the router's balance for the token
            uint256 balance = IERC20(token).balanceOf(address(this));

            // Transfer the token to the recipient address
            if (balance > 0) {
                IERC20(token).safeTransfer(recipient, balance);
            }
        }
    }

    /// @notice Internal function to handle a permit batch transfer
    /// @param user The address of the user
    /// @param permit The permit details
    /// @param permitSignature The signature for the permit
    function _handlePermitBatch(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory permitSignature
    ) internal {
        // Create the witness that should be signed over
        bytes32 witness = keccak256(
            abi.encode(_EIP_712_RELAYER_WITNESS_TYPE_HASH, msg.sender)
        );

        // Create the SignatureTransferDetails array
        ISignatureTransfer.SignatureTransferDetails[]
            memory signatureTransferDetails = new ISignatureTransfer.SignatureTransferDetails[](
                permit.permitted.length
            );
        for (uint256 i = 0; i < permit.permitted.length; i++) {
            uint256 amount = permit.permitted[i].amount;

            signatureTransferDetails[i] = ISignatureTransfer
                .SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount
                });
        }

        // Use the SignatureTransferDetails and permit signature to transfer tokens to the router
        PERMIT2.permitWitnessTransferFrom(
            permit,
            signatureTransferDetails,
            // When using a permit signature, cannot deposit on behalf of someone else other than `user`
            user,
            witness,
            _RELAYER_WITNESS_TYPE_STRING,
            permitSignature
        );
    }

    /// @notice Internal function to set the recipient address for ERC721 or ERC1155 mint
    /// @dev If the chain does not support tstore, recipient will be saved in storage
    /// @param recipient The address of the recipient
    function _setRecipient(address recipient) internal {
        // For safety, revert if the recipient is this contract
        // Tokens should either be minted directly to recipient, or transferred to recipient through the onReceived hooks
        if (recipient == address(this)) {
            revert InvalidRecipient(address(this));
        }

        // Set the recipient in storage
        _setTstorish(RECIPIENT_STORAGE_SLOT, uint256(uint160(recipient)));
    }

    /// @notice Internal function to get the recipient address for ERC721 or ERC1155 mint
    function _getRecipient() internal view returns (address) {
        // Get the recipient from storage
        return address(uint160(_getTstorish(RECIPIENT_STORAGE_SLOT)));
    }

    /// @notice Internal function to clear the recipient address for ERC721 or ERC1155 mint
    function _clearRecipient() internal {
        // Return if recipient hasn't been set
        if (_getRecipient() == address(0)) {
            return;
        }

        // Clear the recipient in storage
        _clearTstorish(RECIPIENT_STORAGE_SLOT);
    }

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

    function onERC721Received(
        address /*_operator*/,
        address /*_from*/,
        uint256 _tokenId,
        bytes calldata _data
    ) external returns (bytes4) {
        // Get the recipient from storage
        address recipient = _getRecipient();

        // Revert if no recipient is set
        // Note this means transferring NFTs to this contract via `safeTransferFrom` will revert,
        // unless the transfer is part of a multicall that sets the recipient in storage
        if (recipient == address(0)) {
            revert NoRecipientSet();
        }

        // Transfer the NFT to the recipient
        IERC721(msg.sender).safeTransferFrom(
            address(this),
            recipient,
            _tokenId,
            _data
        );

        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address /*_operator*/,
        address /*_from*/,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external returns (bytes4) {
        // Get the recipient from storage
        address recipient = _getRecipient();

        // Revert if no recipient is set
        // Note this means transferring NFTs to this contract via `safeTransferFrom` will revert,
        // unless the transfer is part of a multicall that sets the recipient in storage
        if (recipient == address(0)) {
            revert NoRecipientSet();
        }

        // Transfer the tokens to the recipient
        IERC1155(msg.sender).safeTransferFrom(
            address(this),
            recipient,
            _id,
            _value,
            _data
        );

        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address /*_operator*/,
        address /*_from*/,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external returns (bytes4) {
        // Get the recipient from storage
        address recipient = _getRecipient();

        // Revert if no recipient is set
        // Note this means transferring NFTs to this contract via `safeTransferFrom` will revert,
        // unless the transfer is part of a multicall that sets the recipient in storage
        if (recipient == address(0)) {
            revert NoRecipientSet();
        }

        // Transfer the tokens to the recipient
        IERC1155(msg.sender).safeBatchTransferFrom(
            address(this),
            recipient,
            _ids,
            _values,
            _data
        );

        return this.onERC1155BatchReceived.selector;
    }
}
