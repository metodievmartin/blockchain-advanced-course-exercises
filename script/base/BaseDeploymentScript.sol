// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title BaseDeploymentScript
 * @notice Base contract for deployment scripts with helper functions for saving deployment addresses
 * @dev Inherit from this contract to get access to Script functionality and deployment saving functions
 */
abstract contract BaseDeploymentScript is Script {
    /**
     * @notice Saves deployment addresses to a JSON file
     * @param deploymentName Name of the deployment (used in filename)
     * @param addresses Array of addresses to save
     * @param labels Array of labels for the addresses
     * @dev Creates a file in ./deployments/{deploymentName}_{chainId}.json
     */
    function saveDeployment(
        string memory deploymentName,
        address[] memory addresses,
        string[] memory labels
    ) internal {
        require(addresses.length == labels.length, "Arrays length mismatch");
        
        // Create deployments directory if it doesn't exist
        // Using system command to create directory is not needed
        // Forge will create parent directories automatically
        
        // Build JSON string
        string memory json = "{\n";
        
        for (uint i = 0; i < addresses.length; i++) {
            if (i > 0) {
                json = string(abi.encodePacked(json, ",\n"));
            }
            json = string(abi.encodePacked(
                json,
                '  "', labels[i], '": "', vm.toString(addresses[i]), '"'
            ));
        }
        
        json = string(abi.encodePacked(json, "\n}"));
        
        // Create filename with chain ID
        string memory filename = string(abi.encodePacked(
            "./deployments/", 
            deploymentName, 
            "_", 
            vm.toString(block.chainid), 
            ".json"
        ));
        
        // Write to file
        vm.writeFile(filename, json);
        console.log("Deployment saved to:", filename);
    }

    /**
     * @notice Creates a map entry for a deployment address
     * @param label The label for the address
     * @param addr The address to save
     * @return A formatted JSON entry
     */
    function createMapEntry(string memory label, address addr) internal pure returns (string memory) {
        return string(abi.encodePacked('"', label, '": "', vm.toString(addr), '"'));
    }
}
