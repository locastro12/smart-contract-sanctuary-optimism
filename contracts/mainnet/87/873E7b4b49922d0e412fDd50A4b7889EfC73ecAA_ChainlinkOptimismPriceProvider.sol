// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeCast.sol)

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128) {
        require(value >= type(int128).min && value <= type(int128).max, "SafeCast: value doesn't fit in 128 bits");
        return int128(value);
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64) {
        require(value >= type(int64).min && value <= type(int64).max, "SafeCast: value doesn't fit in 64 bits");
        return int64(value);
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32) {
        require(value >= type(int32).min && value <= type(int32).max, "SafeCast: value doesn't fit in 32 bits");
        return int32(value);
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16) {
        require(value >= type(int16).min && value <= type(int16).max, "SafeCast: value doesn't fit in 16 bits");
        return int16(value);
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits.
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8) {
        require(value >= type(int8).min && value <= type(int8).max, "SafeCast: value doesn't fit in 8 bits");
        return int8(value);
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../interfaces/core/IAddressProvider.sol";

/**
 * @notice Contract module which provides access control mechanism, where
 * the governor account is granted with exclusive access to specific functions.
 * @dev Uses the AddressProvider to get the governor
 */
abstract contract Governable {
    IAddressProvider public constant addressProvider = IAddressProvider(0xfbA0816A81bcAbBf3829bED28618177a2bf0e82A);

    /// @dev Throws if called by any account other than the governor.
    modifier onlyGovernor() {
        require(msg.sender == addressProvider.governor(), "not-governor");
        _;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./ChainlinkPriceProvider.sol";

/**
 * @title Chainlink's price provider for optimism network
 */
contract ChainlinkOptimismPriceProvider is ChainlinkPriceProvider {
    constructor() {
        // optimism aggregators: https://docs.chain.link/data-feeds/price-feeds/addresses?network=optimism
        // Note: These are NOT all available aggregators, not adding them all to avoid too expensive deployment cost
        _setAggregator(0x7F5c764cBc14f9669B88837ca1490cCa17c31607, AggregatorV3Interface(0x16a9FA2FDa030272Ce99B29CF780dFA30361E0f3)); // USDC
        _setAggregator(0x68f180fcCe6836688e9084f035309E29Bf0A2095, AggregatorV3Interface(0x718A5788b89454aAE3A028AE9c111A29Be6c2a6F)); // WBTC
        _setAggregator(0x4200000000000000000000000000000000000042, AggregatorV3Interface(0x0D276FC14719f9292D5C1eA2198673d1f4269246)); // OP
        _setAggregator(0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1, AggregatorV3Interface(0x8dBa75e83DA73cc766A7e5a0ee71F656BAb470d6)); // DAI
        _setAggregator(0x4200000000000000000000000000000000000006, AggregatorV3Interface(0x13e3Ee699D1909E989722E753853AE30b17e08c5)); // WETH               
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "../interfaces/core/IChainlinkPriceProvider.sol";
import "./PriceProvider.sol";
import "../access/Governable.sol";

/**
 * @title ChainLink's price provider
 * @dev This contract wraps chainlink aggregators
 */
contract ChainlinkPriceProvider is IChainlinkPriceProvider, PriceProvider, Governable {
    using SafeCast for int256;

    uint256 public constant CHAINLINK_DECIMALS = 8;
    uint256 public constant TO_SCALE = 10**(USD_DECIMALS - CHAINLINK_DECIMALS);

    /**
     * @notice Aggregators map (token => aggregator)
     */
    mapping(address => AggregatorV3Interface) public aggregators;

    /// Emitted when an aggregator is updated
    event AggregatorUpdated(address token, AggregatorV3Interface oldAggregator, AggregatorV3Interface newAggregator);

    /// @inheritdoc IPriceProvider
    function getPriceInUsd(address token_)
        public
        view
        virtual
        override(IPriceProvider, PriceProvider)
        returns (uint256 _priceInUsd, uint256 _lastUpdatedAt)
    {
        AggregatorV3Interface _aggregator = aggregators[token_];
        require(address(_aggregator) != address(0), "token-without-aggregator");
        int256 _price;
        (, _price, , _lastUpdatedAt, ) = _aggregator.latestRoundData();
        return (_price.toUint256() * TO_SCALE, _lastUpdatedAt);
    }

    /// @inheritdoc IChainlinkPriceProvider
    function updateAggregator(address token_, AggregatorV3Interface aggregator_) external override onlyGovernor {
        require(token_ != address(0), "token-is-null");
        AggregatorV3Interface _current = aggregators[token_];
        require(aggregator_ != _current, "same-as-current");
        _setAggregator(token_, aggregator_);
        emit AggregatorUpdated(token_, _current, aggregator_);
    }

    function _setAggregator(address token_, AggregatorV3Interface aggregator_) internal {
        require(address(aggregator_) == address(0) || aggregator_.decimals() == CHAINLINK_DECIMALS, "invalid-decimals");
        aggregators[token_] = aggregator_;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../interfaces/core/IPriceProvider.sol";

/**
 * @title Price providers' super class that implements common functions
 */
abstract contract PriceProvider is IPriceProvider {
    uint256 public constant USD_DECIMALS = 18;

    /// @inheritdoc IPriceProvider
    function getPriceInUsd(address token_) public view virtual returns (uint256 _priceInUsd, uint256 _lastUpdatedAt);

    /// @inheritdoc IPriceProvider
    function quote(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        virtual
        override
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        )
    {
        uint256 _amountInUsd;
        (_amountInUsd, _tokenInLastUpdatedAt) = quoteTokenToUsd(tokenIn_, amountIn_);
        (_amountOut, _tokenOutLastUpdatedAt) = quoteUsdToToken(tokenOut_, _amountInUsd);
    }

    /// @inheritdoc IPriceProvider
    function quoteTokenToUsd(address token_, uint256 amountIn_)
        public
        view
        override
        returns (uint256 _amountOut, uint256 _lastUpdatedAt)
    {
        uint256 _price;
        (_price, _lastUpdatedAt) = getPriceInUsd(token_);
        _amountOut = (amountIn_ * _price) / 10**IERC20Metadata(token_).decimals();
    }

    /// @inheritdoc IPriceProvider
    function quoteUsdToToken(address token_, uint256 amountIn_)
        public
        view
        override
        returns (uint256 _amountOut, uint256 _lastUpdatedAt)
    {
        uint256 _price;
        (_price, _lastUpdatedAt) = getPriceInUsd(token_);
        _amountOut = (amountIn_ * 10**IERC20Metadata(token_).decimals()) / _price;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "./IStableCoinProvider.sol";
import "./IPriceProvidersAggregator.sol";

interface IAddressProvider {
    function governor() external view returns (address);

    function providersAggregator() external view returns (IPriceProvidersAggregator);

    function stableCoinProvider() external view returns (IStableCoinProvider);

    function updateProvidersAggregator(IPriceProvidersAggregator providersAggregator_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./IPriceProvider.sol";

interface IChainlinkPriceProvider is IPriceProvider {
    /**
     * @notice Update token's aggregator
     */
    function updateAggregator(address token_, AggregatorV3Interface aggregator_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IPriceProvider {
    /**
     * @notice Get USD (or equivalent) price of an asset
     * @param token_ The address of asset
     * @return _priceInUsd The USD price
     * @return _lastUpdatedAt Last updated timestamp
     */
    function getPriceInUsd(address token_) external view returns (uint256 _priceInUsd, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote
     * @param tokenIn_ The address of assetIn
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote in USD (or equivalent) amount
     * @param token_ The address of assetIn
     * @param amountIn_ Amount of input token.
     * @return amountOut_ Amount in USD
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteTokenToUsd(address token_, uint256 amountIn_)
        external
        view
        returns (uint256 amountOut_, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote from USD (or equivalent) amount to amount of token
     * @param token_ The address of assetOut
     * @param amountIn_ Input amount in USD
     * @return _amountOut Output amount of token
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteUsdToToken(address token_, uint256 amountIn_)
        external
        view
        returns (uint256 _amountOut, uint256 _lastUpdatedAt);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../../libraries/DataTypes.sol";
import "./IPriceProvider.sol";

/**
 * @notice PriceProvidersAggregator interface
 * @dev Worth noting that the `_lastUpdatedAt` logic depends on the underlying price provider. In summary:
 * ChainLink: returns the last updated date from the aggregator
 * UniswapV2: returns the date of the latest pair oracle update
 * UniswapV3: assumes that the price is always updated (returns block.timestamp)
 * Flux: returns the last updated date from the aggregator
 * Umbrella (FCD): returns the last updated date returned from their oracle contract
 * Umbrella (Passport): returns the date of the latest pallet submission
 * Anytime that a quote performs more than one query, it uses the oldest date as the `_lastUpdatedAt`.
 * See more: https://github.com/bloqpriv/one-oracle/issues/64
 */
interface IPriceProvidersAggregator {
    /**
     * @notice Get USD (or equivalent) price of an asset
     * @param provider_ The price provider to get quote from
     * @param token_ The address of asset
     * @return _priceInUsd The USD price
     * @return _lastUpdatedAt Last updated timestamp
     */
    function getPriceInUsd(DataTypes.Provider provider_, address token_)
        external
        view
        returns (uint256 _priceInUsd, uint256 _lastUpdatedAt);

    /**
     * @notice Provider Providers' mapping
     */
    function priceProviders(DataTypes.Provider provider_) external view returns (IPriceProvider _priceProvider);

    /**
     * @notice Get quote
     * @param provider_ The price provider to get quote from
     * @param tokenIn_ The address of assetIn
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        DataTypes.Provider provider_,
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote
     * @dev If providers aren't the same, uses native token as "bridge"
     * @param providerIn_ The price provider to get quote for the tokenIn
     * @param tokenIn_ The address of assetIn
     * @param providerOut_ The price provider to get quote for the tokenOut
     * @param tokenOut_ The address of assetOut
     * @param amountIn_ Amount of input token
     * @return _amountOut Amount out
     * @return _tokenInLastUpdatedAt Last updated timestamp of `tokenIn_`
     * @return _nativeTokenLastUpdatedAt Last updated timestamp of native token (i.e. WETH) used when providers aren't the same
     * @return _tokenOutLastUpdatedAt Last updated timestamp of `tokenOut_`
     */
    function quote(
        DataTypes.Provider providerIn_,
        address tokenIn_,
        DataTypes.Provider providerOut_,
        address tokenOut_,
        uint256 amountIn_
    )
        external
        view
        returns (
            uint256 _amountOut,
            uint256 _tokenInLastUpdatedAt,
            uint256 _nativeTokenLastUpdatedAt,
            uint256 _tokenOutLastUpdatedAt
        );

    /**
     * @notice Get quote in USD (or equivalent) amount
     * @param provider_ The price provider to get quote from
     * @param token_ The address of assetIn
     * @param amountIn_ Amount of input token.
     * @return amountOut_ Amount in USD
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteTokenToUsd(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view returns (uint256 amountOut_, uint256 _lastUpdatedAt);

    /**
     * @notice Get quote from USD (or equivalent) amount to amount of token
     * @param provider_ The price provider to get quote from
     * @param token_ The address of assetOut
     * @param amountIn_ Input amount in USD
     * @return _amountOut Output amount of token
     * @return _lastUpdatedAt Last updated timestamp
     */
    function quoteUsdToToken(
        DataTypes.Provider provider_,
        address token_,
        uint256 amountIn_
    ) external view returns (uint256 _amountOut, uint256 _lastUpdatedAt);

    /**
     * @notice Set a price provider
     * @dev Administrative function
     * @param provider_ The provider (from enum)
     * @param priceProvider_ The price provider contract
     */
    function setPriceProvider(DataTypes.Provider provider_, IPriceProvider priceProvider_) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IStableCoinProvider {
    /**
     * @notice Return the stable coin if pegged
     * @dev Check price relation between both stable coins and revert if peg is too loose
     * @return _stableCoin The primary stable coin if pass all checks
     */
    function getStableCoinIfPegged() external view returns (address _stableCoin);

    /**
     * @notice Convert given amount of stable coin to USD representation (18 decimals)
     */
    function toUsdRepresentation(uint256 stableCoinAmount_) external view returns (uint256 _usdAmount);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library DataTypes {
    /**
     * @notice Price providers enumeration
     */
    enum Provider {
        NONE,
        CHAINLINK,
        UNISWAP_V3,
        UNISWAP_V2,
        SUSHISWAP,
        TRADERJOE,
        PANGOLIN,
        QUICKSWAP,
        UMBRELLA_FIRST_CLASS,
        UMBRELLA_PASSPORT,
        FLUX
    }

    enum ExchangeType {
        UNISWAP_V2,
        SUSHISWAP,
        TRADERJOE,
        PANGOLIN,
        QUICKSWAP,
        UNISWAP_V3,
        PANCAKE_SWAP,
        CURVE
    }

    enum SwapType {
        EXACT_INPUT,
        EXACT_OUTPUT
    }
}