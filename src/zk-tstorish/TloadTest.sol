// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract TloadTest {
    fallback() external {
        bool success;
        bytes memory result;

        assembly {
            let tloadResult

            // Attempt to use TLOAD
            tloadResult := tload(0)

            // Store the result
            mstore(0x80, tloadResult)

            // Set success to true if we reach this point (i.e., if TLOAD didn't revert)
            success := 1

            // Set result to the free memory pointer
            result := mload(0x40)

            // Store the length of the result as 32 bytes
            mstore(result, 0x20)

            // Store the TLOAD result at the next 32 bytes
            mstore(add(result, 0x20), tloadResult)

            // Update the free memory pointer
            mstore(0x40, add(result, 0x40))
        }

        return (success, result);
    }
}
