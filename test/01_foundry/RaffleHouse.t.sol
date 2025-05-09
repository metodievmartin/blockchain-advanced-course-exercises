// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol";
import "forge-std/Test.sol";
import {
    RaffleHouse,
    TicketPriceTooLow,
    RaffleAlreadyStarted,
    InvalidRaffleEndTime,
    InsufficientRaffleDuration,
    RaffleDoesNotExist,
    RaffleNotStarted,
    RaffleEnded,
    InvalidTicketPrice,
    WinnerAlreadyChosen,
    WinnerNotChosen,
    NotWinner,
    RaffleNotEnded
} from "src/01_foundry/RaffleHouse.sol";
import {TicketNFT} from "src/01_foundry/TicketNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract RaffleHouseTest is Test {
    RaffleHouse raffleHouse;
    address owner = address(this);
    address user1 = address(0x123);
    address user2 = address(0x456);
    uint256 ticketPrice = 0.1 ether;
    uint256 nowTs;
    uint256 duration = 2 hours;
    string name = "TestRaffle";
    string symbol = "TRF";

    function setUp() public {
        raffleHouse = new RaffleHouse();
        nowTs = block.timestamp;
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function _createDefaultRaffle() internal returns (uint256 start, uint256 end) {
        start = nowTs + 10;
        end = start + duration;
        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);
    }

    function test_Initialisation() public {
        uint256 start = nowTs + 10;
        uint256 end = start + duration;

        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);

        (uint256 tp, uint256 rs, uint256 re, TicketNFT tkt, uint256 winIdx, bool isWinnerChosen) =
            raffleHouse.raffles(0);

        assertEq(tp, ticketPrice, "ticketPrice");
        assertEq(rs, start, "raffleStart");
        assertEq(re, end, "raffleEnd");
        assertEq(address(tkt) != address(0), true, "ticketsContract address");
        assertEq(winIdx, 0, "winningTicketIndex");
        assertEq(raffleHouse.raffleCount(), 1, "raffleCount");
        assertEq(TicketNFT(tkt).name(), name, "TicketNFT name");
        assertEq(TicketNFT(tkt).symbol(), symbol, "TicketNFT symbol");
        assertFalse(isWinnerChosen, "isWinnerChosen");
    }

    function test_CreateRaffle() public {
        uint256 start = nowTs + 10;
        uint256 end = start + duration;

        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);
        RaffleHouse.Raffle memory r = raffleHouse.getRaffle(0);

        assertEq(r.ticketPrice, ticketPrice);
        assertEq(r.raffleStart, start);
        assertEq(r.raffleEnd, end);
        assertEq(r.isWinnerChosen, false);
    }

    function test_RevertWhen_TicketPriceTooLow() public {
        uint256 start = nowTs + 10;
        uint256 end = start + duration;
        vm.expectRevert(TicketPriceTooLow.selector);
        raffleHouse.createRaffle(0, start, end, name, symbol);
    }

    function test_RevertWhen_RaffleAlreadyStarted() public {
        uint256 start = nowTs - 1;
        uint256 end = start + duration;
        vm.expectRevert(RaffleAlreadyStarted.selector);
        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);
    }

    function test_RevertWhen_InvalidRaffleEndTime() public {
        uint256 start = nowTs + 10;
        vm.expectRevert(InvalidRaffleEndTime.selector);
        raffleHouse.createRaffle(ticketPrice, start, start, name, symbol);
    }

    function test_RevertWhen_InsufficientRaffleDuration() public {
        uint256 start = nowTs + 10;
        uint256 end = start + 10;
        vm.expectRevert(InsufficientRaffleDuration.selector);
        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);
    }

    function test_RaffleCreated_Event() public {
        uint256 start = nowTs + 10;
        uint256 end = start + duration;
        vm.expectEmit(true, false, false, true);
        emit RaffleHouse.RaffleCreated(0, ticketPrice, start, end, name, symbol);
        raffleHouse.createRaffle(ticketPrice, start, end, name, symbol);
    }

    // --- Ticket Purchase ---
    function test_BuyTicket_Success() public {
        vm.deal(user1, 1 ether);
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);
        // Ticket should be minted to user1
        TicketNFT tkt = raffleHouse.getRaffle(0).ticketsContract;
        assertEq(tkt.ownerOf(0), user1);
    }

    function test_RevertWhen_BuyTicket_RaffleDoesNotExist() public {
        vm.warp(nowTs + 100);
        vm.prank(user1);
        vm.expectRevert(RaffleDoesNotExist.selector);
        raffleHouse.buyTicket{value: ticketPrice}(0);
    }

    function test_RevertWhen_BuyTicket_NotStarted() public {
        (uint256 start,) = _createDefaultRaffle();
        vm.warp(start - 1);
        vm.prank(user1);
        vm.expectRevert(RaffleNotStarted.selector);
        raffleHouse.buyTicket{value: ticketPrice}(0);
    }

    function test_RevertWhen_BuyTicket_RaffleEnded() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(end + 1);
        vm.prank(user1);
        vm.expectRevert(RaffleEnded.selector);
        raffleHouse.buyTicket{value: ticketPrice}(0);
    }

    function test_RevertWhen_BuyTicket_InvalidTicketPrice() public {
        (uint256 start,) = _createDefaultRaffle();
        vm.warp(start + 1);
        vm.prank(user1);
        vm.expectRevert(InvalidTicketPrice.selector);
        raffleHouse.buyTicket{value: ticketPrice + 1}(0);
    }

    function test_TicketPurchased_Event() public {
        (uint256 start,) = _createDefaultRaffle();
        vm.warp(start + 1);
        vm.prank(user1);

        vm.expectEmit(true, true, false, true);
        emit RaffleHouse.TicketPurchased(0, user1, 0);

        raffleHouse.buyTicket{value: ticketPrice}(0);
        TicketNFT tkt = raffleHouse.getRaffle(0).ticketsContract;
    }

    // --- Get Raffle ---
    function test_GetRaffle_ReturnsCorrectStruct() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        RaffleHouse.Raffle memory r = raffleHouse.getRaffle(0);
        assertEq(r.ticketPrice, ticketPrice);
        assertEq(r.raffleStart, start);
        assertEq(r.raffleEnd, end);
    }

    function test_RevertWhen_GetRaffle_RaffleDoesNotExist() public {
        vm.expectRevert(RaffleDoesNotExist.selector);
        raffleHouse.getRaffle(99);
    }

    // --- Choose Winner ---
    function test_RevertWhen_ChooseWinner_RaffleDoesNotExist() public {
        vm.expectRevert(RaffleDoesNotExist.selector);
        raffleHouse.chooseWinner(0);
    }

    function test_RevertWhen_ChooseWinner_NotEnded() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);
        vm.expectRevert(RaffleNotEnded.selector);
        raffleHouse.chooseWinner(0);
    }

    function test_RevertWhen_ChooseWinner_WinnerAlreadyChosen() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);
        // Mint a ticket to user1
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        vm.warp(end + 1);

        // First call
        raffleHouse.chooseWinner(0);

        // Second call should revert
        vm.expectRevert(WinnerAlreadyChosen.selector);
        raffleHouse.chooseWinner(0);
    }

    function test_ChooseWinner_SuccessAndEvent() public {
        vm.deal(user1, 1 ether);

        (uint256 start, uint256 end) = _createDefaultRaffle();

        vm.warp(start + 1);
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        vm.warp(end + 1);

        vm.expectEmit(true, false, false, true);
        emit RaffleHouse.WinnerChosen(0, 0);

        raffleHouse.chooseWinner(0);
        uint256 winnerIdx = raffleHouse.getRaffle(0).winningTicketIndex;

        console.log("Winner index: ", winnerIdx);
        assertTrue(winnerIdx == 0 || winnerIdx == 1, "Winner index in range");
    }

    // --- Get Raffle Count ---
    function test_GetRaffleCount_AfterMultipleCreations() public {
        for (uint256 i = 0; i < 3; i++) {
            _createDefaultRaffle();
        }
        assertEq(raffleHouse.getRaffleCount(), 3);
    }

    // --- General/Edge Cases ---
    function test_MultipleRaffles_Isolation() public {
        (uint256 s1, uint256 e1) = _createDefaultRaffle();
        (uint256 s2,) = _createDefaultRaffle();

        vm.warp(s1 + 1);

        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        vm.prank(user2);
        raffleHouse.buyTicket{value: ticketPrice}(1);

        TicketNFT tkt1 = raffleHouse.getRaffle(0).ticketsContract;
        TicketNFT tkt2 = raffleHouse.getRaffle(1).ticketsContract;

        assertEq(tkt1.ownerOf(0), user1);
        assertEq(tkt2.ownerOf(0), user2);
    }

    // --- Claim Prize Tests ---
    function test_ClaimPrize_Success() public {
        // Create raffle and buy tickets
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys a ticket
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // User2 buys a ticket
        vm.prank(user2);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // End raffle and choose winner
        vm.warp(end + 1);

        // Set prevrandao to a known value
        bytes32 fixedRandao = keccak256("fixed randomness");
        vm.prevrandao(fixedRandao);

        raffleHouse.chooseWinner(0);

        // Check balance before claiming
        uint256 user1BalanceBefore = user1.balance;

        console.log("winningTicketIndex", raffleHouse.getRaffle(0).winningTicketIndex);
        console.log("isWinnerChosen", raffleHouse.getRaffle(0).isWinnerChosen);

        // Approve the transfer of the winning ticket
        vm.startPrank(user1);
        TicketNFT ticketsContract = raffleHouse.getRaffle(0).ticketsContract;
        ticketsContract.approve(address(raffleHouse), 0);

        // Claim prize
        raffleHouse.claimPrize(0);
        vm.stopPrank();

        // Expected prize is 2 tickets * ticket price
        uint256 expectedPrize = ticketPrice * 2;

        // Check user1 received the prize
        assertEq(user1.balance, user1BalanceBefore + expectedPrize, "Prize amount incorrect");

        // Check the winning ticket was transferred to the contract
        assertEq(ticketsContract.ownerOf(0), address(raffleHouse), "Winning ticket not transferred to contract");
    }

    function test_RevertWhen_ClaimPrize_RaffleDoesNotExist() public {
        vm.prank(user1);
        vm.expectRevert(RaffleDoesNotExist.selector);
        raffleHouse.claimPrize(99);
    }

    function test_RevertWhen_ClaimPrize_RaffleNotEnded() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys a ticket
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // Try to claim before raffle ends
        vm.prank(user1);
        vm.expectRevert(RaffleNotEnded.selector);
        raffleHouse.claimPrize(0);
    }

    function test_RevertWhen_ClaimPrize_WinnerNotChosen() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys a ticket
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // End raffle but don't choose winner
        vm.warp(end + 1);

        // Try to claim without choosing winner
        vm.prank(user1);
        vm.expectRevert(WinnerNotChosen.selector);
        raffleHouse.claimPrize(0);
    }

    function test_RevertWhen_ClaimPrize_NotWinner() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys ticket 0
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // User2 buys ticket 1
        vm.prank(user2);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // End raffle and choose winner
        vm.warp(end + 1);
        raffleHouse.chooseWinner(0);

        // Manually set winning ticket index to 0 (user1's ticket)
        bytes32 winningTicketIndexSlot = keccak256(abi.encode(uint256(0), uint256(4)));
        vm.store(address(raffleHouse), winningTicketIndexSlot, bytes32(uint256(0)));

        // User2 tries to claim but is not the winner
        vm.prank(user2);
        vm.expectRevert(NotWinner.selector);
        raffleHouse.claimPrize(0);
    }

    function test_ClaimPrize_Event() public {
        // Create raffle and buy tickets
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys a ticket
        vm.prank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0);

        // End raffle and choose winner
        vm.warp(end + 1);

        // Set prevrandao to a known value to make test deterministic
        bytes32 fixedRandao = keccak256("fixed randomness");
        vm.prevrandao(fixedRandao);

        raffleHouse.chooseWinner(0);

        console.log("winningTicketIndex", raffleHouse.getRaffle(0).winningTicketIndex);
        console.log("isWinnerChosen", raffleHouse.getRaffle(0).isWinnerChosen);

        // Approve the transfer
        vm.startPrank(user1);
        TicketNFT ticketsContract = raffleHouse.getRaffle(0).ticketsContract;
        ticketsContract.approve(address(raffleHouse), 0);

        // Calculate the expected prize amount
        uint256 totalTickets = ticketsContract.totalSupply();
        uint256 expectedPrize = ticketPrice * totalTickets;

        // Expect the PrizeClaimed event with the correct prize amount
        vm.expectEmit(true, true, false, true);
        emit RaffleHouse.PrizeClaimed(0, user1, expectedPrize);

        // Claim prize
        raffleHouse.claimPrize(0);
        vm.stopPrank();
    }

    // --- Multiple Tickets Per Raffle ---
    function test_MultipleTicketsPerRaffle() public {
        (uint256 start, uint256 end) = _createDefaultRaffle();
        vm.warp(start + 1);

        // User1 buys multiple tickets
        vm.startPrank(user1);
        raffleHouse.buyTicket{value: ticketPrice}(0); // ticket 0
        raffleHouse.buyTicket{value: ticketPrice}(0); // ticket 1
        raffleHouse.buyTicket{value: ticketPrice}(0); // ticket 2
        vm.stopPrank();

        // User2 buys a ticket
        vm.prank(user2);
        raffleHouse.buyTicket{value: ticketPrice}(0); // ticket 3

        // Verify ownership
        TicketNFT ticketsContract = raffleHouse.getRaffle(0).ticketsContract;
        assertEq(ticketsContract.ownerOf(0), user1);
        assertEq(ticketsContract.ownerOf(1), user1);
        assertEq(ticketsContract.ownerOf(2), user1);
        assertEq(ticketsContract.ownerOf(3), user2);

        // Verify total supply
        assertEq(ticketsContract.totalSupply(), 4);
    }

    // --- Edge Cases: Large Number of Tickets ---
    
    function test_LargeNumberOfTickets() public {
        // Create a raffle with a low ticket price to allow many purchases
        uint256 smallTicketPrice = 0.001 ether;
        uint256 start = nowTs + 10;
        uint256 end = start + duration;
        raffleHouse.createRaffle(smallTicketPrice, start, end, name, symbol);
        
        // Warp to raffle start
        vm.warp(start + 1);
        
        // Fund users with enough ETH
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        
        // Buy 50 tickets (25 each user)
        uint256 ticketCount = 50;
        uint256 halfTickets = ticketCount / 2;
        
        // User1 buys first half of tickets
        vm.startPrank(user1);
        for (uint256 i = 0; i < halfTickets; i++) {
            raffleHouse.buyTicket{value: smallTicketPrice}(0);
        }
        vm.stopPrank();
        
        // User2 buys second half of tickets
        vm.startPrank(user2);
        for (uint256 i = 0; i < halfTickets; i++) {
            raffleHouse.buyTicket{value: smallTicketPrice}(0);
        }
        vm.stopPrank();
        
        // Verify total supply
        TicketNFT ticketsContract = raffleHouse.getRaffle(0).ticketsContract;
        assertEq(ticketsContract.totalSupply(), ticketCount);
        
        // Verify ownership distribution
        for (uint256 i = 0; i < halfTickets; i++) {
            assertEq(ticketsContract.ownerOf(i), user1);
            assertEq(ticketsContract.ownerOf(i + halfTickets), user2);
        }
        
        // End raffle and choose winner
        vm.warp(end + 1);
        raffleHouse.chooseWinner(0);
        
        // Verify winner was chosen
        assertTrue(raffleHouse.getRaffle(0).isWinnerChosen);
        
        // Winning index should be within range
        uint256 winningIndex = raffleHouse.getRaffle(0).winningTicketIndex;
        assertTrue(winningIndex < ticketCount);
    }
    
    function test_HighValueRaffleWithManyTickets() public {
        // Create a raffle with a high ticket price
        uint256 highTicketPrice = 1 ether;
        uint256 start = nowTs + 10;
        uint256 end = start + duration;
        raffleHouse.createRaffle(highTicketPrice, start, end, name, symbol);
        
        // Warp to raffle start
        vm.warp(start + 1);
        
        // Fund users with enough ETH
        vm.deal(user1, 20 ether);
        vm.deal(user2, 20 ether);
        
        // Buy 10 tickets (5 each user)
        uint256 ticketCount = 10;
        uint256 halfTickets = ticketCount / 2;
        
        // User1 buys first half of tickets
        vm.startPrank(user1);
        for (uint256 i = 0; i < halfTickets; i++) {
            raffleHouse.buyTicket{value: highTicketPrice}(0);
        }
        vm.stopPrank();
        
        // User2 buys second half of tickets
        vm.startPrank(user2);
        for (uint256 i = 0; i < halfTickets; i++) {
            raffleHouse.buyTicket{value: highTicketPrice}(0);
        }
        vm.stopPrank();
        
        // End raffle and choose winner
        vm.warp(end + 1);
        raffleHouse.chooseWinner(0);
        
        // Calculate expected prize (10 tickets * 1 ether = 10 ether)
        uint256 expectedPrize = highTicketPrice * ticketCount;
        
        // Determine winner
        uint256 winningIndex = raffleHouse.getRaffle(0).winningTicketIndex;
        address winner = winningIndex < halfTickets ? user1 : user2;
        
        // Record winner's balance before claiming
        uint256 winnerBalanceBefore = winner.balance;
        
        // Approve and claim prize
        uint256 winnerTicketId = winningIndex;
        vm.startPrank(winner);
        TicketNFT ticketsContract = raffleHouse.getRaffle(0).ticketsContract;
        ticketsContract.approve(address(raffleHouse), winnerTicketId);
        raffleHouse.claimPrize(0);
        vm.stopPrank();
        
        // Verify winner received the correct prize amount
        assertEq(winner.balance, winnerBalanceBefore + expectedPrize);
    }
    
    function test_MultipleRafflesWithManyTickets() public {
        // Create multiple raffles
        uint256 raffleCount = 3;
        uint256[] memory raffleIds = new uint256[](raffleCount);
        uint256 ticketsPerRaffle = 10;
        
        for (uint256 i = 0; i < raffleCount; i++) {
            uint256 start = nowTs + 10 + i;
            uint256 end = start + duration;
            raffleHouse.createRaffle(ticketPrice, start, end, string.concat(name, "-", vm.toString(i)), string.concat(symbol, vm.toString(i)));
            raffleIds[i] = i;
        }
        
        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        
        // Buy tickets for each raffle
        for (uint256 i = 0; i < raffleCount; i++) {
            // Warp to raffle start
            uint256 start = raffleHouse.getRaffle(i).raffleStart;
            vm.warp(start + 1);
            
            // Each user buys tickets for this raffle
            vm.startPrank(user1);
            for (uint256 j = 0; j < ticketsPerRaffle / 2; j++) {
                raffleHouse.buyTicket{value: ticketPrice}(i);
            }
            vm.stopPrank();
            
            vm.startPrank(user2);
            for (uint256 j = 0; j < ticketsPerRaffle / 2; j++) {
                raffleHouse.buyTicket{value: ticketPrice}(i);
            }
            vm.stopPrank();
        }
        
        // Verify each raffle has correct number of tickets
        for (uint256 i = 0; i < raffleCount; i++) {
            TicketNFT ticketsContract = raffleHouse.getRaffle(i).ticketsContract;
            assertEq(ticketsContract.totalSupply(), ticketsPerRaffle);
        }
        
        // End all raffles and choose winners
        uint256 lastEnd = raffleHouse.getRaffle(raffleCount - 1).raffleEnd;
        vm.warp(lastEnd + 1);
        
        for (uint256 i = 0; i < raffleCount; i++) {
            raffleHouse.chooseWinner(i);
            assertTrue(raffleHouse.getRaffle(i).isWinnerChosen);
        }
    }
}
