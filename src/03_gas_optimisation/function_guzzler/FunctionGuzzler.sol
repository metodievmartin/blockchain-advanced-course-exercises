// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @dev A contract that demonstrates inefficient function implementations
 */
contract FunctionGuzzler {
    uint256 public totalValue;
    uint256[] public values;
    mapping(address => uint256) public balances;
    mapping(address => bool) public isRegistered;
    address[] public users;

    event ValueAdded(address user, uint256 value);
    event Transfer(address from, address to, uint256 amount);

    function registerUser() external {
        require(!isRegistered[msg.sender], "Already registered");
        isRegistered[msg.sender] = true;
        users.push(msg.sender);
    }

    function sumValues() external view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }
        return sum;
    }

    function addValue(uint256 newValue) external {
        require(isRegistered[msg.sender], "Not registered");

        for (uint256 i = 0; i < values.length; i++) {
            if (values[i] == newValue) {
                revert("Value already exists");
            }
        }

        values.push(newValue);
        totalValue += newValue;

        emit ValueAdded(msg.sender, newValue);
    }

    function deposit(uint256 amount) external {
        require(isRegistered[msg.sender], "Not registered");

        uint256 oldBalance = balances[msg.sender];
        uint256 newBalance = oldBalance + amount;
        balances[msg.sender] = newBalance;

        totalValue += amount;
    }

    function findUser(address user) external view returns (bool) {
        for (uint256 i = 0; i < users.length; i++) {
            if (users[i] == user) {
                return true;
            }
        }
        return false;
    }

    function transfer(address to, uint256 amount) external {
        require(isRegistered[msg.sender], "Sender not registered");
        require(isRegistered[to], "Recipient not registered");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
    }

    function getAverageValue() external view returns (uint256) {
        if (values.length == 0) return 0;

        uint256 sum = 0;
        for (uint256 i = 0; i < values.length; i++) {
            sum += values[i];
        }

        return sum / values.length;
    }
}
