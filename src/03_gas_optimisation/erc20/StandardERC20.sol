// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev A standard but gas-inefficient ERC20 implementation
 *
 * GAS INEFFICIENCIES:
 * 1. Poor state variable ordering wastes storage slots
 * 2. Inefficient error handling with require statements
 * 3. Multiple SLOAD/SSTORE operations in transfer functions
 * 4. No use of unchecked blocks for safe arithmetic
 * 5. Missing optimizations for common approval patterns
 */
contract StandardERC20 {
    // INEFFICIENT: State variables not ordered by type
    // - Solidity stores variables in 32-byte slots
    // - string and uint8 should be grouped together to share storage slots
    // - This wastes storage space and increases gas costs
    string public name; // 32 bytes (pointer)
    string public symbol; // 32 bytes (pointer)
    uint8 public decimals; // 1 byte (but takes 32 bytes in storage)
    uint256 public totalSupply; // 32 bytes

    // Mappings always take a full storage slot, so their position doesn't matter
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Events are fine as-is, but could use more descriptive parameter names
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply) {
        // INEFFICIENT: Direct assignments without any optimization
        // - Each assignment is a separate SSTORE operation
        // - No use of immutable for compile-time constants
        name = _name;
        symbol = _symbol;
        decimals = _decimals; // Could be immutable since it never changes
        totalSupply = _initialSupply;

        // INEFFICIENT: Direct balance assignment without using a mint function
        // - No overflow protection
        // - Emits a transfer event directly in constructor
        balanceOf[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        // INEFFICIENT: Multiple require statements
        // Each require costs gas for:
        // 1. Evaluating the condition
        // 2. Storing the error string in the bytecode
        // 3. Reverting state changes
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        require(to != address(0), "Transfer to zero address");

        // INEFFICIENT: Multiple SLOAD/SSTORE operations
        // balanceOf[msg.sender] is read (SLOAD), modified, and written (SSTORE)
        // balanceOf[to] is read (SLOAD), modified, and written (SSTORE)
        balanceOf[msg.sender] -= value; // SLOAD, SUB, SSTORE
        balanceOf[to] += value; // SLOAD, ADD, SSTORE

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        // INEFFICIENT: No optimization for max allowance pattern
        // Many dApps set allowance to max to save gas on future approvals
        // This implementation doesn't handle that common case
        require(spender != address(0), "Approve to zero address");

        // Single SSTORE is fine, but could be optimized for the max allowance case
        allowance[msg.sender][spender] = value;

        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        // INEFFICIENT: Multiple require statements
        // Each require is a separate JUMPI operation and stores an error string
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        require(to != address(0), "Transfer to zero address");

        // INEFFICIENT: Multiple SLOAD/SSTORE operations
        // balanceOf[from] is read and written
        // balanceOf[to] is read and written
        // allowance is read and written
        // Total: 6 storage operations
        balanceOf[from] -= value; // SLOAD, SUB, SSTORE
        balanceOf[to] += value; // SLOAD, ADD, SSTORE
        allowance[from][msg.sender] -= value; // SLOAD, SUB, SSTORE

        emit Transfer(from, to, value);
        return true;
    }

    // MISSING: No internal _mint function
    // - Minting logic is directly in the constructor
    // - Not reusable for other functions
    // - No way to mint tokens after deployment
}
