// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract TloadTest {
    fallback() external {
        bool success;
        bytes memory result;

        assembly {
            // Attempt to use TLOAD
            let tloadResult := tload(0)

            // Store the result
            mstore(0x80, tloadResult)

            // Set success to true if we reach this point
            success := 1

            // Prepare the result bytes
            result := mload(0x40)
            mstore(result, 0x20) // Length of the result (32 bytes)
            mstore(add(result, 0x20), tloadResult) // TLOAD result
            mstore(0x40, add(result, 0x40)) // Update free memory pointer

            // Prepare the return data
            let returnData := mload(0x40)
            mstore(returnData, success)
            mstore(add(returnData, 0x20), 0x40) // Offset of the result bytes
            mstore(add(returnData, 0x40), mload(result)) // Length of result
            mstore(add(returnData, 0x60), mload(add(result, 0x20))) // Result data
            return(returnData, 0x80)
        }
    }
}
