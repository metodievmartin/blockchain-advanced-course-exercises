// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {TicketNFT} from "./TicketNFT.sol";
import {ReentrancyGuardTransient} from "@openzeppelin/contracts/utils/ReentrancyGuardTransient.sol";

error TicketPriceTooLow();
error RaffleAlreadyStarted();
error InvalidRaffleEndTime();
error InsufficientRaffleDuration();
error RaffleDoesNotExist();
error RaffleNotStarted();
error RaffleEnded();
error InvalidTicketPrice();
error RaffleNotEnded();
error WinnerAlreadyChosen();
error WinnerNotChosen();
error NotWinner();

/**
 * @title RaffleHouse
 * @notice A contract for managing decentralized raffles with NFT tickets
 * @dev Uses TicketNFT for ticket representation and ReentrancyGuardTransient for security
 */
contract RaffleHouse is ReentrancyGuardTransient {
    struct Raffle {
        uint256 ticketPrice;
        uint256 raffleStart;
        uint256 raffleEnd;
        TicketNFT ticketsContract;
        uint256 winningTicketIndex;
        bool isWinnerChosen;
    }

    uint256 public constant MIN_DURATION = 1 hours;

    uint256 public raffleCount;

    mapping(uint256 raffleId => Raffle) public raffles;

    event RaffleCreated(
        uint256 indexed raffleId,
        uint256 ticketPrice,
        uint256 raffleStart,
        uint256 raffleEnd,
        string raffleName,
        string raffleSymbol
    );
    event TicketPurchased(uint256 indexed raffleId, address indexed buyer, uint256 ticketId);
    event WinnerChosen(uint256 indexed raffleId, uint256 winningTicketIndex);
    event PrizeClaimed(uint256 indexed raffleId, address indexed winner, uint256 prizeAmount);

    /**
     * @notice Creates a new raffle with specified parameters
     * @param ticketPrice Price per ticket in wei
     * @param raffleStart Start timestamp of the raffle
     * @param raffleEnd End timestamp of the raffle
     * @param raffleName Name of the raffle NFT collection
     * @param raffleSymbol Symbol of the raffle NFT collection
     */
    function createRaffle(
        uint256 ticketPrice,
        uint256 raffleStart,
        uint256 raffleEnd,
        string calldata raffleName,
        string calldata raffleSymbol
    ) public {
        if (ticketPrice == 0) revert TicketPriceTooLow();
        if (raffleStart < block.timestamp) revert RaffleAlreadyStarted();
        if (raffleEnd <= raffleStart) revert InvalidRaffleEndTime();
        if (raffleEnd - raffleStart < MIN_DURATION) {
            revert InsufficientRaffleDuration();
        }

        TicketNFT ticketsContract = new TicketNFT(raffleName, raffleSymbol);

        Raffle memory raffle = Raffle({
            ticketPrice: ticketPrice,
            raffleStart: raffleStart,
            raffleEnd: raffleEnd,
            ticketsContract: ticketsContract,
            winningTicketIndex: 0,
            isWinnerChosen: false
        });
        raffles[raffleCount] = raffle;
        emit RaffleCreated(raffleCount++, ticketPrice, raffleStart, raffleEnd, raffleName, raffleSymbol);
    }

    /**
     * @notice Purchase a ticket for a specific raffle
     * @param raffleId ID of the raffle to buy a ticket for
     */
    function buyTicket(uint256 raffleId) public payable nonReentrant {
        if (raffleId >= raffleCount) revert RaffleDoesNotExist();
        if (block.timestamp < raffles[raffleId].raffleStart) {
            revert RaffleNotStarted();
        }
        if (block.timestamp >= raffles[raffleId].raffleEnd) {
            revert RaffleEnded();
        }
        if (msg.value != raffles[raffleId].ticketPrice) {
            revert InvalidTicketPrice();
        }

        uint256 ticketId = raffles[raffleId].ticketsContract.safeMint(msg.sender);
        emit TicketPurchased(raffleId, msg.sender, ticketId);
    }

    /**
     * @notice Get raffle details by ID
     * @param raffleId ID of the raffle
     * @return Raffle struct containing raffle details
     */
    function getRaffle(uint256 raffleId) public view returns (Raffle memory) {
        if (raffleId >= raffleCount) revert RaffleDoesNotExist();
        return raffles[raffleId];
    }

    /**
     * @notice Choose a winner for a completed raffle
     * @param raffleId ID of the raffle
     */
    function chooseWinner(uint256 raffleId) public nonReentrant {
        if (raffleId >= raffleCount) revert RaffleDoesNotExist();
        if (block.timestamp < raffles[raffleId].raffleEnd) {
            revert RaffleNotEnded();
        }
        if (raffles[raffleId].isWinnerChosen) {
            revert WinnerAlreadyChosen();
        }

        uint256 totalTickets = raffles[raffleId].ticketsContract.totalSupply();

        uint256 winningTicketIndex =
            uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, totalTickets))) % totalTickets;

        raffles[raffleId].winningTicketIndex = winningTicketIndex;
        raffles[raffleId].isWinnerChosen = true;
        emit WinnerChosen(raffleId, winningTicketIndex);
    }

    /**
     * @notice Claim prize for winning a raffle
     * @param raffleId ID of the raffle
     */
    function claimPrize(uint256 raffleId) public nonReentrant {
        if (raffleId >= raffleCount) revert RaffleDoesNotExist();
        if (block.timestamp < raffles[raffleId].raffleEnd) {
            revert RaffleNotEnded();
        }
        if (!raffles[raffleId].isWinnerChosen) revert WinnerNotChosen();
        if (raffles[raffleId].ticketsContract.ownerOf(raffles[raffleId].winningTicketIndex) != msg.sender) {
            revert NotWinner();
        }

        raffles[raffleId].ticketsContract.transferFrom(msg.sender, address(this), raffles[raffleId].winningTicketIndex);

        uint256 ticketsCount = raffles[raffleId].ticketsContract.totalSupply();
        uint256 prizeAmount = raffles[raffleId].ticketPrice * ticketsCount;

        payable(msg.sender).transfer(prizeAmount);
        emit PrizeClaimed(raffleId, msg.sender, prizeAmount);
    }

    /**
     * @notice Get total number of raffles created
     * @return Total number of raffles
     */
    function getRaffleCount() public view returns (uint256) {
        return raffleCount;
    }
}
