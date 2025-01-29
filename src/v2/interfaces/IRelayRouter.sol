// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Call3Value, Result, PermitBatchTransferFrom} from "../utils/RelayStructs.sol";

interface IRelayRouter {
    function permitMulticall(
        address user,
        PermitBatchTransferFrom memory permit,
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
