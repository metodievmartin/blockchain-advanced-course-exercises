// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VotingLogicV1, Proposal} from "./VotingLogicV1.sol";

/// @custom:oz-upgrades-from VotingLogicV1
contract VotingLogicV2 is VotingLogicV1 {
    // A dummy state variable to test initialisation
    uint256 public initTest;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        // Disable initialisation on the logic contract directly
        _disableInitializers();
    }

    /// @custom:oz-upgrades-from VotingLogicV1
    function initializeV2() public reinitializer(2) {
        // This function is meant to be called ONLY when upgrading from V1 -> V2

        // DO NOT call `super.initialize()` here if you're upgrading from V1,
        // because `initialize()` was already executed during the original deployment of V1.
        // Calling it again would revert due to the `reinitializer(1)` guard in V1.

        // Instead, initialise only V2-specific state:
        initTest = 1;

        // NOTE: The `reinitializer(2)` ensures that this function can only be called once,
        // and only if version 2 of initialisation has not yet been executed.
    }

    /**
     * @dev Executes a proposal if it meets the requirements:
     * 1. Not already executed
     * 2. Has enough votes to meet quorum
     * 3. Has more votes for than against
     * @param proposalId The ID of the proposal to execute
     * @return success Whether the proposal was executed successfully
     */
    function execute(uint256 proposalId) public override returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        // Check if already executed
        if (proposal.executed) return false;

        // Check if proposal exists
        if (proposal.proposer == address(0)) return false;

        // Check if meets quorum
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes;
        if (totalVotes < quorum()) return false;

        // Check if more votes for than against
        if (proposal.forVotes <= proposal.againstVotes) return false;

        // Mark as executed - fixing the bug in V1
        proposal.executed = true;

        return true;
    }

    /**
     * @dev Returns the minimum number of votes required for a proposal to be executed
     * @return The quorum threshold
     */
    function quorum() public pure returns (uint256) {
        return 1000;
    }
}
