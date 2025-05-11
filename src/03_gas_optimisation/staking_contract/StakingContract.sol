// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev A simple staking contract with inefficient gas implementation
 * 
 * CRITICAL BUGS & GAS INEFFICIENCIES:
 * 1. CRITICAL BUG: Memory vs Storage in updateReward() - changes don't persist
 * 2. Gas Waste: Duplicate entries in stakers array
 * 3. Gas Waste: No immutable variables for constants
 * 4. Gas Waste: Inefficient reward calculation approach
 * 5. Gas Waste: Unnecessary updateAllRewards() function with O(n) complexity
 * 6. Gas Waste: No custom errors (uses string error messages)
 * 7. Gas Waste: Inconsistent storage usage patterns
 * 8. Gas Waste: No code organization/separation of concerns
 */
contract StakingContract {
    // INEFFICIENCY: These should be marked as immutable since they never change after construction
    IERC20 public stakingToken;
    uint256 public rewardRate = 100;

    struct UserInfo {
        uint256 stakedAmount;
        uint256 lastUpdateBlock;
        uint256 rewardsAccumulated;
    }

    mapping(address => UserInfo) public userInfo;
    
    // INEFFICIENCY: This array can contain duplicate addresses, wasting gas
    // INEFFICIENCY: No way to remove addresses when they unstake completely
    address[] public stakers;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(address _stakingToken) {
        stakingToken = IERC20(_stakingToken);
    }

    /**
     * @dev Stakes tokens in the contract
     * 
     * INEFFICIENCIES:
     * 1. Uses string for error message instead of custom errors
     * 2. Blindly adds user to stakers array without checking for duplicates
     * 3. Calls updateReward() which has a critical bug
     */
    function stake(uint256 amount) external {
        // INEFFICIENCY: String errors use more gas than custom errors
        require(amount > 0, "Cannot stake 0");

        // CRITICAL BUG: This calls the buggy updateReward function
        // which doesn't actually persist any changes to storage
        updateReward(msg.sender);

        stakingToken.transferFrom(msg.sender, address(this), amount);

        userInfo[msg.sender].stakedAmount += amount;
        
        // INEFFICIENCY: This adds the user to the array without checking if they're already in it
        // This creates duplicates and wastes gas in the updateAllRewards function
        stakers.push(msg.sender); // Could add duplicates?

        emit Staked(msg.sender, amount);
    }

    /**
     * @dev Withdraws staked tokens
     * 
     * INEFFICIENCIES:
     * 1. Uses string for error messages instead of custom errors
     * 2. Calls updateReward() which has a critical bug
     * 3. Doesn't remove user from stakers array if they withdraw everything
     */
    function withdraw(uint256 amount) external {
        // INEFFICIENCY: String errors use more gas than custom errors
        require(amount > 0, "Cannot withdraw 0");
        require(userInfo[msg.sender].stakedAmount >= amount, "Not enough staked");

        // CRITICAL BUG: This calls the buggy updateReward function
        // which doesn't actually persist any changes to storage
        updateReward(msg.sender);

        userInfo[msg.sender].stakedAmount -= amount;
        stakingToken.transfer(msg.sender, amount);

        // INEFFICIENCY: If user withdraws everything, they should be removed from stakers array
        // but there's no logic to handle this

        emit Withdrawn(msg.sender, amount);
    }

    /**
     * @dev Claims accumulated rewards
     * 
     * INEFFICIENCIES:
     * 1. Calls updateReward() which has a critical bug
     */
    function claimReward() external {
        // CRITICAL BUG: This calls the buggy updateReward function
        // which doesn't actually persist any changes to storage
        updateReward(msg.sender);

        uint256 reward = userInfo[msg.sender].rewardsAccumulated;
        if (reward > 0) {
            userInfo[msg.sender].rewardsAccumulated = 0;
            stakingToken.transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    /**
     * @dev Updates reward for a specific account
     * 
     * CRITICAL BUG: This function uses memory instead of storage for the UserInfo struct,
     * which means any changes made to the user variable are NOT saved back to storage.
     * This is a critical bug that prevents rewards from being properly accumulated.
     * 
     * INEFFICIENCIES:
     * 1. Redundant code that could be refactored
     */
    function updateReward(address account) public {
        // CRITICAL BUG: This uses memory instead of storage!
        // Changes to this variable are NOT persisted to the blockchain
        UserInfo memory user = userInfo[account];

        if (user.stakedAmount > 0) {
            uint256 blocksSinceLastUpdate = block.number - user.lastUpdateBlock;
            uint256 newRewards = (user.stakedAmount * rewardRate * blocksSinceLastUpdate) / 1e18;
            user.rewardsAccumulated += newRewards;
        }

        // CRITICAL BUG: This updates the lastUpdateBlock in memory but not in storage
        // So the next time updateReward is called, it will calculate rewards from the original
        // lastUpdateBlock, not the updated one
        user.lastUpdateBlock = block.number;
        
        // CRITICAL BUG: Missing code to save the updated user back to storage
        // Should have: userInfo[account] = user; 
        // But even that wouldn't work because memory to storage assignment creates a copy
    }

    /**
     * @dev Updates rewards for all stakers
     * 
     * INEFFICIENCIES:
     * 1. O(n) complexity where n is the number of stakers
     * 2. Processes duplicate addresses due to the stakers array issue
     * 3. Calls the buggy updateReward function for each staker
     * 4. No batching or gas optimization for bulk operations
     */
    function updateAllRewards() external {
        // INEFFICIENCY: This is an O(n) operation that processes every staker
        // Including duplicates in the stakers array
        for (uint256 i = 0; i < stakers.length; i++) {
            // CRITICAL BUG: This calls the buggy updateReward function
            // which doesn't actually persist any changes to storage
            updateReward(stakers[i]);
        }
    }

    /**
     * @dev Returns pending reward for an account
     * 
     * NOTE: This function actually works correctly because it uses storage for UserInfo
     * and doesn't try to save any changes back to storage
     */
    function pendingReward(address account) external view returns (uint256) {
        // NOTE: This correctly uses storage for reading data
        UserInfo storage user = userInfo[account];

        uint256 pending = user.rewardsAccumulated;

        if (user.stakedAmount > 0) {
            uint256 blocksSinceLastUpdate = block.number - user.lastUpdateBlock;
            uint256 newRewards = (user.stakedAmount * rewardRate * blocksSinceLastUpdate) / 1e18;
            pending += newRewards;
        }

        return pending;
    }
}
