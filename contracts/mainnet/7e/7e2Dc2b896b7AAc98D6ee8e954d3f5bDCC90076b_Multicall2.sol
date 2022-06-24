/**
 *Submitted for verification at optimistic.etherscan.io on 2022-06-24
*/

/**
 *Submitted for verification at Etherscan.io on 2021-04-29
*/

/**
 *Submitted for verification at Etherscan.io on 2021-03-23
*/

pragma solidity >=0.5.0;
pragma experimental ABIEncoderV2;

/**
 * @title IOVM_L1BlockNumber
 */
interface IOVM_L1BlockNumber {
    /********************
     * Public Functions *
     ********************/

    function getL1BlockNumber() external view returns (uint256);
}

/// @title Multicall2 - Aggregate results from multiple read-only function calls
/// @author Michael Elliot <[email protected]>
/// @author Joshua Levine <[email protected]>
/// @author Nick Johnson <[email protected]>

contract Multicall2 {
    struct Call {
        address target;
        bytes callData;
    }
    struct Result {
        bool success;
        bytes returnData;
    }

    function aggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        blockNumber = _getBlockNumber();
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success, "Multicall aggregate: call failed");
            returnData[i] = ret;
        }
    }
    function blockAndAggregate(Call[] memory calls) public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        (blockNumber, blockHash, returnData) = tryBlockAndAggregate(true, calls);
    }
    function getBlockHash(uint256 blockNumber) public view returns (bytes32 blockHash) {
        blockHash = blockhash(blockNumber);
    }
    function getBlockNumber() public view returns (uint256 blockNumber) {
        blockNumber = _getBlockNumber();
    }
    function getCurrentBlockCoinbase() public view returns (address coinbase) {
        coinbase = block.coinbase;
    }
    function getCurrentBlockDifficulty() public view returns (uint256 difficulty) {
        difficulty = block.difficulty;
    }
    function getCurrentBlockGasLimit() public view returns (uint256 gaslimit) {
        gaslimit = block.gaslimit;
    }
    function getCurrentBlockTimestamp() public view returns (uint256 timestamp) {
        timestamp = block.timestamp;
    }
    function getEthBalance(address addr) public view returns (uint256 balance) {
        balance = addr.balance;
    }
    function getLastBlockHash() public view returns (bytes32 blockHash) {
        blockHash = blockhash(_getBlockNumber() - 1);
    }
    function tryAggregate(bool requireSuccess, Call[] memory calls) public returns (Result[] memory returnData) {
        returnData = new Result[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);

            if (requireSuccess) {
                require(success, "Multicall2 aggregate: call failed");
            }

            returnData[i] = Result(success, ret);
        }
    }
    function tryBlockAndAggregate(bool requireSuccess, Call[] memory calls) public returns (uint256 blockNumber, bytes32 blockHash, Result[] memory returnData) {
        blockNumber = _getBlockNumber();
        blockHash = blockhash(_getBlockNumber());
        returnData = tryAggregate(requireSuccess, calls);
    }

    /**
     * @dev Function to simply retrieve block number.
     */
    function _getBlockNumber() internal view returns (uint) {
        return IOVM_L1BlockNumber(
            0x4200000000000000000000000000000000000013
        ).getL1BlockNumber();
    }
}