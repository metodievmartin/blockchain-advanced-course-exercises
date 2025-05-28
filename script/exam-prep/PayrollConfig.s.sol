// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../../test/exam-prep/mocks/MockV3Aggregator.sol";

contract PayrollConfig is Script {
    struct NetworkConfig {
        address priceFeed;
        address director;
        address hrManager;
        string departmentName;
    }

    NetworkConfig public localNetworkConfig;

    uint256 public constant LOCAL_CHAIN_ID = 31337;
    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;

    // Mock price feed parameters
    uint8 public constant DECIMALS = 8;
    int256 public constant INITIAL_PRICE = 2000 * 10**8; // $2000 with 8 decimals

    // Sepolia price feed
    address public constant SEPOLIA_ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    // First address in Anvil
    address public constant ANVIL_FIRST_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant ANVIL_SECOND_ACCOUNT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;

    function getNetworkConfig() public returns (NetworkConfig memory config) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            config = getSepoliaConfig();
        } else {
            config = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: SEPOLIA_ETH_USD_PRICE_FEED,
            director: vm.envAddress("DIRECTOR_ADDRESS"),
            hrManager: vm.envAddress("HR_MANAGER_ADDRESS"),
            departmentName: "IT"
        });
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.priceFeed != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mock price feed
        vm.startBroadcast();
        MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
            DECIMALS,
            INITIAL_PRICE
        );
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            priceFeed: address(mockPriceFeed),
            director: ANVIL_FIRST_ACCOUNT,
            hrManager: ANVIL_SECOND_ACCOUNT,
            departmentName: "IT"
        });

        return localNetworkConfig;
    }
}
