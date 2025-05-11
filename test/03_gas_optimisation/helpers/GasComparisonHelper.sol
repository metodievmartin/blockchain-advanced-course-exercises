// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/console.sol";

/**
 * @title GasComparisonHelper
 * @notice Utility contract providing helper functions for gas comparison tests
 * @dev Test contracts should inherit from both this contract and Test
 */
abstract contract GasComparisonHelper {
    /**
     * @notice Logs gas comparison results between original and optimized implementations
     * @param operation The name of the operation being compared
     * @param originalGasUsed Gas used by the original implementation
     * @param optimizedGasUsed Gas used by the optimized implementation
     */
    function logGasComparison(string memory operation, uint256 originalGasUsed, uint256 optimizedGasUsed)
        internal
        pure
    {
        console.log("===== Gas Comparison for `%s` =====", operation);
        console.log("Original gas used:", originalGasUsed);
        console.log("Optimized gas used:", optimizedGasUsed);

        if (originalGasUsed > optimizedGasUsed) {
            console.log("Gas saved:", originalGasUsed - optimizedGasUsed);
            console.log("Percentage saved:", ((originalGasUsed - optimizedGasUsed) * 100) / originalGasUsed, "%");
        } else {
            console.log("Gas increase:", optimizedGasUsed - originalGasUsed);
            console.log("Percentage increase:", ((optimizedGasUsed - originalGasUsed) * 100) / originalGasUsed, "%");
        }
        console.log("==================================");
    }
}
