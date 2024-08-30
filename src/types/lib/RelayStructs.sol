// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

enum OrderStatus {
    NotInitiated,
    Initiated,
    Settled__FulfilledPrimary,
    Settled__FulfilledSecondary,
    Settled__Refund,
    Cancelled
}

enum Verdict {
    FulfilledPrimary,
    FulfilledSecondary,
    Refund
}

/// @notice A struct representing an input or output token transfer. These transfers must take place
///         on their respective chains in order for validators to sign the order.
/// @param token   The address of the token to transfer
/// @param from    The from address
/// @param to      The to address
/// @param amount  The amount to transfer
/// @param chainId The chainId of the transfer
struct TokenTransfer {
    address token; // address(0) for native, erc20 otherwise
    address from;
    address to;
    uint256 amount;
    uint256 chainId; // chainId of 0 means escrow balance should be transferred between `from` and `to`
}

/// @notice A call to be executed as part of the order. If a call is representing a "pre-hook", the output
///         of the call will be bridged to the destination chain. If a call is representing a "post-hook",
///         the output of the call will be sent to the user.
/// @param to        The address of the contract to call
/// @param isPreHook If true, the call is a "pre-hook". If false, the call is a "post-hook"
/// @param value     The value to send with the call
/// @param data      The data to send with the call
struct Route {
    address to;
    uint256 value;
    uint256 chainId;
    bytes data;
}

/// @notice An order that can be sequenced and settled by the protocol
///         To complete the order lifecycle, the order must be signed by the user, relayer, validator, and oracle
/// @param user             The address of the user
/// @param relayer          The address of the relayer
/// @param validator        The address of the validator
/// @param collateralAmount The amount of collateral to lock as part of the order
/// @param expiration       The order expiration timestamp. If a validator determines that input tokens haven't been transferred by expiration,
///                         it can cancel the order.
/// @param intentCommit     A hash of the order's input and output TokenTransfer[], or the order's "intent". Any internal Relay ETH fees to other
///                         parties in the order lifecylce should be specified in the output array. Note that the order of the encoded inputs will affect
///                         the intentCommit hash. The intentCommit is meant to be revealed in the call to `settleOrder`.
/// @param primaryCommit    A hash of the order's origin and destination Route[]. This route should satisfy the hashed intentCommit.
///                         The routeCommit is meant to be verified offchain between the relayer and the validator.
/// @param hookCommit       A hash of the order's pre and post hooks, if necessary. Note that the pre hook will be executed with the user's input tokens
///                         on the origin chain, and the post hook will be executed with the user's output tokens on the destination chain
struct Order {
    address user;
    address relayer;
    address validator;
    uint256 nonce;
    uint256 collateralAmount;
    uint256 inputDeadline;
    uint256 primaryDeadline;
    uint256 secondaryDeadline;
    bytes32 intentCommit;
    bytes32 primaryCommit;
    bytes32 secondaryCommit;
}

/// @notice Collateral balances (user or relayer)
/// @param totalBalance The total balance of the account
/// @param outstandingBalance The balance locked in initiated but unsettled orders
/// @param relayEthBalance Surplus ETH from fees that can be used to pay for fees or gas
struct Balances {
    uint256 totalBalance;
    uint256 outstandingBalance;
    uint256 relayEthBalance;
}

struct RelayerWitness {
    address relayer;
}

struct EscrowBalance {
    uint256 timelock;
    uint256 lockedBalance;
}
