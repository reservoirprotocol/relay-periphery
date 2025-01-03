// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAllowanceHolder} from "0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import {Multicaller} from "multicaller/src/Multicaller.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {IPermit2} from "permit2-relay/src/interfaces/IPermit2.sol";
import {PermitSignature} from "permit2-relay/test/utils/PermitSignature.sol";
import {ApprovalProxy} from "../src/ApprovalProxy.sol";
import {RelayRouter} from "../src/RelayRouter.sol";
import {Multicall3} from "../src/utils/Multicall3.sol";
import {RelayStructs} from "../src/utils/RelayStructs.sol";
import {NoOpERC20} from "./mocks/NoOpERC20.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {TestERC721_ERC20PaymentToken} from "./mocks/TestERC721_ERC20PaymentToken.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router02.sol";

struct RelayerWitness {
    address relayer;
}

contract RelayRouterTest is Test, BaseRelayTest, RelayStructs {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error InvalidSender();
    error InvalidTarget(address target);
    error ERC20InsufficientAllowance(
        address spender,
        uint256 allowance,
        uint256 needed
    );
    error ERC20InsufficientBalance(
        address sender,
        uint256 balance,
        uint256 needed
    );

    event FundsReceived();
    event FundsReceivedWithData(bytes data);
    event RouterUpdated(address newRouter);

    Permit2 permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    Multicaller multicaller =
        Multicaller(payable(0x0000000000002Bdbf1Bf3279983603Ec279CC6dF));
    IAllowanceHolder allowanceHolder =
        IAllowanceHolder(payable(0x0000000000001fF3684f28c67538d4D072C22734));
    RelayRouter router;
    ApprovalProxy approvalProxy;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant _EIP_712_RELAYER_WITNESS_TYPE_HASH =
        keccak256("RelayerWitness(address relayer)");
    bytes32 public constant _FULL_RELAYER_WITNESS_TYPEHASH =
        keccak256(
            "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,RelayerWitness witness)RelayerWitness(address relayer)TokenPermissions(address token,uint256 amount)"
        );
    bytes32 public constant _FULL_RELAYER_WITNESS_BATCH_TYPEHASH =
        keccak256(
            "PermitBatchWitnessTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline,RelayerWitness witness)RelayerWitness(address relayer)TokenPermissions(address token,uint256 amount)"
        );
    bytes32 public constant _PERMIT_BATCH_TRANSFER_FROM_TYPEHASH =
        keccak256(
            "PermitBatchTransferFrom(TokenPermissions[] permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
        );
    string public constant _RELAYER_WITNESS_TYPE_STRING =
        "RelayerWitness witness)RelayerWitness(address relayer)TokenPermissions(address token,uint256 amount)";

    ISignatureTransfer.PermitBatchTransferFrom emptyPermit =
        ISignatureTransfer.PermitBatchTransferFrom({
            permitted: new ISignatureTransfer.TokenPermissions[](0),
            nonce: 1,
            deadline: 0
        });

    function setUp() public override {
        super.setUp();

        router = new RelayRouter(address(permit2));

        approvalProxy = new ApprovalProxy(address(this), address(router));

        // Alice approves permit2 on the ERC20
        erc20_1.mint(alice.addr, 1 ether);
        erc20_2.mint(alice.addr, 1 ether);
        erc20_3.mint(alice.addr, 1 ether);

        vm.startPrank(alice.addr);
        erc20_1.approve(address(permit2), type(uint256).max);
        erc20_2.approve(address(permit2), type(uint256).max);
        erc20_3.approve(address(permit2), type(uint256).max);
        vm.stopPrank();

        DOMAIN_SEPARATOR = permit2.DOMAIN_SEPARATOR();
    }

    function testReceive__revert() public {
        uint256 value = 1 ether;

        vm.prank(alice.addr);
        (bool success, ) = address(router).call{value: value}("");
        assert(!success);
    }

    function testCorrectWitnessTypehashes() public {
        assertEq(
            keccak256(
                abi.encodePacked(
                    _PERMIT_WITNESS_TRANSFER_TYPEHASH_STUB,
                    _RELAYER_WITNESS_TYPE_STRING
                )
            ),
            _FULL_RELAYER_WITNESS_TYPEHASH
        );
        assertEq(
            keccak256(
                abi.encodePacked(
                    _PERMIT_BATCH_WITNESS_TRANSFER_TYPEHASH_STUB,
                    _RELAYER_WITNESS_TYPE_STRING
                )
            ),
            _FULL_RELAYER_WITNESS_BATCH_TYPEHASH
        );
    }

    function testPermitMulticall() public {
        // Create the permit
        ISignatureTransfer.TokenPermissions[]
            memory permitted = new ISignatureTransfer.TokenPermissions[](3);
        permitted[0] = ISignatureTransfer.TokenPermissions({
            token: address(erc20_1),
            amount: 0.1 ether
        });
        permitted[1] = ISignatureTransfer.TokenPermissions({
            token: address(erc20_2),
            amount: 0.2 ether
        });
        permitted[2] = ISignatureTransfer.TokenPermissions({
            token: address(erc20_3),
            amount: 0.3 ether
        });

        ISignatureTransfer.PermitBatchTransferFrom
            memory permit = ISignatureTransfer.PermitBatchTransferFrom({
                permitted: permitted,
                nonce: 1,
                deadline: block.timestamp + 100
            });

        // Get the witness
        bytes32 witness = keccak256(
            abi.encode(_EIP_712_RELAYER_WITNESS_TYPE_HASH, relayer.addr)
        );

        // Get the permit signature
        bytes memory permitSig = getPermitBatchWitnessSignature(
            permit,
            address(router),
            alice.key,
            _FULL_RELAYER_WITNESS_BATCH_TYPEHASH,
            witness,
            DOMAIN_SEPARATOR
        );

        // Create calldata to transfer tokens from the router to Bob
        bytes memory calldata1 = abi.encodeWithSelector(
            erc20_1.transfer.selector,
            bob.addr,
            0.03 ether
        );

        bytes memory calldata2 = abi.encodeWithSelector(
            erc20_2.transfer.selector,
            bob.addr,
            0.15 ether
        );

        bytes memory calldata3 = abi.encodeWithSelector(
            erc20_3.transfer.selector,
            bob.addr,
            0.2 ether
        );

        bytes memory calldata4 = abi.encodeWithSelector(
            erc20_1.approve.selector,
            alice.addr,
            1 ether
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](4);
        calls[0] = Multicall3.Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });
        calls[1] = Multicall3.Call3Value({
            target: address(erc20_2),
            allowFailure: false,
            value: 0,
            callData: calldata2
        });
        calls[2] = Multicall3.Call3Value({
            target: address(erc20_3),
            allowFailure: false,
            value: 0,
            callData: calldata3
        });
        calls[3] = Multicall3.Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata4
        });

        // Call the router as the relayer
        vm.prank(relayer.addr);
        router.permitMulticall(alice.addr, permit, calls, permitSig);

        assertEq(erc20_1.balanceOf(bob.addr), 0.03 ether);
        assertEq(erc20_2.balanceOf(bob.addr), 0.15 ether);
        assertEq(erc20_3.balanceOf(bob.addr), 0.2 ether);

        assertEq(erc20_1.balanceOf(address(router)), 0.07 ether);
        assertEq(erc20_2.balanceOf(address(router)), 0.05 ether);
        assertEq(erc20_3.balanceOf(address(router)), 0.1 ether);

        assertEq(erc20_1.balanceOf(alice.addr), 0.9 ether);
        assertEq(erc20_2.balanceOf(alice.addr), 0.8 ether);
        assertEq(erc20_3.balanceOf(alice.addr), 0.7 ether);
    }

    function testMulticall() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        bytes memory data = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactETHForTokens.selector,
            0,
            path,
            alice.addr,
            block.timestamp
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 1 ether,
            callData: data
        });

        uint256 aliceBalanceBefore = alice.addr.balance;
        uint256 aliceUSDCBalanceBefore = IERC20(USDC).balanceOf(alice.addr);

        vm.prank(alice.addr);
        router.multicall{value: 1 ether}(calls, address(0));

        uint256 aliceBalanceAfter = alice.addr.balance;
        uint256 aliceUSDCBalanceAfter = IERC20(USDC).balanceOf(alice.addr);

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1 ether);
        assertGt(aliceUSDCBalanceAfter, aliceUSDCBalanceBefore);
    }

    function testMulticallTwoSwaps() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        bytes memory calldata1 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactETHForTokens.selector,
            0,
            path,
            alice.addr,
            block.timestamp
        );
        bytes memory calldata2 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactETHForTokens.selector,
            0,
            path,
            alice.addr,
            block.timestamp
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](2);
        calls[0] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 1 ether,
            callData: calldata1
        });
        calls[1] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 1 ether,
            callData: calldata2
        });

        uint256 aliceBalanceBefore = alice.addr.balance;
        uint256 aliceUSDCBalanceBefore = IERC20(USDC).balanceOf(alice.addr);

        vm.prank(alice.addr);
        router.multicall{value: 2 ether}(calls, alice.addr);

        uint256 aliceBalanceAfter = alice.addr.balance;
        uint256 aliceUSDCBalanceAfter = IERC20(USDC).balanceOf(alice.addr);

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 2 ether);
        assertGt(aliceUSDCBalanceAfter, aliceUSDCBalanceBefore);
    }

    function testSwapAndCallWithCleanup() public {
        // Deploy NFT that costs 20 USDC to mint
        TestERC721_ERC20PaymentToken nft = new TestERC721_ERC20PaymentToken(
            USDC
        );

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        bytes memory calldata1 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactETHForTokens.selector,
            0,
            path,
            address(router),
            block.timestamp
        );
        bytes memory calldata2 = abi.encodeWithSelector(
            IERC20.approve.selector,
            address(nft),
            type(uint256).max
        );
        bytes memory calldata3 = abi.encodeWithSelector(
            nft.mint.selector,
            alice.addr,
            10
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](3);
        calls[0] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 1 ether,
            callData: calldata1
        });
        calls[1] = Multicall3.Call3Value({
            target: USDC,
            allowFailure: false,
            value: 0,
            callData: calldata2
        });
        calls[2] = Multicall3.Call3Value({
            target: address(nft),
            allowFailure: false,
            value: 0,
            callData: calldata3
        });

        uint256 aliceBalanceBefore = alice.addr.balance;
        uint256 routerUSDCBalanceBefore = IERC20(USDC).balanceOf(
            address(router)
        );

        vm.prank(alice.addr);
        router.multicall{value: 1 ether}(calls, alice.addr);

        uint256 aliceBalanceAfterMulticall = alice.addr.balance;
        uint256 routerUSDCBalanceAfterMulticall = IERC20(USDC).balanceOf(
            address(router)
        );

        assertEq(aliceBalanceBefore - aliceBalanceAfterMulticall, 1 ether);
        assertGt(routerUSDCBalanceAfterMulticall, routerUSDCBalanceBefore);
        assertEq(nft.ownerOf(10), alice.addr);

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        address[] memory recipients = new address[](1);
        recipients[0] = alice.addr;

        router.cleanupErc20s(tokens, recipients);

        uint256 aliceUSDCBalanceAfterCleanup = IERC20(USDC).balanceOf(
            alice.addr
        );
        uint256 routerUSDCBalanceAfterCleanup = IERC20(USDC).balanceOf(
            address(this)
        );
        assertEq(aliceUSDCBalanceAfterCleanup, routerUSDCBalanceAfterMulticall);
        assertEq(routerUSDCBalanceAfterCleanup, 0);
    }

    function testSwapETHForERC20() public {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = USDC;

        bytes memory calldata1 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactETHForTokens.selector,
            0,
            path,
            alice.addr,
            block.timestamp
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 1 ether,
            callData: calldata1
        });

        uint256 aliceBalanceBefore = alice.addr.balance;
        uint256 aliceUSDCBalanceBefore = IERC20(USDC).balanceOf(alice.addr);

        vm.prank(alice.addr);
        router.permitMulticall{value: 1 ether}(
            alice.addr,
            emptyPermit,
            calls,
            bytes("")
        );

        uint256 aliceBalanceAfter = alice.addr.balance;
        uint256 aliceUSDCBalanceAfter = IERC20(USDC).balanceOf(alice.addr);

        assertEq(aliceBalanceBefore - aliceBalanceAfter, 1 ether);
        assertGt(aliceUSDCBalanceAfter, aliceUSDCBalanceBefore);
    }

    function testMalicious_ApproveThenMulticall() public {
        // Approve the router to spend erc20_1
        vm.prank(alice.addr);
        erc20_1.approve(address(router), 1 ether);

        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            alice.addr,
            bob.addr,
            1 ether
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.prank(bob.addr);
        router.multicall(calls, bob.addr);

        assertEq(erc20_1.balanceOf(bob.addr), 1 ether);
    }

    function testApprovalProxyMulticall__transferFrom() public {
        // Approve the approval helper to spend erc20_1
        vm.prank(alice.addr);
        erc20_1.approve(address(approvalProxy), 1 ether);

        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20_1);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;
        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            alice.addr,
            bob.addr,
            1 ether
        );

        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.prank(alice.addr);
        vm.expectRevert("Multicall3: call failed");
        approvalProxy.transferAndMulticall(tokens, amounts, calls, alice.addr);

        assertEq(erc20_1.balanceOf(address(router)), 0);

        calls[0] = Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: abi.encodeWithSelector(
                IERC20.transfer.selector,
                bob.addr,
                1 ether
            )
        });

        vm.prank(alice.addr);
        approvalProxy.transferAndMulticall(tokens, amounts, calls, alice.addr);

        assertEq(erc20_1.balanceOf(bob.addr), 1 ether);
    }

    function testApprovalProxyMulticall__swapExactTokensForTokens() public {
        // Deal alice some USDC
        deal(USDC, alice.addr, 1000 * 10 ** 6);

        // Approve the approval helper to spend USDC
        vm.prank(alice.addr);
        IERC20(USDC).approve(address(approvalProxy), 1 ether);

        // Create the path from usdc to dai
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = DAI;

        address[] memory tokens = new address[](1);
        tokens[0] = USDC;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 6;

        // RelayRouter approves UniV2Router to spend USDC
        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.approve.selector,
            ROUTER_V2,
            1000 * 10 ** 6
        );
        // RelayRouter swaps USDC for DAI and alice receives output
        bytes memory calldata2 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactTokensForTokens.selector,
            1000 * 10 ** 6,
            990 * 10 ** 18,
            path,
            alice.addr,
            block.timestamp
        );

        Call3Value[] memory calls = new Call3Value[](2);
        calls[0] = Call3Value({
            target: USDC,
            allowFailure: false,
            value: 0,
            callData: calldata1
        });
        calls[1] = Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 0,
            callData: calldata2
        });

        vm.prank(alice.addr);
        approvalProxy.transferAndMulticall(tokens, amounts, calls, alice.addr);

        assertEq(IERC20(USDC).balanceOf(alice.addr), 0);
        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertGt(IERC20(DAI).balanceOf(alice.addr), 990 * 10 ** 18);
    }

    function testAllowanceHolder__swapExactTokensForTokens() public {
        // Deal alice some USDC
        deal(USDC, alice.addr, 1000 * 10 ** 6);

        vm.prank(alice.addr);
        IERC20(USDC).approve(address(allowanceHolder), 1000 * 10 ** 6);

        // Create the path from usdc to dai
        address[] memory path = new address[](2);
        path[0] = USDC;
        path[1] = DAI;

        uint256 amount = 1000 * 10 ** 6;

        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.approve.selector,
            ROUTER_V2,
            amount
        );

        bytes memory calldata2 = abi.encodeWithSelector(
            IAllowanceHolder.transferFrom.selector,
            USDC,
            alice.addr,
            address(router),
            amount
        );

        // RelayRouter swaps USDC for DAI and alice receives output
        bytes memory calldata3 = abi.encodeWithSelector(
            IUniswapV2Router01.swapExactTokensForTokens.selector,
            1000 * 10 ** 6,
            990 * 10 ** 18,
            path,
            alice.addr,
            block.timestamp
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](3);
        calls[0] = Multicall3.Call3Value({
            target: USDC,
            allowFailure: false,
            value: 0,
            callData: calldata1
        });
        calls[1] = Multicall3.Call3Value({
            target: address(allowanceHolder),
            allowFailure: false,
            value: 0,
            callData: calldata2
        });
        calls[2] = Multicall3.Call3Value({
            target: ROUTER_V2,
            allowFailure: false,
            value: 0,
            callData: calldata3
        });

        bytes memory allowanceHolderData = abi.encodeWithSelector(
            router.multicall.selector,
            calls,
            alice.addr
        );

        vm.prank(alice.addr);
        allowanceHolder.exec(
            address(router),
            USDC,
            amount,
            payable(address(router)),
            allowanceHolderData
        );

        assertEq(IERC20(USDC).balanceOf(alice.addr), 0);
        assertEq(IERC20(USDC).balanceOf(address(router)), 0);
        assertGt(IERC20(DAI).balanceOf(alice.addr), 990 * 10 ** 18);
    }

    function testApprovalProxyMulticall__RevertNoOpERC20() public {
        NoOpERC20 noOpERC20 = new NoOpERC20();
        vm.startPrank(alice.addr);
        noOpERC20.mint(alice.addr, 1 ether);
        noOpERC20.approve(address(approvalProxy), 1 ether);

        address[] memory tokens = new address[](1);
        tokens[0] = address(noOpERC20);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.transfer.selector,
            bob.addr,
            1 ether
        );

        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(noOpERC20),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.expectRevert("Multicall3: call failed");
        approvalProxy.transferAndMulticall(tokens, amounts, calls, alice.addr);
    }

    function testApprovalProxySetRouter() public {
        vm.expectRevert(Unauthorized.selector);
        vm.prank(alice.addr);
        approvalProxy.setRouter(alice.addr);

        vm.expectEmit();
        emit RouterUpdated(bob.addr);
        approvalProxy.setRouter(bob.addr);
    }

    function testApprovalProxy__RevertApprovalExploit() public {
        // Alice approves the approval helper to spend erc20_1
        vm.prank(alice.addr);
        erc20_1.approve(address(approvalProxy), 1 ether);

        // Bob listens to this tx and tries to transfer Alice's tokens
        // via the approval
        NoOpERC20 noOpERC20 = new NoOpERC20();
        vm.prank(bob.addr);
        noOpERC20.approve(address(approvalProxy), 1 ether);

        address[] memory tokens = new address[](1);
        tokens[0] = address(noOpERC20);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        bytes memory calldata1 = abi.encodeWithSelector(
            IERC20.transferFrom.selector,
            alice.addr,
            bob.addr,
            1 ether
        );

        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.prank(bob.addr);
        vm.expectRevert("Multicall3: call failed");
        approvalProxy.transferAndMulticall(tokens, amounts, calls, alice.addr);
    }

    function testUSDTCleanupWithSafeERC20() public {
        // Deal router some USDT
        deal(USDT, address(router), 1000 * 10 ** 6);

        address[] memory tokens = new address[](1);
        tokens[0] = USDT;

        address[] memory recipients = new address[](1);
        recipients[0] = relaySolver;

        bytes memory calldata1 = abi.encodeWithSelector(
            router.cleanupErc20s.selector,
            tokens,
            recipients
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: address(router),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.prank(relaySolver);
        router.multicall(calls, relaySolver);

        assertEq(IERC20(USDT).balanceOf(relaySolver), 1000 * 10 ** 6);
    }

    function testUSDTTransferAndMulticall() public {
        // Deal solver some USDT
        deal(USDT, relaySolver, 1000 * 10 ** 6);

        address[] memory tokens = new address[](1);
        tokens[0] = USDT;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000 * 10 ** 6;

        address[] memory recipients = new address[](1);
        recipients[0] = relaySolver;

        bytes memory calldata1 = abi.encodeWithSelector(
            router.cleanupErc20s.selector,
            tokens,
            recipients
        );

        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(router),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.startPrank(relaySolver);
        IERC20(USDT).safeIncreaseAllowance(
            address(approvalProxy),
            1000 * 10 ** 6
        );

        approvalProxy.transferAndMulticall(tokens, amounts, calls, relaySolver);

        assertEq(IERC20(USDT).balanceOf(relaySolver), 1000 * 10 ** 6);
    }

    function testERC721__SafeMintCorrectRecipient() public {
        TestERC721 erc721 = new TestERC721();

        bytes memory calldata1 = abi.encodeWithSignature(
            "safeMint(address,uint256)",
            address(router),
            1
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: address(erc721),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        vm.prank(alice.addr);
        router.multicall(calls, alice.addr);

        assertEq(erc721.ownerOf(1), alice.addr);
    }

    function testERC721__MintMsgSender() public {
        TestERC721 erc721 = new TestERC721();

        bytes memory calldata1 = abi.encodeWithSignature("mint(uint256)", 1);
        bytes memory calldata2 = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)",
            address(router),
            alice.addr,
            1
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](2);
        calls[0] = Multicall3.Call3Value({
            target: address(erc721),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });
        calls[1] = Multicall3.Call3Value({
            target: address(erc721),
            allowFailure: false,
            value: 0,
            callData: calldata2
        });

        vm.prank(alice.addr);
        router.multicall(calls, alice.addr);

        assertEq(erc721.ownerOf(1), alice.addr);
    }

    function testERC721__SafeMintMsgSender() public {
        TestERC721 erc721 = new TestERC721();

        address[] memory targets = new address[](1);
        targets[0] = address(erc721);

        bytes memory calldata1 = abi.encodeWithSignature(
            "safeMint(uint256)",
            1
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](1);
        calls[0] = Multicall3.Call3Value({
            target: address(erc721),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        router.multicall(calls, alice.addr);

        assertEq(erc721.ownerOf(1), alice.addr);
    }

    function defaultERC20PermitTransfer(
        address token,
        uint256 amount,
        uint256 nonce
    )
        internal
        view
        returns (ISignatureTransfer.PermitTransferFrom memory result)
    {
        result.permitted.token = token;
        result.permitted.amount = amount;
        result.nonce = nonce;
        result.deadline = block.timestamp + 100;
    }
}
