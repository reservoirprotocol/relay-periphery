// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

struct Input {
    address to;
    address token;
    uint256 chainId;
    uint256 value;
    uint256 weight;
    Refund refund;
}

struct Output {
    uint256 chainId;
    address to;
    address token;
    uint256 minimumAmount;
    uint256 expectedAmount;
    Call3Value[] calls;
}

struct Refund {
    uint256 chainId;
    address to;
    address token;
    uint256 minimumAmount;
}

/// @dev The struct representing a commitment
/// @param commitmentId The onchain identifier of the commitment
/// @param relayer The address of the relayer which will insure the request
/// @param bond The bond amount for this commitment
/// @param quoteExpiration The timestamp after which the quote is no longer valid
/// @param salt A random salt value to ensure commitment uniqueness
/// @param inputs The list of input payments to be sent to the relayer
/// @param output The output payment to be sent to the user, including a list of calls
///               to be executed on the destination chain
struct Commitment {
    bytes32 commitmentId;
    address relayer;
    uint256 bond;
    uint256 quoteExpiration;
    bytes32 salt;
    Input[] inputs;
    Output output;
}

enum ClaimStatus {
    NotInitiated,
    Initiated__awaitingRelayerResponse,
    Initiated__awaitingUserResponse,
    EscalatedToArbitration,
    Cancelled,
    Settled__forRelayer,
    Settled__forUser
}
