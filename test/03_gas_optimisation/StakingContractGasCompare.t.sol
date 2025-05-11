// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {StakingContract} from "@/03_gas_optimisation/staking_contract/StakingContract.sol";
import {StakingContractOptimised} from "@/03_gas_optimisation/staking_contract/StakingContractOptimised.sol";
import {StandardERC20Optimised} from "@/03_gas_optimisation/erc20/StandardERC20Optimised.sol";
import {GasComparisonHelper} from "./helpers/GasComparisonHelper.sol";

contract StakingContractGasCompareTest is Test, GasComparisonHelper {
    uint256 constant REWARD_RATE = 100;

    StakingContract public original;
    StakingContractOptimised public optimized;
    StandardERC20Optimised public token;

    address public user1;
    address public user2;

    function setUp() public {
        // 1. Deploy the ERC20 token
        token = new StandardERC20Optimised("Test TKN", "TST", 18, 1000000 * 10 ** 18);

        // 2. Deploy staking contracts with the same reward rate
        original = new StakingContract(address(token));
        optimized = new StakingContractOptimised(address(token), REWARD_RATE);

        // 3. Setup test users
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 4. Send tokens to users
        token.transfer(user1, 10000 * 10 ** 18);
        token.transfer(user2, 10000 * 10 ** 18);

        // 5. Approve tokens for both contracts
        vm.startPrank(user1);
        token.approve(address(original), type(uint256).max);
        token.approve(address(optimized), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        token.approve(address(original), type(uint256).max);
        token.approve(address(optimized), type(uint256).max);
        vm.stopPrank();
    }

    function testGasCompare_Stake() public {
        // 1. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.stake(1000 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.stake(1000 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("stake", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_Withdraw() public {
        // 1. First stake some tokens in both contracts
        vm.startPrank(user1);
        original.stake(1000 * 10 ** 18);
        optimized.stake(1000 * 10 ** 18);
        vm.stopPrank();

        // 2. Mine some blocks to accumulate rewards
        vm.roll(block.number + 100);

        // 3. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.withdraw(500 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 4. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.withdraw(500 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 5. Compare results
        logGasComparison("withdraw", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_ClaimReward() public {
        // 1. First stake some tokens in both contracts
        vm.startPrank(user1);
        original.stake(1000 * 10 ** 18);
        optimized.stake(1000 * 10 ** 18);
        vm.stopPrank();

        // 2. Mine some blocks to accumulate rewards
        vm.roll(block.number + 100);

        // 3. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.claimReward();
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 4. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.claimReward();
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 5. Compare results
        logGasComparison("claimReward", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_PendingReward() public {
        // 1. First stake some tokens in both contracts
        vm.startPrank(user1);
        original.stake(1000 * 10 ** 18);
        optimized.stake(1000 * 10 ** 18);
        vm.stopPrank();

        // 2. Mine some blocks to accumulate rewards
        vm.roll(block.number + 100);

        // 3. Test original contract
        uint256 originalGasBefore = gasleft();
        original.pendingReward(user1);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 4. Test optimized contract
        uint256 optimizedGasBefore = gasleft();
        optimized.getPendingReward(user1);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 5. Compare results
        logGasComparison("pendingReward", originalGasUsed, optimizedGasUsed);
    }
}
