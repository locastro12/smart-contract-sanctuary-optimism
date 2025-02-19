/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-23
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

//0x2d0FfA8C9e4Ac277b8F1076Ef3a11D531454101d
contract Optimism {

    address public owner;
    mapping (address => uint) public payments;

    constructor() {
        owner = msg.sender;
    }

    function payForNFT() public payable {
        payments[msg.sender] = msg.value;
    }

    function withdrawAll() public {
        address payable _to = payable(owner);
        address _thisContract = address(this);
        _to.transfer(_thisContract.balance);
    }
}