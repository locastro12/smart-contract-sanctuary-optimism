// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IAggregator {
  function latestAnswer() external view returns (int256);

  function latestTimestamp() external view returns (uint256);

  function latestRound() external view returns (uint256);

  function getAnswer(uint256 roundId) external view returns (int256);

  function getTimestamp(uint256 roundId) external view returns (uint256);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../IOracleRelay.sol";
import "../../_external/chainlink/IAggregator.sol";

/// @title Oracle that wraps a chainlink oracle
/// @notice The oracle returns (chainlinkPrice) * mul / div
contract ChainlinkOracleRelay is IOracleRelay {
  IAggregator private immutable _aggregator;

  uint256 public immutable _multiply;
  uint256 public immutable _divide;

  /// @notice all values set at construction time
  /// @param  feed_address address of chainlink feed
  /// @param mul numerator of scalar
  /// @param div denominator of scalar
  constructor(address feed_address, uint256 mul, uint256 div) {
    _aggregator = IAggregator(feed_address);
    _multiply = mul;
    _divide = div;
  }

  /// @notice the current reported value of the oracle
  /// @return the current value
  /// @dev implementation in getLastSecond
  function currentValue() external view override returns (uint256) {
    return getLastSecond();
  }

  function getLastSecond() private view returns (uint256) {
    int256 latest = _aggregator.latestAnswer();
    require(latest > 0, "chainlink: px < 0");
    uint256 scaled = (uint256(latest) * _multiply) / _divide;
    return scaled;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

/// @title OracleRelay Interface
/// @notice Interface for interacting with OracleRelay
interface IOracleRelay {
  // returns  price with 18 decimals
  function currentValue() external view returns (uint256);
}