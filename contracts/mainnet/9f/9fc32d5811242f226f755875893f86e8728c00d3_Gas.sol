/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-24
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Gas {
    uint public i = 0;

    // Using up all of the gas that you send causes your transaction to fail.
    // State changes are undone.
    // Gas spent are not refunded.
    function forever() public {
        // Here we run a loop until all of the gas are spent
        // and the transaction fails
        while (true) {
            i += 1;
        }
    }
}