/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-09-11
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

contract Casino {

  /*
  struct does not include the commitment hash(randomA) value, 
  because used as key to locate the ProposedBet
  */
  struct ProposedBet {
    address sideA;
    uint value;
    uint placedAt;
    bool accepted;  
  } // struct ProposedBet

  struct AcceptedBet {
    address sideB;
    uint acceptedAt;
    uint randomB;
  } // struct AcceptedBet

  // Proposed bets, keyed by the commitment value
  mapping(uint => ProposedBet) public proposedBet;
  // Accepted bets, also keyed by commitment value
  mapping(uint => AcceptedBet) public acceptedBet;

  event BetProposed (
   uint indexed _commitment,
   uint value
  );

  event BetAccepted (
   uint indexed _commitment,
   address indexed _sideA
  );

  event BetSettled (
   uint indexed _commitment,
   address winner,
   address loser,
   uint value   
  );

  // Called by sideA to start the process
  function proposeBet(uint _commitment) external payable {
    require(proposedBet[_commitment].value == 0, "there is already a bet on that commitment");
    require(msg.value > 0, "you need to actually bet something");
    proposedBet[_commitment].sideA = msg.sender;
    proposedBet[_commitment].value = msg.value;
    proposedBet[_commitment].placedAt = block.timestamp;
    // accepted is false by default
     emit BetProposed(_commitment, msg.value);
  } 

  // Called by sideB to continue
  function acceptBet(uint _commitment, uint _random) external payable {
    require(!proposedBet[_commitment].accepted,"Bet has already been accepted");
    require(proposedBet[_commitment].sideA != address(0),"Nobody made that bet");
    require(msg.value == proposedBet[_commitment].value, "Need to bet the same amount as sideA");
    acceptedBet[_commitment].sideB = msg.sender;
    acceptedBet[_commitment].acceptedAt = block.timestamp;
    acceptedBet[_commitment].randomB = _random;
    proposedBet[_commitment].accepted = true;
    emit BetAccepted(_commitment, proposedBet[_commitment].sideA);
  }

  // sideA reveals randomA, and we are able to see who won: 
  function reveal(uint _random) external {
    uint _commitment = uint256(keccak256(abi.encodePacked(_random)));  
    address payable _sideA = payable(msg.sender);
    address payable _sideB = payable(acceptedBet[_commitment].sideB);  
    // agreed random value is an XOR of the two random values,
    uint _agreedRandom = _random ^ acceptedBet[_commitment].randomB;
    uint _value = proposedBet[_commitment].value;
    require(proposedBet[_commitment].sideA == msg.sender, "Not a bet you placed or wrong value");
    require(proposedBet[_commitment].accepted, "Bet has not been accepted yet");

    // Pay and emit an event
    if (_agreedRandom % 2 == 0) {
       // sideA wins
      _sideA.transfer(2*_value);
        emit BetSettled(_commitment, _sideA, _sideB, _value);
    } else {
      // sideB wins
      _sideB.transfer(2*_value);
      emit BetSettled(_commitment, _sideB, _sideA, _value);
    }
    // Cleanup
    delete proposedBet[_commitment];
    delete acceptedBet[_commitment];
  }


  

}