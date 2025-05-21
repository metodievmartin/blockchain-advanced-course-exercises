# Blockchain Oracles: Verifiable Random Function (VRF)

## Introduction to Blockchain Oracles

Blockchain oracles are third-party services that provide smart contracts with external information from the outside world. They serve as a bridge between blockchains and external systems, allowing smart contracts to access data that isn't available on-chain.

### The Oracle Problem

Blockchains are deterministic systems that can only access data already on the chain. This creates the "oracle problem" - how to securely bring external data on-chain without compromising the blockchain's security and trustlessness.

### Types of Oracles

1. **Input Oracles**: Bring off-chain data onto the blockchain (e.g., price feeds)
2. **Output Oracles**: Send blockchain data to external systems
3. **Computation Oracles**: Perform complex computations off-chain
4. **Cross-Chain Oracles**: Transfer data between different blockchains

## Verifiable Random Function (VRF): Overview

### The Need for On-Chain Randomness

Generating true randomness on a blockchain is inherently difficult because:

1. **Determinism**: Blockchains are deterministic - the same input always produces the same output
2. **Public Visibility**: All data and computations are visible to miners/validators
3. **Manipulation Risk**: Miners could theoretically manipulate "random" values to their advantage

### What is a VRF?

A Verifiable Random Function (VRF) is a cryptographic function that:

1. Takes an input and produces a random output
2. Provides a proof that the output was generated correctly
3. Allows anyone to verify this proof without compromising randomness

## Chainlink VRF Architecture

### Core Components

1. **VRF Coordinator**: The central contract that manages VRF requests and responses
2. **Subscription Manager**: Handles payment for VRF services
3. **Chainlink Nodes**: Off-chain oracles that generate random values and cryptographic proofs
4. **Consumer Contract**: Your smart contract that requests and uses randomness

### How Chainlink VRF Works

```
┌─────────────────┐          ┌───────────────────┐          ┌─────────────────┐
│                 │  Step 1  │                   │  Step 2  │                 │
│  Consumer       │────────► │  VRF Coordinator  │────────► │  Chainlink Node │
│  Contract       │          │  Contract         │          │                 │
│                 │◄──────── │                   │◄──────── │                 │
│                 │  Step 4  │                   │  Step 3  │                 │
└─────────────────┘          └───────────────────┘          └─────────────────┘
```

1. **Request**: Consumer contract requests randomness from the VRF Coordinator
2. **Processing**: Request is sent to a Chainlink Node
3. **Generation**: Node generates random value + cryptographic proof
4. **Fulfillment**: Proof is verified on-chain, and random value is returned to consumer

## Implementation Guide

### 1. Setting Up a VRF Consumer

To use Chainlink VRF, your contract must inherit from the VRF consumer base contract:

```solidity
// Import the VRF consumer base contract
import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// Inherit from the VRF consumer base
contract MyRandomContract is VRFConsumerBaseV2Plus {
    // Configuration parameters
    uint64 private immutable s_subscriptionId;
    bytes32 private immutable s_keyHash;
    uint32 private immutable s_callbackGasLimit;
    
    constructor(
        uint64 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        address vrfCoordinatorAddress
    ) VRFConsumerBaseV2Plus(vrfCoordinatorAddress) {
        s_subscriptionId = subscriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
    }
}
```

### 2. Requesting Random Values

```solidity
// Request random values
function requestRandomness() external returns (uint256 requestId) {
    // Create the request
    requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest({
            keyHash: s_keyHash,
            subId: s_subscriptionId,
            requestConfirmations: 3,  // Number of block confirmations to wait
            callbackGasLimit: s_callbackGasLimit,
            numWords: 1,  // Number of random values requested
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
            )
        })
    );
    
    // Track the request (optional)
    s_requests[requestId] = RequestStatus({
        fulfilled: false,
        randomWords: new uint256[](0)
    });
    
    return requestId;
}
```

### 3. Receiving Random Values

You must implement the `fulfillRandomWords` function to receive the random values:

```solidity
// Callback function that receives random values
function fulfillRandomWords(
    uint256 requestId,
    uint256[] memory randomWords
) internal override {
    // Update request status
    s_requests[requestId].fulfilled = true;
    s_requests[requestId].randomWords = randomWords;
    
    // Use the random values for your application
    uint256 randomValue = randomWords[0];
    // Your application logic here...
}
```

### 4. Using Random Values

Random values can be used for various applications:

```solidity
// Generate a random number between min and max (inclusive)
function getRandomInRange(
    uint256 randomValue,
    uint256 min,
    uint256 max
) public pure returns (uint256) {
    // Ensure max > min
    require(max > min, "Max must be greater than min");
    
    // Calculate the range size
    uint256 range = max - min + 1;
    
    // Generate random number in range
    return (randomValue % range) + min;
}

// Select a random item from an array
function getRandomItem(
    uint256 randomValue,
    string[] memory items
) public pure returns (string memory) {
    // Get a random index
    uint256 randomIndex = randomValue % items.length;
    
    // Return the item at that index
    return items[randomIndex];
}
```

## Subscription Management

### Creating and Funding a Subscription

Subscriptions are managed through the VRF Coordinator's subscription manager:

1. **Create**: Create a new subscription
2. **Fund**: Add LINK tokens or native ETH to the subscription
3. **Add Consumer**: Authorize your contract to use the subscription
4. **Monitor**: Keep the subscription funded to ensure requests are fulfilled

## Example: RandomisedNFT

Here's how the RandomisedNFT contract uses Chainlink VRF to generate random attributes for NFTs:

```solidity
// Excerpt from RandomisedNFT.sol
function requestMint() external payable {
    if (msg.value < mintFee) {
        revert RandomisedNFT__NeedMoreETHSent();
    }

    // Request random words from the VRF Coordinator
    uint256 requestId = s_vrfCoordinator.requestRandomWords(
        VRFV2PlusClient.RandomWordsRequest({
            keyHash: GAS_LANE,
            subId: SUBSCRIPTION_ID,
            requestConfirmations: REQ_CONFIRMATIONS,
            callbackGasLimit: CALLBACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
            )
        })
    );

    // Store request metadata
    mintRequests[requestId] = MintRequest({
        requester: msg.sender, 
        fulfilled: false
    });

    emit MintRequested(requestId, msg.sender);
}
```

When the VRF callback is received, the contract generates NFT attributes using the random values:

```solidity
// Excerpt from RandomisedNFT.sol
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
```

## Best Practices and Security Considerations

### Request Management

- **Track Requests**: Store request IDs and their status
- **Prevent Duplicates**: Ensure each request is processed only once
- **Handle Failures**: Implement retry mechanisms for failed requests

### Gas Considerations

- **Callback Gas Limit**: Set an appropriate gas limit for the callback function
- **Efficient Processing**: Optimize the code that processes random values
- **Storage Efficiency**: Minimize storage operations in the callback

### Randomness Usage

- **Modulo Bias**: Be aware of modulo bias when generating bounded random numbers
- **Multiple Sources**: Use multiple random values for critical applications
- **Avoid Predictability**: Don't make randomness predictable by using known inputs

## Applications of VRF

1. **Gaming**: Fair distribution of items, random encounters, dice rolls
2. **NFTs**: Random trait generation, blind box reveals
3. **DeFi**: Random selection of validators, fair distribution of rewards
4. **Governance**: Random selection of committee members

## Conclusion

Chainlink VRF provides a secure and verifiable source of randomness for blockchain applications. By understanding its components and implementation, developers can create fair and unpredictable systems that maintain the security and trustlessness of blockchain technology.

Remember that while VRF provides cryptographically secure randomness, it's important to use it correctly and consider the specific requirements of your application.
