// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {StdUtils} from "forge-std/StdUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAllowanceHolder} from "0x-settler/src/allowanceholder/IAllowanceHolder.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {ApprovalProxy} from "../src/v2/ApprovalProxy.sol";
import {OwnableRelayRouter} from "../src/v2/OwnableRelayRouter.sol";
import {Call3Value} from "../src/v2/utils/RelayStructs.sol";
import {NoOpERC20} from "./mocks/NoOpERC20.sol";
import {TestERC721} from "./mocks/TestERC721.sol";
import {TestERC721_ERC20PaymentToken} from "./mocks/TestERC721_ERC20PaymentToken.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router02.sol";

contract OwnableRelayRouterTest is Test, BaseRelayTest {
    Permit2 permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    OwnableRelayRouter ownableRouter;

    error Unauthorized();

    function setUp() public override {
        super.setUp();

        ownableRouter = new OwnableRelayRouter(solver.addr);
    }

    function testMulticall__RevertOnlyOwner() public {
        Call3Value[] memory calls = new Call3Value[](1);
        calls[0] = Call3Value({
            target: address(0),
            allowFailure: false,
            value: 0,
            callData: abi.encodeWithSelector(
                OwnableRelayRouter.multicall.selector,
                calls,
                address(0)
            )
        });

        vm.expectRevert(Unauthorized.selector);
        vm.prank(alice.addr);
        ownableRouter.multicall(calls, address(0), address(0));
    }
}
