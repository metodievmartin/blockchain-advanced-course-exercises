// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Payroll} from "./Payroll.sol";

contract PayrollFactory is Ownable {
    using Clones for address;

    address public immutable payrollImplementation;
    address[] public payrolls;

    event PayrollCreated(address indexed payrollAddress);

    error InvalidImplementationAddress();
    error InvalidDirectorAddress();
    error InvalidPriceFeedAddress();

    constructor(address _payrollImplementation, address _hr) Ownable(_hr) {
        require(_payrollImplementation != address(0), InvalidImplementationAddress());

        payrollImplementation = _payrollImplementation;
    }

    /**
     * @notice Creates a new Payroll proxy instance
     * @param _director Address of the department director who will sign pay-stubs
     * @param _priceFeed Address of the Chainlink ETH/USD price feed
     * @return The address of the newly created Payroll clone
     */
    function createPayroll(address _director, string calldata _departmentName, address _priceFeed)
        external
        onlyOwner
        returns (address)
    {
        require(_director != address(0), InvalidDirectorAddress());
        require(_priceFeed != address(0), InvalidPriceFeedAddress());

        address payrollClone = payrollImplementation.clone();
        Payroll(payable(payrollClone)).initialize(_director, _departmentName, _priceFeed);

        payrolls.push(payrollClone);

        emit PayrollCreated(payrollClone);

        return payrollClone;
    }
}
