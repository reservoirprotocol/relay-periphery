pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {Permit2} from "permit2-relay/src/Permit2.sol";
import {ISignatureTransfer} from "permit2-relay/src/interfaces/ISignatureTransfer.sol";
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

    event Deposit(
        address indexed to,
        address indexed token,
        uint256 value,
        bytes32 commitmentId
    );

    Permit2 permit2 = Permit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    RelayDepositor depositor;

    bytes32 public DOMAIN_SEPARATOR;
    bytes32 public constant _EIP_712_DEPOSITOR_WITNESS_TYPE_HASH =
        keccak256("DepositorWitness(bytes32 commitmentId)");
    bytes32 public constant _FULL_DEPOSITOR_WITNESS_TYPEHASH =
        keccak256(
            "PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,DepositorWitness witness)DepositorWitness(bytes32 commitmentId)TokenPermissions(address token,uint256 amount)"
        );
    string public constant _DEPOSITOR_WITNESS_TYPE_STRING =
        "DepositorWitness witness)DepositorWitness(bytes32 commitmentId)TokenPermissions(address token,uint256 amount)";
    bytes32 public commitmentId = keccak256(abi.encodePacked("commitmentId"));

    function setUp() public override {
        super.setUp();

        depositor = new RelayDepositor(address(permit2));

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

    function testCorrectWitnessTypehashes() public {
        assertEq(
            keccak256(
                abi.encodePacked(
                    _PERMIT_WITNESS_TRANSFER_TYPEHASH_STUB,
                    _DEPOSITOR_WITNESS_TYPE_STRING
                )
            ),
            _FULL_DEPOSITOR_WITNESS_TYPEHASH
        );
    }

    function testPermitTransferFrom() public {
        // Alice approves permit2 on the ERC20
        erc20_1.mint(alice.addr, 1 ether);

        vm.startPrank(alice.addr);
        erc20_1.approve(address(permit2), 1 ether);
        vm.stopPrank();

        // Create the permit
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer
            .PermitTransferFrom({
                permitted: ISignatureTransfer.TokenPermissions({
                    token: address(erc20_1),
                    amount: 1 ether
                }),
                nonce: 1,
                deadline: block.timestamp + 100
            });

        // Create the witness that should be signed over
        bytes32 witness = keccak256(
            abi.encode(_EIP_712_DEPOSITOR_WITNESS_TYPE_HASH, commitmentId)
        );

        // Get the permit signature
        bytes memory permitSig = getPermitWitnessTransferSignature(
            permit,
            address(depositor),
            alice.key,
            _FULL_DEPOSITOR_WITNESS_TYPEHASH,
            witness,
            DOMAIN_SEPARATOR
        );

        vm.expectEmit();
        emit Deposit(relayer.addr, address(erc20_1), 1 ether, commitmentId);
        vm.prank(relayer.addr);
        depositor.permitTransferErc20(
            alice.addr,
            permit,
            commitmentId,
            permitSig
        );
    }
}
