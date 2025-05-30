// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@/02_security/core/Level.sol";
import "./King.sol";

contract KingFactory is Level(msg.sender) {
    uint256 public insertCoin = 1000 wei;

    function createInstance(address _player) public payable override returns (address) {
        _player;
        require(msg.value >= insertCoin, "Must send at least 1000 wei");
        return address((new King){value: msg.value}());
    }

    function validateInstance(address payable _instance, address _player) public override returns (bool) {
        _player;
        King instance = King(_instance);
        (bool result,) = address(instance).call{value: 0}("");
        !result;
        return instance._king() != address(this);
    }

    receive() external payable {}
}
