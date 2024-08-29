// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {SystemContractsCaller} from "../lib/v2-testnet-contracts/l2/system-contracts/libraries/SystemContractsCaller.sol";
import {IContractDeployer} from "../lib/v2-testnet-contracts/l2/system-contracts/interfaces/IContractDeployer.sol";
import {WETH9} from "../src/utils/WETH9.sol";

contract ZkScript is Script {
    uint256 forkAbstractTestnet;
    address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));

    function setUp() public {
        forkAbstractTestnet = vm.createFork("https://api.testnet.abs.xyz");
    }

    function run() public {
        deployWeth();
    }

    function deployWeth() public {
        vm.selectFork(forkAbstractTestnet);
        string memory artifact = vm.readFile("zkout/utils/WETH9.sol/WETH9.json");
        bytes32 bytecodeHash = vm.parseJsonBytes32(artifact, ".hash");
        bytes32 salt = "12345";
        bytes32 constructorInputHash = keccak256(abi.encode());
        address expectedDeployedAddress = _computeCreate2Address(
            deployer,
            salt,
            bytes32(bytecodeHash),
            constructorInputHash
        );

        // deploy via create2
        vm.startBroadcast(deployer);
        address actualDeployedAddress = address(
            new WETH9{salt: salt}()
        );
        assert(expectedDeployedAddress == actualDeployedAddress);
    }

    function _computeCreate2Address(
        address sender,
        bytes32 salt,
        bytes32 creationCodeHash,
        bytes32 constructorInputHash
    ) private pure returns (address) {
        bytes32 zksync_create2_prefix = keccak256("zksyncCreate2");
        bytes32 address_hash = keccak256(
            bytes.concat(
                zksync_create2_prefix,
                bytes32(uint256(uint160(sender))),
                salt,
                creationCodeHash,
                constructorInputHash
            )
        );

        return address(uint160(uint256(address_hash)));
    }
}

// contract Auxiliary {
//     address constant DEPLOYER_SYSTEM_CONTRACT = 0x0000000000000000000000000000000000008006;

//     function deploy(
//         bytes32 bytecodeHash,
//         bytes32 salt
//     ) public returns (address) {
//         IContractDeployer deployer = IContractDeployer(
//             DEPLOYER_SYSTEM_CONTRACT
//         );

//         (bool success, bytes memory returndata) = SystemContractsCaller
//             .systemCallWithReturndata(
//                 uint32(gasleft()),
//                 DEPLOYER_SYSTEM_CONTRACT,
//                 0,
//                 abi.encodeCall(
//                     IContractDeployer.create2,
//                     (salt, bytecodeHash, abi.encode(address(0), ""))
//                 )
//             );

//         if (!success) {
//             assembly {
//                 returndatacopy(0, 0, returndatasize())
//                 revert(0, returndatasize())
//             }
//         }
//         address ret = abi.decode(returndata, (address));
//         return ret;
//     }
// }