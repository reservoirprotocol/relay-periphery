// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {TrustlessPermit} from "trustlessPermit/TrustlessPermit.sol";
import {IRelayRouter} from "./interfaces/IRelayRouter.sol";
import {Multicall3} from "./utils/Multicall3.sol";

contract ApprovalProxy is Ownable {
    struct Permit {
        address token;
        address owner;
        uint256 salt;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        bytes saltSignature;
    }

    using SafeERC20 for IERC20;
    using SignatureCheckerLib for address;
    using TrustlessPermit for address;

    error ArrayLengthsMismatch();
    error ERC20TransferFromFailed();
    error InvalidSignature();
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
    /// @param calls The calls to perform
    /// @param refundTo The address to refund any leftover ETH to
    function transferAndMulticall(
        address[] calldata tokens,
        uint256[] calldata amounts,
        Multicall3.Call3Value[] calldata calls,
        address refundTo
    ) external payable returns (bytes memory) {
        // Revert if array lengths do not match
        if ((tokens.length != amounts.length)) {
            revert ArrayLengthsMismatch();
        }

        // Transfer the tokens to the router
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).safeTransferFrom(msg.sender, router, amounts[i]);
        }

        // Call multicall on the router
        // @dev msg.sender for the calls to targets will be the router
        bytes memory data = IRelayRouter(router).multicall{value: msg.value}(
            calls,
            refundTo
        );

        return data;
    }

    /// @notice Use ERC2612 permit to transfer tokens to ERC20Router and execute multicall in a single tx
    /// @dev Approved spender must be address(this) to transfer user's tokens to the ERC20Router
    /// @param permits An array of permits
    /// @param calls The calls to perform
    /// @param refundTo The address to refund any leftover ETH to
    /// @return returnData The return data from the multicall
    function permitTransferAndMulticall(
        Permit[] calldata permits,
        Multicall3.Call3Value[] calldata calls,
        address refundTo
    ) external payable returns (bytes memory returnData) {
        for (uint256 i = 0; i < permits.length; i++) {
            Permit memory permit = permits[i];

            // Validate the owner signed the salt
            bytes32 saltHash = keccak256(abi.encodePacked(permit.salt));

            if (
                !permit.owner.isValidSignatureNow(
                    saltHash,
                    permit.saltSignature
                )
            ) {
                revert InvalidSignature();
            }

            // Use the permit. Calling `trustlessPermit` allows tx to
            // continue even if permit gets frontrun
            permit.token.trustlessPermit(
                permit.owner,
                address(this),
                permit.value,
                permit.deadline,
                permit.v,
                permit.r,
                permit.s
            );

            // Transfer the tokens to the router
            IERC20(permit.token).safeTransferFrom(
                permit.owner,
                router,
                permit.value
            );
        }

        // Call multicall on the router
        // @dev msg.sender for the calls to targets will be the router
        returnData = IRelayRouter(router).multicall{value: msg.value}(
            calls,
            refundTo
        );
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
