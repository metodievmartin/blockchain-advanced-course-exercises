// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {DeployPayroll} from "@script/exam-prep/DeployPayroll.s.sol";
import {Payroll} from "@/exam-prep/Payroll.sol";
import {PayrollFactory} from "@/exam-prep/PayrollFactory.sol";
import {PayrollConfig} from "@script/exam-prep/PayrollConfig.s.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";
import {PayrollTestHelper} from "./helpers/PayrollTestHelper.sol";

contract PayrollTest is Test {
    /* ============================================================================================== */
    /*                                         STATE_VARIABLES                                        */
    /* ============================================================================================== */
    Payroll public payroll;
    PayrollFactory public payrollFactory;
    PayrollConfig public configHelper;
    MockV3Aggregator public mockPriceFeed;
    PayrollTestHelper public signatureHelper;

    // Network configuration
    address public priceFeed;
    address public director;
    address public hrManager;
    string public departmentName;
    address public payrollImplementation;
    address public payrollFactoryAddress;
    address payable public payrollInstance;

    // Constants for test accounts
    address public constant EMPLOYEE1 = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC; // Third Anvil address index 2
    address public constant EMPLOYEE2 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906; // Fourth Anvil address index 3
    address public constant SCRIPT_EMPLOYEE = 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720; // Last Anvil address index 9

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant INITIAL_CONTRACT_FUNDING = 10 ether;

    // Pay stub data
    uint256 public constant PERIOD_1 = 202505;
    uint256 public constant PERIOD_2 = 202506;
    uint256 public constant USD_AMOUNT_1 = 500000; // $5,000.00 in cents
    uint256 public constant USD_AMOUNT_2 = 700000; // $7,000.00 in cents
    uint256 public constant SCRIPT_USD_AMOUNT = 1100; // $11.00 in cents (from the script)

    // Private keys for testing (derived from known Anvil addresses)
    uint256 private constant DIRECTOR_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 private constant HR_MANAGER_PRIVATE_KEY = 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    /* ============================================================================================== */
    /*                                             EVENTS                                             */
    /* ============================================================================================== */
    event SalaryClaimed(address indexed employee, uint256 period, uint256 usdAmount, uint256 ethAmount);

    /* ============================================================================================== */
    /*                                           ERROR_CODES                                          */
    /* ============================================================================================== */
    error AlreadyInitialized();
    error InvalidDirectorAddress();
    error InvalidPriceFeedAddress();
    error PeriodAlreadyClaimed();
    error InvalidSignature();
    error InsufficientContractBalance();
    error ETHTransferFailed();
    error OnlyDirectorCanFundContract();
    error InvalidPriceFeedData();
    error InvalidInitialization();

    function setUp() external {
        // Deploy the Payroll contract using the deployment script
        DeployPayroll deployer = new DeployPayroll();
        (address instanceAddress, address implAddress, address factoryAddress, PayrollConfig config) = deployer.run();

        // Store the addresses and config helper
        payrollImplementation = implAddress;
        payrollFactoryAddress = factoryAddress;
        payrollInstance = payable(instanceAddress);
        configHelper = config;

        // Get the network configuration for local testing
        PayrollConfig.NetworkConfig memory networkConfig = configHelper.getOrCreateAnvilConfig();

        // Store configuration values
        priceFeed = networkConfig.priceFeed;
        director = networkConfig.director;
        hrManager = networkConfig.hrManager;
        departmentName = networkConfig.departmentName;

        // Get the PayrollFactory contract instance
        payrollFactory = PayrollFactory(payrollFactoryAddress);

        // Get the Payroll instance created during deployment
        payroll = Payroll(payrollInstance);

        // Get the mock price feed instance
        mockPriceFeed = MockV3Aggregator(priceFeed);

        // Create the signature helper with the same domain name and version as the Payroll contract
        string memory domainName = string(abi.encodePacked("Payroll ", departmentName));
        signatureHelper = new PayrollTestHelper(domainName, "1", address(payroll));

        // Fund test accounts
        vm.deal(director, STARTING_USER_BALANCE);
        vm.deal(hrManager, STARTING_USER_BALANCE);
        vm.deal(EMPLOYEE1, STARTING_USER_BALANCE);
        vm.deal(EMPLOYEE2, STARTING_USER_BALANCE);
        vm.deal(SCRIPT_EMPLOYEE, STARTING_USER_BALANCE);

        // Note: The deployment script already funds the contract with 10 ETH
        // for local testing, so we don't need to fund it again
    }

    /* ============================================================================================== */
    /*                                         INITIALIZATION                                         */
    /* ============================================================================================== */

    function test_SetUpState() public view {
        // Verify the contract was initialized correctly
        assertEq(payroll.director(), director, "director");
        assertEq(address(payroll.priceFeed()), priceFeed, "priceFeed");

        // Verify the factory state
        assertEq(payrollFactory.payrollImplementation(), payrollImplementation, "implementation");
        assertEq(payrollFactory.owner(), hrManager, "hrManager");

        // Verify the factory created the payroll instance
        assertEq(payrollFactory.payrolls(0), address(payrollInstance), "payrollInstance");

        // Verify the contract has funds (already funded by the deployment script)
        assertGt(address(payroll).balance, 0, "contractBalance");
    }

    function test_RevertIf_InitializeCalledTwice() public {
        // Try to initialize the contract again
        vm.expectRevert();
        payroll.initialize(director, departmentName, priceFeed);
    }

    function test_RevertWhen_InitializeWithZeroDirector() public {
        // Deploy a new implementation for testing initialization
        Payroll newImpl = new Payroll();

        // Try to initialize with zero address for director
        vm.expectRevert(InvalidInitialization.selector);
        newImpl.initialize(address(0), departmentName, priceFeed);
    }

    function test_RevertWhen_InitializeWithZeroPriceFeed() public {
        // Deploy a new implementation for testing initialization
        Payroll newImpl = new Payroll();

        // Try to initialize with zero address for price feed
        vm.expectRevert(InvalidInitialization.selector);
        newImpl.initialize(director, departmentName, address(0));
    }

    /* ============================================================================================== */
    /*                                         SIGNATURE_TESTS                                        */
    /* ============================================================================================== */

    function test_ValidSignature() public {
        // Generate a valid signature for EMPLOYEE1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Verify the signature is valid
        bool isValid = payroll.isValidSignature(EMPLOYEE1, PERIOD_1, USD_AMOUNT_1, signature);
        assertTrue(isValid, "signature should be valid");
    }

    function test_InvalidSignatureWrongSigner() public {
        // Generate a signature with wrong signer (HR_MANAGER instead of director)
        bytes memory signature = signatureHelper.signPayStub(
            HR_MANAGER_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Verify the signature is invalid
        bool isValid = payroll.isValidSignature(EMPLOYEE1, PERIOD_1, USD_AMOUNT_1, signature);
        assertFalse(isValid, "signature should be invalid");
    }

    function test_InvalidSignatureWrongEmployee() public {
        // Generate a signature for EMPLOYEE1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Try to verify with EMPLOYEE2
        bool isValid = payroll.isValidSignature(EMPLOYEE2, PERIOD_1, USD_AMOUNT_1, signature);
        assertFalse(isValid, "signature should be invalid");
    }

    function test_InvalidSignatureWrongPeriod() public {
        // Generate a signature for PERIOD_1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Try to verify with PERIOD_2
        bool isValid = payroll.isValidSignature(EMPLOYEE1, PERIOD_2, USD_AMOUNT_1, signature);
        assertFalse(isValid, "signature should be invalid");
    }

    function test_InvalidSignatureWrongAmount() public {
        // Generate a signature for USD_AMOUNT_1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Try to verify with USD_AMOUNT_2
        bool isValid = payroll.isValidSignature(EMPLOYEE1, PERIOD_1, USD_AMOUNT_2, signature);
        assertFalse(isValid, "signature should be invalid");
    }

    function test_ClaimSalary() public {
        // Generate a valid signature for EMPLOYEE1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Get initial balances
        uint256 initialContractBalance = address(payroll).balance;
        uint256 initialEmployeeBalance = EMPLOYEE1.balance;

        // Calculate expected ETH amount
        uint256 expectedEthAmount = _calculateExpectedEthAmount(USD_AMOUNT_1);

        // Claim salary as EMPLOYEE1
        vm.prank(EMPLOYEE1);
        vm.expectEmit(true, true, true, true);
        emit SalaryClaimed(EMPLOYEE1, PERIOD_1, USD_AMOUNT_1, expectedEthAmount);
        payroll.claimSalary(PERIOD_1, USD_AMOUNT_1, signature);

        // Verify balances
        assertEq(address(payroll).balance, initialContractBalance - expectedEthAmount, "contract balance");
        assertEq(EMPLOYEE1.balance, initialEmployeeBalance + expectedEthAmount, "employee balance");

        // Verify period is marked as claimed
        assertTrue(payroll.claimedPeriods(EMPLOYEE1, PERIOD_1), "period should be marked as claimed");
    }

    function test_RevertWhen_ClaimingAlreadyClaimedPeriod() public {
        // Generate a valid signature for EMPLOYEE1
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Claim salary first time
        vm.prank(EMPLOYEE1);
        payroll.claimSalary(PERIOD_1, USD_AMOUNT_1, signature);

        // Try to claim again
        vm.prank(EMPLOYEE1);
        vm.expectRevert(PeriodAlreadyClaimed.selector);
        payroll.claimSalary(PERIOD_1, USD_AMOUNT_1, signature);
    }

    function test_RevertWhen_ClaimingWithInvalidSignature() public {
        // Generate an invalid signature (signed by HR_MANAGER instead of director)
        bytes memory signature = signatureHelper.signPayStub(
            HR_MANAGER_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            USD_AMOUNT_1
        );

        // Try to claim with invalid signature
        vm.prank(EMPLOYEE1);
        vm.expectRevert(InvalidSignature.selector);
        payroll.claimSalary(PERIOD_1, USD_AMOUNT_1, signature);
    }

    function test_RevertWhen_InsufficientContractBalance() public {
        // Set a very high USD amount
        uint256 hugeAmount = 100000000000; // $1,000,000,000.00 in cents

        // Generate a valid signature for the huge amount
        bytes memory signature = signatureHelper.signPayStub(
            DIRECTOR_PRIVATE_KEY, 
            EMPLOYEE1, 
            PERIOD_1, 
            hugeAmount
        );

        // Try to claim with insufficient contract balance
        vm.prank(EMPLOYEE1);
        vm.expectRevert(InsufficientContractBalance.selector);
        payroll.claimSalary(PERIOD_1, hugeAmount, signature);
    }

    /* ============================================================================================== */
    /*                                         HELPER_FUNCTIONS                                       */
    /* ============================================================================================== */

    function _calculateExpectedEthAmount(uint256 usdAmountInCents) internal view returns (uint256) {
        (, int256 price,,,) = mockPriceFeed.latestRoundData();
        require(price > 0, "Invalid price feed data");

        // USD amount is in cents, price is in USD with 8 decimals
        return (1 ether * (usdAmountInCents * 10 ** 6)) / uint256(price);
    }
}
