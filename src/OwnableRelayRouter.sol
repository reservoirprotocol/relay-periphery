// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {RelayRouter} from "./RelayRouter.sol";

/// @title OwnableRelayRouter
/// @notice An owned RelayRouter that can only be called by the owner
contract OwnableRelayRouter is RelayRouter, Ownable {
    constructor(address permit2, address owner) RelayRouter(permit2) {
        // Set the owner that can perform multicalls and withdraw funds stuck in the contract
        _initializeOwner(owner);
    }

    /// @notice Withdraw function in case funds get stuck in contract
    function withdraw() external onlyOwner {
        _send(msg.sender, address(this).balance);
    }

    /// @notice Pull user ERC20 tokens through a signed batch permit
    ///         and perform an arbitrary multicall. Pass in an empty
    ///         permitSignature to only perform the multicall.
    /// @dev msg.value will persist across all calls in the multicall
    /// @param user The address of the user
    /// @param permit The permit details
    /// @param targets The addresses of the contracts to call
    /// @param datas The calldata for each call
    /// @param values The value to send with each call
    /// @param refundTo The address to refund any leftover ETH to
    /// @param permitSignature The signature for the permit
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        address[] calldata targets,
        bytes[] calldata datas,
        uint256[] calldata values,
        address refundTo,
        bytes memory permitSignature
    ) external payable override onlyOwner returns (bytes[] memory) {
        super.permitMulticall(
            user,
            permit,
            targets,
            datas,
            values,
            refundTo,
            permitSignature
        );
    }

    /// @notice Perform the multicall and send leftover ETH to the refundTo address
    /// @dev    If a multicall is expecting to mint ERC721s or ERC1155s, the recipient must be explicitly set
    ///         All calls to ERC721s and ERC1155s in the multicall will have the same recipient set in refundTo
    ///         If refundTo is address(this), be sure to transfer tokens out of the router as part of the multicall
    /// @param targets The addresses of the contracts to call
    /// @param datas The calldata for each call
    /// @param values The value to send with each call
    /// @param refundTo The address to send any leftover ETH and set as recipient of ERC721/ERC1155 mints
    function multicall(
        address[] calldata targets,
        bytes[] calldata datas,
        uint256[] calldata values,
        address refundTo
    ) external payable override onlyOwner returns (bytes[] memory) {
        super.multicall(targets, datas, values, refundTo);
    }

    /// @notice Send leftover ERC20 tokens to the refundTo address
    /// @dev Should be included in the multicall if the router is expecting to receive tokens
    /// @param tokens The addresses of the ERC20 tokens
    /// @param recipients The addresses to refund the tokens to
    function cleanupErc20s(
        address[] calldata tokens,
        address[] calldata recipients
    ) public override onlyOwner {
        super.cleanupErc20s(tokens, recipients);
    }
}
