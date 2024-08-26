// SPDX-License-Identifier: MIT
import {CrossChainOrder, ResolvedCrossChainOrder} from "../lib/ERC7683Structs.sol";

/// @title ISettlementContract
/// @notice Standard interface for settlement contracts
interface ISettlementContract {
    /// @notice Initiates the settlement of a cross-chain order
    /// @dev To be called by the filler
    /// @param order The CrossChainOrder definition
    /// @param signature The swapper's signature over the order
    /// @param fillerData Any filler-defined data required by the settler
    function initiate(
        CrossChainOrder memory order,
        bytes memory signature,
        bytes memory fillerData
    ) external;

    /// @notice Resolves a specific CrossChainOrder into a generic ResolvedCrossChainOrder
    /// @dev Intended to improve standardized integration of various order types and settlement contracts
    /// @param order The CrossChainOrder definition
    /// @param fillerData Any filler-defined data required by the settler
    /// @return ResolvedCrossChainOrder hydrated order data including the inputs and outputs of the order
    function resolve(
        CrossChainOrder memory order,
        bytes memory fillerData
    ) external view returns (ResolvedCrossChainOrder memory);
}
