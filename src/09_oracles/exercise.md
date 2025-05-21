# Exercise: Oracles

## Randomised NFT Minting

Build a collectible digital asset structure where each NFT has unique, randomly generated visual and/or functional traits.

### Requirements

#### Use Chainlink VRF for Randomness

* Integrate Chainlink's **Verifiable Random Function (VRF)** to generate real randomness on every mint
* When a user requests to mint an NFT, your contract sends a VRF request

#### NFT Design & Attribute Storage

Sample Attributes:

* Appearance: fur or wing colour, eye shape, accessories
* Species/Class: Dragon, Unicorn, Phoenix, etc.
* Stats: FlightSpeed, FireResistance (values from 1–100)

```solidity
struct Attributes {
    string species;
    string color;
    uint8 flightSpeed;
    uint8 fireResistance;
}

mapping(uint256 => Attributes) public tokenAttributes;
```

* Use the VRF-provided random value to derive each attribute

#### Minting Flow

1. User calls `requestMint()` and pays the minting fee (if applicable)
2. Contract records the request and calls Chainlink VRF
3. Upon VRF callback `fulfillRandomness(requestId, randomness)`:

    * The contract generates attributes from randomness
    * Calls `_safeMint(to, tokenId)`
    * Stores the attribute struct in `tokenAttributes[tokenId]`

#### Metadata Retrieval

* Provide ways to view or retrieve the attributes assigned to each NFT after it is minted

---

## Stop-Loss Vault

Imagine Alice is bullish on ETH long-term but wants to minimise downside risk. She deposits 1 ETH and sets a stop-loss price of \$1,800. If ETH falls below that level, she can request to withdraw her funds. The contract verifies the current price using **Chainlink Data Feeds** before releasing her deposit.

### Requirements

#### 1. Using Chainlink Price Feeds

* Integrate Chainlink's **decentralised price oracles** to fetch real-time asset prices (e.g. ETH/USD)

#### 2. Vault Creation & Deposit

Users interact with the contract to deposit ETH and set a stop-loss threshold:

```solidity
struct Vault {
    address owner;
    uint256 amount;
    uint256 stopLossPrice; // in USD, 8 decimals
    bool active;
}

mapping(uint256 => Vault) public vaults;
```

* On `createVault()`, store the user’s deposit and stop-loss price
* Emit a `VaultCreated` event

#### 3. Manual Withdrawal Request with Price Verification

* The user sees ETH price has dropped and calls the `withdraw()` method
* The contract fetches the current ETH/USD price
* If the price is **below** the user's defined threshold, the funds are unlocked and returned
