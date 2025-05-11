// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IOptimizedStakingContract {
    struct StakerData {
        uint256 stakedAmount;
        uint256 lastUpdateBlock;
        uint256 rewardsAccumulated;
    }

    event Stake(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardClaim(address indexed user, uint256 reward);
}
