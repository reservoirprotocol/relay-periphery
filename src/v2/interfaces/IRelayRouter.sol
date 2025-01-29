// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";

import {Multicall3} from "../utils/Multicall3.sol";

interface IRelayRouter {
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        Multicall3.Call3Value[] calldata calls,
        address refundTo,
        bytes memory permitSignature
    ) external payable returns (Multicall3.Result[] memory returnData);

    function multicall(
        Multicall3.Call3Value[] calldata calls,
        address refundTo
    ) external payable returns (Multicall3.Result[] memory returnData);

    function cleanupERC20(address token, address refundTo) external;
}
