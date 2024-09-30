// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @title IMulticaller
 * @notice Interface for the Multicaller contract.
 */
interface IMulticaller {
    /**
     * @dev Aggregates multiple calls in a single transaction.
     * @param targets  An array of addresses to call.
     * @param data     An array of calldata to forward to the targets.
     * @param values   How much ETH to forward to each target.
     * @param refundTo The address to transfer any remaining ETH in the contract after the calls.
     *                 If `address(0)`, remaining ETH will NOT be refunded.
     *                 If `address(1)`, remaining ETH will be refunded to `msg.sender`.
     *                 If anything else, remaining ETH will be refunded to `refundTo`.
     * @return An array of the returndata from each call.
     */
    function aggregate(
        address[] calldata targets,
        bytes[] calldata data,
        uint256[] calldata values,
        address refundTo
    ) external payable returns (bytes[] memory);
}
