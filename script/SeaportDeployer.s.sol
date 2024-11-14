// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";

import {Seaport} from "seaport-core/Seaport.sol";
import {ConduitController} from "seaport-core/conduit/ConduitController.sol";

contract SeaportDeployer is Script {
    function run() public {
        // Utilizes the locally-defined PRIVATE_KEY environment variable to sign txs.
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy ConduitController
        // ConduitController conduitController = new ConduitController{
        //     salt: bytes32(0)
        // }();

        // Deploy Seaport 1.6
        Seaport seaport = new Seaport{salt: bytes32(0)}(
            0x48f799859eC128c7434a81b850420714a6b015ea
        );

        vm.stopBroadcast();
    }
}
