// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {FunctionGuzzler} from "@/03_gas_optimisation/function_guzzler/FunctionGuzzler.sol";
import {FunctionGuzzlerOptimised} from "@/03_gas_optimisation/function_guzzler/FunctionGuzzlerOptimised.sol";
import {GasComparisonHelper} from "./helpers/GasComparisonHelper.sol";

contract FunctionGuzzlerGasCompareTest is Test, GasComparisonHelper {
    FunctionGuzzler public original;
    FunctionGuzzlerOptimised public optimized;
    address public user1;
    address public user2;

    function setUp() public {
        original = new FunctionGuzzler();
        optimized = new FunctionGuzzlerOptimised();
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // 1. Register users for testing original contract
        vm.prank(user1);
        original.registerUser();

        vm.prank(user2);
        original.registerUser();

        // 2. Register users for testing optimized contract
        vm.prank(user1);
        optimized.registerUser();

        vm.prank(user2);
        optimized.registerUser();
    }

    function testGasCompare_RegisterUser() public {
        address newUser = makeAddr("newUser");

        // 1. Test original contract
        vm.prank(newUser);
        uint256 originalGasBefore = gasleft();
        original.registerUser();
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Reset user for optimized test
        newUser = makeAddr("newUser2");

        // 3. Test optimized contract
        vm.prank(newUser);
        uint256 optimizedGasBefore = gasleft();
        optimized.registerUser();
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 4. Compare results
        logGasComparison("registerUser", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_AddValue() public {
        // 1. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.addValue(100);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.addValue(100);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("addValue", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_SumValues() public {
        // 1. Add some values first to both contracts
        vm.startPrank(user1);
        original.addValue(10);
        original.addValue(20);
        original.addValue(30);

        optimized.addValue(10);
        optimized.addValue(20);
        optimized.addValue(30);
        vm.stopPrank();

        // 2. Test original contract
        uint256 originalGasBefore = gasleft();
        original.sumValues();
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 3. Test optimized contract
        uint256 optimizedGasBefore = gasleft();
        optimized.sumValues();
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 4. Compare results
        logGasComparison("sumValues", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_Deposit() public {
        // 1. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.deposit(1000);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.deposit(1000);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("deposit", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_FindUser() public view {
        // 1. Test original contract
        uint256 originalGasBefore = gasleft();
        original.findUser(user1);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        uint256 optimizedGasBefore = gasleft();
        optimized.findUser(user1);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("findUser", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_Transfer() public {
        // 1. First make deposits to both contracts
        vm.startPrank(user1);
        original.deposit(2000);
        optimized.deposit(2000);
        vm.stopPrank();

        // 2. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.transfer(user2, 1000);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 3. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.transfer(user2, 1000);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 4. Compare results
        logGasComparison("transfer", originalGasUsed, optimizedGasUsed);
    }

    function testGasCompare_GetAverageValue() public {
        // 1. Add some values first to both contracts
        vm.startPrank(user1);
        original.addValue(10);
        original.addValue(20);
        original.addValue(30);

        optimized.addValue(10);
        optimized.addValue(20);
        optimized.addValue(30);
        vm.stopPrank();

        // 2. Test original contract
        uint256 originalGasBefore = gasleft();
        original.getAverageValue();
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 3. Test optimized contract
        uint256 optimizedGasBefore = gasleft();
        optimized.getAverageValue();
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 4. Compare results
        logGasComparison("getAverageValue", originalGasUsed, optimizedGasUsed);
    }
}
