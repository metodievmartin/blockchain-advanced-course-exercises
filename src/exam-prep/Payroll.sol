// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {AggregatorV3Interface} from "chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Payroll is Initializable, EIP712Upgradeable {
    bytes32 private constant PAY_STUB_TYPE_HASH =
        keccak256("PayStub(address employee,uint256 period,uint256 usdAmount)");

    address public director;
    AggregatorV3Interface public priceFeed;
    mapping(address => mapping(uint256 => bool)) public claimedPeriods;

    event SalaryClaimed(address indexed employee, uint256 period, uint256 usdAmount, uint256 ethAmount);

    error AlreadyInitialized();
    error InvalidDirectorAddress();
    error InvalidPriceFeedAddress();
    error PeriodAlreadyClaimed();
    error InvalidSignature();
    error InsufficientContractBalance();
    error ETHTransferFailed();
    error OnlyDirectorCanFundContract();
    error InvalidPriceFeedData();

    constructor() {
        _disableInitializers();
    }

    // Function to initialize the clone
    function initialize(address _director, string calldata _departmentName, address _priceFeed) external initializer {
        require(director == address(0), AlreadyInitialized());
        require(_director != address(0), InvalidDirectorAddress());
        require(_priceFeed != address(0), InvalidPriceFeedAddress());

        __EIP712_init(string(abi.encodePacked("Payroll ", _departmentName)), "1");

        director = _director;
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function claimSalary(uint256 period, uint256 usdAmount, bytes calldata signature) external {
        address employee = msg.sender;

        require(!claimedPeriods[employee][period], PeriodAlreadyClaimed());
        require(isValidSignature(employee, period, usdAmount, signature), InvalidSignature());

        // "Effect" before "interaction" with external contracts
        claimedPeriods[employee][period] = true;

        uint256 ethAmount = convertUsdToEth(usdAmount);

        require(address(this).balance >= ethAmount, InsufficientContractBalance());

        (bool success,) = employee.call{value: ethAmount}("");
        require(success, ETHTransferFailed());

        emit SalaryClaimed(employee, period, usdAmount, ethAmount);
    }

    function isValidSignature(address employee, uint256 period, uint256 usdAmount, bytes calldata signature)
        public
        view
        returns (bool)
    {
        bytes32 structHash = keccak256(abi.encode(PAY_STUB_TYPE_HASH, employee, period, usdAmount));

        bytes32 digest = _hashTypedDataV4(structHash);

        return ECDSA.recover(digest, signature) == director;
    }

    function convertUsdToEth(uint256 usdAmountInCents) internal view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, InvalidPriceFeedData());

        // USD amount is in cents, price is in USD with 8 decimals
        return (1 ether * (usdAmountInCents * 10 ** 6)) / uint256(price);
    }

    // Function for director to fund the contract
    receive() external payable {
        require(msg.sender == director, OnlyDirectorCanFundContract());
    }

    // Special admin function suitable for testing (being able to easily withdraw Ether)
    function withdraw() external {
        require(msg.sender == director, "Only director");
        (bool success,) = director.call{value: address(this).balance}("");
        require(success, "Emergency ETH transfer failed");
    }
}
