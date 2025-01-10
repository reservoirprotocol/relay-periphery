pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {Multicall3} from "../src/utils/Multicall3.sol";
import {RelayCreditManager} from "../src/RelayCreditManager.sol";
import {ApprovalProxy} from "../src/ApprovalProxy.sol";
import {RelayRouter} from "../src/RelayRouter.sol";

contract RelayCreditManagerTest is Test, BaseRelayTest {
    event Deposit(address from, address token, uint256 value, bytes32 id);

    RelayCreditManager cm;
    RelayRouter router;
    ApprovalProxy approvalProxy;

    address allocator = vm.addr(69);

    function setUp() public override {
        super.setUp();

        cm = new RelayCreditManager(allocator);
        router = new RelayRouter(PERMIT2);
        approvalProxy = new ApprovalProxy(address(this), address(router));
    }

    function testDepositEth(uint256 amount) public {
        vm.deal(alice.addr, amount);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Deposit(alice.addr, address(0), amount, bytes32(uint256(1)));

        vm.prank(alice.addr);
        cm.depositNative{value: amount}(alice.addr, bytes32(uint256(1)));
        assertEq(address(cm).balance, amount);
    }

    function testDepositErc20(uint96 amount) public {
        erc20_1.mint(alice.addr, amount);

        vm.startPrank(alice.addr);

        // Alice approves CM to pull tokens
        IERC20(address(erc20_1)).approve(address(cm), amount);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Deposit(alice.addr, address(erc20_1), amount, bytes32(uint256(1)));

        // Alice deposits ERC20s to CM
        cm.depositErc20(
            alice.addr,
            address(erc20_1),
            amount,
            bytes32(uint256(1))
        );
    }

    function testDepositErc20__ApprovalProxy(uint96 amount) public {
        erc20_1.mint(alice.addr, amount);

        bytes memory calldata0 = abi.encodeWithSelector(
            erc20_1.approve.selector,
            address(cm),
            amount
        );

        bytes memory calldata1 = abi.encodeWithSelector(
            cm.depositErc20.selector,
            alice.addr,
            address(erc20_1),
            amount,
            bytes32("test")
        );

        Multicall3.Call3Value[] memory calls = new Multicall3.Call3Value[](2);
        calls[0] = Multicall3.Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata0
        });
        calls[1] = Multicall3.Call3Value({
            target: address(cm),
            allowFailure: false,
            value: 0,
            callData: calldata1
        });

        address[] memory tokens = new address[](1);
        tokens[0] = address(erc20_1);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.startPrank(alice.addr);

        // Alice approves AP to pull tokens
        IERC20(address(erc20_1)).approve(address(approvalProxy), amount);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Deposit(alice.addr, address(erc20_1), amount, bytes32("test"));

        // Alice transfers ERC20s to ApprovalProxy
        // ApprovalProxy transfers tokens to RelayRouter
        // RelayRouter calls `depositErc20` on CreditManager to deposit on behalf of Alice
        approvalProxy.transferAndMulticall(tokens, amounts, calls, address(0));

        assertEq(amount, erc20_1.balanceOf(address(cm)));
    }
}
