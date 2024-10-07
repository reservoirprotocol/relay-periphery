// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";

interface IRelayRouter {
    function permitMulticall(
        address user,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        address[] calldata targets,
        bytes[] calldata datas,
        uint256[] calldata values,
        address refundTo,
        bytes memory permitSignature
    ) external payable returns (bytes memory);

    function multicall(
        address[] calldata targets,
        bytes[] calldata datas,
        uint256[] calldata values,
        address refundTo
    ) external payable returns (bytes memory);

    function cleanupERC20(address token, address refundTo) external;
}
