## Exercise: Signatures and Advanced ERC-20 Standards

### Advanced ERC-20 Token with Signature-Based Approvals

In this assignment, you need to implement an advanced ERC-20 token that incorporates 
modern signature-based approval mechanisms. You will build a token that supports 
both **ERC-2612 (Permit)** and **ERC-3009 (Transfer with Authorization)** standards, 
allowing for gasless approvals and transfers through off-chain signatures.

### Requirements

#### Standard ERC-20 Implementation

Implement a fully compliant ERC-20 token with:

* Name, symbol, and decimals
* `transfer`, `approve`, and `transferFrom` functions
* Proper event emissions
* **Optional**: Supply caps, minting, and burning functions

#### ERC-2612 (Permit) Implementation

Implement the ERC-2612 `permit` function that:

* Allows off-chain approval of token spending
* Validates signatures using EIP-712 structured data
* Includes **nonce** management to prevent replay attacks
* Handles **deadline expiration**

#### ERC-3009 Implementation

Implement the ERC-3009 `transferWithAuthorization` function that:

* Processes transfers based on signed authorisations
* Validates signatures using EIP-712
* Implements a mechanism to prevent **authorisation reuse**
* Handles validity period with `validAfter` and `validBefore` parameters

### Optimisation & Security Considerations

* Implement **storage optimisation** techniques
* Use appropriate **visibility modifiers**
* Protect against **signature malleability**
* Implement proper **domain separator** and **type hash** calculations
* Handle **edge cases** and potential **attack vectors**
* Apply **gas optimisation** techniques

### Testing

* Verify basic ERC-20 functionality
* Test `permit` functionality with valid and invalid signatures
* Test `transferWithAuthorization` with various parameters
* Include **edge cases** and **attack vectors**
* Demonstrate **gas cost comparisons**

### Resources

* [EIP-2612](https://eips.ethereum.org/EIPS/eip-2612)
* [EIP-3009](https://eips.ethereum.org/EIPS/eip-3009)
* [EIP-712](https://eips.ethereum.org/EIPS/eip-712)