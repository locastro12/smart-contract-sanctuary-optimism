/**
 *Submitted for verification at optimistic.etherscan.io on 2022-04-26
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

contract HelloAuthor {
  event MessageSent(address indexed sender, string message);
  function sendMessage(string calldata newMessage) public {
    emit MessageSent(msg.sender, newMessage);
  }
}