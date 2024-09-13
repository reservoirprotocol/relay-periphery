pragma solidity ^0.8.13;

interface ICreate2Factory {
    function safeCreate2(
        bytes32 salt,
        bytes calldata initializationCode
    ) external payable returns (address deploymentAddress);
}
