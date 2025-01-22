// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Router} from "./interfaces/IERC20Router.sol";

contract ApprovalProxy is Ownable {
    using SafeERC20 for IERC20;

    error ArrayLengthsMismatch();
    error ERC20TransferFromFailed();
    error NativeTransferFailed();

    event RouterUpdated(address newRouter);

    address public router;

    receive() external payable {}

    constructor(address _owner, address _router) {
        _initializeOwner(_owner);
        router = _router;
    }

    /// @notice Withdraw function in case funds get stuck in contract
    function withdraw() external onlyOwner {
        _send(msg.sender, address(this).balance);
    }

    /// @notice Set the router address
    /// @param _router The address of the router contract
    function setRouter(address _router) external onlyOwner {
        router = _router;

        emit RouterUpdated(_router);
    }

    /// @notice Transfer tokens to ERC20Router and perform multicall in a single tx
    /// @dev This contract must be approved to transfer msg.sender's tokens to the ERC20Router
    /// @param tokens An array of token addresses to transfer
    /// @param amounts An array of token amounts to transfer
    /// @param targets An array of target addresses to pass to the multicall
    /// @param datas An array of calldata to pass to the multicall
    /// @param values An array of msg values to pass to the multicall
    /// @param refundTo The address to refund any leftover ETH to
    function transferAndMulticall(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address[] calldata targets,
        bytes[] calldata datas,
        uint256[] calldata values,
        address refundTo
    ) external payable returns (bytes memory) {
        // Revert if array lengths do not match
        if ((tokens.length != amounts.length)) {
            revert ArrayLengthsMismatch();
        }

        // Revert if array lengths do not match (split from above for readability)
        if (targets.length != datas.length || datas.length != values.length) {
            revert ArrayLengthsMismatch();
        }

        // Transfer the tokens to the router
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, router, amounts[i]);
        }

        // Call delegatecallMulticall on the router. The router will perform a
        // delegatecall to the Multicaller.
        // @dev msg.sender for the calls to targets will be the router
        bytes memory data = IERC20Router(router).delegatecallMulticall{
            value: msg.value
        }(targets, datas, values, refundTo);

        return data;
    }

    function _send(address to, uint256 value) internal {
        bool success;
        assembly {
            // Save gas by avoiding copying the return data to memory.
            // Provide at most 100k gas to the internal call, which is
            // more than enough to cover common use-cases of logic for
            // receiving native tokens (eg. SCW payable fallbacks).
            success := call(100000, to, value, 0, 0, 0, 0)
        }

        if (!success) {
            revert NativeTransferFailed();
        }
    }
}
