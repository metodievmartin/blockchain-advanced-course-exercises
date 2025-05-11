# Visual Representation of Bit Shifting Operations in Solidity

This guide provides a visual walkthrough of how bitwise operations work in the context of the `FunctionGuzzlerOptimised` contract, which uses bit packing to store both user registration status and balance in a single storage slot.

## 1. User Registration

Let's start with a fresh user (address never seen before):

```
Initial state of usersData[user]:
Decimal: 0
Binary:  0000 0000
```

When we register the user:
```solidity
usersData[msg.sender] |= 1;
```

```
Operation: 0000 0000 | 0000 0001
Result:    0000 0001

New state of usersData[user]:
Decimal: 1
Binary:  0000 0001
                 ↑
                 LSB set to 1 (registered)
```

## 2. Deposit Operation

Let's say we want to deposit 5 tokens for this user:
```solidity
usersData[msg.sender] += _amount << 1;
```

### Step 1: Shift the amount left by 1 bit
```
_amount = 5
Binary:   0000 0101

_amount << 1:
Operation: Shift all bits left by 1 position
Result:    0000 1010  (decimal: 10)

Explanation:
0000 0101  (5 in decimal)
  ↓ ↓ ↓ ↓
0000 1010  (10 in decimal)
     ↑↑↑
     Each bit moved one position left
     (equivalent to multiplying by 2)
```

### Step 2: Add the shifted amount to the user data
```
usersData[user] = 1 (from registration)
_amount << 1 = 10

usersData[user] += _amount << 1
Operation: 0000 0001 + 0000 1010
Result:    0000 1011  (decimal: 11)

New state of usersData[user]:
Decimal: 11
Binary:  0000 1011
                 ↑
                 LSB still 1 (registered)
```

## 3. Balance Retrieval

Now let's retrieve the balance:
```solidity
return usersData[_user] >> 1;
```

```
usersData[user] = 11
Binary: 0000 1011

usersData[user] >> 1:
Operation: Shift all bits right by 1 position
Result:    0000 0101  (decimal: 5)

Explanation:
0000 1011  (11 in decimal)
  ↓ ↓ ↓ ↓
0000 0101  (5 in decimal)
      ↑↑↑
      Each bit moved one position right
      (equivalent to dividing by 2)
      The LSB (registration bit) is discarded
```

## 4. Another Deposit

Let's deposit 3 more tokens:

### Step 1: Shift the amount left by 1 bit
```
_amount = 3
Binary:   0000 0011

_amount << 1:
Operation: Shift all bits left by 1 position
Result:    0000 0110  (decimal: 6)

Visualization:
0000 0011  (3 in decimal)
  ↓ ↓ ↓ ↓
0000 0110  (6 in decimal)
```

### Step 2: Add the shifted amount to the user data
```
Current usersData[user] = 11
_amount << 1 = 6

usersData[user] += _amount << 1
Operation: 0000 1011 + 0000 0110
Result:    0001 0001  (decimal: 17)

New state of usersData[user]:
Decimal: 17
Binary:  0001 0001
                 ↑
                 LSB still 1 (registered)
```

## 5. Balance Retrieval After Second Deposit

```
usersData[user] = 17
Binary: 0001 0001

usersData[user] >> 1:
Operation: Shift all bits right by 1 position
Result:    0000 1000  (decimal: 8)

Visualization:
0001 0001  (17 in decimal)
  ↓ ↓ ↓ ↓
0000 1000  (8 in decimal)
```

## 6. Transfer Operation

Let's say we want to transfer 2 tokens from our user to another registered user:

### Step 1: Shift the amount left by 1 bit
```
_amount = 2
Binary:   0000 0010

_amount << 1:
Operation: Shift all bits left by 1 position
Result:    0000 0100  (decimal: 4)

Visualization:
0000 0010  (2 in decimal)
  ↓ ↓ ↓ ↓
0000 0100  (4 in decimal)
```

### Step 2: Subtract from sender
```
Current usersData[sender] = 17
_amount << 1 = 4

usersData[sender] -= _amount << 1
Operation: 0001 0001 - 0000 0100
Result:    0000 1101  (decimal: 13)

New state of usersData[sender]:
Decimal: 13
Binary:  0000 1101
                 ↑
                 LSB still 1 (registered)
```

### Step 3: Add to recipient
Assuming recipient's current state is just registered (value 1):
```
Current usersData[recipient] = 1
_amount << 1 = 4

usersData[recipient] += _amount << 1
Operation: 0000 0001 + 0000 0100
Result:    0000 0101  (decimal: 5)

New state of usersData[recipient]:
Decimal: 5
Binary:  0000 0101
                 ↑
                 LSB still 1 (registered)
```

## Summary Table

| Operation | Starting Value | Binary | Operation | Result Value | Binary Result | Explanation |
|-----------|----------------|--------|-----------|--------------|---------------|-------------|
| Register | 0 | 0000 0000 | \|= 1 | 1 | 0000 0001 | Set LSB to 1 |
| Deposit 5 | 1 | 0000 0001 | += (5 << 1) | 11 | 0000 1011 | Add (5×2) while preserving LSB |
| Get Balance | 11 | 0000 1011 | >> 1 | 5 | 0000 0101 | Shift right to remove LSB |
| Deposit 3 | 11 | 0000 1011 | += (3 << 1) | 17 | 0001 0001 | Add (3×2) while preserving LSB |
| Get Balance | 17 | 0001 0001 | >> 1 | 8 | 0000 1000 | Shift right to remove LSB |
| Transfer 2 (from) | 17 | 0001 0001 | -= (2 << 1) | 13 | 0000 1101 | Subtract (2×2) while preserving LSB |
| Transfer 2 (to) | 1 | 0000 0001 | += (2 << 1) | 5 | 0000 0101 | Add (2×2) while preserving LSB |

## Bitwise Operations Cheat Sheet

### Core Operators

| Operator | Name | Description | Example |
|----------|------|-------------|---------|
| `&` | AND | Returns 1 if both bits are 1 | `5 & 3 = 1` |
| `\|` | OR | Returns 1 if either bit is 1 | `5 \| 3 = 7` |
| `^` | XOR | Returns 1 if exactly one bit is 1 | `5 ^ 3 = 6` |
| `~` | NOT | Inverts all bits | `~5 = -6` (in two's complement) |
| `<<` | Left Shift | Shifts bits left, filling with 0s | `5 << 1 = 10` |
| `>>` | Right Shift | Shifts bits right | `5 >> 1 = 2` |

### Common Bit Manipulation Techniques

| Operation | Code | Description |
|-----------|------|-------------|
| Set bit n | `x \|= (1 << n)` | Sets the nth bit to 1 |
| Clear bit n | `x &= ~(1 << n)` | Sets the nth bit to 0 |
| Toggle bit n | `x ^= (1 << n)` | Flips the nth bit |
| Check bit n | `(x & (1 << n)) != 0` | Returns true if nth bit is 1 |
| Extract lowest bit | `x & -x` | Gets the lowest set bit |
| Remove lowest bit | `x & (x-1)` | Clears the lowest set bit |
| Check if power of 2 | `(x & (x-1)) == 0` | True for 0 and powers of 2 |
