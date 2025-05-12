# ERC-3009 transfer signature flow

This guide explains how ERC-3009 works, enabling gasless `transferWithAuthorization` operations using EIP-712 signatures. 
It is especially useful for improving UX in token transfers — no need for the sender to pay gas.

## What is ERC-3009?

ERC-3009 allows **transferring tokens via a signature**, without the sender initiating an on-chain transaction. 
This is similar in spirit to ERC-2612, but for token transfers instead of approvals.

### Core function

```solidity
function transferWithAuthorization(
  address from,
  address to,
  uint256 value,
  uint256 validAfter,
  uint256 validBefore,
  bytes32 nonce,
  uint8 v, bytes32 r, bytes32 s
) external;
```

### Use Case

1. A user signs a message authorising a transfer.
2. Anyone can submit this signature on-chain to transfer tokens.

## Signature Structure (EIP-712)

The struct being signed is:

```solidity
TransferWithAuthorization(
  address from,
  address to,
  uint256 value,
  uint256 validAfter,
  uint256 validBefore,
  bytes32 nonce
)
```

### TYPEHASH

```solidity
bytes32 constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
  keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)");
```

### Domain Separator (via ERC20Permit)

Automatically constructed using:

```solidity
EIP712Domain(
  string name, // Token name
  string version = "1",
  uint256 chainId,
  address verifyingContract
)
```

## The `transferWithAuthorization` Flow

### Step 1: Verify Time Window

```solidity
require(block.timestamp >= validAfter, "AuthorizationNotYetValid");
require(block.timestamp <= validBefore, "AuthorizationExpired");
```

### Step 2: Prevent Replay

```solidity
require(!_authorizationStates[from][nonce], "AuthorizationAlreadyUsed");
```

This mapping tracks which nonces were already used.

### Step 3: Recreate Signed Message

```solidity
bytes32 structHash = keccak256(
  abi.encode(
    TRANSFER_WITH_AUTHORIZATION_TYPEHASH,
    from,
    to,
    value,
    validAfter,
    validBefore,
    nonce
  )
);

bytes32 digest = _hashTypedDataV4(structHash);
```

### Step 4: Recover Signer and Check

```solidity
address signer = ECDSA.recover(digest, v, r, s);
require(signer == from, "InvalidSignature");
```

### Step 5: Mark Nonce Used and Transfer

```solidity
_authorizationStates[from][nonce] = true;
_transfer(from, to, value);
```

...

---

## Replay Protection

* ERC-3009 uses **arbitrary `bytes32` nonces**.
* These nonces are **provided by the user** (not incremented automatically).
* Once a nonce is used, it's recorded in a mapping:

```solidity
mapping(address => mapping(bytes32 => bool)) private _authorizationStates;
```

* If a transaction with the same nonce is submitted again, it will fail:

```solidity
require(!_authorizationStates[from][nonce], "AuthorizationAlreadyUsed");
```

### Why This Works

Each signature includes a specific `nonce`, and the smart contract:

1. Validates that it's **not yet used**.
2. **Marks it as used** immediately upon accepting the signature.
3. **Rejects any reuse**, preventing replay attacks.

### How It Differs from ERC-2612

| Feature           | ERC-2612                   | ERC-3009                              |
| ----------------- | -------------------------- | ------------------------------------- |
| Nonce Type        | `uint256` (auto-increment) | `bytes32` (arbitrary)                 |
| Who defines nonce | Smart contract             | Off-chain signer                      |
| Tracking          | `nonces[address]`          | `authorizationStates[address][nonce]` |

### Example Replay Scenario

1. Alice signs a `transferWithAuthorization` with `nonce = 0xABC123...`
2. Someone submits it → ✅ transfer executes
3. Same signature used again → ❌ fails due to `AuthorizationAlreadyUsed`

This model provides flexibility: users can choose UUID-style nonces or timestamps encoded as nonces, 
as long as they are unique per address and never reused.

## Example Off-Chain Signing Payload

```json
{
  "types": {
    "EIP712Domain": [
      {"name": "name", "type": "string"},
      {"name": "version", "type": "string"},
      {"name": "chainId", "type": "uint256"},
      {"name": "verifyingContract", "type": "address"}
    ],
    "TransferWithAuthorization": [
      {"name": "from", "type": "address"},
      {"name": "to", "type": "address"},
      {"name": "value", "type": "uint256"},
      {"name": "validAfter", "type": "uint256"},
      {"name": "validBefore", "type": "uint256"},
      {"name": "nonce", "type": "bytes32"}
    ]
  },
  "domain": {
    "name": "AdvancedToken",
    "version": "1",
    "chainId": 1,
    "verifyingContract": "0xYourTokenAddress"
  },
  "primaryType": "TransferWithAuthorization",
  "message": {
    "from": "0xSenderAddress",
    "to": "0xRecipientAddress",
    "value": "5000000000000000000",
    "validAfter": 0,
    "validBefore": 1719000000,
    "nonce": "0xa1b2c3..."
  }
}
```

## Mental Model Summary

1. A user signs a **transfer authorisation message** off-chain.
2. Anyone can submit it on-chain.
3. The contract verifies:

    * The signature
    * Time window
    * Nonce unused
4. Tokens are transferred without the sender needing ETH or gas.

