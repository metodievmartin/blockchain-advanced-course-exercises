// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@/02_security/core/Level.sol";
import "./Elevator.sol";

contract ElevatorFactory is Level(msg.sender) {
    function createInstance(address _player) public payable override returns (address) {
        _player;
        Elevator instance = new Elevator();
        return address(instance);
    }

    function validateInstance(address payable _instance, address) public view override returns (bool) {
        Elevator elevator = Elevator(_instance);
        return elevator.top();
    }
}
