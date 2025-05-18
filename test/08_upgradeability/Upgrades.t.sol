// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

import {VotingLogicV1} from "src/08_upgradeability/VotingLogicV1.sol";
import {VotingLogicV2} from "src/08_upgradeability/VotingLogicV2.sol";

contract UpgradesTest is Test {
    VotingLogicV1 public votingLogicV1;
    VotingLogicV2 public votingLogicV2;

    function setUp() public {
        votingLogicV1 = new VotingLogicV1();
        votingLogicV2 = new VotingLogicV2();
    }

    function test_Transparent() public {
        // 1. Deploy a transparent proxy with VotingLogicV1 as the implementation and initialize it with 10
        address proxy = Upgrades.deployTransparentProxy(
            "VotingLogicV1.sol", msg.sender, abi.encodeCall(VotingLogicV1.initialize, ())
        );

        // 2. Get the instance of the contract
        VotingLogicV1 instance = VotingLogicV1(proxy);

        // 3. Create a proposal and add votes
        instance.createProposal("Test Proposal");

        // 4. Add enough votes to reach quorum (1000 for votes to pass)
        for (uint256 i = 0; i < 1000; i++) {
            address voter = address(uint160(i + 1));
            vm.prank(voter);
            instance.vote(1, true);
        }

        // 5. Get the implementation address of the proxy
        address implAddrV1 = Upgrades.getImplementationAddress(proxy);

        // 6. Get the admin address of the proxy
        address adminAddr = Upgrades.getAdminAddress(proxy);

        // 7. Ensure the admin address is valid
        assertFalse(adminAddr == address(0));

        // 8. Log the initial value
        console.log("----------------------------------");
        console.log("Owner before upgrade          --> ", instance.owner());
        console.log("Proposal count before upgrade --> ", instance.proposalCount());
        console.log("----------------------------------");

        // 9. Verify initial value is as expected
        assertEq(instance.proposalCount(), 1);

        // 10. Upgrade the proxy to VotingLogicV2
        //        Upgrades.upgradeProxy(proxy, "VotingLogicV2.sol", "", msg.sender);
        Upgrades.upgradeProxy(proxy, "VotingLogicV2.sol", abi.encodeCall(VotingLogicV2.initializeV2, ()), msg.sender);

        // 11. Get the new implementation address after upgrade
        address implAddrV2 = Upgrades.getImplementationAddress(proxy);

        // 12. Verify admin address remains unchanged
        assertEq(Upgrades.getAdminAddress(proxy), adminAddr);

        // 13. Verify implementation address has changed
        assertFalse(implAddrV1 == implAddrV2);
        console.log("Implementation address before upgrade --> ", implAddrV1);
        console.log("Implementation address after upgrade  --> ", implAddrV2);

        // 14. Invoke the execute function separately
        bool result = VotingLogicV2(address(instance)).execute(1);
        assertTrue(result);

        // 15. Log the updated value
        console.log("----------------------------------");
        console.log("Owner after upgrade          --> ", instance.owner());
        console.log("Proposal count after upgrade --> ", instance.proposalCount());
        console.log("----------------------------------");
        assertEq(instance.proposalCount(), 1);
    }
}
