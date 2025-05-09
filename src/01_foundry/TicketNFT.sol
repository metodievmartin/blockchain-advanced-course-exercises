// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable2Step, Ownable} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title TicketNFT
 * @notice An NFT contract representing raffle tickets
 * @dev Extends ERC721 with enumerable extension and two-step ownership transfer
 */
contract TicketNFT is ERC721, ERC721Enumerable, Ownable2Step {
    uint256 private _nextTokenId;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) Ownable(msg.sender) {}

    /**
     * @notice Safely mints a new ticket NFT to the specified address
     * @param to Address to mint the ticket to
     * @return tokenId The ID of the newly minted NFT
     */
    function safeMint(address to) public onlyOwner returns (uint256 tokenId) {
        tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
    }

    /**
     * @dev Returns whether the contract implements the specified interface
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Required override when using ERC721Enumerable to handle
     * both basic ERC721 transfers and enumerable tracking updates
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev See `_update`
     */
    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }
}
