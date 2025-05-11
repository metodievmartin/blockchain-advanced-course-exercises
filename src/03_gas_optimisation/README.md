## Exercise: Gas Optimization Techniques

### Gas Optimisation Challenges

This exercise aims to strengthen your understanding of gas optimisation techniques 
through hands-on practice with practical optimisation challenges. 
We encourage you to approach these optimisation tasks methodically, 
using the tools and techniques covered in the lecture.

### Tasks

In the provided repository, you will find a few contracts that need to be optimised. 
Specifically, you will need to address issues such as:

* Optimising loop structures
* Caching storage variables appropriately
* Using the right data locations (memory, storage, calldata)
* Implementing custom errors to reduce gas consumption
* Refactoring the token contract to lower gas costs
* Spotting issues such as redundant state changes and inefficient reward calculations
* Eliminating unnecessary loops or minimising loop iterations
* Caching frequently accessed storage variables
* Choosing optimal data types and storage locations
* Documenting before-and-after gas metrics along with a brief explanation of the optimisation techniques applied

Go through every contract and minimise gas costs as much as possible while preserving security and good quality code.

### Additional Notes

* All solutions must be developed and tested using **Foundry**
* Implement comprehensive tests to ensure your optimisations maintain the intended functionalities
