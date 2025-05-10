// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Preservation {
    // public library contracts
    address public timeZone1Library;
    address public timeZone2Library;
    address public owner;
    uint256 storedTime;
    // Sets the function signature for delegatecall
    bytes4 constant setTimeSignature = bytes4(keccak256("setTime(uint256)"));

    constructor(address _timeZone1LibraryAddress, address _timeZone2LibraryAddress) {
        timeZone1Library = _timeZone1LibraryAddress;
        timeZone2Library = _timeZone2LibraryAddress;
        owner = msg.sender;
    }

    // set the time for timezone 1
    function setFirstTime(uint256 _timeStamp) public {
        // ⚠️ Vulnerability: delegatecall executes code in the context of the caller contract.
        // If the delegatecall target is malicious or changed to malicious, it can overwrite Preservation's storage.
        timeZone1Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }

    // set the time for timezone 2
    function setSecondTime(uint256 _timeStamp) public {
        timeZone2Library.delegatecall(abi.encodePacked(setTimeSignature, _timeStamp));
    }
}

/**
 * ⚠️ SECURITY FLAW:
 *
 * This LibraryContract is designed to update a timestamp (`storedTime`) using `delegatecall`.
 * However, it only has one variable at slot 0, while the caller contract (Preservation)
 * expects this call to affect a variable at slot 3 (`storedTime` in Preservation).
 *
 * Because delegatecall reuses the caller's storage:
 * - The write to slot 0 here will overwrite `Preservation.timeZone1Library`
 * - This opens the door for the attacker to inject a malicious contract
 *   into Preservation via a crafted uint256 cast from an address.
 *
 * This highlights the critical requirement: when using delegatecall,
 * the storage layouts **must match exactly** between the calling and target contracts,
 * otherwise you get unpredictable and exploitable behaviour.
 */
contract LibraryContract {
    // stores a timestamp
    // Should match the storage layout of the Preservation contract but it doesn't!
    uint256 storedTime;

    function setTime(uint256 _time) public {
        // Security Issue:
        // This line writes to slot 0 in the caller’s storage — not LibraryContract’s.
        // When called via `delegatecall` from the Preservation contract,
        // this assignment affects whatever variable happens to be at slot 0 in Preservation,
        // which is: `timeZone1Library`.
        storedTime = _time;
    }
}
