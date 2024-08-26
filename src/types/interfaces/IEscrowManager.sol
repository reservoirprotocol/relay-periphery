// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Order} from "../lib/RelayStructs.sol";

interface IEscrowManager {
    function depositCollateral(address relayer) external payable;

    function depositRelayEth(address relayer) external payable;

    function withdrawCollateral(uint256 amount) external;

    /// @notice Initiate a new order
    /// @param order The order to initiate
    /// @param relayerSig The relayer's signature
    /// @return orderHash The hash of the initiated order
    function initiateOrder(
        Order memory order,
        bytes memory relayerSig
    ) external returns (bytes32 orderHash);

    /// @notice Settle an order
    /// @param orderHash The hash of the order to settle
    /// @param salt The salt used to create the order hash
    /// @param validatorSig The validator's signature
    /// @param commitData The commit data
    function settleOrder(
        bytes32 orderHash,
        uint256 salt,
        bytes memory validatorSig,
        bytes memory commitData
    ) external;
}
