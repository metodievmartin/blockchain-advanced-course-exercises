// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Ethernaut} from "./Ethernaut.sol";
import {Level} from "./Level.sol";

abstract contract Tests is Test {
    Ethernaut private ethernaut;
    Level internal levelFactory;
    address payable internal levelAddress;

    address internal constant PLAYER = address(uint160(uint256(keccak256("foundry default caller"))));
    address internal constant RANDOM = address(1);

    /* ========================================== TEMPLATE OF EXECUTION ========================================== */

    function setupLevel() internal virtual {}

    function attack() internal virtual {}

    /* ========================== "HARDCODED" EXECUTION ========================= */

    function setupEthernaut() private {
        assert(address(levelFactory) != address(0));

        ethernaut = new Ethernaut();
        ethernaut.registerLevel(levelFactory);

        vm.deal(PLAYER, 30 ether);
        vm.label(PLAYER, "PLAYER");
    }

    function createLevelInstance() external payable returns (address) {
        vm.prank(PLAYER);
        return ethernaut.createLevelInstance{value: msg.value}(levelFactory);
    }

    function checkSuccess() private {
        vm.startPrank(PLAYER);

        bool success = ethernaut.submitLevelInstance(levelAddress);
        assertTrue(success);

        vm.stopPrank();
    }

    /* ========================== "PACKED" EXECUTION ========================= */

    function runLevel() internal {
        setupEthernaut();
        setupLevel();
        attack();
        checkSuccess();
    }
}
