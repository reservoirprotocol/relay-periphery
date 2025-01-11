// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Script.sol";

import {CreditMaster} from "../src/CreditMaster.sol";

contract CreditMasterDeployer is Script {
    address allocator;

    function setUp() public {
        allocator = 0xf70da97812CB96acDF810712Aa562db8dfA3dbEF;
    }

    function run() public {
        // Utilizes the locally-defined PRIVATE_KEY environment variable to sign txs.
        vm.startBroadcast(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        // Deploy CreditMaster
        CreditMaster cm = new CreditMaster(allocator);

        assert(cm.allocator() == allocator);
        assert(cm.owner() == 0xf3d63166F0Ca56C3c1A3508FcE03Ff0Cf3Fb691e);

        vm.stopBroadcast();
    }
}
