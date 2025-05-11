// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {StandardERC20} from "@/03_gas_optimisation/erc20/StandardERC20.sol";
import {StandardERC20Optimised} from "@/03_gas_optimisation/erc20/StandardERC20Optimised.sol";
import {GasComparisonHelper} from "./helpers/GasComparisonHelper.sol";

contract ERC20GasCompareTest is Test, GasComparisonHelper {
    StandardERC20 public original;
    StandardERC20Optimised public optimized;
    address public deployer;
    address public user1;
    address public user2;

    function setUp() public {
        deployer = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        original = new StandardERC20("Test TKN", "TST", 18, 1000000 * 10 ** 18);
        optimized = new StandardERC20Optimised("Test TKN", "TST", 18, 1000000 * 10 ** 18);

        original.transfer(user1, 10000 * 10 ** 18);
        optimized.transfer(user1, 10000 * 10 ** 18);
    }

    function test_GasCompare_Deploy() public {
        uint256 originalGasBefore = gasleft();
        new StandardERC20("Test TKN", "TST", 18, 1000000 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        uint256 optimizedGasBefore = gasleft();
        new StandardERC20Optimised("Test TKN", "TST", 18, 1000000 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        logGasComparison("deployment", originalGasUsed, optimizedGasUsed);
    }

    function test_GasCompare_Transfer() public {
        // 1. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.transfer(user2, 1000 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.transfer(user2, 1000 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("transfer", originalGasUsed, optimizedGasUsed);
    }

    function test_GasCompare_Approve() public {
        // 1. Test original contract
        vm.prank(user1);
        uint256 originalGasBefore = gasleft();
        original.approve(user2, 1000 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 2. Test optimized contract
        vm.prank(user1);
        uint256 optimizedGasBefore = gasleft();
        optimized.approve(user2, 1000 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 3. Compare results
        logGasComparison("approve", originalGasUsed, optimizedGasUsed);
    }

    function test_GasCompare_TransferFrom() public {
        // 1. First approve for both contracts
        vm.startPrank(user1);
        original.approve(address(this), 5000 * 10 ** 18);
        optimized.approve(address(this), 5000 * 10 ** 18);
        vm.stopPrank();

        // 2. Test original contract
        uint256 originalGasBefore = gasleft();
        original.transferFrom(user1, user2, 1000 * 10 ** 18);
        uint256 originalGasAfter = gasleft();
        uint256 originalGasUsed = originalGasBefore - originalGasAfter;

        // 3. Test optimized contract
        uint256 optimizedGasBefore = gasleft();
        optimized.transferFrom(user1, user2, 1000 * 10 ** 18);
        uint256 optimizedGasAfter = gasleft();
        uint256 optimizedGasUsed = optimizedGasBefore - optimizedGasAfter;

        // 4. Compare results
        logGasComparison("transferFrom", originalGasUsed, optimizedGasUsed);
    }
}
