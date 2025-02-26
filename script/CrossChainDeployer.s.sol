// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Script, console} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";
import {Multicaller} from "../src/v1/Multicaller.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ApprovalProxy} from "../src/v1/ApprovalProxyV1.sol";
import {OnlyOwnerMulticaller} from "../src/v1/OnlyOwnerMulticallerV1.sol";
import {ERC20Router} from "../src/v1/ERC20RouterV1.sol";
import {RelayReceiver} from "../src/v1/RelayReceiverV1.sol";
import {BaseDeployer} from "./BaseDeployer.s.sol";

contract CrossChainDeployer is Script, Test, BaseDeployer {
    error InvalidContractAddress(address expected, address actual);

    bytes32 constant salt = bytes32(uint256(3));

    // 0xaaaaaae6F6BD313e62907E1c0010795cAed22b2b
    bytes32 constant APPROVAL_PROXY_V1_SALT = 0x00000000000000000000000000000000000000005bc677c8df4fe9855e0200c0;

    // 0xeEEeEEEb40Ca06d60444256905f6287321462acC
    bytes32 constant ERC20_ROUTER_V1_SALT = 0x00000000000000000000000000000000000000004e330ef61479baa6450100a8;

    function setUp() public {}

    function run() public {
        createDeployMultichain();
    }

    function createDeployMultichain() private {
        /// @dev add new chain(s) below and update array length accordingly
        /// NOTE: contracts have already been deployed to commented out chains. Make sure to also add your chain to the Chain enum and forks mapping in BaseDeployer.s.sol
        Chains[] memory deployForks = new Chains[](1);
        // deployForks[0] = Chains.Mainnet; // Amoy
        // deployForks[1] = Chains.Base;
        // deployForks[2] = Chains.Arbitrum;
        // deployForks[3] = Chains.Optimism;
        // deployForks[4] = Chains.Null; // DeBank testnet *
        // deployForks[5] = Chains.Null; // Manta testnet *
        // deployForks[6] = Chains.Null; // Barret **
        // deployForks[7] = Chains.Null; // ZkSync Sepolia *
        // deployForks[8] = Chains.Null; // Align testnet v2 *
        // deployForks[9] = Chains.Null; // Mode testnet *
        // deployForks[10] = Chains.Boba;
        // deployForks[11] = Chains.Null; // Goerli *
        // deployForks[12] = Chains.Null; // Gin testnet *
        // deployForks[13] = Chains.Null; // Frame testnet *
        // deployForks[14] = Chains.Null; // Blast Sepolia *
        // deployForks[15] = Chains.Null; // Astar Zkyoto *
        // deployForks[16] = Chains.Null; // Hypr *
        // deployForks[17] = Chains.Hekla;
        // deployForks[18] = Chains.OpSepolia;
        // deployForks[19] = Chains.Null; // Garnet *
        // deployForks[20] = Chains.Null; // Ancient8 celestia testnet *
        // deployForks[21] = Chains.Null; // Atlas *
        // deployForks[22] = Chains.B3;
        // deployForks[23] = Chains.ZoraSepolia;
        // deployForks[24] = Chains.FunkiTestnet;
        // deployForks[25] = Chains.LiskSepolia;
        // deployForks[26] = Chains.Cloud;
        // deployForks[27] = Chains.Game7Testnet;
        // deployForks[28] = Chains.ShapeSepolia;
        // deployForks[29] = Chains.ArbitrumBlueberry;
        // deployForks[30] = Chains.Null; // M Integrations Testnet
        // deployForks[31] = Chains.Sepolia;
        // deployForks[32] = Chains.Null; // Memecoin 2
        // deployForks[33] = Chains.BaseSepolia;
        // deployForks[34] = Chains.Redstone;
        // deployForks[35] = Chains.Rari;
        // deployForks[36] = Chains.Null; // ZkSync
        // deployForks[37] = Chains.Degen;
        // deployForks[38] = Chains.Linea; // Linea
        // deployForks[39] = Chains.Avalanche;
        // deployForks[40] = Chains.Zora;
        // deployForks[41] = Chains.Polygon;
        // deployForks[42] = Chains.Ancient8;
        // deployForks[43] = Chains.Xai;
        // deployForks[44] = Chains.Null; // AstarZkevm *
        // deployForks[45] = Chains.Mode;
        // deployForks[46] = Chains.Gnosis;
        // deployForks[47] = Chains.Blast;
        // deployForks[48] = Chains.Apex;
        // deployForks[49] = Chains.Funki;
        // deployForks[50] = Chains.Lisk;
        // deployForks[51] = Chains.Ham;
        // deployForks[52] = Chains.OnchainPoints;
        // deployForks[53] = Chains.PolygonZkevm;
        // deployForks[54] = Chains.ArbitrumNova;
        // deployForks[55] = Chains.Taiko;
        // deployForks[56] = Chains.Null;
        // deployForks[57] = Chains.Cyber;
        // deployForks[58] = Chains.ArbitrumSepolia; // Arbitrum Sepolia
        // deployForks[59] = Chains.Null; // Scroll *
        // deployForks[60] = Chains.Amoy;
        // deployForks[61] = Chains.Bsc;
        // deployForks[62] = Chains.Null;
        // deployForks[63] = Chains.Mint;
        // deployForks[64] = Chains.Null;
        // deployForks[65] = Chains.ApeChain;
        // deployForks[66] = Chains.UniChain;
        // deployForks[67] = Chains.Mantle;
        // deployForks[68] = Chains.BeraChain;
        // deployForks[0] = Chains.Null; // Linea doesn't support Cancun
        // deployForks[1] = Chains.Polygon;
        // deployForks[2] = Chains.Gnosis;
        // deployForks[3] = Chains.Bsc;
        // deployForks[4] = Chains.Scroll;
        // deployForks[5] = Chains.PolygonZkevm;
        // deployForks[6] = Chains.ArbitrumNova;
        // deployForks[7] = Chains.Blast;
        // deployForks[8] = Chains.Sepolia;
        // deployForks[9] = Chains.BaseSepolia;
        // deployForks[10] = Chains.BlastSepolia;

        // opensea
        deployForks[0] = Chains.BeraChain;
        deployForks[1] = Chains.Avalanche;
        deployForks[2] = Chains.ApeChain;
        deployForks[3] = Chains.Soneium;
        deployForks[4] = Chains.Zora;
        deployForks[5] = Chains.B3;
        deployForks[6] = Chains.Arbitrum;
        deployForks[7] = Chains.Optimism;
        deployForks[8] = Chains.Mainnet;

        // blockscout
        // deployForks[0] = Chains.Boba;
        // deployForks[1] = Chains.Hekla;
        // deployForks[2] = Chains.OpSepolia;
        // deployForks[3] = Chains.B3;
        // deployForks[4] = Chains.ZoraSepolia;
        // deployForks[5] = Chains.FunkiTestnet;
        // deployForks[6] = Chains.LiskSepolia;
        // deployForks[7] = Chains.Cloud;
        // deployForks[8] = Chains.Game7Testnet;
        // deployForks[9] = Chains.ShapeSepolia;
        // deployForks[10] = Chains.ArbitrumBlueberry;
        // deployForks[11] = Chains.Redstone;
        // deployForks[12] = Chains.Rari;
        // deployForks[13] = Chains.Avalanche;
        // deployForks[14] = Chains.Zora;
        // deployForks[15] = Chains.Ancient8;
        // deployForks[16] = Chains.Xai;
        // deployForks[17] = Chains.Apex;
        // deployForks[18] = Chains.Funki;
        // deployForks[19] = Chains.Lisk;
        // deployForks[20] = Chains.Ham;
        // deployForks[21] = Chains.OnchainPoints;
        // deployForks[22] = Chains.Taiko;
        // deployForks[23] = Chains.Cyber;
        // deployForks[24] = Chains.Mint;
        // deployForks[25] = Chains.ApeChain;
        // deployForks[26] = Chains.UniChain;
        // deployForks[27] = Chains.Mantle;
        // deployForks[28] = Chains.BeraChain;

        // No Cancun:
        // Arbitrum Sepolia
        // Arbitrum Blueberry
        // Barret
        // Rari
        // Apex
        // Cloud

        for (uint256 i; i < deployForks.length; ++i) {
            if (deployForks[i] == Chains.Null) {
                continue;
            }

            console2.log(
                "Deploying contracts to chain: ",
                forks[deployForks[i]]
            );

            createSelectFork(deployForks[i]);

            vm.startBroadcast(owner);
            // address permit2 = deployPermit2();
            // address multicaller = deployMulticaller();
            address erc20Router = deployERC20Router(
                PERMIT2
            );
            deployApprovalProxy(erc20Router);
            // if (vm.envBool("IS_TESTNET") == true) {
            //     deployRelayReceiver(TESTNET_SOLVER);
            // } else {
            //     deployRelayReceiver(SOLVER);
            // }
            // deployOnlyOwnerMulticaller();

            vm.stopBroadcast();

            console2.log("\n");
        }
    }

    /// @notice Deploys the Multicaller contract to the given chain
    function deployMulticaller() public returns (address) {
        console2.log("Deploying Multicaller...");

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            FOUNDRY_CREATE2_FACTORY,
                            salt,
                            keccak256(
                                abi.encodePacked(type(Multicaller).creationCode)
                            )
                        )
                    )
                )
            )
        );

        if (_hasBeenDeployed(predictedAddress)) {
            console2.log(
                "Multicaller has already been deployed at: ",
                predictedAddress
            );
            return predictedAddress;
        }

        // Reuse salt for simplicity
        Multicaller multicaller = new Multicaller{salt: salt}();

        console2.log("Multicaller deployed: ", address(multicaller));

        return address(multicaller);
    }

    function deployOnlyOwnerMulticaller() public returns (address) {
        console2.log("Deploying OnlyOwnerMulticaller...");

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            FOUNDRY_CREATE2_FACTORY,
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(OnlyOwnerMulticaller).creationCode,
                                    abi.encode(SOLVER)
                                )
                            )
                        )
                    )
                )
            )
        );

        if (_hasBeenDeployed(predictedAddress)) {
            console2.log(
                "OnlyOwnerMulticaller has already been deployed at: ",
                predictedAddress
            );
            return ONLY_OWNER_MULTICALLER;
        }

        // Reuse salt for simplicity
        OnlyOwnerMulticaller onlyOwnerMulticaller = new OnlyOwnerMulticaller{
            salt: salt
        }(SOLVER);

        console2.log(
            "OnlyOwnerMulticaller deployed: ",
            address(onlyOwnerMulticaller)
        );

        return address(onlyOwnerMulticaller);
    }

    function deployApprovalProxy(address router) public returns (address) {
        console2.log("Deploying ApprovalProxy...");

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            FOUNDRY_CREATE2_FACTORY,
                            APPROVAL_PROXY_V1_SALT,
                            keccak256(
                                abi.encodePacked(
                                    type(ApprovalProxy).creationCode,
                                    abi.encode(owner, router)
                                )
                            )
                        )
                    )
                )
            )
        );

        console2.log("approval proxy init code hash: ");
        console2.logBytes32(keccak256(
                                abi.encodePacked(
                                    type(ApprovalProxy).creationCode,
                                    abi.encode(owner, router)
                                )));

        if (_hasBeenDeployed(predictedAddress)) {
            console2.log(
                "ApprovalProxy has already been deployed at: ",
                predictedAddress
            );
            return predictedAddress;
        }

        // Reuse salt for simplicity
        ApprovalProxy approvalProxy = new ApprovalProxy{salt: APPROVAL_PROXY_V1_SALT}(
            owner,
            router
        );

        if (address(approvalProxy) != predictedAddress) {
            revert InvalidContractAddress(
                predictedAddress,
                address(approvalProxy)
            );
        }

        console2.log("ApprovalProxy deployed: ", address(approvalProxy));

        return address(approvalProxy);
    }

    /// @notice Deploys the ERC20 Router contract to the given chain
    function deployERC20Router(
        address permit2
    ) public returns (address) {
        console2.log("Deploying ERC20 Router...");

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            FOUNDRY_CREATE2_FACTORY,
                            ERC20_ROUTER_V1_SALT,
                            keccak256(
                                abi.encodePacked(
                                    type(ERC20Router).creationCode,
                                    abi.encode(permit2)
                                )
                            )
                        )
                    )
                )
            )
        );

        console2.log("router init code hash: ");
        console2.logBytes32(keccak256(
                                abi.encodePacked(
                                    type(ERC20Router).creationCode,
                                    abi.encode(permit2)
                )
            ));

        if (_hasBeenDeployed(predictedAddress)) {
            console2.log(
                "ERC20 Router has already been deployed at: ",
                predictedAddress
            );
            return predictedAddress;
        }

        ERC20Router router = new ERC20Router{salt: ERC20_ROUTER_V1_SALT}(
            permit2
        );

        if (address(router) != predictedAddress) {
            revert InvalidContractAddress(predictedAddress, address(router));
        }

        console2.log("ERC20 Router deployed: ", address(router));

        return address(router);
    }

    /// @notice Deploys the Relay Receiver contract to the given chain
    function deployRelayReceiver(address _solver) public returns (address) {
        console2.log("Deploying Receiver...");

        address predictedAddress = address(
            uint160(
                uint(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            FOUNDRY_CREATE2_FACTORY,
                            salt,
                            keccak256(
                                abi.encodePacked(
                                    type(RelayReceiver).creationCode,
                                    abi.encode(_solver)
                                )
                            )
                        )
                    )
                )
            )
        );

        if (_hasBeenDeployed(predictedAddress)) {
            console2.log(
                "Receiver has already been deployed at: ",
                predictedAddress
            );
            return predictedAddress;
        }

        // Reuse salt for simplicity
        RelayReceiver relayReceiver = new RelayReceiver{salt: salt}(_solver);

        console2.log("Receiver deployed: ", address(relayReceiver));

        return address(relayReceiver);
    }

    function deployPermit2() public returns (address) {
        console2.log("Deploying Permit2...");

        if (_hasBeenDeployed(PERMIT2)) {
            console2.log("Permit2 has already been deployed at: ", PERMIT2);
            return PERMIT2;
        }

        (bool success, bytes memory data) = FOUNDRY_CREATE2_FACTORY.call(
            hex"0000000000000000000000000000000000000000d3af2663da51c1021500000060c0346100bb574660a052602081017f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86681527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a60408301524660608301523060808301526080825260a082019180831060018060401b038411176100a557826040525190206080526123c090816100c1823960805181611b47015260a05181611b210152f35b634e487b7160e01b600052604160045260246000fd5b600080fdfe6040608081526004908136101561001557600080fd5b600090813560e01c80630d58b1db1461126c578063137c29fe146110755780632a2d80d114610db75780632b67b57014610bde57806330f28b7a14610ade5780633644e51514610a9d57806336c7851614610a285780633ff9dcb1146109a85780634fe02b441461093f57806365d9723c146107ac57806387517c451461067a578063927da105146105c3578063cc53287f146104a3578063edd9444b1461033a5763fe8ec1a7146100c657600080fd5b346103365760c07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff833581811161033257610114903690860161164b565b60243582811161032e5761012b903690870161161a565b6101336114e6565b9160843585811161032a5761014b9036908a016115c1565b98909560a43590811161032657610164913691016115c1565b969095815190610173826113ff565b606b82527f5065726d697442617463685769746e6573735472616e7366657246726f6d285460208301527f6f6b656e5065726d697373696f6e735b5d207065726d69747465642c61646472838301527f657373207370656e6465722c75696e74323536206e6f6e63652c75696e74323560608301527f3620646561646c696e652c000000000000000000000000000000000000000000608083015282519a8b9181610222602085018096611f93565b918237018a8152039961025b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe09b8c8101835282611437565b5190209085515161026b81611ebb565b908a5b8181106102f95750506102f6999a6102ed9183516102a081610294602082018095611f66565b03848101835282611437565b519020602089810151858b015195519182019687526040820192909252336060820152608081019190915260a081019390935260643560c08401528260e081015b03908101835282611437565b51902093611cf7565b80f35b8061031161030b610321938c5161175e565b51612054565b61031b828661175e565b52611f0a565b61026e565b8880fd5b8780fd5b8480fd5b8380fd5b5080fd5b5091346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103365767ffffffffffffffff9080358281116103325761038b903690830161164b565b60243583811161032e576103a2903690840161161a565b9390926103ad6114e6565b9160643590811161049f576103c4913691016115c1565b949093835151976103d489611ebb565b98885b81811061047d5750506102f697988151610425816103f9602082018095611f66565b037fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08101835282611437565b5190206020860151828701519083519260208401947ffcf35f5ac6a2c28868dc44c302166470266239195f02b0ee408334829333b7668652840152336060840152608083015260a082015260a081526102ed8161141b565b808b61031b8261049461030b61049a968d5161175e565b9261175e565b6103d7565b8680fd5b5082346105bf57602090817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126103325780359067ffffffffffffffff821161032e576104f49136910161161a565b929091845b848110610504578580f35b8061051a610515600193888861196c565b61197c565b61052f84610529848a8a61196c565b0161197c565b3389528385528589209173ffffffffffffffffffffffffffffffffffffffff80911692838b528652868a20911690818a5285528589207fffffffffffffffffffffffff000000000000000000000000000000000000000081541690558551918252848201527f89b1add15eff56b3dfe299ad94e01f2b52fbcb80ae1a3baea6ae8c04cb2b98a4853392a2016104f9565b8280fd5b50346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610676816105ff6114a0565b936106086114c3565b6106106114e6565b73ffffffffffffffffffffffffffffffffffffffff968716835260016020908152848420928816845291825283832090871683528152919020549251938316845260a083901c65ffffffffffff169084015260d09190911c604083015281906060820190565b0390f35b50346103365760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336576106b26114a0565b906106bb6114c3565b916106c46114e6565b65ffffffffffff926064358481169081810361032a5779ffffffffffff0000000000000000000000000000000000000000947fda9fa7c1b00402c17d0161b249b1ab8bbec047c5a52207b9c112deffd817036b94338a5260016020527fffffffffffff0000000000000000000000000000000000000000000000000000858b209873ffffffffffffffffffffffffffffffffffffffff809416998a8d5260205283878d209b169a8b8d52602052868c209486156000146107a457504216925b8454921697889360a01b16911617179055815193845260208401523392a480f35b905092610783565b5082346105bf5760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576107e56114a0565b906107ee6114c3565b9265ffffffffffff604435818116939084810361032a57338852602091600183528489209673ffffffffffffffffffffffffffffffffffffffff80911697888b528452858a20981697888a5283528489205460d01c93848711156109175761ffff9085840316116108f05750907f55eb90d810e1700b35a8e7e25395ff7f2b2259abd7415ca2284dfb1c246418f393929133895260018252838920878a528252838920888a5282528389209079ffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffff000000000000000000000000000000000000000000000000000083549260d01b16911617905582519485528401523392a480f35b84517f24d35a26000000000000000000000000000000000000000000000000000000008152fd5b5084517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b503461033657807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610336578060209273ffffffffffffffffffffffffffffffffffffffff61098f6114a0565b1681528084528181206024358252845220549051908152f35b5082346105bf57817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf577f3704902f963766a4e561bbaab6e6cdc1b1dd12f6e9e99648da8843b3f46b918d90359160243533855284602052818520848652602052818520818154179055815193845260208401523392a280f35b8234610a9a5760807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc360112610a9a57610a606114a0565b610a686114c3565b610a706114e6565b6064359173ffffffffffffffffffffffffffffffffffffffff8316830361032e576102f6936117a1565b80fd5b503461033657817ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657602090610ad7611b1e565b9051908152f35b508290346105bf576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf57610b1a3661152a565b90807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c36011261033257610b4c611478565b9160e43567ffffffffffffffff8111610bda576102f694610b6f913691016115c1565b939092610b7c8351612054565b6020840151828501519083519260208401947f939c21a48a8dbe3a9a2404a1d46691e4d39f6583d6ec6b35714604c986d801068652840152336060840152608083015260a082015260a08152610bd18161141b565b51902091611c25565b8580fd5b509134610336576101007ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033657610c186114a0565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc360160c08112610332576080855191610c51836113e3565b1261033257845190610c6282611398565b73ffffffffffffffffffffffffffffffffffffffff91602435838116810361049f578152604435838116810361049f57602082015265ffffffffffff606435818116810361032a5788830152608435908116810361049f576060820152815260a435938285168503610bda576020820194855260c4359087830182815260e43567ffffffffffffffff811161032657610cfe90369084016115c1565b929093804211610d88575050918591610d786102f6999a610d7e95610d238851611fbe565b90898c511690519083519260208401947ff3841cd1ff0085026a6327b620b67997ce40f282c88a8e905a7a5626e310f3d086528401526060830152608082015260808152610d70816113ff565b519020611bd9565b916120c7565b519251169161199d565b602492508a51917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b5091346103365760607ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc93818536011261033257610df36114a0565b9260249081359267ffffffffffffffff9788851161032a578590853603011261049f578051978589018981108282111761104a578252848301358181116103265785019036602383011215610326578382013591610e50836115ef565b90610e5d85519283611437565b838252602093878584019160071b83010191368311611046578801905b828210610fe9575050508a526044610e93868801611509565b96838c01978852013594838b0191868352604435908111610fe557610ebb90369087016115c1565b959096804211610fba575050508998995151610ed681611ebb565b908b5b818110610f9757505092889492610d7892610f6497958351610f02816103f98682018095611f66565b5190209073ffffffffffffffffffffffffffffffffffffffff9a8b8b51169151928551948501957faf1b0d30d2cab0380e68f0689007e3254993c596f2fdd0aaa7f4d04f794408638752850152830152608082015260808152610d70816113ff565b51169082515192845b848110610f78578580f35b80610f918585610f8b600195875161175e565b5161199d565b01610f6d565b80610311610fac8e9f9e93610fb2945161175e565b51611fbe565b9b9a9b610ed9565b8551917fcd21db4f000000000000000000000000000000000000000000000000000000008352820152fd5b8a80fd5b6080823603126110465785608091885161100281611398565b61100b85611509565b8152611018838601611509565b838201526110278a8601611607565b8a8201528d611037818701611607565b90820152815201910190610e7a565b8c80fd5b84896041867f4e487b7100000000000000000000000000000000000000000000000000000000835252fd5b5082346105bf576101407ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc3601126105bf576110b03661152a565b91807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7c360112610332576110e2611478565b67ffffffffffffffff93906101043585811161049f5761110590369086016115c1565b90936101243596871161032a57611125610bd1966102f6983691016115c1565b969095825190611134826113ff565b606482527f5065726d69745769746e6573735472616e7366657246726f6d28546f6b656e5060208301527f65726d697373696f6e73207065726d69747465642c6164647265737320737065848301527f6e6465722c75696e74323536206e6f6e63652c75696e7432353620646561646c60608301527f696e652c0000000000000000000000000000000000000000000000000000000060808301528351948591816111e3602085018096611f93565b918237018b8152039361121c7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe095868101835282611437565b5190209261122a8651612054565b6020878101518589015195519182019687526040820192909252336060820152608081019190915260a081019390935260e43560c08401528260e081016102e1565b5082346105bf576020807ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc36011261033257813567ffffffffffffffff92838211610bda5736602383011215610bda5781013592831161032e576024906007368386831b8401011161049f57865b8581106112e5578780f35b80821b83019060807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffdc83360301126103265761139288876001946060835161132c81611398565b611368608461133c8d8601611509565b9485845261134c60448201611509565b809785015261135d60648201611509565b809885015201611509565b918291015273ffffffffffffffffffffffffffffffffffffffff80808093169516931691166117a1565b016112da565b6080810190811067ffffffffffffffff8211176113b457604052565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b6060810190811067ffffffffffffffff8211176113b457604052565b60a0810190811067ffffffffffffffff8211176113b457604052565b60c0810190811067ffffffffffffffff8211176113b457604052565b90601f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0910116810190811067ffffffffffffffff8211176113b457604052565b60c4359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b600080fd5b6004359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6024359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b6044359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b359073ffffffffffffffffffffffffffffffffffffffff8216820361149b57565b7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc01906080821261149b576040805190611563826113e3565b8082941261149b57805181810181811067ffffffffffffffff8211176113b457825260043573ffffffffffffffffffffffffffffffffffffffff8116810361149b578152602435602082015282526044356020830152606435910152565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020838186019501011161149b57565b67ffffffffffffffff81116113b45760051b60200190565b359065ffffffffffff8216820361149b57565b9181601f8401121561149b5782359167ffffffffffffffff831161149b576020808501948460061b01011161149b57565b91909160608184031261149b576040805191611666836113e3565b8294813567ffffffffffffffff9081811161149b57830182601f8201121561149b578035611693816115ef565b926116a087519485611437565b818452602094858086019360061b8501019381851161149b579086899897969594939201925b8484106116e3575050505050855280820135908501520135910152565b90919293949596978483031261149b578851908982019082821085831117611730578a928992845261171487611509565b81528287013583820152815201930191908897969594936116c6565b602460007f4e487b710000000000000000000000000000000000000000000000000000000081526041600452fd5b80518210156117725760209160051b010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b92919273ffffffffffffffffffffffffffffffffffffffff604060008284168152600160205282828220961695868252602052818120338252602052209485549565ffffffffffff8760a01c16804211611884575082871696838803611812575b5050611810955016926118b5565b565b878484161160001461184f57602488604051907ff96fb0710000000000000000000000000000000000000000000000000000000082526004820152fd5b7fffffffffffffffffffffffff000000000000000000000000000000000000000084846118109a031691161790553880611802565b602490604051907fd81b2f2e0000000000000000000000000000000000000000000000000000000082526004820152fd5b9060006064926020958295604051947f23b872dd0000000000000000000000000000000000000000000000000000000086526004860152602485015260448401525af13d15601f3d116001600051141617161561190e57565b60646040517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601460248201527f5452414e534645525f46524f4d5f4641494c45440000000000000000000000006044820152fd5b91908110156117725760061b0190565b3573ffffffffffffffffffffffffffffffffffffffff8116810361149b5790565b9065ffffffffffff908160608401511673ffffffffffffffffffffffffffffffffffffffff908185511694826020820151169280866040809401511695169560009187835260016020528383208984526020528383209916988983526020528282209184835460d01c03611af5579185611ace94927fc6a377bfc4eb120024a8ac08eef205be16b817020812c73223e81d1bdb9708ec98979694508715600014611ad35779ffffffffffff00000000000000000000000000000000000000009042165b60a01b167fffffffffffff00000000000000000000000000000000000000000000000000006001860160d01b1617179055519384938491604091949373ffffffffffffffffffffffffffffffffffffffff606085019616845265ffffffffffff809216602085015216910152565b0390a4565b5079ffffffffffff000000000000000000000000000000000000000087611a60565b600484517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b467f000000000000000000000000000000000000000000000000000000000000000003611b69577f000000000000000000000000000000000000000000000000000000000000000090565b60405160208101907f8cad95687ba82c2ce50e74f7b754645e5117c3a5bec8151c0726d5857980a86682527f9ac997416e8ff9d2ff6bebeb7149f65cdae5e32e2b90440b566bb3044041d36a604082015246606082015230608082015260808152611bd3816113ff565b51902090565b611be1611b1e565b906040519060208201927f190100000000000000000000000000000000000000000000000000000000000084526022830152604282015260428152611bd381611398565b9192909360a435936040840151804211611cc65750602084510151808611611c955750918591610d78611c6594611c60602088015186611e47565b611bd9565b73ffffffffffffffffffffffffffffffffffffffff809151511692608435918216820361149b57611810936118b5565b602490604051907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b602490604051907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b959093958051519560409283830151804211611e175750848803611dee57611d2e918691610d7860209b611c608d88015186611e47565b60005b868110611d42575050505050505050565b611d4d81835161175e565b5188611d5a83878a61196c565b01359089810151808311611dbe575091818888886001968596611d84575b50505050505001611d31565b611db395611dad9273ffffffffffffffffffffffffffffffffffffffff6105159351169561196c565b916118b5565b803888888883611d78565b6024908651907f3728b83d0000000000000000000000000000000000000000000000000000000082526004820152fd5b600484517fff633a38000000000000000000000000000000000000000000000000000000008152fd5b6024908551907fcd21db4f0000000000000000000000000000000000000000000000000000000082526004820152fd5b9073ffffffffffffffffffffffffffffffffffffffff600160ff83161b9216600052600060205260406000209060081c6000526020526040600020818154188091551615611e9157565b60046040517f756688fe000000000000000000000000000000000000000000000000000000008152fd5b90611ec5826115ef565b611ed26040519182611437565b8281527fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0611f0082946115ef565b0190602036910137565b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff8114611f375760010190565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b805160208092019160005b828110611f7f575050505090565b835185529381019392810192600101611f71565b9081519160005b838110611fab575050016000815290565b8060208092840101518185015201611f9a565b60405160208101917f65626cad6cb96493bf6f5ebea28756c966f023ab9e8a83a7101849d5573b3678835273ffffffffffffffffffffffffffffffffffffffff8082511660408401526020820151166060830152606065ffffffffffff9182604082015116608085015201511660a082015260a0815260c0810181811067ffffffffffffffff8211176113b45760405251902090565b6040516020808201927f618358ac3db8dc274f0cd8829da7e234bd48cd73c4a740aede1adec9846d06a1845273ffffffffffffffffffffffffffffffffffffffff81511660408401520151606082015260608152611bd381611398565b919082604091031261149b576020823592013590565b6000843b61222e5750604182036121ac576120e4828201826120b1565b939092604010156117725760209360009360ff6040608095013560f81c5b60405194855216868401526040830152606082015282805260015afa156121a05773ffffffffffffffffffffffffffffffffffffffff806000511691821561217657160361214c57565b60046040517f815e1d64000000000000000000000000000000000000000000000000000000008152fd5b60046040517f8baa579f000000000000000000000000000000000000000000000000000000008152fd5b6040513d6000823e3d90fd5b60408203612204576121c0918101906120b1565b91601b7f7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff84169360ff1c019060ff8211611f375760209360009360ff608094612102565b60046040517f4be6321b000000000000000000000000000000000000000000000000000000008152fd5b929391601f928173ffffffffffffffffffffffffffffffffffffffff60646020957fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0604051988997889687947f1626ba7e000000000000000000000000000000000000000000000000000000009e8f8752600487015260406024870152816044870152868601378b85828601015201168101030192165afa9081156123a857829161232a575b507fffffffff000000000000000000000000000000000000000000000000000000009150160361230057565b60046040517fb0669cbc000000000000000000000000000000000000000000000000000000008152fd5b90506020813d82116123a0575b8161234460209383611437565b810103126103365751907fffffffff0000000000000000000000000000000000000000000000000000000082168203610a9a57507fffffffff0000000000000000000000000000000000000000000000000000000090386122d4565b3d9150612337565b6040513d84823e3d90fdfea164736f6c6343000811000a"
        );

        if (!success || address(bytes20(data)) != PERMIT2) {
            revert InvalidContractAddress(PERMIT2, address(bytes20(data)));
        }

        console2.log("Permit2 deployed:", PERMIT2);

        return PERMIT2;
    }

    function deployApprovalProxy__latestBytecode(
        address expectedAddress
    ) public returns (address) {
        if (_hasBeenDeployed(expectedAddress)) {
            console2.log(
                "ApprovalProxy has already been deployed at: ",
                expectedAddress
            );
            return expectedAddress;
        }

        if (
            !_hasBeenDeployed(ERC20_ROUTER) &&
            !_hasBeenDeployed(ERC20_ROUTER_ARACHNID_CREATE2_FACTORY)
        ) {
            console2.log("ERC20Router has not been deployed");
            return address(0);
        }

        console2.log("Deploying ApprovalProxy...");

        bool success;
        bytes memory data;

        // 0xcdf11EF8FeB47C9a9498c4F89D71f1768fEADec7
        (success, data) = FOUNDRY_CREATE2_FACTORY.call(
            hex"0000000000000000000000000000000000000000ef4834b251a91000a916248a6080346100ac57601f610b1238819003918201601f19168301916001600160401b038311848410176100b15780849260409485528339810103126100ac57610052602061004b836100c7565b92016100c7565b6001600160a01b03918216638b78c6d81981905560007f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08180a31660018060a01b03196000541617600055604051610a3690816100dc8239f35b600080fd5b634e487b7160e01b600052604160045260246000fd5b51906001600160a01b03821682036100ac5756fe6080604052600436101561001b575b361561001957600080fd5b005b60003560e01c806325692962146100cb5780633ccfd60b146100c657806354d1f13d146100c15780635caab55a146100bc578063715018a6146100b75780638da5cb5b146100b2578063c0d78655146100ad578063f04e283e146100a8578063f2fde38b146100a3578063f887ea401461009e5763fee81cf40361000e5761049f565b610476565b610436565b6103e2565b610372565b610345565b6102fe565b610245565b61015e565b61011a565b6000806003193601126101175763389a75e1600c523381526202a30042016020600c2055337fdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d8280a280f35b80fd5b34610159576000806003193601126101175761013461084c565b808080804733620186a0f1156101475780f35b604051633d2cec6f60e21b8152600490fd5b600080fd5b6000806003193601126101175763389a75e1600c52338152806020600c2055337ffa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c928280a280f35b9181601f840112156101595782359167ffffffffffffffff8311610159576020808501948460051b01011161015957565b6001600160a01b0381160361015957565b60a435906101f4826101d6565b565b60005b8381106102095750506000910152565b81810151838201526020016101f9565b6040916020825261023981518092816020860152602086860191016101f6565b601f01601f1916010190565b60c03660031901126101595767ffffffffffffffff600480358281116101595761027290369083016101a5565b6024358481116101595761028990369085016101a5565b604492919235868111610159576102a390369087016101a5565b606492919235888111610159576102bd90369089016101a5565b939092608435998a11610159576102dd6102ee996102fa9b3691016101a5565b9790966102e86101e7565b9961073a565b60405191829182610219565b0390f35b6000806003193601126101175761031361084c565b80638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08280a35580f35b3461015957600036600319011261015957638b78c6d819546040516001600160a01b039091168152602090f35b34610159576020366003190112610159577f7aed1d3e8155a07ccf395e44ea3109a0e2d6c9b29bbbe9f142d9790596f4dc8060206004356103b2816101d6565b6103ba61084c565b600080546001600160a01b0319166001600160a01b03929092169182179055604051908152a1005b6020366003190112610159576004356103fa816101d6565b61040261084c565b63389a75e1600c52806000526020600c209081544211610428576000610019925561094c565b636f5e88186000526004601cfd5b60203660031901126101595760043561044e816101d6565b61045661084c565b8060601b15610468576100199061094c565b637448fbae6000526004601cfd5b34610159576000366003190112610159576000546040516001600160a01b039091168152602090f35b34610159576020366003190112610159576004356104bc816101d6565b63389a75e1600c52600052602080600c2054604051908152f35b91908110156104e65760051b0190565b634e487b7160e01b600052603260045260246000fd5b35610506816101d6565b90565b634e487b7160e01b600052604160045260246000fd5b60a0810190811067ffffffffffffffff82111761053b57604052565b610509565b90601f8019910116810190811067ffffffffffffffff82111761053b57604052565b67ffffffffffffffff811161053b57601f01601f191660200190565b6020818303126101595780519067ffffffffffffffff8211610159570181601f820112156101595780516105b181610562565b926105bf6040519485610540565b818452602082840101116101595761050691602080850191016101f6565b908060209392818452848401376000828201840152601f01601f1916010190565b81835290916001600160fb1b0383116101595760209260051b809284830137010190565b97969593909492918060808a0160808b525260a08901959060005b8181106106ff575050506020888603818a015281865280860195818360051b82010196846000925b85841061069f57505050505050508260609261068c92886101f497960360408a01526105fe565b6001600160a01b03909216940193909352565b90919293949598601f198282030184528935601e198436030181121561015957830186810191903567ffffffffffffffff8111610159578036038313610159576106ee889283926001956105dd565b9b0194019401929594939190610665565b90919293966001908435610712816101d6565b60a083901b83900316815260209081019895940192910161063d565b6040513d6000823e3d90fd5b9291909a999a9893949597969882810361083057898714801590610842575b6108305760005b8181106107ee575050505050906107b66000969798879361079961078d61078d875460018060a01b031690565b6001600160a01b031690565b966040519a8b998a98899762dc60bf60e71b895260048901610622565b03925af19081156107e9576000916107cc575090565b61050691503d806000833e6107e18183610540565b81019061057e565b61072e565b8061082a61080a61078d610805600195878b6104d6565b6104fc565b6000546001600160a01b03166108218489896104d6565b35913390610869565b01610760565b604051631dc0052360e11b8152600490fd5b50848a1415610759565b638b78c6d81954330361085b57565b6382b429006000526004601cfd5b6040516323b872dd60e01b602082019081526001600160a01b03938416602483015293831660448201526064808201959095529384526108e99260009283926108b18761051f565b1694519082865af13d15610944573d906108ca82610562565b916108d86040519384610540565b82523d6000602084013e5b8361099d565b8051908115159182610922575b50506108ff5750565b604051635274afe760e01b81526001600160a01b03919091166004820152602490fd5b61093d925090602080610939938301019101610985565b1590565b38806108f6565b6060906108e3565b60018060a01b0316638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0600080a355565b90816020910312610159575180151581036101595790565b906109c457508051156109b257805190602001fd5b604051630a12f52160e11b8152600490fd5b815115806109f7575b6109d5575090565b604051639996b31560e01b81526001600160a01b039091166004820152602490fd5b50803b156109cd56fea2646970667358221220b249e0d6157226e6b3a28d694f1cceaa479b365dd7d849fdd53bc28a0a92be4064736f6c63430008170033000000000000000000000000f70da97812cb96acdf810712aa562db8dfa3dbef00000000000000000000000083095af87de31ef97ecca8312493f42547a5ff2c"
        );

        if (!success || address(bytes20(data)) != expectedAddress) {
            revert InvalidContractAddress(
                expectedAddress,
                address(bytes20(data))
            );
        }

        console2.log("ApprovalProxy deployed: ", expectedAddress);

        return expectedAddress;
    }

    function deployRouter__latestBytecode(
        address expectedAddress
    ) public returns (address) {
        console2.log("Deploying ERC20Router...");

        if (_hasBeenDeployed(expectedAddress)) {
            console2.log(
                "ERC20Router has already been deployed at: ",
                expectedAddress
            );
            return expectedAddress;
        }

        if (!_hasBeenDeployed(PERMIT2)) {
            console2.log(
                "Permit2 has not been deployed at 0x000000000022D473030F116dDEE9F6B43aC78BA3"
            );
            return address(0);
        }

        if (
            !_hasBeenDeployed(MULTICALLER) &&
            !_hasBeenDeployed(MULTICALLER_ARACHNID_CREATE2_FACTORY)
        ) {
            console2.log("Multicaller has not been deployed");
            return address(0);
        }

        bool success;
        bytes memory data;

        // 0x83095Af87DE31eF97ECCa8312493F42547A5ff2C
        (success, data) = FOUNDRY_CREATE2_FACTORY.call(
            hex"0000000000000000000000000000000000000000177317f7617d575e615800c060c0346100c557601f61113338819003918201601f19168301916001600160401b038311848410176100ca578084926060946040528339810103126100c557610047816100e0565b906100606040610059602084016100e0565b92016100e0565b6001600160a01b0392831660805260a09190915216638b78c6d81981905560007f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08180a360405161103e90816100f58239608051816109dd015260a05181610edc0152f35b600080fd5b634e487b7160e01b600052604160045260246000fd5b51906001600160a01b03821682036100c55756fe6080604052600436101561001b575b361561001957600080fd5b005b60003560e01c806325692962146100eb5780633806a3cf146100e65780633ccfd60b146100e15780633dad0c9c146100dc57806354d1f13d146100d757806366b9ca7b146100d25780636e305f80146100cd578063715018a6146100c85780638da5cb5b146100c3578063c99a0d65146100be578063f04e283e146100b9578063f2fde38b146100b45763fee81cf40361000e57610897565b610857565b610803565b6107c8565b61079b565b610754565b6106af565b6105f2565b610445565b610399565b61032f565b6102fb565b610100565b60009103126100fb57565b600080fd5b60008060031936011261014c5763389a75e1600c523381526202a30042016020600c2055337fdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d8280a280f35b80fd5b634e487b7160e01b600052604160045260246000fd5b606081019081106001600160401b0382111761018057604052565b61014f565b604081019081106001600160401b0382111761018057604052565b6001600160401b03811161018057604052565b608081019081106001600160401b0382111761018057604052565b90601f801991011681019081106001600160401b0382111761018057604052565b604051906101fc82610185565b565b6001600160401b03811161018057601f01601f191660200190565b6040519060a082018281106001600160401b03821117610180576040526064825263756e742960e01b6080837f52656c617965725769746e657373207769746e6573732952656c61796572576960208201527f746e65737328616464726573732072656c6179657229546f6b656e5065726d6960408201527f7373696f6e73286164647265737320746f6b656e2c75696e7432353620616d6f60608201520152565b919082519283825260005b8481106102e7575050826000602080949584010152601f8019910116010190565b6020818301810151848301820152016102c6565b346100fb5760003660031901126100fb5761032b610317610219565b6040519182916020835260208301906102bb565b0390f35b346100fb5760008060031936011261014c57610349610a6f565b808080804733620186a0f11561035c5780f35b604051633d2cec6f60e21b8152600490fd5b6001600160a01b038116036100fb57565b600435906101fc8261036e565b60a435906101fc8261036e565b346100fb5760403660031901126100fb576004356103b68161036e565b602435906103c38261036e565b6040516370a0823160e01b81523060048201526001600160a01b039190911691602082602481865afa9182156104405760009261040c575b508161040357005b61001992610a8c565b9091506020813d602011610438575b81610428602093836101ce565b810103126100fb575190386103fb565b3d915061041b565b6108ce565b60008060031936011261014c5763389a75e1600c52338152806020600c2055337ffa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c928280a280f35b6001600160401b0381116101805760051b60200190565b90916060828403126100fb5760408051906104bd82610165565b819380356001600160401b0381116100fb57810186601f820112156100fb5780356020916104ea8261048c565b916104f7865193846101ce565b808352838084019160061b830101918a83116100fb578401905b8282106105305750505084528181013590840152810135910152909150565b86828c03126100fb57848791825161054781610185565b84356105528161036e565b81528285013583820152815201910190610511565b9181601f840112156100fb578235916001600160401b0383116100fb576020808501948460051b0101116100fb57565b81601f820112156100fb578035906105ae826101fe565b926105bc60405194856101ce565b828452602083830101116100fb57816000926020809301838601378301015290565b9060206105ef9281815201906102bb565b90565b60e03660031901126100fb5761060661037f565b6001600160401b036024358181116100fb576106269036906004016104a3565b916044358281116100fb5761063f903690600401610567565b6064358481116100fb57610657903690600401610567565b6084929192358681116100fb57610672903690600401610567565b93909261067d61038c565b9560c4359889116100fb5761032b9961069d6106a39a3690600401610597565b986108da565b604051918291826105de565b60803660031901126100fb576001600160401b036004358181116100fb576106db903690600401610567565b916024358181116100fb576106f4903690600401610567565b90916044359081116100fb5761070e903690600401610567565b916064359361071c8561036e565b81871480159061074a575b6107385761032b966106a396610e96565b604051631dc0052360e11b8152600490fd5b5083821415610727565b60008060031936011261014c57610769610a6f565b80638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08280a35580f35b346100fb5760003660031901126100fb57638b78c6d819546040516001600160a01b039091168152602090f35b346100fb5760003660031901126100fb5760206040517f4910260415865c6d3ecf96968c7d912a0d533a72c3479ab1e1df0f4eb86fb0088152f35b60203660031901126100fb5760043561081b8161036e565b610823610a6f565b63389a75e1600c52806000526020600c2090815442116108495760006100199255610f6c565b636f5e88186000526004601cfd5b60203660031901126100fb5760043561086f8161036e565b610877610a6f565b8060601b156108895761001990610f6c565b637448fbae6000526004601cfd5b346100fb5760203660031901126100fb576004356108b48161036e565b63389a75e1600c52600052602080600c2054604051908152f35b6040513d6000823e3d90fd5b90999899858414801590610a65575b610738578a51610901575b50506105ef979850610e96565b969297936040999692959199519860209960208101906109688161095a3385919091602060408201937f4910260415865c6d3ecf96968c7d912a0d533a72c3479ab1e1df0f4eb86fb008835260018060a01b0316910152565b03601f1981018352826101ce565b519020966109778a5151610b4d565b9c60005b8b5180518210156109c557908f818f91826109be9361099c84600198610bc6565b5101516109a76101ef565b308152918201526109b88383610bc6565b52610bc6565b500161097b565b505093979b92969a5093979b90949860018060a01b037f00000000000000000000000000000000000000000000000000000000000000001693610a06610219565b853b156100fb5760405163fe8ec1a760e01b81529d8e958695610a2c9560048801610c32565b03815a6000948591f1978815610440576105ef98610a4c575b89986108f4565b80610a59610a5f926101a0565b806100f0565b38610a45565b50878614156108e9565b638b78c6d819543303610a7e57565b6382b429006000526004601cfd5b60405163a9059cbb60e01b602082019081526001600160a01b0393841660248301526044808301959095529381529291610ae691610ac9856101b3565b1692600080938192519082875af1610adf610e66565b9084610fa5565b908151918215159283610b21575b505050610afe5750565b604051635274afe760e01b81526001600160a01b03919091166004820152602490fd5b819293509060209181010312610b4957602001519081159182150361014c5750388080610af4565b5080fd5b90610b578261048c565b604090610b6760405191826101ce565b8381528093610b78601f199161048c565b019160009060005b848110610b8e575050505050565b6020908251610b9c81610185565b848152828581830152828701015201610b80565b634e487b7160e01b600052603260045260246000fd5b8051821015610bda5760209160051b010190565b610bb0565b90815180825260208080930193019160005b828110610bff575050505090565b9091929382604082610c2660019489516020809160018060a01b0381511684520151910152565b01950193929101610bf1565b9491969593909660c086526101208601978051606060c08901528051809a5261014088019960208092019160005b828110610cd15750505050610c9f6105ef9899610cc3969594936040846020610cb196015160e08d015201516101008b015289820360208b0152610bdf565b6001600160a01b039094166040880152565b606086015284820360808601526102bb565b9160a08184039101526102bb565b835180516001600160a01b03168e52602090810151908e01526040909c019b92810192600101610c60565b9190811015610bda5760051b0190565b356105ef8161036e565b908060209392818452848401376000828201840152601f01601f1916010190565b81835290916001600160fb1b0383116100fb5760209260051b809284830137010190565b97969593909492918060808a0160808b525260a08901959060005b818110610e37575050506020888603818a015281865280860195818360051b82010196846000925b858410610dd8575050505050505082606092610dc592886101fc97960360408a0152610d37565b6001600160a01b03909216940193909352565b90919293949598601f198282030184528935601e19843603018112156100fb5783018681019190356001600160401b0381116100fb5780360383136100fb57610e2688928392600195610d16565b9b0194019401929594939190610d9e565b90919293966001908435610e4a8161036e565b60a083901b839003168152602090810198959401929101610d76565b3d15610e91573d90610e77826101fe565b91610e8560405193846101ce565b82523d6000602084013e565b606090565b959294919493909360005b858110610f165750600096949193610ed89388979561095a93604051978896602088019a63991f255f60e01b8c5260248901610d5b565b51907f00000000000000000000000000000000000000000000000000000000000000005af4610f05610e66565b9015610f0e5790565b602081519101fd5b737777777f279eba3d3ad8f4e708545291a6fdba8b610f4d610f41610f3c848a8d610cfc565b610d0c565b6001600160a01b031690565b14610f5a57600101610ea1565b60405163416aebb560e11b8152600490fd5b60018060a01b0316638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0600080a355565b90610fcc5750805115610fba57805190602001fd5b604051630a12f52160e11b8152600490fd5b81511580610fff575b610fdd575090565b604051639996b31560e01b81526001600160a01b039091166004820152602490fd5b50803b15610fd556fea26469706673582212204555a8c168bf659ad9699e2237ee7ac2847c22b2664218de0675609faec2a3a664736f6c63430008170033000000000000000000000000000000000022d473030f116ddee9f6b43ac78ba3000000000000000000000000b0e22f8b026c5dc4b0bc33ef4c5d3231544aee3e000000000000000000000000f70da97812cb96acdf810712aa562db8dfa3dbef"
        );

        if (!success || address(bytes20(data)) != expectedAddress) {
            revert InvalidContractAddress(
                expectedAddress,
                address(bytes20(data))
            );
        }

        console2.log("Router deployed: ", expectedAddress);

        return expectedAddress;
    }

    function deployOnlyOwnerMulticaller__latestBytecode(
        address expectedAddress
    ) public returns (address) {
        console2.log("Deploying OnlyOwnerMulticaller...");

        if (_hasBeenDeployed(expectedAddress)) {
            console2.log(
                "OnlyOwnerMulticaller has already been deployed at: ",
                expectedAddress
            );
            return expectedAddress;
        }

        // 0xb90ed4c123843cbFD66b11411Ee7694eF37E6E72
        (bool success, bytes memory data) = FOUNDRY_CREATE2_FACTORY.call(
            hex"0000000000000000000000000000000000000000ef4834b251a91000a916248a60803461008e57601f6105f738819003918201601f19168301916001600160401b038311848410176100935780849260209460405283398101031261008e57516001600160a01b0381169081900361008e5780638b78c6d8195560007f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08180a360405161054d90816100aa8239f35b600080fd5b634e487b7160e01b600052604160045260246000fdfe60806040526004361015610015575b3661043857005b6000803560e01c90816325692962146100985750806354d1f13d14610093578063715018a61461008e5780638da5cb5b14610089578063991f255f14610084578063f04e283e1461007f578063f2fde38b1461007a5763fee81cf40361000e57610405565b6103c9565b610377565b610202565b610173565b61012c565b6100e5565b806003193601126100e25763389a75e1600c523381526202a30042016020600c2055337fdbf36a107da19e49527a7176a1babf963b4b0ff8cde35ee35d6cd8f1f9ac7e1d8280a280f35b80fd5b6000806003193601126100e25763389a75e1600c52338152806020600c2055337ffa7b8eab7da67f412cc9575ed43464468f9bfbae89d1675917346ca6d8fe3c928280a280f35b6000806003193601126100e2576101416104c1565b80638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e08280a35580f35b346101a05760003660031901126101a057638b78c6d819546040516001600160a01b039091168152602090f35b600080fd5b9181601f840112156101a05782359167ffffffffffffffff83116101a0576020808501948460051b0101116101a057565b606435906001600160a01b03821682036101a057565b600435906001600160a01b03821682036101a057565b60803660031901126101a05767ffffffffffffffff6004358181116101a05761022f9036906004016101a5565b90916024358181116101a0576102499036906004016101a5565b9390916044359081116101a0576102649036906004016101a5565b929061026e6101d6565b936102776104c1565b8614868614161561036a5785926040966102e4575b50505050806102a3575b5060206000526020526000f35b47156102965733811860018214021860003881804785620186a0f1610296576000526073600b5360ff6020536016600b47f0156102e05738610296565b3838fd5b91939592839060051b9283868637838501935b82518701908681018235908160208095018237600080809383603f19808b8d010135908b8b0101355af115610361578286523d90523d90606083013e603f601f19913d01011692019588858814610350575095916102f7565b96505050915050019238808061028c565b503d81803e3d90fd5b633b800a463d526004601cfd5b60203660031901126101a05761038b6101ec565b6103936104c1565b63389a75e1600c52806000526020600c2090815442116103bb5760006103b992556104de565b005b636f5e88186000526004601cfd5b60203660031901126101a0576103dd6101ec565b6103e56104c1565b8060601b156103f7576103b9906104de565b637448fbae6000526004601cfd5b346101a05760203660031901126101a05761041e6101ec565b63389a75e1600c52600052602080600c2054604051908152f35b3d356366e0daa08160e01c1461044c573d3dfd5b193d5260043d815b8092368210156104a7578135831a600180930194811561047b5750815301905b9091610454565b3d19835260020194607f9150353d1a8181111561049c575b16010190610474565b838101388439610493565b600080809281305af43d82803e156104bd573d90f35b3d90fd5b638b78c6d8195433036104d057565b6382b429006000526004601cfd5b60018060a01b0316638b78c6d8198181547f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0600080a35556fea264697066735822122019c6e5e37b4bd8c4f76bdcd77ff33167fa20318acdbcffc98e8424da4d545ad664736f6c63430008170033000000000000000000000000f70da97812cb96acdf810712aa562db8dfa3dbef"
        );

        if (!success || address(bytes20(data)) != expectedAddress) {
            revert InvalidContractAddress(
                expectedAddress,
                address(bytes20(data))
            );
        }

        console2.log("OnlyOwnerMulticaller deployed: ", expectedAddress);

        return expectedAddress;
    }

    function deployRelayReceiver__latestBytecode(
        address expectedAddress
    ) public returns (address) {
        console2.log("Deploying RelayReceiver...");

        if (_hasBeenDeployed(expectedAddress)) {
            console2.log(
                "RelayReceiver has already been deployed at: ",
                expectedAddress
            );
            return expectedAddress;
        }

        // 0xa06e1351E2fD2D45b5D35633ca7eCF328684a109
        (bool success, bytes memory data) = FOUNDRY_CREATE2_FACTORY.call(
            hex"0000000000000000000000000000000000000000ef4834b251a91000a916248a60a03461007e57601f61054738819003918201601f19168301916001600160401b038311848410176100835780849260209460405283398101031261007e57516001600160a01b038116810361007e576080526040516104ad908161009a823960805181818160b9015281816101470152818161038b01526103dc0152f35b600080fd5b634e487b7160e01b600052604160045260246000fdfe60806040526004361015610026575b361561001e5761001c6103d6565b005b61001c610385565b6000803560e01c908163d948d46814610049575063dd4ed8370361000e576100f7565b60203660031901126100f45760043567ffffffffffffffff8082116100f057366023830112156100f05781600401359081116100f05736602482840101116100f0577f936c2ca3b35d2d0b24057b0675c459e4515f48fe132d138e213ae59ffab7f53e916100ea6024926100dd347f0000000000000000000000000000000000000000000000000000000000000000610452565b60405193849301836101f5565b0390a180f35b8280fd5b80fd5b6020806003193601126101f05760049067ffffffffffffffff9082358281116101f057366023820112156101f05780600401359283116101f0576024810190602436918560051b0101116101f0577f00000000000000000000000000000000000000000000000000000000000000006001600160a01b031633036101df5760005b83811061018157005b61019461018f82868561021d565b6102d2565b805160009081906001600160a01b0316926040938785830151920151918883519301915af16101c161035f565b50156101d05750600101610178565b51633204506f60e01b81528590fd5b6040516282b42960e81b8152600490fd5b600080fd5b90918060409360208452816020850152848401376000828201840152601f01601f1916010190565b919081101561023f5760051b81013590605e19813603018212156101f0570190565b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052604160045260246000fd5b604051906060820182811067ffffffffffffffff82111761028b57604052565b610255565b6040519190601f01601f1916820167ffffffffffffffff81118382101761028b57604052565b67ffffffffffffffff811161028b57601f01601f191660200190565b6060813603126101f0576102e461026b565b9080356001600160a01b03811681036101f05782526020908181013567ffffffffffffffff81116101f05781019136601f840112156101f05782359061033161032c836102b6565b610290565b91808352368282870101116101f0578181600092826040980183870137840101528401520135604082015290565b3d15610380573d9061037361032c836102b6565b9182523d6000602084013e565b606090565b6103af347f0000000000000000000000000000000000000000000000000000000000000000610452565b7f4c995d67adb0cb7b809d0281cf3388fc87502a20f2ca89a171173633592cfd06600080a1565b610400347f0000000000000000000000000000000000000000000000000000000000000000610452565b7f936c2ca3b35d2d0b24057b0675c459e4515f48fe132d138e213ae59ffab7f53e604051602081523660208201523660006040830137600060403683010152604081601f19601f3601168101030190a1565b60008080938193620186a0f11561046557565b604051633d2cec6f60e21b8152600490fdfea2646970667358221220cef8aeb2ee4005fbbd2ba384f819bf11d48bd896cba370f3fe619a068e30a2e964736f6c63430008170033000000000000000000000000f70da97812cb96acdf810712aa562db8dfa3dbef"
        );

        if (!success || address(bytes20(data)) != expectedAddress) {
            revert InvalidContractAddress(
                expectedAddress,
                address(bytes20(data))
            );
        }

        console2.log("RelayReceiver deployed: ", expectedAddress);

        return expectedAddress;
    }

    function _hasBeenDeployed(
        address contractToCheck
    ) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(contractToCheck)
        }
        return (size > 0);
    }
}
