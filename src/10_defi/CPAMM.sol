// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "./interfaces/IERC20.sol";

error InvalidToken();
error InsufficientAmount();
error InvalidLiquidityRatio();
error InsufficientLiquidityMinted();
error InsufficientLiquidityBurned();

/**
 * @title Constant Product Automated Market Maker (CPAMM)
 * @dev Implementation of a basic AMM using the constant product formula (x*y=k)
 * This is similar to Uniswap V2's core pricing mechanism where the product of 
 * the reserves must remain constant after trades (minus fees)
 */
contract CPAMM {
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    /**
     * @notice Initializes the CPAMM contract with two tokens
     * @param _token0 Address of the first token
     * @param _token1 Address of the second token
     */
    constructor(address _token0, address _token1) {
        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    /**
     * @notice Exchange one token for another using the constant product formula
     * @param _tokenIn Address of the token being provided to the pool
     * @param _amountIn Amount of input tokens to swap
     * @dev Implements the core AMM formula that powers Uniswap V2 and similar DEXs
     * The 0.3% fee is standard in many AMMs and serves as revenue for liquidity providers
     * The formula ensures that as trades get larger, price impact increases (slippage)
     * This creates a price curve where larger trades become increasingly expensive
     */
    function swap(address _tokenIn, uint256 _amountIn) external {
        if (_tokenIn != address(token0) && _tokenIn != address(token1)) {
            revert InvalidToken();
        }
        if (_amountIn == 0) {
            revert InsufficientAmount();
        }

        bool isToken0 = _tokenIn == address(token0);
        (
            IERC20 tokenIn,
            IERC20 tokenOut,
            uint256 reserveIn,
            uint256 reserveOut
        ) = isToken0
                ? (token0, token1, reserve0, reserve1)
                : (token1, token0, reserve1, reserve0);

        tokenIn.transferFrom(msg.sender, address(this), _amountIn);

        // Calculate swap amount:
        // 1. Take 0.3% fee by using only 99.7% of input amount
        // 2. Use the formula: (amount_out = pool_out * amount_in / (pool_in + amount_in))
        // This formula maintains x*y=k after the swap (the constant product)
        uint256 amountInWithFee = (_amountIn * 997) / 1000;
        uint256 amountOut = (reserveOut * amountInWithFee) /
            (reserveIn + amountInWithFee);

        tokenOut.transfer(msg.sender, amountOut);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    /**
     * @notice Add tokens to the pool and receive LP tokens representing pool ownership
     * @param _amount0 Amount of token0 to add to the pool
     * @param _amount1 Amount of token1 to add to the pool
     * @return shares Number of LP tokens minted to the provider
     * @dev For initial liquidity, LP tokens = sqrt(amount0 * amount1)
     * For subsequent deposits, LP tokens are proportional to contribution relative to existing reserves
     * Enforces that liquidity must be added in the same ratio as current reserves to prevent manipulation
     */
    function addLiquidity(
        uint256 _amount0,
        uint256 _amount1
    ) external returns (uint256 shares) {
        token0.transferFrom(msg.sender, address(this), _amount0);
        token1.transferFrom(msg.sender, address(this), _amount1);

        // If pool already has tokens, make sure new tokens are added in same ratio
        // The check uses: current_token0/current_token1 = new_token0/new_token1
        // Rearranged to avoid division: current_token0 * new_token1 = current_token1 * new_token0
        if (reserve0 > 0 || reserve1 > 0) {
            if (reserve0 * _amount1 != reserve1 * _amount0)
                revert InvalidLiquidityRatio();
        }

        // Calculate how many LP tokens (shares) to give:
        if (totalSupply == 0) {
            // For first liquidity: use square root of token0*token1
            // This sets initial LP tokens proportional to pool value
            shares = _sqrt(_amount0 * _amount1);
        } else {
            // For later additions: give LP tokens proportional to contribution
            // If you add 10% more to the pool, you get 10% of existing LP tokens
            shares = _min(
                (_amount0 * totalSupply) / reserve0,
                (_amount1 * totalSupply) / reserve1
            );
        }

        if (shares == 0) revert InsufficientLiquidityMinted();

        _mint(msg.sender, shares);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this))
        );
    }

    /**
     * @notice Burn LP tokens to withdraw liquidity from the pool
     * @param _shares Amount of LP tokens to burn
     * @return amount0 Amount of token0 returned to the user
     * @return amount1 Amount of token1 returned to the user
     * @dev Liquidity withdrawal is proportional to ownership percentage
     * If you own 10% of LP tokens, you get 10% of each token in the pool
     * This includes both original deposits and accrued fees, which are automatically
     * reinvested into the pool, increasing the value of LP tokens over time
     */
    function removeLiquidity(
        uint256 _shares
    ) external returns (uint256 amount0, uint256 amount1) {
        // Calculate how many tokens to return:
        // If you have 10% of all LP tokens, you get 10% of each token in the pool
        uint256 bal0 = token0.balanceOf(address(this));
        uint256 bal1 = token1.balanceOf(address(this));

        amount0 = (_shares * bal0) / totalSupply;
        amount1 = (_shares * bal1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidityBurned();

        _burn(msg.sender, _shares);

        _update(bal0 - amount0, bal1 - amount1);

        token0.transfer(msg.sender, amount0);
        token1.transfer(msg.sender, amount1);
    }

    /* ============================================================================================== */
    /*                                        PRIVATE FUNCTIONS                                       */
    /* ============================================================================================== */

    /**
     * @notice Mints new LP tokens and assigns them to an address
     * @param _to Address to receive the minted LP tokens
     * @param _amount Amount of LP tokens to mint
     * @dev LP tokens represent proportional ownership of the pool's assets
     */
    function _mint(address _to, uint256 _amount) private {
        balanceOf[_to] += _amount;
        totalSupply += _amount;
    }

    /**
     * @notice Burns LP tokens from an address
     * @param _from Address to burn LP tokens from
     * @param _amount Amount of LP tokens to burn
     */
    function _burn(address _from, uint256 _amount) private {
        balanceOf[_from] -= _amount;
        totalSupply -= _amount;
    }

    /**
     * @dev Updates the pool reserves to match current token balances
     * @param _reserve0 New reserve amount for token0
     * @param _reserve1 New reserve amount for token1
     */
    function _update(uint256 _reserve0, uint256 _reserve1) private {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    /**
     * @dev Calculates the square root of a number using the Babylonian method
     * @param y Number to calculate square root of
     * @return z Square root of the input
     * @dev Used for calculating initial LP tokens as geometric mean of deposits
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

    /**
     * @dev Returns the minimum of two numbers
     * @param x First number
     * @param y Second number
     * @return The smaller of the two inputs
     */
    function _min(uint256 x, uint256 y) private pure returns (uint256) {
        return x <= y ? x : y;
    }
}
