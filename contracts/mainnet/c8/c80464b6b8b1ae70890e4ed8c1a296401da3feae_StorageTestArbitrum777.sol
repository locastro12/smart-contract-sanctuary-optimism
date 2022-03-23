/**
 *Submitted for verification at optimistic.etherscan.io on 2022-03-23
*/

// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/**
 * @title Storage
 * @dev Store & retrieve value in a variable
 */
contract StorageTestArbitrum777 {

    uint256 number;

    /**
     * @dev Store value in variable
     * @param num value to store
     */
    function storeVal(uint256 num) public {
        number = num;
    }

    /**
     * @dev Return value 
     * @return value of 'number'
     */
    function retrieve() public view returns (uint256){
        return number;
    }
}