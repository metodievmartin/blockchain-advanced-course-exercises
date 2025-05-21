// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2} from "forge-std/Test.sol";

import {
    StopLossVault,
    StopLossVault__TransferFailed,
    StopLossVault__AboveStopLossPrice,
    StopLossVault__NotVaultOwner,
    StopLossVault__AmountMustBeGreaterThanZero,
    StopLossVault__VaultDoesNotExist,
    StopLossVault__InactiveVault
} from "@/09_oracles/StopLossVault.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

contract StopLossVaultTest is Test {
    StopLossVault public vault;
    MockV3Aggregator public mockPriceFeed;

    address public USER = makeAddr("user");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000 * 10 ** 8; // $2000 with 8 decimals

    uint256 public constant STOP_LOSS_PRICE = 1800 * 10 ** 8; // $1800 with 8 decimals
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */
    event VaultCreated(uint256 indexed vaultId, address indexed owner, uint256 amount, uint256 stopLossPrice);

    event VaultWithdrawn(uint256 indexed vaultId, address indexed owner, uint256 amount, uint256 currentPrice);

    /* ============================================================================================== */
    /*                                             SETUP                                              */
    /* ============================================================================================== */
    function setUp() external {
        mockPriceFeed = new MockV3Aggregator(DECIMALS, INITIAL_PRICE);
        vault = new StopLossVault(address(mockPriceFeed));

        vm.deal(USER, STARTING_USER_BALANCE);
    }

    /* ============================================================================================== */
    /*                                      CREATE VAULT TESTS                                        */
    /* ============================================================================================== */
    function testCreateVault() public {
        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit VaultCreated(0, USER, DEPOSIT_AMOUNT, STOP_LOSS_PRICE);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 1. Verify vault details
        StopLossVault.Vault memory vaultDetails = vault.getVaultDetails(0);
        assertEq(vaultDetails.owner, USER);
        assertEq(vaultDetails.amount, DEPOSIT_AMOUNT);
        assertEq(vaultDetails.stopLossPrice, STOP_LOSS_PRICE);
        assertTrue(vaultDetails.active);

        // 2. Verify counter incremented
        assertEq(vault.getVaultCounter(), 1);
    }

    function testCreateMultipleVaults() public {
        // 1. Create first vault
        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 2. Create second vault with different parameters
        uint256 secondStopLossPrice = 1900 * 10 ** 8; // $1900
        uint256 secondDepositAmount = 2 ether;

        vm.prank(USER);
        vault.createVault{value: secondDepositAmount}(secondStopLossPrice);

        // 3. Verify both vaults exist with correct details
        StopLossVault.Vault memory vault1 = vault.getVaultDetails(0);
        StopLossVault.Vault memory vault2 = vault.getVaultDetails(1);

        assertEq(vault1.stopLossPrice, STOP_LOSS_PRICE);
        assertEq(vault1.amount, DEPOSIT_AMOUNT);

        assertEq(vault2.stopLossPrice, secondStopLossPrice);
        assertEq(vault2.amount, secondDepositAmount);

        // 4. Verify counter
        assertEq(vault.getVaultCounter(), 2);
    }

    function testRevertsWhenAmountIsZero() public {
        vm.prank(USER);
        vm.expectRevert(StopLossVault__AmountMustBeGreaterThanZero.selector);
        vault.createVault{value: 0}(STOP_LOSS_PRICE);
    }

    /* ============================================================================================== */
    /*                                      WITHDRAW TESTS                                            */
    /* ============================================================================================== */
    function testWithdrawWhenPriceIsBelowStopLoss() public {
        // 1. Setup: create a vault
        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 2. Update price to below stop loss
        int256 newPrice = 1700 * 10 ** 8; // $1700, below the $1800 stop loss
        mockPriceFeed.updateAnswer(newPrice);

        // 3. Get user's balance before withdrawal
        uint256 userBalanceBefore = USER.balance;

        // 4. Withdraw
        vm.prank(USER);
        vm.expectEmit(true, true, false, true);
        emit VaultWithdrawn(0, USER, DEPOSIT_AMOUNT, uint256(newPrice));
        vault.withdraw(0);

        // 5. Verify user received the funds
        uint256 userBalanceAfter = USER.balance;
        assertEq(userBalanceAfter, userBalanceBefore + DEPOSIT_AMOUNT);

        // 6. Verify vault is now inactive
        StopLossVault.Vault memory vaultDetails = vault.getVaultDetails(0);
        assertFalse(vaultDetails.active);
    }

    function testRevertsWhenPriceIsAboveStopLoss() public {
        // 1. Setup: create a vault
        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 2. Price is already above stop loss at $2000 > $1800

        // 3. Attempt to withdraw
        vm.prank(USER);
        vm.expectRevert(StopLossVault__AboveStopLossPrice.selector);
        vault.withdraw(0);
    }

    function testRevertsWhenCallerIsNotVaultOwner() public {
        // 1. Setup: create a vault owned by USER
        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 2. Update price to below stop loss
        mockPriceFeed.updateAnswer(1700 * 10 ** 8);

        // 3. Attempt to withdraw from a different address
        address attacker = makeAddr("attacker");
        vm.prank(attacker);
        vm.expectRevert(StopLossVault__NotVaultOwner.selector);
        vault.withdraw(0);
    }

    function testRevertsWhenVaultDoesNotExist() public {
        // 1. Attempt to withdraw from a non-existent vault
        vm.prank(USER);
        vm.expectRevert(StopLossVault__VaultDoesNotExist.selector);
        vault.withdraw(999);
    }

    function testRevertsWhenVaultIsInactive() public {
        // 1. Setup: create a vault
        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);

        // 2. Update price to below stop loss
        mockPriceFeed.updateAnswer(1700 * 10 ** 8);

        // 3. First withdrawal (should succeed)
        vm.prank(USER);
        vault.withdraw(0);

        // 4. Second withdrawal attempt (should fail)
        vm.prank(USER);
        vm.expectRevert(StopLossVault__InactiveVault.selector);
        vault.withdraw(0);
    }

    /* ============================================================================================== */
    /*                                      VIEW FUNCTION TESTS                                       */
    /* ============================================================================================== */
    function testGetLatestPrice() public {
        int256 price = vault.getLatestPrice();
        assertEq(price, INITIAL_PRICE);

        int256 newPrice = 1900 * 10 ** 8;
        mockPriceFeed.updateAnswer(newPrice);

        assertEq(vault.getLatestPrice(), newPrice);
    }

    function testGetPriceFeed() public view {
        assertEq(vault.getPriceFeed(), address(mockPriceFeed));
    }

    function testGetVaultCounter() public {
        assertEq(vault.getVaultCounter(), 0);

        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);
        assertEq(vault.getVaultCounter(), 1);

        vm.prank(USER);
        vault.createVault{value: DEPOSIT_AMOUNT}(STOP_LOSS_PRICE);
        assertEq(vault.getVaultCounter(), 2);
    }
}
