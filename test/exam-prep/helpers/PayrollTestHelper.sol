// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title PayrollTestHelper
 * @dev Helper contract for Payroll tests that handles EIP-712 signature generation
 */
contract PayrollTestHelper is Test {
    // Type hash constants
    bytes32 public constant PAY_STUB_TYPE_HASH = keccak256("PayStub(address employee,uint256 period,uint256 usdAmount)");
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    
    // Domain separator values
    string public name;
    string public version;
    address public verifyingContract;
    
    /**
     * @dev Constructor that initializes the domain parameters
     * @param _name The name of the signing domain
     * @param _version The version of the signing domain
     * @param _verifyingContract The address of the contract that will verify the signature
     */
    constructor(string memory _name, string memory _version, address _verifyingContract) {
        name = _name;
        version = _version;
        verifyingContract = _verifyingContract;
    }
    
    /**
     * @dev Computes the domain separator used in the encoding of the signature
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                verifyingContract
            )
        );
    }
    
    /**
     * @dev Returns the hash of the fully encoded EIP-712 message for the domain, which can be used to recover the signer
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash));
    }

    /**
     * @dev Signs a pay stub using the provided private key
     * @param privateKey The private key to sign with
     * @param employee The employee address
     * @param period The pay period
     * @param usdAmount The USD amount in cents
     * @return The signature bytes
     */
    function signPayStub(uint256 privateKey, address employee, uint256 period, uint256 usdAmount)
        public
        view
        returns (bytes memory)
    {
        // Create the struct hash
        bytes32 structHash = keccak256(abi.encode(PAY_STUB_TYPE_HASH, employee, period, usdAmount));

        // Get the digest using EIP712 helper
        bytes32 digest = _hashTypedDataV4(structHash);

        // Sign the digest with the private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Return the signature in the format expected by the contract
        return abi.encodePacked(r, s, v);
    }

    /**
     * @dev Verifies a pay stub signature
     * @param employee The employee address
     * @param period The pay period
     * @param usdAmount The USD amount in cents
     * @param signature The signature to verify
     * @param expectedSigner The expected signer address
     * @return True if signature is valid, false otherwise
     */
    function verifySignature(
        address employee,
        uint256 period,
        uint256 usdAmount,
        bytes memory signature,
        address expectedSigner
    ) public view returns (bool) {
        bytes32 structHash = keccak256(abi.encode(PAY_STUB_TYPE_HASH, employee, period, usdAmount));

        bytes32 digest = _hashTypedDataV4(structHash);
        address recoveredSigner = ECDSA.recover(digest, signature);

        return recoveredSigner == expectedSigner;
    }
}
