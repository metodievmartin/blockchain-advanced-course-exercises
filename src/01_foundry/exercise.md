Introduction to Foundry and Development Setup

Raffle System Tests

You have a Raffle System implemented with two smart contracts: TicketNFT and RaffleHouse. 
The TicketNFT contract is an ERC721 implementation that represents raffle tickets, 
while the 'RaffleHouse' contract manages raffles, ticket purchases, winner selection, 
and prize distribution. You should thoroughly test all aspects of this raffle system, 
including proper ticket minting, raffle creation and management, ticket purchasing, 
winner selection mechanics, and prize claiming functionality. 
You must use Foundry for writing and running these tests.

Tasks

1. Test Setup 

    a. Create a test file structure using Foundry's testing framework

    b. Create helper functions for common operations


2. Test Contract State and Initialization

    a. Verify initial contract states


3. Test TicketNFT Functionality

    a. Test NFT minting
    
    b. Test ownership transfers
    
    c. Verify ERC721 compliance
    
    d. Test enumeration functionality
    
    e. Test proper access control


4. Test RaffleHouse Functionality

    a. Test raffle creation
    
    b. Test ticket purchasing
    
    c. Test winner selection
    
    d. Test prize claiming
    
    e. Verify raffle state transitions


5. Test Integration and Interaction Flow
    
    a. Test the complete raffle lifecycle


6. Test Events and Error Messages


7. Measure Coverage


8. Gas Optimization
    
    a. Measure gas costs for all operations using Foundry's gas reporting
    
    b. Compare gas usage in different scenarios
    
    c. Document gas-intensive operations
    
    d. Suggest optimization strategies