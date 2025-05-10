// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * This level is inspired by a real-world vulnerability pattern.
 * Most of Ethernaut's levels try to expose (in an oversimplified form of course)
 * something that actually happened — a real hack or a real bug.
 *
 * In this case, see:
 * - [King of the Ether](https://www.kingoftheether.com/)
 * - [King of the Ether Postmortem](https://www.reddit.com/r/ethereum/comments/2qg3l1/king_of_the_ether_throne_post_mortem/)
 */
contract King {
    address king;
    uint256 public prize;
    address public owner;

    constructor() payable {
        owner = msg.sender;
        king = msg.sender;
        prize = msg.value;
    }

    /*
     * This is the main logic for claiming the throne.
     * Any address that sends enough ETH becomes the new king.
     * The old king is paid the new amount.
     *
     * Vulnerability:
     * If the current king is a contract that cannot receive ETH via `transfer()`,
     * this function will revert and no one else can become king.
     */
    receive() external payable {
        require(msg.value >= prize || msg.sender == owner);

        // Try to send ETH to the current king
        // This may fail if `king` is a contract with no `receive()` or a rejecting fallback
        payable(king).transfer(msg.value);

        // If transfer succeeds, update king and prize
        king = msg.sender;
        prize = msg.value;
    }

    function _king() public view returns (address) {
        return king;
    }
}
