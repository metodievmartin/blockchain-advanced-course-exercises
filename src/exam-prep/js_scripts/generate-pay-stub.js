import { ethers } from "ethers";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";

dotenv.config();

// Parse command line arguments
const args = process.argv.slice(2);
const network = args[0] || "sepolia"; // Default to sepolia if no argument provided

// Define the output directory (same as the script)
const __filename = fileURLToPath(import.meta.url);
const scriptDir = path.dirname(__filename);

// Network-specific configurations
const networkConfig = {
  sepolia: {
    chainId: 11155111,
    verifyingContract: "0xA115aFAf44ab10A0E2a91E370affe6aFA312fD4e", // Deployed Payroll instance address
    outputFile: "signature.json",
    employeeAddress: "0x4cd51E138D3cdF9f4E723F33DeF144D71E189b8E" // Your Sepolia address
  },
  local: {
    chainId: 31337,
    verifyingContract: "0x75537828f2ce51be7289709686A69CbFDbB714F1", // Replace it with your local contract address
    outputFile: "signature_local.json",
    employeeAddress: "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720" // Fourth Anvil address (index 3)
  }
};

// Get the configuration for the selected network
const config = networkConfig[network];
if (!config) {
  console.error(`Error: Unknown network '${network}'. Use 'sepolia' or 'local'.`);
  process.exit(1);
}

// EIP-712 domain separator
const domain = {
  name: "Payroll IT",
  version: "1",
  chainId: config.chainId,
  verifyingContract: config.verifyingContract,
};

// EIP-712 types
const types = {
  PayStub: [
    { name: "employee", type: "address" },
    { name: "period", type: "uint256" },
    { name: "usdAmount", type: "uint256" },
  ],
};

async function generateSignature() {
  // Get private key from environment variable or .env file
  let privateKey;
  
  if (network === "local") {
    // For local testing, we can use a hardcoded private key (Anvil's first account)
    // First Anvil account is the Director
    privateKey = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80";
    console.log("Using local Anvil private key");
  } else {
    // For Sepolia, use the private key from environment variable
    privateKey = process.env.DIRECTOR_PRIVATE_KEY;
    if (!privateKey) {
      console.error("Error: DIRECTOR_PRIVATE_KEY environment variable is not set.");
      console.error("Please set it in your .env file or export it in your terminal.");
      process.exit(1);
    }

    // Check if the private key starts with "0x" and remove it if present
    if (privateKey.startsWith("0x")) {
      privateKey = privateKey.slice(2);
    }

    console.log("Using Sepolia private key from environment variable");
  }

  // Create a wallet with the private key
  const wallet = new ethers.Wallet(privateKey);
  console.log(`Wallet address: ${wallet.address}`);
  console.log(`Network: ${network}`);
  console.log(`Chain ID: ${config.chainId}`);
  console.log(`Verifying contract address: ${config.verifyingContract}`);
  console.log(`Employee address: ${config.employeeAddress}`);

  // Create the message to sign
  const message = {
    employee: config.employeeAddress,
    period: 202505,
    usdAmount: "1100", // 11 USD (in cents)
  };

  // Sign the message
  const signature = await wallet.signTypedData(domain, types, message);

  // Create the signature object with stringified BigInt values
  const signatureData = {
    signature,
    message: {
      employee: message.employee,
      period: message.period.toString(),
      usdAmount: message.usdAmount.toString(),
    },
    domain: {
      name: domain.name,
      version: domain.version,
      chainId: domain.chainId,
      verifyingContract: domain.verifyingContract
    }
  };

  // Create full path for the output file
  const outputPath = path.join(scriptDir, config.outputFile);
  
  // Save signature to a file
  fs.writeFileSync(outputPath, JSON.stringify(signatureData, null, 2));

  console.log(`Signature generated and saved to ${outputPath}`);
  console.log(`Signature: ${signature}`);
}

generateSignature().catch(console.error);