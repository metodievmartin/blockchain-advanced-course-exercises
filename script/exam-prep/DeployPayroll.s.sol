// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Payroll} from "@/exam-prep/Payroll.sol";
import {PayrollFactory} from "@/exam-prep/PayrollFactory.sol";
import {PayrollConfig} from "./PayrollConfig.s.sol";
import {BaseDeploymentScript} from "../base/BaseDeploymentScript.sol";

/*
  Sepolia Deployment:
  - Payroll implementation deployed to: 0x1364636ce4a674374c294D9819E940AB8Cc4D14d
  - PayrollFactory deployed to: 0x7B02fC73F2148201095AADdfAc884212151A5075
  - First Payroll instance deployed to: 0xA115aFAf44ab10A0E2a91E370affe6aFA312fD4e
*/

contract DeployPayroll is BaseDeploymentScript {
    function run()
        external
        returns (address instanceAddress, address payrollImplementation, address payrollFactory, PayrollConfig)
    {
        // Get network configuration
        PayrollConfig configHelperInstance = new PayrollConfig();
        PayrollConfig.NetworkConfig memory config = configHelperInstance.getNetworkConfig();

        console.log("Deploying Payroll with the following configuration:");
        console.log("- Network Chain ID:", block.chainid);
        console.log("- Director:", config.director);
        console.log("- HR Manager:", config.hrManager);
        console.log("- Price Feed:", config.priceFeed);
        console.log("- Department Name:", config.departmentName);

        // Use the private key from .env for Sepolia, or a default key for Anvil
        uint256 deployerPrivateKey;
        uint256 hrManagerPrivateKey;
        if (block.chainid == configHelperInstance.SEPOLIA_CHAIN_ID()) {
            deployerPrivateKey = vm.envUint("DIRECTOR_PRIVATE_KEY");
            hrManagerPrivateKey = vm.envUint("HR_MANAGER_PRIVATE_KEY");
        } else {
            // Default Anvil private key for the first account
            deployerPrivateKey = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
            // Default Anvil private key for the second account
            hrManagerPrivateKey = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Payroll implementation
        Payroll payrollImpl = new Payroll();

        // Deploy PayrollFactory
        PayrollFactory factory = new PayrollFactory(address(payrollImpl), config.hrManager);

        vm.stopBroadcast();

        // ===========================================

        // Only the HR Manager can create a new Payroll
        vm.startBroadcast(hrManagerPrivateKey);

        // Create a Payroll instance through the factory
        address payrollInstance = factory.createPayroll(config.director, config.departmentName, config.priceFeed);

        vm.stopBroadcast();

        // ===========================================

        // Fund the payroll contract with some ETH for testing
        if (block.chainid == configHelperInstance.LOCAL_CHAIN_ID()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
            vm.startBroadcast(deployerPrivateKey);

            // Send 10 ETH to the payroll contract
            (bool success,) = payrollInstance.call{value: 10 ether}("");
            require(success, "Failed to fund payroll contract");
            console.log("Funded payroll contract with 10 ETH");

            vm.stopBroadcast();
        }

        console.log("Payroll implementation deployed to:", address(payrollImpl));
        console.log("PayrollFactory deployed to:", address(factory));
        console.log("First Payroll instance deployed to:", payrollInstance);

        // Save deployment addresses to a file using the BaseDeploymentScript helper
        address[] memory addresses = new address[](3);
        addresses[0] = address(factory);
        addresses[1] = address(payrollImpl);
        addresses[2] = payrollInstance;

        string[] memory labels = new string[](3);
        labels[0] = "factory";
        labels[1] = "implementation";
        labels[2] = "instance";

        saveDeployment("payroll_deployment", addresses, labels);

        return (payrollInstance, address(payrollImpl), address(factory), configHelperInstance);
    }
}
