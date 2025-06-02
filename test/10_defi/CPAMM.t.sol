// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";

import {CPAMM, InvalidLiquidityRatio, InvalidToken, InsufficientAmount} from "@/10_defi/CPAMM.sol";
import {IERC20} from "@/10_defi/interfaces/IERC20.sol";
import {MockERC20} from "./mocks/ERC20.sol";

/**
 * @title CPAMM (Constant Product AMM) Test Suite
 * @dev Comprehensive tests for the CPAMM implementation
 * Tests cover the core AMM functionality including:
 * - Liquidity provision and withdrawal
 * - Token swaps and price impact
 * - Fee collection and constant product invariant
 */
contract CPAMMTest is Test {
    uint256 public constant INITIAL_LIQUIDITY_TOKEN0 = 1000 ether;
    uint256 public constant INITIAL_LIQUIDITY_TOKEN1 = 500 ether;

    CPAMM public cpamm;
    MockERC20 public token0;
    MockERC20 public token1;

    address public user1 = address(0x1);
    address public user2 = address(0x2);

    function setUp() public {
        // 1. Deploy mock tokens
        token0 = new MockERC20("Token0", "TK0", 18);
        token1 = new MockERC20("Token1", "TK1", 18);

        // 2. Ensure tokens are sorted by address (required by many AMMs)
        if (address(token0) > address(token1)) {
            (token0, token1) = (token1, token0);
        }

        // 3. Deploy CPAMM
        cpamm = new CPAMM(address(token0), address(token1));

        // 4. Mint tokens to users
        token0.mint(user1, 2000 ether);
        token1.mint(user1, 1000 ether);
        token0.mint(user2, 1000 ether);
        token1.mint(user2, 2000 ether);

        // 5. Give allowance for the test contract
        vm.startPrank(user1);
        token0.approve(address(cpamm), type(uint256).max);
        token1.approve(address(cpamm), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token0.approve(address(cpamm), type(uint256).max);
        token1.approve(address(cpamm), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @dev Verifies the initial state of the CPAMM contract
     * Ensures that token addresses are set correctly and reserves start at zero
     */
    function testInitialState() public view {
        assertEq(address(cpamm.token0()), address(token0));
        assertEq(address(cpamm.token1()), address(token1));
        assertEq(cpamm.reserve0(), 0);
        assertEq(cpamm.reserve1(), 0);
        assertEq(cpamm.totalSupply(), 0);
    }

    /**
     * @dev Tests adding initial liquidity to an empty pool
     * For first liquidity provider, LP tokens = sqrt(amount0 * amount1)
     * This formula sets initial LP tokens proportional to pool value
     * and makes LP token value invariant to the ratio of tokens provided
     */
    function testAddInitialLiquidity() public {
        vm.startPrank(user1);

        uint256 shares = cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);

        // 1. Check LP tokens minted
        assertEq(shares, _sqrt(INITIAL_LIQUIDITY_TOKEN0 * INITIAL_LIQUIDITY_TOKEN1));
        assertEq(cpamm.balanceOf(user1), shares);
        assertEq(cpamm.totalSupply(), shares);

        // 2. Check reserves updated
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1);

        // 3. Check token balances
        assertEq(token0.balanceOf(address(cpamm)), INITIAL_LIQUIDITY_TOKEN0);
        assertEq(token1.balanceOf(address(cpamm)), INITIAL_LIQUIDITY_TOKEN1);

        vm.stopPrank();
    }

    /**
     * @dev Tests adding more liquidity to an existing pool
     * For subsequent liquidity providers, LP tokens are proportional to contribution
     * If you add 10% more to the pool, you get 10% of existing LP tokens
     * This test also verifies that the ratio of added tokens must match the pool's ratio
     */
    function testAddMoreLiquidity() public {
        // 1. First add initial liquidity
        vm.startPrank(user1);
        uint256 initialShares = cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);
        vm.stopPrank();

        uint256 addToken0 = 500 ether;
        uint256 addToken1 = 250 ether; // Must maintain the ratio

        vm.startPrank(user2);
        uint256 newShares = cpamm.addLiquidity(addToken0, addToken1);
        vm.stopPrank();

        // 2. Check new shares calculation
        uint256 expectedShares = (addToken0 * initialShares) / INITIAL_LIQUIDITY_TOKEN0;
        assertEq(newShares, expectedShares);

        // 3. Check LP tokens
        assertEq(cpamm.balanceOf(user2), newShares);
        assertEq(cpamm.totalSupply(), initialShares + newShares);

        // 4. Check reserves
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 + addToken0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 + addToken1);
    }

    /**
     * @dev Tests that adding liquidity with incorrect token ratio reverts
     * This is a key protection mechanism in AMMs to prevent price manipulation
     * All liquidity must be added in the same ratio as current reserves
     */
    function test_RevertIfAddLiquidityWrongRatio() public {
        // 1. First add initial liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);
        vm.stopPrank();

        // 2. Try to add liquidity with incorrect ratio
        vm.startPrank(user2);
        vm.expectRevert(InvalidLiquidityRatio.selector);
        cpamm.addLiquidity(500 ether, 300 ether); // Wrong ratio, should revert
        vm.stopPrank();
    }

    /**
     * @dev Tests swapping token0 for token1
     * Verifies the constant product formula (x*y=k) and fee collection
     * The 0.3% fee is kept in the pool, which increases the product value (k)
     * This creates a positive feedback loop: more liquidity → better prices → more volume → more fees
     */
    function testSwapToken0ForToken1() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);

        uint256 swapAmount = 100 ether;
        uint256 user1BalanceBefore = token1.balanceOf(user1);

        // 2. Calculate expected output amount (based on the formula used in the contract)
        uint256 amountInWithFee = (swapAmount * 997) / 1000;
        uint256 expectedOut =
            (INITIAL_LIQUIDITY_TOKEN1 * amountInWithFee) / (INITIAL_LIQUIDITY_TOKEN0 + amountInWithFee);

        // 3. Perform swap
        cpamm.swap(address(token0), swapAmount);
        vm.stopPrank();

        // 4. Check balances
        assertEq(token1.balanceOf(user1), user1BalanceBefore + expectedOut);
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 + swapAmount);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 - expectedOut);

        // 5. Verify constant product formula
        uint256 k1 = INITIAL_LIQUIDITY_TOKEN0 * INITIAL_LIQUIDITY_TOKEN1;
        uint256 k2 = cpamm.reserve0() * cpamm.reserve1();

        // Due to fees, k2 can be greater than k1
        // This is because the fee is kept in the pool, which increases the product
        assertGe(k2, (k1 * 997) / 1000); // Should be at least 99.7% of original k value
    }

    /**
     * @dev Tests swapping token1 for token0
     * Demonstrates that swaps work symmetrically in both directions
     * The same constant product formula applies regardless of swap direction
     */
    function testSwapToken1ForToken0() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);
        vm.stopPrank();

        vm.startPrank(user2);
        uint256 swapAmount = 50 ether;
        uint256 user2BalanceBefore = token0.balanceOf(user2);

        // 2. Calculate expected output amount
        uint256 amountInWithFee = (swapAmount * 997) / 1000;
        uint256 expectedOut =
            (INITIAL_LIQUIDITY_TOKEN0 * amountInWithFee) / (INITIAL_LIQUIDITY_TOKEN1 + amountInWithFee);

        // 3. Perform swap
        cpamm.swap(address(token1), swapAmount);
        vm.stopPrank();

        // 4. Check balances
        assertEq(token0.balanceOf(user2), user2BalanceBefore + expectedOut);
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 - expectedOut);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 + swapAmount);
    }

    /**
     * @dev Tests that swapping with an invalid token reverts
     * AMMs can only swap tokens that are part of their pool
     */
    function test_RevertIfSwapInvalidToken() public {
        address fakeToken = makeAddr("fakeToken");
        vm.expectRevert(InvalidToken.selector);
        cpamm.swap(fakeToken, 100 ether);
    }

    /**
     * @dev Tests that swapping zero amount reverts
     * Zero amount swaps would waste gas and potentially manipulate prices
     */
    function test_RevertIfSwapZeroAmount() public {
        vm.expectRevert(InsufficientAmount.selector);
        cpamm.swap(address(token0), 0);
    }

    /**
     * @dev Tests removing liquidity from the pool
     * Verifies that LP tokens are burned and underlying assets are returned proportionally
     * If you own 10% of LP tokens, you get 10% of each token in the pool
     * This includes both original deposits and accrued fees
     */
    function testRemoveLiquidity() public {
        // 1. First add liquidity
        vm.startPrank(user1);
        uint256 shares = cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);

        uint256 token0Before = token0.balanceOf(user1);
        uint256 token1Before = token1.balanceOf(user1);

        // 2. Remove half of the liquidity
        uint256 sharesToRemove = shares / 2;
        (uint256 amount0, uint256 amount1) = cpamm.removeLiquidity(sharesToRemove);
        vm.stopPrank();

        // 3. Check tokens returned
        assertEq(amount0, INITIAL_LIQUIDITY_TOKEN0 / 2);
        assertEq(amount1, INITIAL_LIQUIDITY_TOKEN1 / 2);

        // 4. Verify user received tokens
        assertEq(token0.balanceOf(user1), token0Before + amount0);
        assertEq(token1.balanceOf(user1), token1Before + amount1);

        // 5. Verify LP tokens burned
        assertEq(cpamm.balanceOf(user1), shares - sharesToRemove);
        assertEq(cpamm.totalSupply(), shares - sharesToRemove);

        // 6. Verify reserves updated
        assertEq(cpamm.reserve0(), INITIAL_LIQUIDITY_TOKEN0 - amount0);
        assertEq(cpamm.reserve1(), INITIAL_LIQUIDITY_TOKEN1 - amount1);
    }

    /**
     * @dev Tests that removing more liquidity than owned reverts
     * Prevents users from withdrawing more than their fair share
     */
    function test_RevertIfRemoveTooMuchLiquidity() public {
        // 1. Add liquidity
        vm.startPrank(user1);
        uint256 shares = cpamm.addLiquidity(INITIAL_LIQUIDITY_TOKEN0, INITIAL_LIQUIDITY_TOKEN1);

        // 2. Try to remove more shares than owned
        vm.expectRevert();
        cpamm.removeLiquidity(shares + 1);
        vm.stopPrank();
    }

    /**
     * @dev Calculates the square root of a number using the Babylonian method
     * Used for calculating initial LP tokens as geometric mean of deposits
     */
    function _sqrt(uint256 y) private pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
