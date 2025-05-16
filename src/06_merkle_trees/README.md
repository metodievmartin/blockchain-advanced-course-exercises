## Exercise: Merkle Trees and Merkle Proofs

### Charity Tournament Participant Verification with Merkle Trees

A charity tournament needs an efficient way to verify whether a participant 
took part in the event without storing all addresses on-chain.
**Merkle trees** are ideal for this, as they enable gas-efficient verification while preserving data integrity.

### Requirements

#### Off-Chain Merkle Tree Implementation

Implement a Merkle tree data structure with methods to:

* Generate **leaf nodes** from input data
* Build the complete **Merkle tree**
* Calculate the **Merkle root**
* Generate **proof** for any participant address

#### Off-Chain Merkle Tree Verification

The implementation should:

* Accept a **Merkle proof**
* Verify if a **participant address** belongs to the original dataset
* Return `true` / `false` based on the verification result

#### On-Chain Merkle Proof Verification

Create a smart contract that includes:

* **Storage** for the Merkle root
* Function to **set / update** the Merkle root (with appropriate **access control**)
* Function to **verify Merkle proofs** on-chain
* **Events** for important state changes

### Testing

Write test cases covering the on-chain verification:

* Root setting and updating
* Proof verification
* Access control
* Gas optimisation
* Invalid proof rejection

### Specifications

* Use **Foundry** for development
* Minimum dataset size: **10 elements**
* Include proper **error handling**
* Include comprehensive **documentation**
