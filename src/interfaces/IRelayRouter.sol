// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {RelayStructs} from "../utils/RelayStructs.sol";

interface IRelayRouter {
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        RelayStructs.Call3Value[] calldata calls,
        address refundTo,
        bytes memory permitSignature
    ) external payable returns (bytes memory);

    function multicall(
        RelayStructs.Call3Value[] calldata calls,
        address refundTo
    ) external payable returns (bytes memory);

    function cleanupERC20(address token, address refundTo) external;
}
