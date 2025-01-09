pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {RelayCreditManager} from "../src/RelayCreditManager.sol";

contract RelayCreditManagerTest is Test, BaseRelayTest {
    event Deposit(address from, address token, uint256 value, bytes32 id);

    RelayCreditManager cm;
    address allocator = vm.addr(69);

    function setUp() public override {
        super.setUp();

        cm = new RelayCreditManager(allocator);

        erc20_1.mint(alice.addr, 1 ether);
        erc20_2.mint(alice.addr, 1 ether);
        erc20_3.mint(alice.addr, 1 ether);
    }

    function testDepositEth(uint256 amount) public {
        vm.deal(alice.addr, amount);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Deposit(alice.addr, address(0), amount, bytes32(0));

        vm.prank(alice.addr);
        cm.depositNative{value: amount}(alice.addr, bytes32(0));
        assertEq(address(cm).balance, amount);
    }
}
