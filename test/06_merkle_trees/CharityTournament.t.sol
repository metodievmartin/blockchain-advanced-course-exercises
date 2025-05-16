// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";

import {CharityTournament} from "@/06_merkle_trees/CharityTournament.sol";

contract CharityTournamentTest is Test {
    uint256 private constant ORGANIZER_PRIVATE_KEY = 0x1;

    CharityTournament public tournament;

    address public organizer;
    // From merkle-tree.js
    address public alice = 0x1234567890123456789012345678901234567890;
    address public bob = 0x2345678901234567890123456789012345678901;
    address public charlie = 0x3456789012345678901234567890123456789012;
    address public nonParticipant;

    bytes32 public merkleRoot;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;
    bytes32[] public charlieProof;

    /* ============================================================================================== */
    /*                                              SETUP                                             */
    /* ============================================================================================== */

    function setUp() public {
        organizer = vm.addr(ORGANIZER_PRIVATE_KEY);
        nonParticipant = makeAddr("nonParticipant");

        vm.deal(organizer, 100 ether);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);

        _setupMerkleTree();

        vm.prank(organizer);
        tournament = new CharityTournament(merkleRoot);
    }

    /* ============================================================================================== */
    /*                                    CONSTRUCTOR & ADMIN TESTS                                   */
    /* ============================================================================================== */

    function test_InitialState() public view {
        assertEq(tournament.TOURNAMENT_NAME(), "Charity Tournament");
        assertEq(tournament.TOURNAMENT_TIMESTAMP(), 1717776000);
        assertEq(tournament.owner(), organizer);
        assertEq(tournament.merkleRoot(), merkleRoot);
    }

    function test_UpdateMerkleRoot() public {
        bytes32 newRoot = bytes32(uint256(0x12345));

        // 1. Only the owner can update the root
        vm.prank(alice);
        vm.expectRevert();
        tournament.updateMerkleRoot(newRoot);

        // 2. Owner can update the root
        vm.prank(organizer);
        tournament.updateMerkleRoot(newRoot);

        assertEq(tournament.merkleRoot(), newRoot);
    }

    function test_EmitEvent() public {
        bytes32 newRoot = bytes32(uint256(0x12345));

        vm.startPrank(organizer);
        vm.expectEmit(true, true, false, false);
        emit CharityTournament.MerkleRootUpdated(merkleRoot, newRoot);
        tournament.updateMerkleRoot(newRoot);
        vm.stopPrank();
    }

    /* ============================================================================================== */
    /*                                    CHECK PARTICIPATION TESTS                                   */
    /* ============================================================================================== */

    function test_Participants() public view {
        bool isValid;

        // 1. Test Alice's participation
        isValid = tournament.isParticipant(alice, aliceProof);
        assertTrue(isValid);

        // 2. Test Bob's participation
        isValid = tournament.isParticipant(bob, bobProof);
        assertTrue(isValid);

        // 3. Test Charlie's participation
        isValid = tournament.isParticipant(charlie, charlieProof);
        assertTrue(isValid);
    }

    function test_NonParticipant() public view {
        bool isValid = tournament.isParticipant(nonParticipant, new bytes32[](0));
        assertFalse(isValid);
    }

    function test_WrongProof() public view {
        // 1. Using Bob's proof for Alice
        bool isValid = tournament.isParticipant(alice, bobProof);
        assertFalse(isValid);

        // 2. Using Alice's proof for Bob
        isValid = tournament.isParticipant(bob, aliceProof);
        assertFalse(isValid);
    }

    function test_EmptyProofForParticipant() public view {
        bool isValid = tournament.isParticipant(alice, new bytes32[](0));
        assertFalse(isValid);
    }

    function test_ZeroAddress() public view {
        address zeroAddr = address(0);
        bool isValid = tournament.isParticipant(zeroAddr, new bytes32[](0));
        assertFalse(isValid);
    }

    function test_ReusedProofForNonIncludedAddress() public view {
        // Using Alice's proof for a fake address
        address fakeAddr = 0xdEADBEeF00000000000000000000000000000000;
        bool isValid = tournament.isParticipant(fakeAddr, aliceProof);
        assertFalse(isValid);
    }

    function test_ProofFailsWithWrongRoot() public {
        bytes32 wrongRoot = bytes32(uint256(0x999));
        vm.prank(organizer);
        tournament.updateMerkleRoot(wrongRoot);

        bool isValid = tournament.isParticipant(alice, aliceProof);
        assertFalse(isValid);
    }

    /* ============================================================================================== */
    /*                                             HELPERS                                            */
    /* ============================================================================================== */

    function _setupMerkleTree() internal {
        merkleRoot = 0x02429ce60a5b78e1eea0fc7cd273d6dea15505907d521c589f9320f8889dacec;

        // Alice (0x1234567890123456789012345678901234567890) proof
        aliceProof = new bytes32[](4);
        aliceProof[0] = 0xc9f81d534037cca28de7d2aa8c62e5d6b75d5b58ccc4a265138671179cc4d447;
        aliceProof[1] = 0x3e560d33989b114bae69b54b66e16013d76b5315010a82f581a32ecc27aed872;
        aliceProof[2] = 0x333a086565308a91d326fcbb9e0bfdb187054aae01f4346f32974ffa9aa72553;
        aliceProof[3] = 0x842e21f36d0bd7ae16cbf275cf87ad79d030eacd933bb02b4d017da9b8d3a76d;

        // Bob (0x2345678901234567890123456789012345678901) proof
        bobProof = new bytes32[](4);
        bobProof[0] = 0xb6979620706f8c652cfb6bf6e923f5156eadd5abaf4022a0b19d52ada089475f;
        bobProof[1] = 0x3e560d33989b114bae69b54b66e16013d76b5315010a82f581a32ecc27aed872;
        bobProof[2] = 0x333a086565308a91d326fcbb9e0bfdb187054aae01f4346f32974ffa9aa72553;
        bobProof[3] = 0x842e21f36d0bd7ae16cbf275cf87ad79d030eacd933bb02b4d017da9b8d3a76d;

        // Charlie (0x3456789012345678901234567890123456789012) proof
        charlieProof = new bytes32[](4);
        charlieProof[0] = 0x90a01d80e0e12c0b6acd5e4a69eec3dafeb108be3340405e3264b567330b5ba0;
        charlieProof[1] = 0x9e5273f2eb51774b292c9f9b627bf68a75dae28e7abeae482020e84d6ed2c79c;
        charlieProof[2] = 0x333a086565308a91d326fcbb9e0bfdb187054aae01f4346f32974ffa9aa72553;
        charlieProof[3] = 0x842e21f36d0bd7ae16cbf275cf87ad79d030eacd933bb02b4d017da9b8d3a76d;
    }
}
