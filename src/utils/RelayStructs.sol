// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

enum ClaimStatus {
    NotInitiated,
    Initiated__awaitingRelayerResponse,
    Initiated__relayerSettle__awaitingUserResponse,
    Initiated__relayerDispute__awaitingUserResponse,
    EscalatedToArbitration,
    Cancelled,
    Settled__forRelayer,
    Settled__forUser
}

enum Response {
    User__settle,
    User__dispute,
    Relayer__settle,
    Relayer__dispute
}

struct Balances {
    uint256 outstandingBalance;
    uint256 totalBalance;
}

struct ClaimContext {
    ClaimStatus status;
    uint256 relayerResponseDeadline;
    uint256 userResponseDeadline;
    uint256 arbitrationDeadline;
}

// /// @dev The struct representing a commitment
// /// @param commitmentId The onchain identifier of the commitment
// /// @param relayer The address of the relayer which will insure the request
// /// @param bond The bond amount for this commitment
// /// @param quoteExpiration The timestamp after which the quote is no longer valid
// /// @param salt A random salt value to ensure commitment uniqueness
// /// @param inputs The list of input payments to be sent to the relayer
// /// @param output The output payment to be sent to the user, including a list of calls
// ///               to be executed on the destination chain
// struct Commitment {
//     bytes32 commitmentId;
//     address user;
//     address relayer;
//     uint256 bond;
//     uint256 quoteExpiration;
//     bytes32 salt;
//     Input[] inputs;
//     Output output;
// }

struct EscrowBalance {
    uint256 lockedBalance;
    uint256 totalBalance;
}

struct WithdrawalRequest {
    uint256 amount;
    uint256 timelockExpiration;
}
