// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {AdvancedToken} from "@/05_signatures/AdvancedToken.sol";
import {
    InvalidSignature,
    AuthorizationNotYetValid,
    AuthorizationExpired,
    AuthorizationAlreadyUsed
} from "@/05_signatures/AdvancedToken.sol";

/**
 * @notice Tests for `AdvancedToken`
 */
contract AdvancedTokenTest is Test {
    /* ============================================================================================== */
    /*                                            CONSTANTS                                           */
    /* ============================================================================================== */

    uint256 private constant ALICE_PRIVATE_KEY = 0xA11CE;

    uint256 private constant INITIAL_SUPPLY = 1_000_000 * 1e18;

    uint256 private constant ALICE_ALLOCATION = 100_000 * 1e18;

    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /**
     * @notice EIP-712 typehash for `TransferWithAuthorization`
     * @dev keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
     */
    bytes32 private constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH =
        0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    /* ============================================================================================== */
    /*                                         STATE VARIABLES                                        */
    /* ============================================================================================== */

    AdvancedToken public token;

    address public deployer;
    address public alice;
    address public bob;

    /* ============================================================================================== */
    /*                                              SETUP                                             */
    /* ============================================================================================== */

    function setUp() public {
        deployer = address(this);

        alice = vm.addr(ALICE_PRIVATE_KEY);
        bob = makeAddr("bob");

        vm.deal(alice, 100 ether);

        token = new AdvancedToken("Advanced Token", "ADV", INITIAL_SUPPLY);

        token.transfer(alice, ALICE_ALLOCATION);
    }

    /* ============================================================================================== */
    /*                                 ERC-20 STANDARD FUNCTIONALITIES                                */
    /* ============================================================================================== */

    function test_ERC20Functionality() public {
        // 1. Verify token metadata
        assertEq(token.name(), "Advanced Token");
        assertEq(token.symbol(), "ADV");
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), INITIAL_SUPPLY);

        // 2. Verify initial token distribution
        assertEq(token.balanceOf(deployer), INITIAL_SUPPLY - ALICE_ALLOCATION);
        assertEq(token.balanceOf(alice), ALICE_ALLOCATION);

        // 3. Test transfer functionality
        uint256 transferAmount = 10_000 * 1e18;
        vm.prank(alice);
        token.transfer(bob, transferAmount);

        assertEq(token.balanceOf(alice), ALICE_ALLOCATION - transferAmount);
        assertEq(token.balanceOf(bob), transferAmount);

        // 4. Test approve and transferFrom functionality
        uint256 approvalAmount = 20_000 * 1e18;
        vm.prank(alice);
        token.approve(bob, approvalAmount);
        assertEq(token.allowance(alice, bob), approvalAmount);

        uint256 spendAmount = 5_000 * 1e18;
        vm.prank(bob);
        token.transferFrom(alice, bob, spendAmount);

        // 5. Verify balances and remaining allowance
        assertEq(token.balanceOf(alice), ALICE_ALLOCATION - transferAmount - spendAmount);
        assertEq(token.balanceOf(bob), transferAmount + spendAmount);
        assertEq(token.allowance(alice, bob), approvalAmount - spendAmount);
    }

    /* ============================================================================================== */
    /*                                 ERC-2612 PERMIT FUNCTIONALITIES                                */
    /* ============================================================================================== */

    function test_Permit() public {
        uint256 permitValue = 1_000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 aliceNonce = token.nonces(alice);

        // 1. Generate EIP-712 digest for permit
        bytes32 digest = _getPermitDigest(alice, bob, permitValue, aliceNonce, deadline);

        // 2. Sign the digest with alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);

        // 3. Execute permit function
        token.permit(alice, bob, permitValue, deadline, v, r, s);

        // 4. Verify permit result
        assertEq(token.allowance(alice, bob), permitValue);
        assertEq(token.nonces(alice), aliceNonce + 1);

        // 5. Verify approved tokens can be spent
        vm.prank(bob);
        token.transferFrom(alice, bob, permitValue);
        assertEq(token.balanceOf(alice), ALICE_ALLOCATION - permitValue);
        assertEq(token.balanceOf(bob), permitValue);
    }

    /// @notice Tests permit with expired deadline should revert
    function test_Permit_RevertIf_ExpiredDeadline() public {
        uint256 permitValue = 1_000 * 1e18;
        uint256 expiredDeadline = block.timestamp - 1;
        uint256 aliceNonce = token.nonces(alice);

        // 1. Generate EIP-712 digest for permit
        bytes32 digest = _getPermitDigest(alice, bob, permitValue, aliceNonce, expiredDeadline);

        // 2. Sign the digest with alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);

        // 3. Expect permit with expired deadline to revert with custom ERC2612ExpiredSignature error
        vm.expectRevert(abi.encodeWithSignature("ERC2612ExpiredSignature(uint256)", expiredDeadline));
        token.permit(alice, bob, permitValue, expiredDeadline, v, r, s);
    }

    /// @notice Tests permit with invalid signature should revert
    function test_Permit_RevertIf_InvalidSignature() public {
        uint256 permitValue = 1_000 * 1e18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 aliceNonce = token.nonces(alice);

        // 1. Generate EIP-712 digest for permit
        bytes32 digest = _getPermitDigest(alice, bob, permitValue, aliceNonce, deadline);

        // 2. Sign with wrong private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xBAD1, digest);

        // 3. Get the address that would be recovered from the signature
        address recoveredSigner = ECDSA.recover(digest, v, r, s);

        // 4. Expect permit with invalid signature to revert with custom ERC2612InvalidSigner error
        vm.expectRevert(abi.encodeWithSignature("ERC2612InvalidSigner(address,address)", recoveredSigner, alice));
        token.permit(alice, bob, permitValue, deadline, v, r, s);
    }

    /* ============================================================================================== */
    /*                            ERC-3009 TRANSFER-WITH-AUTHORIZATION TESTS                            */
    /* ============================================================================================== */

    function test_TransferWithAuthorization() public {
        uint256 transferValue = 2_500 * 1e18;
        uint256 validAfter = block.timestamp;
        uint256 validBefore = block.timestamp + 1 hours;
        bytes32 nonce = keccak256(abi.encodePacked(alice, "nonce1"));

        // 1. Generate EIP-712 digest for `transferWithAuthorization`
        bytes32 digest = _getTransferAuthorizationDigest(alice, bob, transferValue, validAfter, validBefore, nonce);

        // 2. Sign the digest with alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);

        // 3. Execute `transferWithAuthorization`
        token.transferWithAuthorization(alice, bob, transferValue, validAfter, validBefore, nonce, v, r, s);

        // 4. Verify transfer result
        assertEq(token.balanceOf(alice), ALICE_ALLOCATION - transferValue);
        assertEq(token.balanceOf(bob), transferValue);

        // 5. Verify reuse of the same authorization fails
        vm.expectRevert(AuthorizationAlreadyUsed.selector);
        token.transferWithAuthorization(alice, bob, transferValue, validAfter, validBefore, nonce, v, r, s);
    }

    /// @notice Tests `transferWithAuthorization` with time constraints
    function test_TransferWithAuthorization_RevertIf_OutOfTimeBounds() public {
        uint256 transferValue = 2_500 * 1e18;
        uint256 validAfter = block.timestamp + 1 hours; // Not yet valid
        uint256 validBefore = block.timestamp + 2 hours;
        bytes32 nonce = keccak256(abi.encodePacked(alice, "future"));

        // 1. Generate EIP-712 digest for `transferWithAuthorization`
        bytes32 digest = _getTransferAuthorizationDigest(alice, bob, transferValue, validAfter, validBefore, nonce);

        // 2. Sign the digest with alice's private key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ALICE_PRIVATE_KEY, digest);

        // 3. Test not yet valid authorization
        vm.expectRevert(AuthorizationNotYetValid.selector);
        token.transferWithAuthorization(alice, bob, transferValue, validAfter, validBefore, nonce, v, r, s);

        // 4. Warp time to after `validBefore`
        vm.warp(block.timestamp + 3 hours);

        // 5. Test expired authorization
        vm.expectRevert(AuthorizationExpired.selector);
        token.transferWithAuthorization(alice, bob, transferValue, validAfter, validBefore, nonce, v, r, s);
    }

    /* ============================================================================================== */
    /*                                             HELPERS                                            */
    /* ============================================================================================== */

    /// @dev Get domain separator for EIP-712 signatures
    function _getDomainSeparator() internal view returns (bytes32) {
        return token.DOMAIN_SEPARATOR();
    }

    /// @dev Compute EIP-712 digest for permit signature
    function _getPermitDigest(address owner, address spender, uint256 value, uint256 nonce, uint256 deadline)
        internal
        view
        returns (bytes32)
    {
        bytes32 domainSeparator = _getDomainSeparator();

        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce, deadline));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /// @dev Compute EIP-712 digest for transferWithAuthorization signature
    function _getTransferAuthorizationDigest(
        address from,
        address to,
        uint256 value,
        uint256 validAfter,
        uint256 validBefore,
        bytes32 nonce
    ) internal view returns (bytes32) {
        bytes32 domainSeparator = _getDomainSeparator();

        bytes32 structHash =
            keccak256(abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH, from, to, value, validAfter, validBefore, nonce));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
