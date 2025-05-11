// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IOptimizedStakingContract} from "./IOptimizedStakingContract.sol";
import {IERC20} from "./IERC20.sol";

/**
 * @dev Custom errors for gas optimization
 * Saves gas compared to string error messages by reducing deployment and runtime costs
 */
error ZeroAmount();
error NotEnoughStaked();

/**
 * @dev The original contract had a CRITICAL bug: in `updateReward()` it used memory instead of storage
 *      for `UserInfo` (or `StakerData` here), meaning reward calculations were done but never saved to storage
 *
 * MAJOR OPTIMIZATIONS IMPLEMENTED:
 * 1. FIX: Memory vs Storage bug fixed by using storage references
 * 2. GAS SAVE: Removed stakers array completely to avoid duplicates and O(n) operations
 * 3. GAS SAVE: Added immutable variables for constants
 * 4. GAS SAVE: Used custom errors instead of string error messages
 * 5. GAS SAVE: Better code organization with public/private separation
 * 6. GAS SAVE: Consistent storage usage patterns
 * 7. GAS SAVE: Extracted common calculation logic to a separate function
 * 8. GAS SAVE: Improved naming conventions for better readability
 *
 * THIS CONTRACT IS USED FOR EDUCATIONAL PURPOSES ONLY.
 * DO NOT USE IT IN PRODUCTION ENVIRONMENTS.
 */
contract StakingContractOptimised is IOptimizedStakingContract {
    /**
     * @dev OPTIMIZATION: Using immutable for values that never change after construction
     * Saves gas per access compared to regular state variables
     */
    IERC20 public immutable STAKING_TOKEN;
    uint256 public immutable REWARD_RATE;

    /**
     * @dev OPTIMIZATION: Removed the stakers array completely
     * This eliminates duplicate entries and O(n) operations
     *
     * OPTIMIZATION: Improved naming from UserInfo to StakerData for clarity
     *
     * OPTIMIZATION: Using named mapping parameters for better code readability
     * This is a gas-neutral change but improves code quality
     */
    mapping(address staker => StakerData) public stakers;

    constructor(address _stakingToken, uint256 _rewardRate) {
        STAKING_TOKEN = IERC20(_stakingToken);
        REWARD_RATE = _rewardRate;
    }

    /* ============================================================================================== */
    /*                                         PUBLIC METHODS                                         */
    /* ============================================================================================== */

    /**
     * @dev Stakes tokens in the contract
     *
     * OPTIMIZATIONS:
     * 1. Uses custom errors instead of string error messages
     * 2. Gets storage reference once and reuses it
     * 3. No stakers array to maintain
     * 4. Proper storage usage with storage keyword
     * 5. Better code organization
     */
    function stake(uint256 amount) external {
        // OPTIMIZATION: Custom error instead of require with string
        if (amount == 0) revert ZeroAmount();

        // OPTIMIZATION: Get storage reference once and reuse it
        // FIX: Using storage instead of memory ensures changes persist
        StakerData storage staker = stakers[msg.sender];

        STAKING_TOKEN.transferFrom(msg.sender, address(this), amount);

        // FIX: Using a private function with storage reference ensures rewards are properly updated
        _updateReward(staker);
        staker.stakedAmount += amount;

        emit Stake(msg.sender, amount);
    }

    /**
     * @dev Withdraws staked tokens
     *
     * OPTIMIZATIONS:
     * 1. Uses custom errors instead of string error messages
     * 2. Gets storage reference once and reuses it
     * 3. No need to remove from stakers array
     * 4. Proper storage usage with storage keyword
     */
    function withdraw(uint256 amount) external {
        // OPTIMIZATION: Custom error instead of require with string
        if (amount == 0) revert ZeroAmount();

        // OPTIMIZATION: Get storage reference once and reuse it
        // FIX: Using storage instead of memory ensures changes persist
        StakerData storage staker = stakers[msg.sender];
        if (staker.stakedAmount < amount) revert NotEnoughStaked();

        // FIX: Using a private function with storage reference ensures rewards are properly updated
        _updateReward(staker);
        staker.stakedAmount -= amount;

        STAKING_TOKEN.transfer(msg.sender, amount);

        emit Withdraw(msg.sender, amount);
    }

    /**
     * @dev Claims accumulated rewards
     *
     * OPTIMIZATIONS:
     * 1. Gets storage reference once and reuses it
     * 2. Proper storage usage with storage keyword
     * 3. Better code organization
     */
    function claimReward() external {
        // OPTIMIZATION: Get storage reference once and reuse it
        // FIX: Using storage instead of memory ensures changes persist
        StakerData storage staker = stakers[msg.sender];

        // FIX: Using a private function with storage reference ensures rewards are properly updated
        _updateReward(staker);

        uint256 reward = staker.rewardsAccumulated;

        if (reward > 0) {
            staker.rewardsAccumulated = 0;

            STAKING_TOKEN.transfer(msg.sender, reward);

            emit RewardClaim(msg.sender, reward);
        }
    }

    /* ============================================================================================== */
    /*                                          VIEW METHODS                                          */
    /* ============================================================================================== */

    /**
     * @dev Returns pending reward for an account
     *
     * OPTIMIZATIONS:
     * 1. Named return variable for gas savings
     * 2. Reuses calculation logic from private function
     * 3. Proper storage usage with storage keyword
     */
    function getPendingReward(address account) external view returns (uint256 pending) {
        // OPTIMIZATION: Get storage reference once and reuse it
        StakerData storage staker = stakers[account];

        pending = staker.rewardsAccumulated;

        if (staker.stakedAmount > 0) {
            // OPTIMIZATION: Reuse calculation logic from private function
            pending += _calculateNewRewards(staker.stakedAmount, staker.lastUpdateBlock);
        }
    }

    /* ============================================================================================== */
    /*                                         PRIVATE METHODS                                        */
    /* ============================================================================================== */

    /**
     * @dev Updates reward for a specific staker
     *
     * CRITICAL FIX: This function now uses storage for the StakerData struct,
     * which means changes are properly saved back to storage.
     *
     * OPTIMIZATIONS:
     * 1. Takes a storage reference parameter instead of an address
     * 2. Extracts calculation logic to a separate function
     * 3. Private visibility for internal use only
     */
    function _updateReward(StakerData storage staker) private {
        if (staker.stakedAmount > 0) {
            // OPTIMIZATION: Reuse calculation logic from private function
            staker.rewardsAccumulated += _calculateNewRewards(staker.stakedAmount, staker.lastUpdateBlock);
        }
        staker.lastUpdateBlock = block.number;
    }

    /**
     * @dev Calculates new rewards based on staked amount and last update block
     *
     * OPTIMIZATIONS:
     * 1. Extracted common calculation logic to reduce code duplication
     * 2. Private visibility for internal use only
     * 3. View function for gas efficiency
     */
    function _calculateNewRewards(uint256 _stakedAmount, uint256 _lastUpdateBlock) private view returns (uint256) {
        uint256 blocksSinceLastUpdate = block.number - _lastUpdateBlock;
        return (_stakedAmount * REWARD_RATE * blocksSinceLastUpdate) / 1e18;
    }
}
