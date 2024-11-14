// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract RelayStructs {
    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }
}
