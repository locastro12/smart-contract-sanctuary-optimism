/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-08
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract scroll {

    address public owner;
    mapping (address => uint) public payments;

    constructor() {
        owner = msg.sender;
    }

    function deposit() public payable {
        payments[msg.sender] = msg.value;
    }

    function withdraw() public {
        address payable _to = payable(owner);
        address _thisContract = address(this);
        _to.transfer(_thisContract.balance);
    }
}