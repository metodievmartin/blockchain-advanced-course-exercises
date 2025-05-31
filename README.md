# Blockchain Advanced Course Exercises

This repository contains practical exercises and projects completed during the SoftUni Blockchain Advanced Course. 
Each directory represents a different topic covered in the course, 
demonstrating implementations of advanced blockchain development concepts.

The corresponding course materials and labs can be found in this repository: [blockchain-advanced-course](https://github.com/metodievmartin/blockchain-advanced-course)

> **Disclaimer**: These implementations are primarily for educational purposes. Many contracts are intentionally simplified to focus on specific learning objectives and concepts being taught in each module. They may not include all the security features or optimizations that would be required in production-ready code.

## Course Topics

### 01. Foundry Toolchain
- Implementation of smart contracts using Foundry's powerful development environment
- Utilization of Forge, Cast, Anvil, and Chisel for comprehensive Ethereum development

### 02. Security in Smart Contract Development
- Solutions to Ethernaut challenges demonstrating security vulnerability understanding:
  - King (Level 9): Preventing malicious contract interactions
  - Elevator (Level 11): Interface manipulation and state control
  - Preservation (Level 16): Storage layout and delegate calls
- Implementation of security best practices for smart contract development
- Examples of common vulnerability mitigations
- Additional security implementations following best practices

### 03. Gas Optimization Techniques
- Implementation of gas-efficient smart contracts
- Practical examples of optimization patterns and techniques

### 04. Secure and Gas Optimised Contracts with Foundry
- Practical application of security principles and gas optimization techniques
- Implementation of secure and efficient contract patterns

### 05. Signatures and Advanced ERC-20 Standards
- Implementation of EIP-712 typed structured data signatures
- Demonstration of cryptographic signature verification
- Advanced token functionalities beyond the basic ERC-20 standard
- Permit functionality implementation (ERC-2612)

### 06. Merkle Trees and Advanced NFT Standards
- `CharityTournament.sol`: Efficient participant verification using Merkle trees
- JavaScript utilities for Merkle tree generation and proof validation
- Advanced NFT implementations with extended functionality
- Implementation of allowlist verification using Merkle proofs

### 07. Advanced Token Contracts
- Implementation of tokens with advanced functionality
- Extensions of standard token interfaces with additional features

### 08. Upgradeability
- Implementation of transparent proxy pattern for contract upgradeability
- VotingLogicV1 and VotingLogicV2 demonstrating contract evolution
- Deployment scripts for both local and testnet environments
- Initializable contracts with OpenZeppelin's upgradeable contracts

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
# Clone the repository (HTTPS)
git clone https://github.com/metodievmartin/blockchain-advanced-course-exercises.git
# OR clone via SSH
git clone git@github.com:metodievmartin/blockchain-advanced-course-exercises.git

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
- `PRIVATE_KEY`: Your wallet's private key for general deployments
- `SEPOLIA_RPC_URL`: RPC endpoint for Sepolia testnet
- `ETHERSCAN_API_KEY`: For contract verification
- `PROXY_ADDRESS`: Address of the deployed proxy contract (for upgrades)

Additional variables for Payroll System:
- `DIRECTOR_PRIVATE_KEY`: Private key of the director account (who signs pay stubs)
- `DIRECTOR_ADDRESS`: Public address of the director account
- `HR_MANAGER_PRIVATE_KEY`: Private key of the HR manager account (who creates Payroll instances)
- `HR_MANAGER_ADDRESS`: Public address of the HR manager account

### Running Tests
```bash
# Run all tests
npm test
# or
forge test

# Run tests with more verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/exam-prep/Payroll.t.sol

# Run tests with gas reports
forge test --gas-report
```

### Deployment Examples

#### Local Deployment
```bash
# Deploy to local Anvil network
forge script script/exam-prep/DeployPayroll.s.sol --rpc-url anvil
```

#### Testnet Deployment
```bash
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

## Project Structure

```
blockchain-advanced-course-exercises/
├── script/                 # Foundry deployment scripts
│   ├── 08_upgradeability/    # Upgradeability scripts
│   └── exam-prep/            # Exam preparation deployment scripts
├── src/                    # Foundry smart contract source code
│   ├── 01_foundry/           # Foundry basics
│   ├── 02_security/          # Security patterns and Ethernaut solutions
│   ├── 03_gas_optimisation/  # Gas optimization techniques
│   ├── 05_signatures/        # Cryptographic signatures
│   ├── 06_merkle_trees/      # Merkle tree implementations
│   ├── 08_upgradeability/    # Upgradeability patterns
│   ├── 09_oracles/           # Oracle integrations
│   └── 10_defi/              # DeFi implementations
├── test/                   # Foundry test files
│   ├── 02_security/          # Security tests
│   ├── 06_merkle_trees/      # Merkle tree tests
│   ├── 08_upgradeability/    # Upgradeability tests
│   ├── 09_oracles/           # Oracle tests
│   └── exam-prep/            # Exam preparation tests
├── deployments/            # JSON files with deployed contract addresses by networkand metadata
└── js_scripts/             # JavaScript utilities
    └── exam-prep/            # Pay stub generation scripts