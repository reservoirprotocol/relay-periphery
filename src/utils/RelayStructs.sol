// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

struct Call3Value {
    address target;
    bool allowFailure;
    uint256 value;
    bytes callData;
}

struct 

enum ClaimStatus {
    Initiated__awaitingRelayerResponse,
    Initiated__awaitingClaimantResponse,
    EscalatedToArbitration,
    Cancelled,
    Settled
}
