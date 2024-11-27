pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {RelayDepositor} from "../src/RelayDepositor.sol";

contract RelayDepositorTest is Test, BaseRelayTest {
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
    RelayDepositor depositor;
    ApprovalProxy approvalProxy;

    bytes32 public DOMAIN_SEPARATOR;

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
}
