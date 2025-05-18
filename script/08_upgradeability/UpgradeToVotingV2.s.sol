// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {VotingLogicV1} from "src/08_upgradeability/VotingLogicV1.sol";
import {VotingLogicV2} from "src/08_upgradeability/VotingLogicV2.sol";

contract UpgradeToVotingV2Script is Script {
    function setUp() public {}

    function run() public {
        // Get the private key from environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        // Get the proxy address from environment variable
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Log the implementation address before upgrade
        address implementationBefore = Upgrades.getImplementationAddress(proxyAddress);
        console.log("Implementation address before upgrade: ", implementationBefore);

        // Upgrade the proxy to VotingLogicV2
        Upgrades.upgradeProxy(
            proxyAddress,
            "VotingLogicV2.sol",
            abi.encodeCall(VotingLogicV2.initializeV2, ()),
            vm.addr(deployerPrivateKey) // Admin address
        );

        // Log the implementation address after upgrade
        address implementationAfter = Upgrades.getImplementationAddress(proxyAddress);
        console.log("Implementation address after upgrade:  ", implementationAfter);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // forgefmt: disable-start
        string memory upgradeJson = string(abi.encodePacked(
            "{\n",
            '  "proxy": "', vm.toString(proxyAddress), '",\n',
            '  "implementation_before": "', vm.toString(implementationBefore), '",\n',
            '  "implementation_after": "', vm.toString(implementationAfter), '"\n',
            "}"
        ));
        // forgefmt: disable-end

        string memory upgradeFilename =
            string(abi.encodePacked("./deployments/voting_v2_upgrade_", vm.toString(block.chainid), ".json"));

        vm.writeFile(upgradeFilename, upgradeJson);
    }
}
