// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

event Transfer(address from, address to, uint256 amount);

error AlreadyRegistered();
error NotRegistered();
error AlreadyExists();
error InsufficientBalance();

/**
 * @notice In our unoptimized contracts we have been required to use two data structures:
 * an array and a mapping. We should make gas-optimizations.
 *
 * PREQUISITES:
 * `usersData[user]` is a packed data structure where:
 *   - The least significant bit represents the registration status (1 if registered, 0 if not)
 *   - The remaining bits represent the balance
 *
 * This allows us to store both registration status and balance in a single storage slot,
 * reducing the storage footprint compared to using two separate mappings.
 *
 * GAS OPTIMIZATION OVERVIEW:
 * 1. Bit Packing: Combines user registration status and balance into a single uint256
 *    - Saves ~20,000 gas per user by eliminating an extra storage slot
 *    - The LSB (bit 0) stores registration status (1=registered, 0=not registered)
 *    - Bits 1-255 store the user's balance (shifted left by 1 bit)
 *
 * 2. Direct Sum Tracking: Maintains a running sum instead of recalculating
 *    - Eliminates the need to iterate through values to calculate sum
 *    - Reduces gas cost from O(n) to O(1) for sum operations
 *
 * 3. Direct Count Tracking: Tracks count directly instead of calculating on demand
 *    - Avoids iteration through arrays or mappings to count elements
 *    - Provides constant-time access to count information
 *
 * 4. Mapping for Existence Checks: Uses mapping for O(1) existence checks
 *    - Replaces array iteration (O(n)) with direct mapping lookup (O(1))
 *    - Significantly reduces gas costs for duplicate checking
 *
 * ==========================
 * THIS CONTRACT IS USED FOR EDUCATIONAL PURPOSES ONLY.
 * DO NOT USE IT IN PRODUCTION ENVIRONMENTS.
 */
contract FunctionGuzzlerOptimised {
    /**
     * @dev Primary storage for user data using bit packing technique
     * For each address, a single uint256 stores both:
     * - Registration status (in bit 0, the least significant bit)
     * - Balance (in bits 1-255, shifted left by 1 bit)
     *
     * Examples:
     * - 0 (binary: 0) = Not registered, 0 balance
     * - 1 (binary: 1) = Registered, 0 balance
     * - 3 (binary: 11) = Registered, balance of 1
     * - 5 (binary: 101) = Registered, balance of 2
     *
     * Gas savings: ~20,000 gas per user by using 1 slot instead of 2
     */
    mapping(address user => uint256) private usersData;

    /**
     * @dev Storage for tracking unique values
     * - values: Maps value to existence status (true if exists)
     * - valuesCount: Total number of unique values added
     * - sum: Running sum of all values (avoids recalculation)
     *
     * Gas optimization: Direct tracking of count and sum eliminates
     * the need for expensive iteration operations
     */
    mapping(uint256 => bool) private values;
    uint256 private valuesCount;
    uint256 private sum;

    /* ============================================================================================== */
    /*                                      EXPLICIT MAPPING USAGE                                     */
    /* ============================================================================================== */

    /**
     * @notice Registers the caller as a user in the system
     * @dev Uses bitwise OR operation to set the LSB to 1 while preserving any existing balance
     *
     * Bitwise operation explained:
     * usersData[msg.sender] |= 1
     * 
     * 1. Bitwise OR (|): Compares each bit and returns 1 if either bit is 1
     * 2. Assignment (=): Stores the result back in usersData[msg.sender]
     * 
     * Example:
     * If usersData[msg.sender] = 0 (binary: 0000)
     * Then 0 | 1 = 1 (binary: 0001)
     * Result: usersData[msg.sender] = 1 (user is now registered with 0 balance)
     * 
     * If usersData[msg.sender] was already non-zero (impossible in normal flow),
     * the LSB would be set to 1 while all other bits remain unchanged.
     *
     * Gas savings: ~20,000 gas by modifying existing storage vs creating new entry
     */
    function registerUser() external {
        if (_isRegistered(msg.sender)) revert AlreadyRegistered();

        // Set the Least Significant Bit (LSB) to 1 to indicate registration
        usersData[msg.sender] |= 1;
    }

    /**
     * @notice Deposits the specified amount to the caller's balance
     * @param _amount The amount to deposit
     * @dev Uses left shift and addition to update balance while preserving registration bit
     *
     * Bitwise operation explained:
     * usersData[msg.sender] += _amount << 1
     * 
     * 1. Left shift (<<): Shifts all bits in _amount to the left by 1 position
     *    - Equivalent to multiplying _amount by 2
     *    - Creates a "gap" at the LSB position
     *    - Ensures the registration bit (LSB) is not affected by the addition
     * 
     * 2. Addition (+=): Adds the shifted amount to the existing usersData value
     * 
     * Example:
     * If _amount = 5 (binary: 0101)
     * Then _amount << 1 = 10 (binary: 1010)
     * 
     * If usersData[msg.sender] = 1 (registered, 0 balance, binary: 0001)
     * Then 1 + 10 = 11 (binary: 1011)
     * Result: usersData[msg.sender] = 11 (registered with balance of 5)
     *
     * Gas savings: Avoids separate SLOAD/SSTORE operations by updating in one operation
     */
    function deposit(uint256 _amount) external {
        if (!_isRegistered(msg.sender)) revert NotRegistered();

        // Shift amount left by 1 and add to userData while preserving isRegistered bit
        usersData[msg.sender] += _amount << 1;
    }

    /**
     * @notice Transfers the specified amount from caller to recipient
     * @param _to The recipient address
     * @param _amount The amount to transfer
     * @dev Uses left shift for balance manipulation to preserve registration bits
     *
     * Bitwise operations explained:
     * 1. usersData[msg.sender] -= _amount << 1
     *    - Shifts _amount left by 1 bit before subtracting
     *    - Ensures only the balance portion is affected, not the registration bit
     * 
     * 2. usersData[_to] += _amount << 1
     *    - Shifts _amount left by 1 bit before adding
     *    - Ensures only the balance portion is affected, not the registration bit
     * 
     * Example:
     * If _amount = 3 (binary: 0011)
     * Then _amount << 1 = 6 (binary: 0110)
     * 
     * If sender has usersData = 11 (registered with balance 5, binary: 1011)
     * Then 11 - 6 = 5 (binary: 0101) = registered with balance 2
     * 
     * If recipient has usersData = 3 (registered with balance 1, binary: 0011)
     * Then 3 + 6 = 9 (binary: 1001) = registered with balance 4
     *
     * Gas savings: Single storage operation per user vs multiple operations in traditional approach
     */
    function transfer(address _to, uint256 _amount) external {
        if (!_isRegistered(msg.sender)) revert NotRegistered();
        if (!_isRegistered(_to)) revert NotRegistered();

        uint256 senderBalance = balances(msg.sender);
        if (senderBalance < _amount) revert InsufficientBalance();

        usersData[msg.sender] -= _amount << 1;

        usersData[_to] += _amount << 1;
        emit Transfer(msg.sender, _to, _amount);
    }

    /**
     * @notice Returns the balance of the specified user
     * @param _user The user address to query
     * @return The user's balance
     * @dev Uses right shift to extract just the balance portion of the packed data
     *
     * Bitwise operation explained:
     * usersData[_user] >> 1
     * 
     * 1. Right shift (>>): Shifts all bits to the right by 1 position
     *    - Equivalent to integer division by 2
     *    - Effectively removes the LSB (registration bit)
     *    - Returns only the balance portion of the packed data
     * 
     * Example:
     * If usersData[_user] = 11 (binary: 1011)
     * Then 11 >> 1 = 5 (binary: 0101)
     * Result: Returns 5 as the balance
     *
     * Gas savings: Efficient extraction of data without additional storage or operations
     */
    function balances(address _user) public view returns (uint256) {
        return usersData[_user] >> 1;
    }

    /**
     * @notice Checks if a user is registered in the system
     * @param _user The user address to check
     * @return Boolean indicating if the user is registered
     * @dev Public wrapper around the private _isRegistered function
     */
    function findUser(address _user) public view returns (bool) {
        return _isRegistered(_user);
    }

    /**
     * @notice Internal function to check if a user is registered
     * @param _user The user address to check
     * @return Boolean indicating if the user is registered
     * @dev Uses bitwise AND to isolate and check the registration bit
     *
     * Bitwise operation explained:
     * (usersData[_user] & 1) == 1
     * 
     * 1. Bitwise AND (&): Performs bitwise AND between usersData[_user] and 1
     *    - 1 in binary is 0001, so this isolates just the LSB
     *    - If LSB is 1, result is 1; if LSB is 0, result is 0
     * 
     * 2. Comparison (==): Checks if the isolated bit equals 1
     * 
     * Example:
     * If usersData[_user] = 11 (binary: 1011)
     * Then 11 & 1 = 1 (binary: 0001)
     * Result: Returns true (user is registered)
     * 
     * If usersData[_user] = 0 (binary: 0000)
     * Then 0 & 1 = 0 (binary: 0000)
     * Result: Returns false (user is not registered)
     *
     * Gas savings: Extremely efficient bit extraction vs separate mapping lookup
     */
    function _isRegistered(address _user) private view returns (bool) {
        return (usersData[_user] & 1) == 1;
    }

    /* ============================================================================================== */
    /*                                      EXPLICIT ARRAY USAGE                                      */
    /* ============================================================================================== */

    /**
     * @notice Adds a new unique value to the system
     * @param _newValue The value to add
     * @dev Uses direct tracking of values, count, and sum for gas efficiency
     *
     * Gas optimizations:
     * 1. Direct mapping lookup for existence check (O(1) vs O(n) for array iteration)
     * 2. Incremental sum update (O(1) vs O(n) for recalculation)
     * 3. Direct count tracking (O(1) vs O(n) for length calculation)
     *
     * Example:
     * If _newValue = 10, values[10] = false, valuesCount = 2, sum = 15
     * After function call: values[10] = true, valuesCount = 3, sum = 25
     */
    function addValue(uint256 _newValue) external {
        if (!_isRegistered(msg.sender)) revert NotRegistered();

        if (values[_newValue]) revert AlreadyExists();

        values[_newValue] = true;
        valuesCount++;
        sum += _newValue;
    }

    /**
     * @notice Returns the sum of all values in the system
     * @return The total sum
     * @dev Uses pre-calculated sum for O(1) access vs O(n) recalculation
     *
     * Gas savings: Constant-time operation regardless of number of values
     */
    function sumValues() external view returns (uint256) {
        return sum;
    }

    /**
     * @notice Calculates the average of all values in the system
     * @return The average value
     * @dev Uses pre-calculated sum and count for O(1) calculation
     *
     * Gas savings: Constant-time operation regardless of number of values
     */
    function getAverageValue() external view returns (uint256) {
        return valuesCount == 0 ? 0 : sum / valuesCount;
    }
}
