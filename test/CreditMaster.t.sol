pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {EIP712} from "solady/src/utils/EIP712.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseRelayTest} from "./base/BaseRelayTest.sol";
import {Multicall3} from "../src/v2/utils/Multicall3.sol";
import {CreditMaster} from "../src/v2/CreditMaster.sol";
import {ApprovalProxy} from "../src/v2/ApprovalProxy.sol";
import {RelayRouter} from "../src/v2/RelayRouter.sol";
import {Call3Value, CallRequest, Result} from "../src/v2/utils/RelayStructs.sol";

contract CreditMasterTest is Test, BaseRelayTest, EIP712 {
    event Deposit(address from, address token, uint256 value, bytes32 id);
    event Withdrawal(address token, uint256 amount, address to);

    error InvalidSignature();
    error Unauthorized();

    CreditMaster cm;
    RelayRouter router;
    ApprovalProxy approvalProxy;

    Account allocator = makeAccountAndDeal("allocator", 1 ether);

    bytes32 public constant _WITHDRAW_REQUEST_TYPEHASH =
        keccak256("WithdrawRequest(address token,uint256 amount,address to)");

    bytes32 public constant DOMAIN_SEPARATOR =
        0x82f0885ae5044a200ee677a7b81601039c097e9ce20f5356020cdf2f472f6a45;

    function setUp() public override {
        super.setUp();

        cm = new CreditMaster(allocator.addr);
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

        Call3Value[] memory calls = new Call3Value[](2);
        calls[0] = Call3Value({
            target: address(erc20_1),
            allowFailure: false,
            value: 0,
            callData: calldata0
        });
        calls[1] = Call3Value({
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

    function testSetAllocator() public {
        Account memory newAllocator = makeAccountAndDeal(
            "newAllocator",
            1 ether
        );

        vm.prank(alice.addr);
        vm.expectRevert(Unauthorized.selector);
        cm.setAllocator(newAllocator.addr);

        cm.setAllocator(newAllocator.addr);
        assertEq(cm.allocator(), newAllocator.addr);
    }

    function testWithdraw__Native(uint256 amount) public {
        // Run depositNative test
        testDepositEth(amount);

        // Create withdraw request
        WithdrawRequest memory request = WithdrawRequest({
            token: address(0),
            amount: amount,
            nonce: 1,
            to: alice.addr
        });

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _WITHDRAW_REQUEST_TYPEHASH,
                    request.token,
                    request.amount,
                    request.to
                )
            )
        );

        // Sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(allocator.key, digest);
        bytes memory signature = bytes.concat(r, s, bytes1(v));

        assertEq(cm.allocator(), allocator.addr);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Withdrawal(address(0), amount, alice.addr);

        // Call `withdraw`
        uint256 aliceBalanceBefore = address(alice.addr).balance;
        cm.withdraw(request, signature);
        uint256 aliceBalanceAfter = address(alice.addr).balance;

        assertEq(aliceBalanceAfter - aliceBalanceBefore, amount);
    }

    function testWithdraw__ERC20(uint96 amount) public {
        testDepositErc20(amount);

        // Create withdraw request
        WithdrawRequest memory request = WithdrawRequest({
            token: address(erc20_1),
            amount: amount,
            nonce: 1,
            to: alice.addr
        });

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _WITHDRAW_REQUEST_TYPEHASH,
                    request.token,
                    request.amount,
                    request.to
                )
            )
        );

        // Sign request
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(allocator.key, digest);
        bytes memory signature = bytes.concat(r, s, bytes1(v));

        assertEq(cm.allocator(), allocator.addr);

        vm.expectEmit(true, true, true, true, address(cm));
        emit Withdrawal(address(erc20_1), amount, alice.addr);

        // Call `withdraw`
        uint256 aliceBalanceBefore = erc20_1.balanceOf(alice.addr);
        cm.withdraw(request, signature);
        uint256 aliceBalanceAfter = erc20_1.balanceOf(alice.addr);

        assertEq(aliceBalanceAfter - aliceBalanceBefore, amount);
    }

    function testWithdraw__InvalidSignature(uint256 amount) public {
        // Create withdraw request
        WithdrawRequest memory request = WithdrawRequest({
            token: address(0),
            amount: amount,
            nonce: 1,
            to: alice.addr
        });

        bytes32 digest = _hashTypedData(
            keccak256(
                abi.encode(
                    _WITHDRAW_REQUEST_TYPEHASH,
                    request.token,
                    request.amount,
                    request.to
                )
            )
        );

        // Sign request with alice's key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alice.key, digest);
        bytes memory signature = bytes.concat(r, s, bytes1(v));

        assertEq(cm.allocator(), allocator.addr);

        vm.expectRevert(InvalidSignature.selector);
        cm.withdraw(request, signature);
    }

    function _domainNameAndVersion()
        internal
        pure
        override
        returns (string memory name, string memory version)
    {
        name = "CreditMaster";
        version = "1";
    }

    // Overwrite _hashTypedData to use CreditMaster's domain separator
    function _hashTypedData(
        bytes32 structHash
    ) internal view override returns (bytes32 digest) {
        digest = DOMAIN_SEPARATOR;
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, digest) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }

    function eip712Domain()
        public
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        fields = hex"0f"; // `0b01111`.
        (name, version) = _domainNameAndVersion();
        chainId = block.chainid;
        verifyingContract = address(cm);
        salt = salt; // `bytes32(0)`.
        extensions = extensions; // `new uint256[](0)`.
    }
}
