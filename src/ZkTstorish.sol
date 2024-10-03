// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Tstorish} from "tstorish/src/Tstorish.sol";

contract ZkTstorish is Tstorish {
    address constant immutable _CONTRACT_DEPLOYER_SYSTEM_CONTRACT =
        0x0000000000000000000000000000000000008006;

    /**
     * @dev Determine TSTORE availability during deployment. This involves
     *      attempting to deploy a contract that utilizes TLOAD as part of the
     *      contract construction bytecode, and configuring initial support for
     *      using TSTORE in place of SSTORE based on the result.
     */
    constructor() {
        // Deploy the contract testing TLOAD support and store the address.
        address tloadTestContract = _prepareTloadTest();

        // Ensure the deployment was successful.
        if (tloadTestContract == address(0)) {
            revert TloadTestContractDeploymentFailed();
        }

        // Determine if TSTORE is supported.
        bool tstoreInitialSupport = _testTload(tloadTestContract);

        if (tstoreInitialSupport) {
            // If TSTORE is supported, set functions to their versions that use
            // tstore/tload directly without support checks.
            _setTstorish = _setTstore;
            _getTstorish = _getTstore;
            _clearTstorish = _clearTstore;
        } else {
            // If TSTORE is not supported, set functions to their versions that
            // fallback to sstore/sload until _tstoreSupport is true.
            _setTstorish = _setTstorishWithSstoreFallback;
            _getTstorish = _getTstorishWithSloadFallback;
            _clearTstorish = _clearTstorishWithSstoreFallback;
        }

        _tstoreInitialSupport = tstoreInitialSupport;

        // Set the address of the deployed TLOAD test contract as an immutable.
        _tloadTestContract = tloadTestContract;
    }

    /**
     * @dev Private function to deploy a test contract that utilizes TLOAD as
     *      part of its fallback logic.
     */
    function _prepareTloadTest()
        private
        override
        returns (address contractAddress)
    {
        // Check if chain is zk stack by checking for ContractDeployer system contract
        uint256 size;
        assembly {
            size := extcodesize(_CONTRACT_DEPLOYER_SYSTEM_CONTRACT)
        }

        if (size > 0) {} else {
            // Utilize assembly to deploy a contract testing TLOAD support.
            assembly {
                // Write the contract deployment code payload to scratch space.
                mstore(0, _TLOAD_TEST_PAYLOAD)

                // Deploy the contract.
                contractAddress := create(
                    0,
                    _TLOAD_TEST_PAYLOAD_OFFSET,
                    _TLOAD_TEST_PAYLOAD_LENGTH
                )
            }
        }
    }
}
