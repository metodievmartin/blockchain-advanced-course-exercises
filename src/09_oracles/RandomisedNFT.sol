// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

error RandomisedNFT__AlreadyRequested();
error RandomisedNFT__TransferFailed();
error RandomisedNFT__NeedMoreETHSent();
error RandomisedNFT__NotOwner();
error RandomisedNFT__ZeroAddress();

contract RandomisedNFT is ERC721URIStorage, VRFConsumerBaseV2Plus {
    struct MintRequest {
        address requester;
        bool fulfilled;
    }

    struct Attributes {
        string species;
        string color;
        uint8 flightSpeed;
        uint8 fireResistance;
    }

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    // Chainlink VRF Variables
    uint16 private constant REQ_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 4;

    uint256 private immutable SUBSCRIPTION_ID;
    bytes32 private immutable GAS_LANE;
    uint32 private immutable CALLBACK_GAS_LIMIT;

    // NFT Variables
    uint256 private tokenCounter;
    uint256 private mintFee;

    mapping(uint256 => MintRequest) private mintRequests;
    mapping(uint256 => Attributes) public tokenAttributes;

    // Species and color options
    string[] private SPECIES_OPTIONS = ["Dragon", "Unicorn", "Phoenix", "Griffin", "Hydra"];
    string[] private COLOR_OPTIONS = ["Red", "Blue", "Green", "Gold", "Silver", "Purple", "Black"];

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */

    event MintRequested(uint256 indexed requestId, address requester);
    event NFTMinted(uint256 indexed tokenId, address nftOwner);

    /* ============================================================================================== */
    /*                                            FUNCTIONS                                           */
    /* ============================================================================================== */

    constructor(
        uint256 subscriptionId,
        bytes32 gasLane,
        uint32 callbackGasLimit,
        address vrfCoordinatorAddress,
        uint256 _mintFee
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress) ERC721("RandomizedMythicalCreatures", "RMC") {
        SUBSCRIPTION_ID = subscriptionId;
        GAS_LANE = gasLane;
        CALLBACK_GAS_LIMIT = callbackGasLimit;

        mintFee = _mintFee;
        tokenCounter = 0;
    }

    function requestMint() external payable {
        if (msg.value < mintFee) {
            revert RandomisedNFT__NeedMoreETHSent();
        }

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: GAS_LANE,
                subId: SUBSCRIPTION_ID,
                requestConfirmations: REQ_CONFIRMATIONS,
                callbackGasLimit: CALLBACK_GAS_LIMIT,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );

        mintRequests[requestId] = MintRequest({requester: msg.sender, fulfilled: false});

        emit MintRequested(requestId, msg.sender);
    }

    /**
     * @dev Callback function used by Chainlink VRF
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        address nftOwner = mintRequests[requestId].requester;

        if (mintRequests[requestId].fulfilled) {
            revert RandomisedNFT__AlreadyRequested();
        }

        mintRequests[requestId].fulfilled = true;

        uint256 newTokenId = tokenCounter;
        tokenCounter++;

        // Generate attributes using randomness and store them
        generateAttributes(randomWords, newTokenId);

        _safeMint(nftOwner, newTokenId);
        emit NFTMinted(newTokenId, nftOwner);
    }

    function setMintFee(uint256 _mintFee) external onlyOwner {
        mintFee = _mintFee;
    }

    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool success,) = payable(owner()).call{value: amount}("");
        if (!success) {
            revert RandomisedNFT__TransferFailed();
        }
    }

    /* ============================================================================================== */
    /*                                         VIEW FUNCTIONS                                         */
    /* ============================================================================================== */

    function getMintFee() external view returns (uint256) {
        return mintFee;
    }

    function getTokenCounter() external view returns (uint256) {
        return tokenCounter;
    }

    function getTokenAttributes(uint256 tokenId) external view returns (Attributes memory) {
        return tokenAttributes[tokenId];
    }

    /* ============================================================================================== */
    /*                                       INTERNAL FUNCTIONS                                       */
    /* ============================================================================================== */

    function generateAttributes(uint256[] calldata randomWords, uint256 tokenId) internal {
        // Use the random words to generate attributes for the NFT

        // Word 0: Determine species (0-4)
        uint256 speciesIndex = randomWords[0] % SPECIES_OPTIONS.length;

        // Word 1: Determine color (0-6)
        uint256 colorIndex = randomWords[1] % COLOR_OPTIONS.length;

        // Word 2: Flight speed (1-100)
        uint8 flightSpeed = uint8((randomWords[2] % 100) + 1);

        // Word 3: Fire resistance (1-100)
        uint8 fireResistance = uint8((randomWords[3] % 100) + 1);

        // Create and store the attributes
        tokenAttributes[tokenId] = Attributes({
            species: SPECIES_OPTIONS[speciesIndex],
            color: COLOR_OPTIONS[colorIndex],
            flightSpeed: flightSpeed,
            fireResistance: fireResistance
        });
    }
}
