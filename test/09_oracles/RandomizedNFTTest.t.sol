// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console2, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {RandomisedNFT, RandomisedNFT__NeedMoreETHSent} from "@/09_oracles/RandomisedNFT.sol";
import {LinkToken} from "./mocks/LinkToken.sol";

contract RandomisedNFTTest is Test {
    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */
    RandomisedNFT public randomisedNFT;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    LinkToken public linkToken;

    // Constants
    uint64 private constant SUBSCRIPTION_ID = 1;
    bytes32 private constant GAS_LANE = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 private constant CALLBACK_GAS_LIMIT = 2500000;
    uint256 private constant MINT_FEE = 0.01 ether;

    // Testing accounts
    address public MINTER = makeAddr("minter");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;
    uint256 public constant NATIVE_BALANCE = 10 ether;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */
    event MintRequested(uint256 indexed requestId, address requester);
    event NFTMinted(uint256 indexed tokenId, address nftOwner);
    event OwnershipTransferred(address indexed previous, address indexed newAddress);

    // Allow the contract to receive ETH
    receive() external payable {}

    function setUp() external {
        // 1. Deploy VRF and Link Token mocks
        vrfCoordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 3000000000, 0.001 ether);
        linkToken = new LinkToken();

        // 2. Create the subscription and fund it with both LINK and Native tokens
        uint256 subId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subId, LINK_BALANCE);

        // 3. Fund with native tokens
        vm.deal(address(this), NATIVE_BALANCE);
        vrfCoordinator.fundSubscriptionWithNative{value: NATIVE_BALANCE}(subId);

        // 4. Deploy the RandomisedNFT contract
        randomisedNFT = new RandomisedNFT(subId, GAS_LANE, CALLBACK_GAS_LIMIT, address(vrfCoordinator), MINT_FEE);

        // 5. Add the consumer
        vrfCoordinator.addConsumer(subId, address(randomisedNFT));

        // 6. Fund the minter
        vm.deal(MINTER, STARTING_USER_BALANCE);
    }

    /* ============================================================================================== */
    /*                                           BASIC TESTS                                          */
    /* ============================================================================================== */

    function testInit() public view {
        assertEq(randomisedNFT.getMintFee(), MINT_FEE, "mint_fee");
        assertEq(randomisedNFT.getTokenCounter(), 0, "token_counter");
        assertEq(randomisedNFT.owner(), address(this), "owner");
    }

    function testMintFeeUpdate() public {
        uint256 newMintFee = 0.02 ether;
        randomisedNFT.setMintFee(newMintFee);
        assertEq(randomisedNFT.getMintFee(), newMintFee, "new_mint_fee");
    }

    function testMintFeeUpdateFailsForNonOwner() public {
        vm.prank(MINTER);
        vm.expectRevert();
        randomisedNFT.setMintFee(0.02 ether);
    }

    function testWithdrawFails() public {
        vm.prank(MINTER);
        vm.expectRevert();
        randomisedNFT.withdraw();
    }

    /* ============================================================================================== */
    /*                                         MINTING TESTS                                          */
    /* ============================================================================================== */

    function testRequestMintFailsWithInsufficientFunds() public {
        vm.prank(MINTER);
        vm.expectRevert(RandomisedNFT__NeedMoreETHSent.selector);
        randomisedNFT.requestMint{value: MINT_FEE - 0.001 ether}();
    }

    function testRequestMintSuccess() public {
        vm.prank(MINTER);
        vm.expectEmit(true, true, false, true, address(randomisedNFT));
        emit MintRequested(1, MINTER);
        randomisedNFT.requestMint{value: MINT_FEE}();
    }

    function testFulfillRandomWordsAndMintNFT() public {
        vm.prank(MINTER);
        randomisedNFT.requestMint{value: MINT_FEE}();

        uint256[] memory randomWords = new uint256[](4);
        randomWords[0] = 1;
        randomWords[1] = 2;
        randomWords[2] = 50;
        randomWords[3] = 75;

        vm.expectEmit(true, true, false, true, address(randomisedNFT));
        emit NFTMinted(0, MINTER);

        vrfCoordinator.fulfillRandomWordsWithOverride(1, address(randomisedNFT), randomWords);

        assertEq(randomisedNFT.getTokenCounter(), 1, "token_counter");
        assertEq(randomisedNFT.ownerOf(0), MINTER, "owner");

        // Verify attributes were assigned correctly based on the random words
        RandomisedNFT.Attributes memory attrs = randomisedNFT.getTokenAttributes(0);

        // Print the attributes in a formatted way
        printAttributes(0, attrs);

        // randomWords[0] = 1, species index = 1 % 5 = 1 (Unicorn)
        assertEq(attrs.species, "Unicorn", "species");

        // randomWords[1] = 2, color index = 2 % 7 = 2 (Green)
        assertEq(attrs.color, "Green", "color");

        // randomWords[2] = 50, flightSpeed = 50 % 100 + 1 = 51
        assertEq(attrs.flightSpeed, 51, "flightSpeed");

        // randomWords[3] = 75, fireResistance = 75 % 100 + 1 = 76
        assertEq(attrs.fireResistance, 76, "fireResistance");
    }

    function testMultipleMints() public {
        uint256 mintCount = 3;

        for (uint256 i = 0; i < mintCount; i++) {
            vm.prank(MINTER);
            randomisedNFT.requestMint{value: MINT_FEE}();

            uint256[] memory randomWords = new uint256[](4);
            randomWords[0] = i + 57;
            randomWords[1] = i + 14;
            randomWords[2] = i + 288;
            randomWords[3] = i + 345;

            vrfCoordinator.fulfillRandomWordsWithOverride(i + 1, address(randomisedNFT), randomWords);

            // Verify attributes for each minted NFT
            RandomisedNFT.Attributes memory attrs = randomisedNFT.getTokenAttributes(i);

            // Calculate expected values based on the random words
            uint256 expectedSpeciesIndex = randomWords[0] % 5; // 5 species options
            uint256 expectedColorIndex = randomWords[1] % 7; // 7 color options
            uint8 expectedFlightSpeed = uint8((randomWords[2] % 100) + 1);
            uint8 expectedFireResistance = uint8((randomWords[3] % 100) + 1);

            console.log("expectedFlightSpeed", expectedFlightSpeed);
            console.log("expectedFireResistance", expectedFireResistance);

            // Get expected species and color based on indices
            string memory expectedSpecies = getSpeciesAtIndex(expectedSpeciesIndex);
            string memory expectedColor = getColorAtIndex(expectedColorIndex);

            // Print attributes in a nicely formatted way
            printAttributes(i, attrs);

            // Verify all attributes
            assertEq(attrs.species, expectedSpecies, string(abi.encodePacked("species_", i)));
            assertEq(attrs.color, expectedColor, string(abi.encodePacked("color_", i)));
            assertEq(attrs.flightSpeed, expectedFlightSpeed, string(abi.encodePacked("flightSpeed_", i)));
            assertEq(attrs.fireResistance, expectedFireResistance, string(abi.encodePacked("fireResistance_", i)));
        }

        assertEq(randomisedNFT.getTokenCounter(), mintCount, "token_counter");
        assertEq(randomisedNFT.balanceOf(MINTER), mintCount, "balance");
    }

    /* ============================================================================================== */
    /*                                        WITHDRAWAL TESTS                                        */
    /* ============================================================================================== */

    function testWithdrawSuccess() public {
        uint256 mintCount = 3;
        uint256 expectedBalance = mintCount * MINT_FEE;

        for (uint256 i = 0; i < mintCount; i++) {
            vm.prank(MINTER);
            randomisedNFT.requestMint{value: MINT_FEE}();
        }

        uint256 preWithdrawBalance = address(this).balance;
        randomisedNFT.withdraw();
        uint256 postWithdrawBalance = address(this).balance;

        assertEq(postWithdrawBalance - preWithdrawBalance, expectedBalance, "withdraw_amount");
        assertEq(address(randomisedNFT).balance, 0, "contract_balance");
    }

    /* ============================================================================================== */
    /*                                        HELPER FUNCTIONS                                        */
    /* ============================================================================================== */

    function getSpeciesAtIndex(uint256 index) internal pure returns (string memory) {
        string[5] memory speciesOptions = ["Dragon", "Unicorn", "Phoenix", "Griffin", "Hydra"];
        return speciesOptions[index];
    }

    function getColorAtIndex(uint256 index) internal pure returns (string memory) {
        string[7] memory colorOptions = ["Red", "Blue", "Green", "Gold", "Silver", "Purple", "Black"];
        return colorOptions[index];
    }

    // Helper function to print attributes in a formatted way
    function printAttributes(uint256 tokenId, RandomisedNFT.Attributes memory attrs) internal pure {
        console.log("===================================================");
        console.log("|  NFT #%s - Mythical Creature Attributes  ", tokenId);
        console.log("===================================================");
        console.log("|  Species:         %s", attrs.species);
        console.log("|  Color:           %s", attrs.color);
        console.log("|  Flight Speed:    %s/100", attrs.flightSpeed);
        console.log("|  Fire Resistance: %s/100", attrs.fireResistance);
        console.log("===================================================");
    }
}
