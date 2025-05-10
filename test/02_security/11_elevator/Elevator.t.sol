// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/console.sol";
import {Tests} from "@/02_security/core/Tests.sol";
import {Elevator, ElevatorFactory} from "@/02_security/11_elevator/ElevatorFactory.sol";
import {ElevatorAttack} from "@/02_security/11_elevator/ElevatorAttack.sol";

contract ElevatorTest is Tests {
    Elevator private level;
    ElevatorAttack private attacker;

    /* =============================== SETUP & ATTACK =============================== */

    constructor() {
        levelFactory = new ElevatorFactory();
    }

    function setupLevel() internal override {
        levelAddress = payable(this.createLevelInstance());
        level = Elevator(levelAddress);
    }

    function attack() internal override {
        vm.startPrank(PLAYER);
        attacker = new ElevatorAttack();

        console.log("Is last floor pre-attack", level.top());

        attacker.attack(address(level));

        console.log("Is last floor post-attack", level.top());

        vm.stopPrank();
    }

    /* =============================== TEST LEVEL =============================== */

    function testLevel() external {
        runLevel();
    }
}
