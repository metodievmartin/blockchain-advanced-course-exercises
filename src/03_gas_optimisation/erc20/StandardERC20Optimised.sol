// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

/**
 * @title Gas-optimized ERC20 Implementation
 * @notice This optimized version implements several gas-saving techniques:
 * - State variables ordered to minimize storage slots
 * - Use of unchecked blocks for safe arithmetic
 * - Caching of storage variables
 * - More efficient error handling
 *
 *  FOR EDUCATIONAL PURPOSES ONLY
 */
contract StandardERC20Optimised {
    // Made immutable as it's set once in constructor
    uint8 immutable decimals;

    string name;
    string symbol;
    uint256 totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        // Using internal _mint function to avoid code duplication
        _mint(msg.sender, _initialSupply);
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        // Single SLOAD and SSTORE for sender's balance
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        // Single SSTORE operation
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        // Cache the allowance to save an SLOAD
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        // Only update allowance if not set to max uint256
        // This optimizes for common cases where approval is set to max
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        // Single SLOAD and SSTORE for sender's balance
        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /**
     * @dev Internal mint function that handles the actual minting logic
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     * This function is marked as virtual to allow for future overrides
     */
    function _mint(address to, uint256 amount) internal virtual {
        // This has an implicit overflow check, so we are guaranteed totalSupply won't overflow
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value
        // We can remove the check due to the token's fixed supply and transfer logic
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }
}
