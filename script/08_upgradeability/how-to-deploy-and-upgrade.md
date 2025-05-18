# Transparent Proxy Deployment and Upgrade Guide

This guide explains how to deploy and upgrade the VotingLogic contracts using the transparent proxy pattern.

## Prerequisites

1. Set up environment variables in a `.env` file:
```
PRIVATE_KEY=your_private_key_here
PROXY_ADDRESS=proxy_address_from_previous_deployment
ETHERSCAN_API_KEY=your_etherscan_api_key_here
RPC_URL_SEPOLIA=your_sepolia_rpc_url_here
```

2. Make sure you have the required dependencies:
```bash
forge install OpenZeppelin/openzeppelin-contracts-upgradeable
forge install OpenZeppelin/openzeppelin-contracts
forge install OpenZeppelin/openzeppelin-foundry-upgrades
```

## Deployment Process

### Local Deployment with Anvil

1. Start a local Anvil node in a separate terminal:

```bash
# Start Anvil with a specific private key for deterministic addresses
anvil --chain-id 1337 --mnemonic "test test test test test test test test test test test junk"
```

2. Deploy to the local network:

```bash
# Create deployments directory if it doesn't exist
mkdir -p deployments

# Deploy to local Anvil node
forge script script/08_upgradeability/DeployVotingV1.s.sol:DeployVotingV1Script \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

3. Upgrade to V2 on the local network:

```bash
# Set the proxy address from the previous deployment
export PROXY_ADDRESS=<proxy_address_from_previous_deployment>

# Or set it in .env and then load it
source .env

# Upgrade to V2
forge script script/08_upgradeability/UpgradeToVotingV2.s.sol:UpgradeToVotingV2Script \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast \
  -vvvv
```

4. Interact with your contracts locally:

> NOTE: Adding the return type to the function signature will parse the return value automatically

```bash
# Create a proposal
cast send $PROXY_ADDRESS "createProposal(string) (uint256)" "My Proposal" \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545
  
# Get proposal
cast call $PROXY_ADDRESS "proposals(uint256)(uint256,address,string,uint256,uint256,bool)" 1 \
--rpc-url http://localhost:8545

# Vote on a proposal
cast send $PROXY_ADDRESS "vote(uint256,bool)" 1 true \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --rpc-url http://localhost:8545
  
# Check the current quorum - in V2 only
cast call $PROXY_ADDRESS "quorum() (uint256)" \
  --rpc-url http://localhost:8545

# Check if a proposal can be executed (after upgrade to V2)
cast call $PROXY_ADDRESS "execute(uint256) (bool)" 1 \
  --rpc-url http://localhost:8545
```

### Sepolia Testnet Deployment

Deploy the initial implementation and proxy:

```bash
# Create deployments directory if it doesn't exist
mkdir -p deployments

# Load environment variables
source .env

# Deploy to Sepolia
forge script script/08_upgradeability/DeployVotingV1.s.sol:DeployVotingV1Script \
  --rpc-url $RPC_URL_SEPOLIA \
  --broadcast \
  --verify \
  -vvvv
```

This will:
- Deploy the implementation contract (VotingLogicV1)
- Deploy the proxy admin contract
- Deploy the transparent proxy
- Initialize the proxy with the implementation
- Save deployment information to `deployments/voting_v1_deployment.txt`

### Upgrading to VotingLogicV2

After the initial deployment, you can upgrade to VotingLogicV2:

```bash
# Load environment variables and set the proxy address
source .env
export PROXY_ADDRESS=<proxy_address_from_previous_deployment>

# Upgrade to V2
forge script script/08_upgradeability/UpgradeToVotingV2.s.sol:UpgradeToVotingV2Script \
  --rpc-url $RPC_URL_SEPOLIA \
  --broadcast \
  --verify \
  -vvvv
```

This will:
- Deploy the new implementation contract (VotingLogicV2)
- Upgrade the proxy to point to the new implementation
- Save upgrade information to `deployments/voting_v2_upgrade.txt`

## Verification on Etherscan

The `--verify` flag in the forge script command will automatically verify your contracts on Etherscan if you've provided a valid `ETHERSCAN_API_KEY`.

If you need to verify manually:

```bash
forge verify-contract <implementation_address> src/08_upgradeability/VotingLogicV1.sol:VotingLogicV1 \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY

forge verify-contract <implementation_address_v2> src/08_upgradeability/VotingLogicV2.sol:VotingLogicV2 \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Interacting with the Deployed Contracts

You can interact with your deployed contracts through the proxy address:

```bash
# Create a proposal
cast send $PROXY_ADDRESS "createProposal(string)" "My Proposal" \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_SEPOLIA

# Vote on a proposal
cast send $PROXY_ADDRESS "vote(uint256,bool)" 1 true \
  --private-key $PRIVATE_KEY \
  --rpc-url $RPC_URL_SEPOLIA

# Check if a proposal can be executed (after upgrade to V2)
cast call $PROXY_ADDRESS "execute(uint256)" 1 \
  --rpc-url $RPC_URL_SEPOLIA
```

## Notes on Transparent Proxy Pattern

- The proxy delegates all calls to the implementation contract
- The proxy admin can upgrade the implementation
- Storage layout must be preserved between upgrades
- Function selectors are handled by the proxy to avoid selector clashes
