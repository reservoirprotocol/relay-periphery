// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DepositAddressContract {
    address public immutable AUTHORIZED_ADDRESS;
    address public immutable PRESET_ADDRESS;

    error Unauthorized();
    error TransferFailed();

    constructor(address _authorized, address _preset) {
        AUTHORIZED_ADDRESS = _authorized;
        PRESET_ADDRESS = _preset;
    }

    // Native currency withdrawal
    function withdrawNative() external {
        if (msg.sender != AUTHORIZED_ADDRESS) revert Unauthorized();

        assembly {
            // Get balance of contract
            let balance := selfbalance()

            // Transfer using call
            let success := call(
                gas(),
                sload(PRESET_ADDRESS.slot),
                balance,
                0,
                0,
                0,
                0
            )

            // Check if transfer failed
            if iszero(success) {
                // Get the free memory pointer
                let ptr := mload(0x40)
                // TransferFailed()
                mstore(ptr, 0x90b8ec18)
                // Revert with the error signature
                revert(ptr, 4)
            }
        }
    }

    function withdrawERC20(address token) external {
        if (msg.sender != AUTHORIZED_ADDRESS) revert Unauthorized();

        // balanceOf(address)
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x70a08231, address(this))
        );
        require(success && data.length >= 32);
        uint256 balance = abi.decode(data, (uint256));

        // transfer(address,uint256)
        (success, ) = token.call(
            abi.encodeWithSelector(0xa9059cbb, PRESET_ADDRESS, balance)
        );

        if (!success) revert TransferFailed();
    }
}
