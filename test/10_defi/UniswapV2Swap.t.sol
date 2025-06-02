/*
  Set `FORK_URL` in .env to mainnet URL
  Test using `forge test test/10_defi/UniswapV2Swap.t.sol --fork-url $FORK_URL -vvvv`
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";

import {IERC20} from "@/10_defi/interfaces/IERC20.sol";
import {IWETH} from "@/10_defi/interfaces/IWETH.sol";
import {IUniswapV2Router02} from "@/10_defi/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@/10_defi/interfaces/IUniswapV2Pair.sol";
import {DAI, WETH, MKR, UNISWAP_V2_PAIR_DAI_MKR, UNISWAP_V2_ROUTER_02} from "@/10_defi/Constants.sol";

/**
 * @title UniswapV2 Swap Integration Test
 * @dev Tests interaction with live Uniswap V2 contracts on a forked mainnet
 * Demonstrates how to execute multi-hop swaps through the Uniswap Router
 */
contract UniswapV2SwapTest is Test {
    IWETH private constant weth = IWETH(WETH);
    IERC20 private constant dai = IERC20(DAI);
    IERC20 private constant mkr = IERC20(MKR);

    IUniswapV2Router02 private constant router = IUniswapV2Router02(UNISWAP_V2_ROUTER_02);
    IUniswapV2Pair private constant pair = IUniswapV2Pair(UNISWAP_V2_PAIR_DAI_MKR);

    address private constant user = address(100);

    function setUp() public {
        // Fund test user with ETH and wrap it to WETH
        deal(user, 100 * 1e18);
        vm.startPrank(user);
        weth.deposit{value: 100 * 1e18}();
        weth.approve(address(router), type(uint256).max);
        vm.stopPrank();

        // Add MKR liquidity to DAI/MKR pool
        // This ensures the pool has enough liquidity for our tests
        deal(DAI, address(pair), 1e6 * 1e18);
        deal(MKR, address(pair), 1e5 * 1e18);
        pair.sync();
    }

    /**
     * @notice Tests swapping an exact amount of input tokens for as many output tokens as possible
     * @dev Demonstrates a multi-hop swap: WETH → DAI → MKR
     * Each hop incurs its own 0.3% fee, making direct routes more efficient when available
     * The amountOutMin parameter provides slippage protection against price movements
     */
    function test_swapExactTokensForTokens() public {
        // Define the swap path: WETH → DAI → MKR
        // The path represents the route tokens will take through various liquidity pools
        // Each adjacent pair in the path must have a corresponding liquidity pool
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        // We know exactly how many tokens we're putting in (1 WETH)
        uint256 amountIn = 1e18;
        
        // But we only set a minimum for what we get out (slippage protection)
        // In production, this would be calculated based on expected price + acceptable slippage
        // Setting it to 1 here just ensures we get something back
        uint256 amountOutMin = 1;

        vm.prank(user);
        // swapExactTokensForTokens guarantees exact input amount but variable output
        // This is useful when you have a specific amount to spend and want the best possible return
        uint256[] memory amounts = router.swapExactTokensForTokens({
            amountIn: amountIn,      // Exact amount of WETH we're spending
            amountOutMin: amountOutMin, // Minimum acceptable MKR to receive (slippage protection)
            path: path,              // Swap route through pools
            to: user,                // Recipient of the output tokens
            deadline: block.timestamp // Transaction will revert if not mined by this time
        });

        // The returned amounts array contains the input and output amounts for each step in the path
        // amounts[0] = WETH input (what we're spending)
        // amounts[1] = DAI intermediate (WETH→DAI swap result)
        // amounts[2] = MKR output (DAI→MKR swap result, what we receive)
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);

        // Verify we received at least the minimum amount of MKR
        assertGe(mkr.balanceOf(user), amountOutMin, "MKR balance of user");
    }

    /**
     * @notice Tests receiving an exact amount of output tokens for as few input tokens as possible
     * @dev Unlike swapExactTokensForTokens which specifies input amount, this specifies output amount
     * The router calculates the required input amount based on current prices
     * The amountInMax parameter provides protection against paying too much
     * This is useful when you need a specific amount of tokens (e.g., for debt repayment)
     */
    function test_swapTokensForExactTokens() public {
        // Define the swap path: WETH → DAI → MKR
        // Same path as previous test, but the swap mechanics differ
        address[] memory path = new address[](3);
        path[0] = WETH;
        path[1] = DAI;
        path[2] = MKR;

        // We specify exactly how many tokens we want to receive (0.1 MKR)
        // This is useful when you need a precise amount for a specific purpose
        uint256 amountOut = 0.1 * 1e18;
        
        // But we set a maximum for what we're willing to pay (price protection)
        // In production, this would be calculated based on expected price + acceptable premium
        uint256 amountInMax = 1e18;

        vm.prank(user);
        // swapTokensForExactTokens guarantees exact output amount but variable input
        // The router will use only as much input as needed to get the exact output
        uint256[] memory amounts = router.swapTokensForExactTokens({
            amountOut: amountOut,    // Exact amount of MKR we want to receive
            amountInMax: amountInMax, // Maximum WETH we're willing to spend
            path: path,              // Swap route through pools
            to: user,                // Recipient of the output tokens
            deadline: block.timestamp // Transaction will revert if not mined by this time
        });

        // The returned amounts array works the same way as in swapExactTokensForTokens
        // But now amounts[0] is calculated by the router to be just enough to get amounts[2]
        // amounts[0] = WETH input (calculated by router, what we're spending)
        // amounts[1] = DAI intermediate (WETH→DAI swap result)
        // amounts[2] = MKR output (DAI→MKR swap result, exactly what we requested)
        console2.log("WETH", amounts[0]);
        console2.log("DAI", amounts[1]);
        console2.log("MKR", amounts[2]);

        // Verify we received exactly the requested amount of MKR
        assertEq(mkr.balanceOf(user), amountOut, "MKR balance of user");
    }
}
