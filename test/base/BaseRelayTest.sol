// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IUniswapV2Factory} from "../interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "../interfaces/IUniswapV2Router02.sol";
import {TestERC20} from "../mocks/TestERC20.sol";
import {WETH9} from "../mocks/WETH9.sol";

contract BaseRelayTest is Test {
    Account relayer;
    Account validator;
    Account oracle;
    Account solver;
    Account alice;
    Account bob;

    TestERC20 erc20_1;
    TestERC20 erc20_2;
    TestERC20 erc20_3;
    WETH9 weth;

    address relaySolver = 0xf70da97812CB96acDF810712Aa562db8dfA3dbEF;

    address UNISWAP_V2 = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    address ROUTER_V2 = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    function setUp() public virtual {
        relayer = makeAccountAndDeal("relayer", 10 ether);
        validator = makeAccountAndDeal("validator", 10 ether);
        oracle = makeAccountAndDeal("oracle", 10 ether);
        solver = makeAccountAndDeal("solver", 10 ether);
        alice = makeAccountAndDeal("alice", 10 ether);
        bob = makeAccountAndDeal("bob", 10 ether);

        erc20_1 = new TestERC20();
        erc20_2 = new TestERC20();
        erc20_3 = new TestERC20();

        erc20_1.mint(address(this), 100 ether);
        erc20_2.mint(address(this), 100 ether);
        erc20_3.mint(address(this), 100 ether);
    }

    function makeAccountAndDeal(
        string memory name,
        uint256 amount
    ) internal returns (Account memory) {
        (address addr, uint256 pk) = makeAddrAndKey(name);

        vm.deal(addr, amount);

        return Account({addr: addr, key: pk});
    }
}
