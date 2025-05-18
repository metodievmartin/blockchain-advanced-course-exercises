// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {VotingLogicV1} from "src/08_upgradeability/VotingLogicV1.sol";

contract DeployVotingV1Script is Script {
    function setUp() public {}

    function run() public {
        // Get the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        console.log("Deploying VotingLogicV1...");
        console.log("Initial owner address: ", vm.addr(deployerPrivateKey));

        // Deploy the transparent proxy with VotingLogicV1 as the implementation
        address proxy = Upgrades.deployTransparentProxy(
            "VotingLogicV1.sol",
            vm.addr(deployerPrivateKey), // Admin address (same as deployer in this case)
            abi.encodeCall(VotingLogicV1.initialize, ())
        );

        // Get the implementation address
        address implementation = Upgrades.getImplementationAddress(proxy);

        // Get the admin address
        address admin = Upgrades.getAdminAddress(proxy);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Log deployment information
        console.log("Proxy deployed at:            ", proxy);
        console.log("Implementation deployed at:   ", implementation);
        console.log("Proxy admin address:          ", admin);

        // Save deployment addresses to a file for future reference
        // forgefmt: disable-start
        string memory json = string(abi.encodePacked(
            "{\n",
            '  "proxy": "', vm.toString(proxy), '",\n',
            '  "implementation": "', vm.toString(implementation), '",\n',
            '  "admin": "', vm.toString(admin), '"\n',
            "}"
        ));
        // forgefmt: disable-end

        string memory filename =
            string(abi.encodePacked("./deployments/voting_v1_", "deployment_", vm.toString(block.chainid), ".json"));
        vm.writeFile(filename, json);
    }
}
