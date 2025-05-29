# Blockchain Advanced Course Exercises

This repository contains practical exercises and projects completed during the SoftUni Blockchain Advanced Course. 
Each directory represents a different topic covered in the course, 
demonstrating implementations of advanced blockchain development concepts.

## Course Topics

### 01. Foundry Toolchain
- Implementation of smart contracts using Foundry's powerful development environment
- Utilization of Forge, Cast, Anvil, and Chisel for comprehensive Ethereum development

### 02. Security in Smart Contract Development
- Solutions to Ethernaut challenges demonstrating security vulnerability understanding:
  - King (Level 9): Preventing malicious contract interactions
  - Elevator (Level 11): Interface manipulation and state control
  - Preservation (Level 16): Storage layout and delegate calls
  - Additional security implementations following best practices

### 03. Gas Optimization Techniques
- Implementation of gas-efficient smart contracts
- Practical examples of optimization patterns and techniques

### 04. Secure and Gas Optimised Contracts with Foundry
- Practical application of security principles and gas optimization techniques
- Implementation of secure and efficient contract patterns

### 05. Signatures and Advanced ERC-20 Standards
- Implementation of EIP-712 typed structured data signatures
- Advanced token functionalities beyond the basic ERC-20 standard

### 06. Merkle Trees and Advanced NFT Standards
- `CharityTournament.sol`: Efficient participant verification using Merkle trees
- JavaScript utilities for Merkle tree generation and proof validation
- Advanced NFT implementations with extended functionality

### 07. Advanced Token Contracts
- Implementation of tokens with advanced functionality
- Extensions of standard token interfaces with additional features

### 08. Upgradeability
- Implementation of transparent proxy pattern for contract upgradeability
- VotingLogicV1 and VotingLogicV2 demonstrating contract evolution
- Deployment scripts for both local and testnet environments

### 09. Oracles and External Data Feeds
- Integration with Chainlink VRF for verifiable randomness in NFT minting
- Implementation of price-feed oracles for financial applications
- `RandomisedNFT.sol`: NFT with randomized attributes using Chainlink VRF
- `StopLossVault.sol`: ETH vault with price-based withdrawal conditions

### 10. DeFi Applications
- Implementation of on-chain payroll system with USD/ETH conversion
- Factory pattern for deploying minimal proxy instances
- Integration with price feeds for real-time currency conversion

## Setup and Usage

### Prerequisites
- Node.js v22 and npm
- Foundry tools (forge, cast, anvil)

### Installation
```bash
# Clone the repository
git clone https://github.com/metodievmartin/blockchain-advanced-course-exercises.git

# Change to the project directory
cd blockchain-advanced-course-exercises

# Install dependencies
npm install

# Install Foundry submodules
forge install
```

### Environment Setup
Copy the example environment file and configure your variables:
```bash
cp .env.example .env
```

Required environment variables:
- `PRIVATE_KEY`: Your wallet's private key for deployments
- `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia testnet
- `ETHERSCAN_API_KEY`: For contract verification

### Running Tests
```bash
# Run all tests
npm test
# or
forge test
```

### Deployment Examples
```bash
# Deploy to local Anvil network
forge script script/exam-prep/DeployPayroll.s.sol --rpc-url anvil

# Deploy to Sepolia testnet
forge script script/exam-prep/DeployPayroll.s.sol --rpc-url sepolia --broadcast --verify
```

### Generating Pay Stubs Examples
```bash
# Generate for Sepolia testnet
npm run generate-pay-stub:sepolia

# Generate for local Anvil network
npm run generate-pay-stub:local
```