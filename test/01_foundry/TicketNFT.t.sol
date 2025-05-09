// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {TicketNFT} from "src/01_foundry/TicketNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";

contract TicketNFTTest is Test, IERC721Receiver {
    TicketNFT ticketNFT;
    address owner = address(this);
    address user1 = address(0x123);
    address user2 = address(0x456);
    string name = "TestTicket";
    string symbol = "TTK";

    function setUp() public {
        ticketNFT = new TicketNFT(name, symbol);
    }

    // --- Basic Functionality Tests ---

    function test_Initialization() public view {
        assertEq(ticketNFT.name(), name);
        assertEq(ticketNFT.symbol(), symbol);
        assertEq(ticketNFT.owner(), owner);
    }

    function test_SafeMint() public {
        uint256 tokenId = ticketNFT.safeMint(user1);
        assertEq(tokenId, 0);
        assertEq(ticketNFT.ownerOf(0), user1);
        assertEq(ticketNFT.balanceOf(user1), 1);
    }

    function test_SafeMint_Multiple() public {
        uint256 tokenId1 = ticketNFT.safeMint(user1);
        uint256 tokenId2 = ticketNFT.safeMint(user2);
        uint256 tokenId3 = ticketNFT.safeMint(user1);

        assertEq(tokenId1, 0);
        assertEq(tokenId2, 1);
        assertEq(tokenId3, 2);

        assertEq(ticketNFT.ownerOf(0), user1);
        assertEq(ticketNFT.ownerOf(1), user2);
        assertEq(ticketNFT.ownerOf(2), user1);

        assertEq(ticketNFT.balanceOf(user1), 2);
        assertEq(ticketNFT.balanceOf(user2), 1);
    }

    // --- Ownership Transfer Tests ---

    function test_TransferFrom() public {
        uint256 tokenId = ticketNFT.safeMint(user1);

        vm.prank(user1);
        ticketNFT.approve(address(this), tokenId);

        ticketNFT.transferFrom(user1, user2, tokenId);

        assertEq(ticketNFT.ownerOf(tokenId), user2);
        assertEq(ticketNFT.balanceOf(user1), 0);
        assertEq(ticketNFT.balanceOf(user2), 1);
    }

    function test_SafeTransferFrom() public {
        uint256 tokenId = ticketNFT.safeMint(user1);

        vm.prank(user1);
        ticketNFT.approve(address(this), tokenId);

        ticketNFT.safeTransferFrom(user1, user2, tokenId);

        assertEq(ticketNFT.ownerOf(tokenId), user2);
    }

    function test_SafeTransferFrom_WithData() public {
        uint256 tokenId = ticketNFT.safeMint(user1);

        vm.prank(user1);
        ticketNFT.approve(address(this), tokenId);

        ticketNFT.safeTransferFrom(user1, address(this), tokenId, "");

        assertEq(ticketNFT.ownerOf(tokenId), address(this));
    }

    // --- Access Control Tests ---

    function test_OnlyOwnerCanMint() public {
        vm.prank(user1);
        vm.expectRevert();
        ticketNFT.safeMint(user2);
    }

    function test_OwnershipTransfer() public {
        // Initial owner is this contract
        assertEq(ticketNFT.owner(), address(this));

        // Transfer ownership to user1
        ticketNFT.transferOwnership(user1);

        // Ownership not transferred yet (two-step process)
        assertEq(ticketNFT.owner(), address(this));
        assertEq(ticketNFT.pendingOwner(), user1);

        // Accept ownership as user1
        vm.prank(user1);
        ticketNFT.acceptOwnership();

        // Verify user1 is now the owner
        assertEq(ticketNFT.owner(), user1);

        // Verify only new owner can mint
        vm.prank(user1);
        uint256 tokenId = ticketNFT.safeMint(user2);
        assertEq(ticketNFT.ownerOf(tokenId), user2);
    }

    function test_RenounceOwnership() public {
        ticketNFT.renounceOwnership();
        assertEq(ticketNFT.owner(), address(0));

        // Try to mint after renouncing ownership
        vm.expectRevert();
        ticketNFT.safeMint(user1);
    }

    // --- ERC721 Compliance Tests ---

    function test_SupportsInterface() public view {
        // Calculate interface IDs instead of hardcoding them
        // ERC165 interface ID: type(IERC165).interfaceId
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        
        // ERC721 interface ID: type(IERC721).interfaceId
        bytes4 erc721InterfaceId = type(IERC721).interfaceId;
        
        // ERC721Enumerable interface ID: type(IERC721Enumerable).interfaceId
        bytes4 erc721EnumerableInterfaceId = type(IERC721Enumerable).interfaceId;
        
        // ERC721Metadata interface ID (can be derived from function selectors)
        // name() + symbol() + tokenURI(uint256)
        bytes4 erc721MetadataInterfaceId = bytes4(
            keccak256("name()") ^ 
            keccak256("symbol()") ^ 
            keccak256("tokenURI(uint256)")
        );

        // Test interface support
        assertTrue(ticketNFT.supportsInterface(erc165InterfaceId), "Should support ERC165");
        assertTrue(ticketNFT.supportsInterface(erc721InterfaceId), "Should support ERC721");
        assertTrue(ticketNFT.supportsInterface(erc721MetadataInterfaceId), "Should support ERC721Metadata");
        assertTrue(ticketNFT.supportsInterface(erc721EnumerableInterfaceId), "Should support ERC721Enumerable");
        
        // Invalid interface
        assertFalse(ticketNFT.supportsInterface(0xffffffff), "Should not support invalid interface");
    }

    function test_ERC721_Approve() public {
        uint256 tokenId = ticketNFT.safeMint(user1);

        vm.prank(user1);
        ticketNFT.approve(user2, tokenId);

        assertEq(ticketNFT.getApproved(tokenId), user2);
    }

    function test_ERC721_SetApprovalForAll() public {
        ticketNFT.safeMint(user1);

        vm.prank(user1);
        ticketNFT.setApprovalForAll(user2, true);

        assertTrue(ticketNFT.isApprovedForAll(user1, user2));
    }

    // --- ERC721Enumerable Tests ---

    function test_Enumerable_TotalSupply() public {
        assertEq(ticketNFT.totalSupply(), 0);

        ticketNFT.safeMint(user1);
        assertEq(ticketNFT.totalSupply(), 1);

        ticketNFT.safeMint(user2);
        assertEq(ticketNFT.totalSupply(), 2);
    }

    function test_Enumerable_TokenByIndex() public {
        uint256 tokenId1 = ticketNFT.safeMint(user1);
        uint256 tokenId2 = ticketNFT.safeMint(user2);

        assertEq(ticketNFT.tokenByIndex(0), tokenId1);
        assertEq(ticketNFT.tokenByIndex(1), tokenId2);
    }

    function test_Enumerable_TokenOfOwnerByIndex() public {
        ticketNFT.safeMint(user1); // tokenId 0
        ticketNFT.safeMint(user2); // tokenId 1
        ticketNFT.safeMint(user1); // tokenId 2

        assertEq(ticketNFT.tokenOfOwnerByIndex(user1, 0), 0);
        assertEq(ticketNFT.tokenOfOwnerByIndex(user1, 1), 2);
        assertEq(ticketNFT.tokenOfOwnerByIndex(user2, 0), 1);
    }

    // --- IERC721Receiver Implementation ---

    function onERC721Received(address, address, uint256, bytes calldata) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
