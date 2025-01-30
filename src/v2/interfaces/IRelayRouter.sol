// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";

import {Call3Value, Result} from "../utils/RelayStructs.sol";

interface IRelayRouter {
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        Call3Value[] calldata calls,
        address refundTo,
        bytes memory permitSignature
    ) external payable returns (Result[] memory returnData);

    function multicall(
        Call3Value[] calldata calls,
        address refundTo
    ) external payable returns (Result[] memory returnData);

    function cleanupERC20(address token, address refundTo) external;
}
