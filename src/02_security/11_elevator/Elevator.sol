// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Security Insight: The contract implicitly trusts the external caller (msg.sender) to return consistent,
 * honest results when queried via isLastFloor. This introduces a reentrancy-like logic inconsistency,
 * enabling an attacker to manipulate return values between calls.
 */
interface Building {
    function isLastFloor(uint256) external returns (bool);
}

contract Elevator {
    bool public top;
    uint256 public floor;

    function goTo(uint256 _floor) public {
        // Cast the caller to the Building interface to call isLastFloor().
        // WARNING: This introduces a trust assumption on msg.sender to follow interface rules.
        Building building = Building(msg.sender);

        // If the caller claims the floor is NOT the last...
        if (!building.isLastFloor(_floor)) {
            // ...set the floor.
            floor = _floor;
            // Then check again and set 'top' accordingly.
            // This is unsafe since isLastFloor is a mutable call and may return a different value on each invocation.
            top = building.isLastFloor(floor);
        }
    }
}
