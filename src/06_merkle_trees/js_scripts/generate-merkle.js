import { writeFileSync } from "fs";
import keccak256 from "keccak256";
import { MerkleTree } from "merkletreejs";

const participants = [
  "0x1234567890123456789012345678901234567890", // 1. Alice
  "0x2345678901234567890123456789012345678901", // 2. Bob
  "0x3456789012345678901234567890123456789012", // 3. Charlie
  "0xABCDEF0123456789ABCDEF0123456789ABCDEF01", // 4. Diana
  "0xabcdef0123456789abcdef0123456789abcdef01", // 5. Edward
  "0x4567890123456789012345678901234567890123", // 6. Fiona
  "0x5678901234567890123456789012345678901234", // 7. George
  "0x6789012345678901234567890123456789012345", // 8. Hannah
  "0x7890123456789012345678901234567890123456", // 9. Ivan
  "0x8901234567890123456789012345678901234567", // 10. Julia
  "0x9012345678901234567890123456789012345678", // 11. Kyle
  "0x0123456789012345678901234567890123456789", // 12. Laura
];

/* ============================================================================================== */
/*                                         HASH LEAF NODES                                        */
/* ============================================================================================== */

console.log("✅ 1 >>> Hash leaf nodes for participants\n");
console.log(`Total participants: ${participants.length}`);

const leaves = participants.map((participantAddress) => {
  console.log(`Hashing address: ${participantAddress}`);
  return hashLeaf(participantAddress);
});

/* ============================================================================================== */
/*                                       CREATE MERKLE TREE                                       */
/* ============================================================================================== */

console.log("\n✅ 2 >>> Create Merkle Tree");
const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });

const root = tree.getHexRoot();
console.log("\nMerkle Root:", root);
console.log("\nTree structure:");
console.log(tree.toString());

/* ============================================================================================== */
/*                                          MERKLE PROOFS                                         */
/* ============================================================================================== */

console.log("\n✅ 3 >>> Generate and display proof for each participant");
const proofs = {};

participants.forEach((participant) => {
  const leaf = hashLeaf(participant);
  const proof = tree.getProof(leaf).map((x) => "0x" + x.data.toString("hex"));
  proofs[participant] = { proof };

  console.log(`\nAddress: ${participant}`);
  console.log(`Proof: ${JSON.stringify(proof, null, 2)}`);

  const isValid = tree.verify(proof, leaf, root);
  console.log(`Proof is valid: ${isValid}`);
});

/* ============================================================================================== */
/*                                            SAVE TREE                                           */
/* ============================================================================================== */

console.log("\n✅ 4 >>> Save proofs and root to file");
const output = {
  merkleRoot: root,
  proofs,
  participants,
  timestamp: new Date().toISOString(),
  description: "Charity Tournament Participants Merkle Tree Data",
};
writeFileSync(
  "./src/06_merkle_trees/data/merkle_data.json",
  JSON.stringify(output, null, 2)
);
console.log("\nMerkle data saved to merkle_data.json\n\n");

/* ============================================================================================== */
/*                                             HELPERS                                            */
/* ============================================================================================== */

function hashLeaf(address) {
  // Remove the ` 0x ` prefix and convert to lowercase for consistency
  const addressBuffer = Buffer.from(address.slice(2).toLowerCase(), "hex");
  return keccak256(addressBuffer);
}