# Payroll System Deployment Guide

This guide provides step-by-step instructions for deploying the Payroll system on both local Anvil and Sepolia testnet environments.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- [Node.js](https://nodejs.org/) (v22 or higher) and npm installed
- Sepolia ETH for testnet deployment
- Etherscan API key (for contract verification on Sepolia)

## Environment Setup

1. Clone the repository and navigate to the project directory:

```bash
git clone <repository-url>
cd <project-directory>
```

2. Install dependencies:

```bash
forge install
npm install
```

3. Create a `.env` file (or copy from `.env.example`) in the project root with the following variables:

```env
# Required for Sepolia deployment
DIRECTOR_PRIVATE_KEY=0x...  # Private key of the director account
HR_MANAGER_PRIVATE_KEY=0x...  # Private key of the HR manager account
DIRECTOR_ADDRESS=0x...  # Public address of the director account
HR_MANAGER_ADDRESS=0x...  # Public address of the HR manager account
SEPOLIA_RPC_URL=https://sepolia...  # Sepolia RPC endpoint

# Optional for contract verification
ETHERSCAN_API_KEY=...
```

## Local Deployment (Anvil)

1. Start a local Anvil node in a separate terminal:

```bash
anvil
```

2. Deploy the contracts locally:

```bash
forge script script/exam-prep/DeployPayroll.s.sol --rpc-url anvil --broadcast
```

The deployment script will:
- Deploy the Payroll implementation contract
- Deploy the PayrollFactory contract
- Create a Payroll instance through the factory
- Fund the Payroll instance with 10 ETH for testing
- Deploy a MockV3Aggregator for price feed data

3. Note the deployed contract addresses from the console output:
   - Payroll implementation address
   - PayrollFactory address
   - Payroll instance address

## Sepolia Testnet Deployment

1. Make sure your `.env` file is properly configured with Sepolia accounts.

2. Deploy the contracts to Sepolia:

```bash
forge script script/exam-prep/DeployPayroll.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

3. Note the deployed contract addresses from the console output.

4. Fund the Payroll instance with ETH manually by sending ETH to the deployed Payroll instance address from the director's account.

### Contract Verification

If the `--verify` flag doesn't automatically verify your contracts, you can manually verify them using the following commands:

1. Verify the Payroll implementation contract:

```bash
forge verify-contract \
    --chain-id 11155111 \
    --compiler-version v0.8.28+commit.8e97066b \
    --watch \
    <PAYROLL_IMPLEMENTATION_ADDRESS> \
    src/exam-prep/Payroll.sol:Payroll
```

2. For the PayrollFactory contract, you need to provide the constructor arguments:

```bash
# First, generate the ABI-encoded constructor arguments
cast abi-encode "constructor(address,address)" <PAYROLL_IMPLEMENTATION_ADDRESS> <HR_MANAGER_ADDRESS>

# Then verify the contract with the constructor arguments
forge verify-contract \
    --chain-id 11155111 \
    --compiler-version v0.8.28+commit.8e97066b \
    --watch \
    --constructor-args <ENCODED_CONSTRUCTOR_ARGS> \
    <PAYROLL_FACTORY_ADDRESS> \
    src/exam-prep/PayrollFactory.sol:PayrollFactory
```

3. For the Payroll instance (clone), you don't need to verify it as it's a minimal proxy.

Example with your deployed contracts:

```bash
# Verify Payroll implementation
forge verify-contract \
    --chain-id 11155111 \
    --compiler-version v0.8.28+commit.8e97066b \
    --watch \
    0x1364636ce4a674374c294D9819E940AB8Cc4D14d \
    src/exam-prep/Payroll.sol:Payroll

# Generate constructor arguments for PayrollFactory
cast abi-encode "constructor(address,address)" \
    0x1364636ce4a674374c294D9819E940AB8Cc4D14d \
    0x4cd51E138D3cdF9f4E723F33DeF144D71E189b8E

# Verify PayrollFactory with constructor arguments
forge verify-contract \
    --chain-id 11155111 \
    --compiler-version v0.8.28+commit.8e97066b \
    --watch \
    --constructor-args 0x0000000000000000000000001364636ce4a674374c294d9819e940ab8cc4d14d0000000000000000000000004cd51e138d3cdf9f4e723f33def144d71e189b8e \
    0x7B02fC73F2148201095AADdfAc884212151A5075 \
    src/exam-prep/PayrollFactory.sol:PayrollFactory
```

Note: The Payroll instance at `0xA115aFAf44ab10A0E2a91E370affe6aFA312fD4e` is a minimal proxy clone and doesn't need separate verification.

## Generating Pay Stubs

The system includes a JavaScript utility for generating EIP-712 signatures for pay stubs. The script handles different configurations for local and Sepolia environments automatically.

### Key Differences Between Local and Sepolia Generation

| Feature | Local (Anvil) | Sepolia Testnet |
|---------|--------------|-----------------|
| Private Key | Uses hardcoded Anvil private key | Uses `DIRECTOR_PRIVATE_KEY` from `.env` file |
| Output File | `signature_local.json` | `signature.json` |
| Chain ID | 31337 | 11155111 |
| Employee Address | Fourth Anvil address by default | Configurable in the script |

### Using npm Commands

The project includes npm scripts for easy pay stub generation:

```bash
# Generate pay stub for local environment
npm run generate-pay-stub:local

# Generate pay stub for Sepolia environment
npm run generate-pay-stub:sepolia
```

### Manual Configuration

If you need to customize the pay stub generation:

1. Update the contract address in the script:
   - Open `src/exam-prep/js_scripts/generate-pay-stub.js`
   - Update the `verifyingContract` value in the appropriate configuration to match your deployed Payroll instance address
   - For Sepolia, update the `employeeAddress` to the address that will claim the salary

2. Run the script directly:

```bash
# For local testing
node src/exam-prep/js_scripts/generate-pay-stub.js local

# For Sepolia
node src/exam-prep/js_scripts/generate-pay-stub.js sepolia
```

3. The signature will be saved to:
   - Local: `src/exam-prep/js_scripts/signature_local.json`
   - Sepolia: `src/exam-prep/js_scripts/signature.json`

### Important Notes

- For Sepolia, ensure your `.env` file contains the `DIRECTOR_PRIVATE_KEY` variable
- The script automatically uses the appropriate private key based on the network
- The pay stub includes a fixed period (202505) and USD amount (1100 cents = $11.00) by default
- To modify these values, edit the `message` object in the `generateSignature` function

## Claiming Salaries

### Using Foundry Cast (CLI)

1. For local testing, use the following command to claim a salary:

```bash
cast send <PAYROLL_INSTANCE_ADDRESS> "claimSalary(uint256,uint256,bytes)" <PERIOD> <USD_AMOUNT> <SIGNATURE> --private-key <EMPLOYEE_PRIVATE_KEY> --rpc-url http://localhost:8545
```

Example:
```bash
cast send 0x75537828f2ce51be7289709686A69CbFDbB714F1 "claimSalary(uint256,uint256,bytes)" 202505 1100 0x22aec0a8b230a5eabf63324b05c47b9f186f3e6393f61cba966d48f6c39c266646ebe73d579eaa024ab681da4e97c360b3296c27c8c21540840e4304463f9c861c --private-key 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6 --rpc-url http://localhost:8545
```

2. For Sepolia, use a similar command but with the Sepolia RPC URL:

```bash
cast send <PAYROLL_INSTANCE_ADDRESS> "claimSalary(uint256,uint256,bytes)" <PERIOD> <USD_AMOUNT> <SIGNATURE> --private-key <EMPLOYEE_PRIVATE_KEY> --rpc-url $SEPOLIA_RPC_URL
```

### Using a Web Interface (Optional)

If you've built a web interface for the Payroll system:

1. Connect your wallet to the interface
2. Select the appropriate network (local or Sepolia)
3. Enter the pay stub details and signature
4. Submit the transaction to claim the salary

## Troubleshooting

### Common Errors

1. **InsufficientContractBalance (0x786e0a99)**
   - The Payroll contract doesn't have enough ETH to pay the requested amount
   - Solution: Fund the contract with more ETH from the director's account

2. **InvalidSignature (0x8baa579f)**
   - The provided signature doesn't match the pay stub data or wasn't signed by the director
   - Solution: Generate a new signature with the correct parameters

3. **PeriodAlreadyClaimed (0x67ff5197)**
   - The employee has already claimed their salary for this period
   - Solution: Use a different period for the next claim

4. **MockV3Aggregator Price Issues**
   - If the price feed is returning an incorrect value, update it:
   ```bash
   cast send <MOCK_PRICE_FEED_ADDRESS> "updateAnswer(int256)" 200000000000 --private-key <DIRECTOR_PRIVATE_KEY> --rpc-url http://localhost:8545
   ```

### Testing

Run the test suite to verify everything is working correctly:

```bash
forge test --match-path test/exam-prep/PayrollTest.t.sol -vv
```

## Environment Variables Reference

| Variable | Description | Required For |
|----------|-------------|-------------|
| `DIRECTOR_PRIVATE_KEY` | Private key of the director account | Sepolia deployment, Pay stub generation |
| `HR_MANAGER_PRIVATE_KEY` | Private key of the HR manager account | Sepolia deployment |
| `DIRECTOR_ADDRESS` | Public address of the director account | Sepolia deployment |
| `HR_MANAGER_ADDRESS` | Public address of the HR manager account | Sepolia deployment |
| `SEPOLIA_RPC_URL` | Sepolia RPC endpoint | Sepolia deployment |
| `ETHERSCAN_API_KEY` | API key for contract verification | Contract verification on Sepolia |

## Contract Architecture

The Payroll system consists of the following contracts:

1. **Payroll.sol**: The main contract that handles salary claims and signature verification
2. **PayrollFactory.sol**: Factory contract that creates new Payroll instances
3. **MockV3Aggregator.sol**: Mock price feed for local testing

The deployment process creates:
1. A Payroll implementation contract
2. A PayrollFactory contract (Minimal Proxy factory) that references the implementation
3. An initial Payroll instance (Clone) through the factory
