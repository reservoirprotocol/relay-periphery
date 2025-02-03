// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {RelayRouter} from "./RelayRouter.sol";
import {Call3Value, Result} from "./utils/RelayStructs.sol";

/// @title OwnableRelayRouter
/// @notice An owned RelayRouter that can only be called by the owner
contract OwnableRelayRouter is RelayRouter, Ownable {
    constructor(address owner) RelayRouter() {
        // Set the owner that can perform multicalls and withdraw funds stuck in the contract
        _initializeOwner(owner);
    }

    /// @notice Perform the multicall and send leftover ETH to the refundTo address
    /// @dev    If a multicall is expecting to mint ERC721s or ERC1155s, the recipient must be explicitly set
    ///         All calls to ERC721s and ERC1155s in the multicall will have the same recipient set in refundTo
    ///         If refundTo is address(this), be sure to transfer tokens out of the router as part of the multicall
    /// @param calls The calls to perform
    /// @param nftRecipient The address to set as recipient of ERC721/ERC1155 mints
    function multicall(
        Call3Value[] calldata calls,
        address refundTo,
        address nftRecipient
    ) public payable override onlyOwner returns (Result[] memory returnData) {
        return super.multicall(calls, refundTo, nftRecipient);
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
