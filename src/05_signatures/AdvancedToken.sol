// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

error InvalidSignature();
error AuthorizationNotYetValid();
error AuthorizationExpired();
error AuthorizationAlreadyUsed();

/**
 * @title AdvancedToken
 * @dev This contract demonstrates advanced ERC20 functionality with signature-based approvals
 *
 * SIGNATURE STANDARDS OVERVIEW:
 * 1. ERC-2612 (Permit): Allows approvals via signatures instead of requiring a separate approve transaction
 * 2. ERC-3009: Enables transferring tokens with a signature, without the sender needing to submit the transaction
 *
 * These standards solve a common UX problem in ERC20 tokens: requiring two transactions for a transfer
 * from a new address (first approve, then transferFrom).
 */
contract AdvancedToken is ERC20Permit {
    /**
     * @notice Mapping of authorization hash => used status
     *  @dev Prevents replay attacks by tracking which authorizations have been used
     */
    mapping(bytes32 => bool) public authorizationState;

    event AuthorizationUsed(address indexed from, bytes32 indexed nonce);

    /**
     * @notice EIP-712 typehash for `TransferWithAuthorization`
     * @dev keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
     *
     * EIP-712 EXPLANATION:
     * - Provides a standard way for signing and verifying typed structured data (not just messages)
     * - The typehash is a unique identifier for the function's parameter structure
     * - This enables wallets to display human-readable data for users to verify before signing
     * - The domain separator (implemented in EIP712 base) prevents cross-contract replay attacks
     */
    bytes32 public constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    constructor(string memory name_, string memory symbol_, uint256 initialSupply)
        ERC20(name_, symbol_)
        ERC20Permit(name_) // ERC20Permit constructor requires the token name for the domain separator
    {
        _mint(msg.sender, initialSupply);
    }

    /**
     * @notice Execute a transfer with a signed authorization
     * @dev Implements ERC-3009 standard for gasless token transfers
     *
     * SIGNATURE VERIFICATION PROCESS:
     * 1. Compute the EIP-712 structured data hash using the typehash and parameters
     * 2. Create the message hash using _hashTypedDataV4 (includes domain separator)
     * 3. Recover the signer's address from the signature components (v, r, s)
     * 4. Verify the signer is the 'from' address
     *
     * SECURITY MEASURES:
     * - Time-bound validity window (validAfter, validBefore)
     * - Unique nonce to prevent replay attacks
     * - Authorization tracking to prevent reuse
     * - Signature verification to ensure authenticity
     *
     * This allows users to sign messages off-chain and have others submit the transaction,
     * paying for gas - enabling "gasless" transactions for the token holder.
     */
    function transferWithAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Compute the authorization hash upfront
        bytes32 authorizationHash = _requireValidAuthorization(from, to, value, validAfter, validBefore, nonce);
        if (authorizationState[authorizationHash]) revert AuthorizationAlreadyUsed();

        // Time-bound validity checks
        if (block.timestamp < validAfter) revert AuthorizationNotYetValid();
        if (block.timestamp > validBefore) revert AuthorizationExpired();

        // EIP-712 signature verification
        // 1. Create the struct hash using the typehash and parameters
        bytes32 structHash =
            keccak256(abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce));

        // 2. Create the EIP-712 message hash (includes domain separator from EIP712 base)
        bytes32 messageHash = _hashTypedDataV4(structHash);

        // 3. Recover the signer's address from the signature components
        address signer = ECDSA.recover(messageHash, v, r, s);

        // 4. Verify the signer is the 'from' address
        if (signer != from) {
            revert InvalidSignature();
        }

        // Mark this authorization as used to prevent replay attacks
        authorizationState[authorizationHash] = true;
        emit AuthorizationUsed(from, nonce);

        // Execute the transfer if all checks pass
        _transfer(from, to, value);
    }

    /**
     * @notice Compute the authorization hash for a transfer
     * @dev This hash uniquely identifies the authorization parameters
     *
     * IMPORTANT: This is different from the EIP-712 hash. This is a simple hash
     * of the parameters used as a key in the authorizationState mapping to track
     * which authorizations have been used.
     *
     * The EIP-712 hash (used for signature verification) follows the EIP-712 standard
     * which includes typehashes and domain separators for enhanced security.
     */
    function _requireValidAuthorization(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(from, to, value, validAfter, validBefore, nonce));
    }
}
