## Exam Preparation Homework

### On-Chain Payroll

A tech company wants to pay small contractor teams in ETH while expressing salaries in USD. 
Department directors can use a dedicated Payroll clone to manage their team’s payment of salaries
using a clone factory (Minimal Proxy factory).

Each month, HR e-mails employees a signed by its director pay-stub (EIP-712)
that states their USD salary and the pay-period ID.

The employee submits this signature to the department’s Payroll clone; 
the contract consults a Chainlink USD/ETH price feed to convert the USD amount to the correct amount
of ETH at claim time, then transfers the funds from its balance.

A director may fund the clone in advance with a small amount of ETH; 
each individual salary should be < 0.001 ETH so the smart contract can be cheaply tested on Sepolia.

The exam delivers a secure, gas-optimised Payroll system that demonstrates:

* Signature-based authorisation - custom EIP-712 pay-stub signed by the director.
* Cloneable architecture - a factory that deploys minimal-proxy Payroll instances.
* Chainlink data feed - live USD/ETH conversion at the moment of payment.

### Project Structure

Students may use Foundry only, or Foundry + Hardhat project setup. 
OpenZeppelin or similar libraries are allowed.

### Detailed Business and Technical Requirements

#### System Overview

* PayrollFactory holds the implementation address and deploys new minimal-proxy instances.
* Proxy is the actual Payroll instance
* Storage lives in the clone; logic lives in the implementation.

### Lifecycle & User Journeys

#### Factory Deployment

* The student must create a deployment script that deploys the PayrollFactory contract.
* You can choose whether to deploy the implementation contract (Payroll.sol) from the Factory or use EOA and a script.
* HR address must be specified - only HR can deploy new instances of the Payroll proxy 
  and can specify the Payroll instance settings (director address and data feed)

#### Create Payroll Proxy Instance

* The HR (Human Resources) address can trigger createPayroll to deploy a Payroll proxy for some of the company departments’ director.
* Each clone (Payroll) is initialised once with:

  * Director's address (admin/funder)
  * The director's address is used to sign the pay-stub as well (EOA)
  * Department name - used in the EIP-712 domain separator
  * PriceFeed (Chainlink AggregatorV3Interface; ETH/USD feed address passed at init)

#### Funding

* The director can send ETH to the clone to cover upcoming salary payments.

#### Pay-Stub Issuance (Off-chain)

Director signs the EIP-712 pay-stub which specifies:

* Employee the stub is made for (address)
* Period - an integer like 202405 (YYYYMM). Note: A monthly payment can be claimed only once
* USD Amount - in cents (e.g. 1250 = \$12.50)

#### Salary Claim

Employee calls `claimSalary(period, usdGross, signature)`

Contract checks:

* Stub unused
* Signature is valid & made from director
* Reads latest price from priceFeed
* Converts usdGross to wei and transfers ETH to employee.
* A monthly payment can be claimed only once

### Roles & Permissions

* Director (clone admin) - funds contract, signs valid pay-stubs.
* HR (factory admin) - Deploys new proxy instances for departments
* Employee - a wallet that submits pay-stub to receive salary.

### Key Business Rules

* No double pay – each employee may claim a pay-stub for a given monthly period only once
* Predictable USD value – payment amount is calculated with the price feed reading taken in the same transaction.
* Transparency – events for factory creation and every salary payment.

### Simplified Assumptions

* All salaries are paid monthly; the pay-period is an integer like 202405 (YYYYMM).
* Salaries are small (≤ 10 USD), so the required ETH on Sepolia is < 0.001.
* The company always funds the department clone in advance.
* Only one department clone (proxy) must be created for the exam, but the factory must support many.
* We ignore income tax, refunds, etc.
* Employees are identified by their wallet address; no off-chain KYC in scope.
* Feel free to add an AdminWithdrawal function that you can use to emergently withdraw ether - this is for easier testing of the contract while preserving the Ether you have.

### General Requirements

#### EIP-712 Signatures

* Custom EIP-712 pay-stub generation and on-chain verification.
* Create generate-pay-stub.js script that generates a signature based on the given (as env variable or hardcoded in the script) employee address and period (use the current month so you can test on Sepolia).
* Save the generated signature with the message signed in a signature.json file

#### Proxies

* Minimal-proxy factory creating independent Payroll instances.

#### Oracles

* Chainlink price feed queried inside each salary claim.

#### Proper Implementation of Key Business Requirements & Roles

* Your solution must fully adhere to the described business logic and roles

### Other Requirements

* Manual testing on Sepolia
* Proof you’ve manually tested all key steps of the process by adding deployment addresses and executed transaction info in the README.md file (More info in the Project Submission section).

### Security and Gas Optimization

* Apply the security principles and gas optimization techniques covered in the course.