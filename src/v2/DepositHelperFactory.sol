import {LibClone} from "solady/src/utils/LibClone.sol";
import {DepositHelper} from "./DepositHelper.sol";

contract DepositHelperFactory {
    using LibClone for address;

    /// @notice The address of the authorized address
    address public immutable AUTHORIZED_ADDRESS;

    /// @notice The address of the preset address
    address public immutable PRESET_ADDRESS;

    /// @notice The address of the DepositHelper implementation
    DepositHelper public immutable depositHelperImplementation;

    constructor(address _authorized, address _preset) {
        AUTHORIZED_ADDRESS = _authorized;
        PRESET_ADDRESS = _preset;
    }
}
