## Exercise: Upgradeability

### Governance Voting

Build a basic voting system that allows token holders to create proposals, vote on them, and upgrade the logic later to add new rules.

### Requirements

#### Voting Token

* Use OpenZeppelin's `ERC20Votes` and `ERC20Permit`
* On deployment, mint **1,000,000 tokens** to the deployer
* Users must be able to **delegate their votes** to themselves or others

#### VotingLogicV1.sol (Initial Version)

* Must be **upgradeable** using OpenZeppelin Upgrades Plugin and `TransparentUpgradeableProxy`
* Define a `Proposal` struct:

    * `uint256 id`
    * `address proposer`
    * `string description`
    * `uint256 forVotes`
    * `uint256 againstVotes`
    * `bool executed`
* Allow users to:

    * **Create** a proposal
    * **Vote** "for" or "against"
    * **Mark** a proposal as executed if it has more "for" than "against" votes

#### VotingLogicV2.sol (Upgraded Version)

* Upgrade the proxy to use this new logic
* Add a new function:

    * `quorum()` → always returns **1000**
* Update `execute()` to only work if total votes (`forVotes + againstVotes`) are at least the **quorum**

### Additional Notes

* Use the OpenZeppelin **Upgradeable** library (upgradeable versions of contracts)
* Use the OpenZeppelin **Upgrades Plugin** to deploy the proxy and perform the upgrade from V1 to V2
* Use the **Transparent Proxy** pattern
