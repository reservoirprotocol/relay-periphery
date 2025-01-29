// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {RelayRouter} from "./RelayRouter.sol";
import {Multicall3} from "./utils/Multicall3.sol";

/// @title OwnableRelayRouter
/// @notice An owned RelayRouter that can only be called by the owner
contract OwnableRelayRouter is RelayRouter, Ownable {
    constructor(address permit2, address owner) RelayRouter(permit2) {
        // Set the owner that can perform multicalls and withdraw funds stuck in the contract
        _initializeOwner(owner);
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
        Multicall3.Call3Value[] calldata calls,
        bytes memory permitSignature
    )
        public
        payable
        override
        onlyOwner
        returns (Multicall3.Result[] memory returnData)
    {
        return super.permitMulticall(user, permit, calls, permitSignature);
    }

    /// @notice Perform the multicall and send leftover ETH to the refundTo address
    /// @dev    If a multicall is expecting to mint ERC721s or ERC1155s, the recipient must be explicitly set
    ///         All calls to ERC721s and ERC1155s in the multicall will have the same recipient set in refundTo
    ///         If refundTo is address(this), be sure to transfer tokens out of the router as part of the multicall
    /// @param calls The calls to perform
    /// @param nftRecipient The address to set as recipient of ERC721/ERC1155 mints
    function multicall(
        Multicall3.Call3Value[] calldata calls,
        address nftRecipient
    )
        public
        payable
        override
        onlyOwner
        returns (Multicall3.Result[] memory returnData)
    {
        return super.multicall(calls, nftRecipient);
    }

    /// @notice Send leftover ERC20 tokens to the refundTo address
    /// @dev Should be included in the multicall if the router is expecting to receive tokens
    /// @param tokens The addresses of the ERC20 tokens
    /// @param recipients The addresses to refund the tokens to
    function cleanupErc20s(
        address[] calldata tokens,
        address[] calldata recipients,
        uint256[] calldata amounts
    ) public override onlyOwner {
        super.cleanupErc20s(tokens, recipients, amounts);
    }

    /// @notice Send leftover native tokens to the recipient address
    /// @dev Set amount to 0 to transfer the full balance. Set recipient to address(0) to transfer to msg.sender
    /// @param amount The amount of native tokens to transfer
    /// @param recipient The recipient address
    function cleanupNative(
        uint256 amount,
        address recipient
    ) public override onlyOwner {
        super.cleanupNative(amount, recipient);
    }
}
