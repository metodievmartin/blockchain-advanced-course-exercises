// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

error StopLossVault__TransferFailed();
error StopLossVault__AboveStopLossPrice();
error StopLossVault__NotVaultOwner();
error StopLossVault__AmountMustBeGreaterThanZero();
error StopLossVault__VaultDoesNotExist();
error StopLossVault__InactiveVault();

contract StopLossVault {
    struct Vault {
        address owner;
        uint256 amount;
        uint256 stopLossPrice; // in USD, 8 decimals
        bool active;
    }

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    AggregatorV3Interface private immutable PRICE_FEED;

    mapping(uint256 => Vault) public vaults;
    uint256 private vaultCounter;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */

    event VaultCreated(uint256 indexed vaultId, address indexed owner, uint256 amount, uint256 stopLossPrice);

    event VaultWithdrawn(uint256 indexed vaultId, address indexed owner, uint256 amount, uint256 currentPrice);

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    constructor(address priceFeedAddress) {
        PRICE_FEED = AggregatorV3Interface(priceFeedAddress);
    }

    /**
     * @notice Create a new vault with a stop loss price
     * @param stopLossPrice The price at which funds can be withdrawn (in USD with 8 decimals)
     */
    function createVault(uint256 stopLossPrice) external payable {
        if (msg.value <= 0) {
            revert StopLossVault__AmountMustBeGreaterThanZero();
        }

        uint256 vaultId = vaultCounter;
        vaultCounter++;

        vaults[vaultId] = Vault({owner: msg.sender, amount: msg.value, stopLossPrice: stopLossPrice, active: true});

        emit VaultCreated(vaultId, msg.sender, msg.value, stopLossPrice);
    }

    /**
     * @notice Withdraw funds from a vault if ETH price is below the stop loss price
     * @param vaultId The ID of the vault to withdraw from
     */
    function withdraw(uint256 vaultId) external {
        Vault storage vault = vaults[vaultId];

        if (vault.owner == address(0)) {
            revert StopLossVault__VaultDoesNotExist();
        }

        if (vault.owner != msg.sender) {
            revert StopLossVault__NotVaultOwner();
        }

        if (!vault.active) {
            revert StopLossVault__InactiveVault();
        }

        int256 currentPrice = getPrice();

        // Convert int256 to uint256 for comparison
        // This is safe because ETH price won't be negative
        if (uint256(currentPrice) > vault.stopLossPrice) {
            revert StopLossVault__AboveStopLossPrice();
        }

        // Mark vault as inactive
        vault.active = false;
        uint256 amount = vault.amount;

        // Transfer funds
        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert StopLossVault__TransferFailed();
        }

        emit VaultWithdrawn(vaultId, msg.sender, amount, uint256(currentPrice));
    }

    /* ============================================================================================== */
    /*                                         VIEW FUNCTIONS                                         */
    /* ============================================================================================== */

    /**
     * @notice Get the latest ETH/USD price
     * @return The latest price
     */
    function getLatestPrice() external view returns (int256) {
        return getPrice();
    }

    /**
     * @notice Get the price feed address
     * @return The price feed address
     */
    function getPriceFeed() external view returns (address) {
        return address(PRICE_FEED);
    }

    /**
     * @notice Get vault details
     * @param vaultId The ID of the vault
     * @return The vault details
     */
    function getVaultDetails(uint256 vaultId) external view returns (Vault memory) {
        return vaults[vaultId];
    }

    /**
     * @notice Get the current vault counter
     * @return The current vault counter
     */
    function getVaultCounter() external view returns (uint256) {
        return vaultCounter;
    }

    /* ============================================================================================== */
    /*                                       INTERNAL FUNCTIONS                                       */
    /* ============================================================================================== */

    /**
     * @notice Get the latest ETH/USD price
     * @return The latest price with 8 decimals
     */
    function getPrice() internal view returns (int256) {
        (, int256 price,,,) = PRICE_FEED.latestRoundData();
        return price;
    }
}
