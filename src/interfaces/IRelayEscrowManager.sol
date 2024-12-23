// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IRelayEscrowManager {
    function deposit() external;

    function withdraw() external;

    function initiateClaim(
        bytes32 depositTxHash,
        bytes32 commitmentId
    ) external payable returns (bytes32 claimId);

    function respondToClaim__relayer(
        bytes32 fillTxHash,
        bytes32 claimId
    ) external;

    function respondToClaim__claimant(bytes32 claimId) external;

    function escalateClaimToArbitration(bytes32 claimId) external;
}
