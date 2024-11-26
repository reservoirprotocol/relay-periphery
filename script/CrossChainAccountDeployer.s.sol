// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.7.6;

import "forge-std/Script.sol";

import {Messenger, CrossChainAccount} from "../src/utils/CrossChainAccount.sol";

contract CrossChainAccountDeployer is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        bytes32 salt = 0x0000000000000000000000000000000000000000000000000000000000000001;
        address messenger = 0x4200000000000000000000000000000000000007;
        address l1Owner = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC;

        // Deploy Seaport 1.5
        CrossChainAccount cca = new CrossChainAccount{salt: salt}(
            Messenger(messenger), l1Owner
        );

        vm.stopBroadcast();
    }
}
