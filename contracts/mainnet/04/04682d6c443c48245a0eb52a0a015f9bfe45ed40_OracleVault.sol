// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Uint256x256Math} from "joe-v2/libraries/math/Uint256x256Math.sol";

import {BaseVault} from "./BaseVault.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IOracleVault} from "./interfaces/IOracleVault.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";

/**
 * @title Liquidity Book Oracle Vault contract
 * @author Trader Joe
 * @notice This contract is used to interact with the Liquidity Book Pair contract.
 * The two tokens of the pair has to have an oracle.
 * The oracle is used to get the price of the token X in token Y.
 * The price is used to value the balance of the strategy and mint shares accordingly.
 * The immutable data should be encoded as follow:
 * - 0x00: 20 bytes: The address of the LB pair.
 * - 0x14: 20 bytes: The address of the token X.
 * - 0x28: 20 bytes: The address of the token Y.
 * - 0x3C: 1 bytes: The decimals of the token X.
 * - 0x3D: 1 bytes: The decimals of the token Y.
 * - 0x3E: 20 bytes: The address of the oracle of the token X.
 * - 0x52: 20 bytes: The address of the oracle of the token Y.
 */
contract OracleVault is BaseVault, IOracleVault {
    using Uint256x256Math for uint256;

    uint8 private constant _PRICE_OFFSET = 128;

    /**
     * @dev Constructor of the contract.
     * @param factory Address of the factory.
     */
    constructor(IVaultFactory factory) BaseVault(factory) {}

    /**
     * @dev Returns the address of the oracle of the token X.
     * @return oracleX The address of the oracle of the token X.
     */
    function getOracleX() external pure override returns (IAggregatorV3 oracleX) {
        return _dataFeedX();
    }

    /**
     * @dev Returns the address of the oracle of the token Y.
     * @return oracleY The address of the oracle of the token Y.
     */
    function getOracleY() external pure override returns (IAggregatorV3 oracleY) {
        return _dataFeedY();
    }

    /**
     * @dev Returns the price of token X in token Y, in 128.128 binary fixed point format.
     * @return price The price of token X in token Y in 128.128 binary fixed point format.
     */
    function getPrice() external view override returns (uint256 price) {
        return _getPrice();
    }

    /**
     * @dev Returns the data feed of the token X.
     * @return dataFeedX The data feed of the token X.
     */
    function _dataFeedX() internal pure returns (IAggregatorV3 dataFeedX) {
        return IAggregatorV3(_getArgAddress(62));
    }

    /**
     * @dev Returns the data feed of the token Y.
     * @return dataFeedY The data feed of the token Y.
     */
    function _dataFeedY() internal pure returns (IAggregatorV3 dataFeedY) {
        return IAggregatorV3(_getArgAddress(82));
    }

    /**
     * @dev Returns the price of a token using its oracle.
     * @param dataFeed The data feed of the token.
     * @return uintPrice The oracle latest answer.
     */
    function _getOraclePrice(IAggregatorV3 dataFeed) internal view returns (uint256 uintPrice) {
        (, int256 price,, uint256 updatedAt,) = dataFeed.latestRoundData();

        if (updatedAt == 0 || updatedAt + 24 hours < block.timestamp) revert OracleVault__StalePrice();
        if (price <= 0 || (uintPrice = uint256(price)) > type(uint96).max) revert OracleVault__InvalidPrice();
    }

    /**
     * @dev Returns the price of token X in token Y.
     * WARNING: Both oracles needs to return the same decimals and use the same quote currency.
     * @return price The price of token X in token Y.
     */
    function _getPrice() internal view returns (uint256 price) {
        uint256 scaledPriceX = _getOraclePrice(_dataFeedX()) * 10 ** _decimalsY();
        uint256 scaledPriceY = _getOraclePrice(_dataFeedY()) * 10 ** _decimalsX();

        // Essentially does `price = (priceX / 1eDecimalsX) / (priceY / 1eDecimalsY)`
        // with 128.128 binary fixed point arithmetic.
        price = scaledPriceX.shiftDivRoundDown(_PRICE_OFFSET, scaledPriceY);

        if (price == 0) revert OracleVault__InvalidPrice();
    }

    /**
     * @dev Returns the shares that will be minted when depositing `expectedAmountX` of token X and
     * `expectedAmountY` of token Y. The effective amounts will never be greater than the input amounts.
     * @param strategy The strategy to deposit to.
     * @param amountX The amount of token X to deposit.
     * @param amountY The amount of token Y to deposit.
     * @return shares The amount of shares that will be minted.
     * @return effectiveX The effective amount of token X that will be deposited.
     * @return effectiveY The effective amount of token Y that will be deposited.
     */
    function _previewShares(IStrategy strategy, uint256 amountX, uint256 amountY)
        internal
        view
        override
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY)
    {
        if (amountX == 0 && amountY == 0) return (0, 0, 0);

        uint256 price = _getPrice();
        uint256 totalShares = totalSupply();

        uint256 valueInY = _getValueInY(price, amountX, amountY);

        if (totalShares == 0) return (valueInY * _SHARES_PRECISION, amountX, amountY);

        (uint256 totalX, uint256 totalY) = _getBalances(strategy);
        uint256 totalValueInY = _getValueInY(price, totalX, totalY);

        shares = valueInY.mulDivRoundDown(totalShares, totalValueInY);

        return (shares, amountX, amountY);
    }

    /**
     * @dev Returns the value of amounts in token Y.
     * @param price The price of token X in token Y.
     * @param amountX The amount of token X.
     * @param amountY The amount of token Y.
     * @return valueInY The value of amounts in token Y.
     */
    function _getValueInY(uint256 price, uint256 amountX, uint256 amountY) internal pure returns (uint256 valueInY) {
        uint256 amountXInY = price.mulShiftRoundDown(amountX, _PRICE_OFFSET);
        return amountXInY + amountY;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Uint256x256 Math Library
 * @author Trader Joe
 * @notice Helper contract used for full precision calculations
 */
library Uint256x256Math {
    error Uint256x256Math__MulShiftOverflow();
    error Uint256x256Math__MulDivOverflow();

    /**
     * @notice Calculates floor(x*y/denominator) with full precision
     * The result will be rounded down
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The denominator cannot be zero
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param denominator The divisor as an uint256
     * @return result The result as an uint256
     */
    function mulDivRoundDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        (uint256 prod0, uint256 prod1) = _getMulProds(x, y);

        return _getEndOfDivRoundDown(x, y, denominator, prod0, prod1);
    }

    /**
     * @notice Calculates ceil(x*y/denominator) with full precision
     * The result will be rounded up
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The denominator cannot be zero
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param denominator The divisor as an uint256
     * @return result The result as an uint256
     */
    function mulDivRoundUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = mulDivRoundDown(x, y, denominator);
        if (mulmod(x, y, denominator) != 0) result += 1;
    }

    /**
     * @notice Calculates floor(x * y / 2**offset) with full precision
     * The result will be rounded down
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The offset needs to be strictly lower than 256
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param offset The offset as an uint256, can't be greater than 256
     * @return result The result as an uint256
     */
    function mulShiftRoundDown(uint256 x, uint256 y, uint8 offset) internal pure returns (uint256 result) {
        (uint256 prod0, uint256 prod1) = _getMulProds(x, y);

        if (prod0 != 0) result = prod0 >> offset;
        if (prod1 != 0) {
            // Make sure the result is less than 2^256.
            if (prod1 >= 1 << offset) revert Uint256x256Math__MulShiftOverflow();

            unchecked {
                result += prod1 << (256 - offset);
            }
        }
    }

    /**
     * @notice Calculates floor(x * y / 2**offset) with full precision
     * The result will be rounded down
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The offset needs to be strictly lower than 256
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param offset The offset as an uint256, can't be greater than 256
     * @return result The result as an uint256
     */
    function mulShiftRoundUp(uint256 x, uint256 y, uint8 offset) internal pure returns (uint256 result) {
        result = mulShiftRoundDown(x, y, offset);
        if (mulmod(x, y, 1 << offset) != 0) result += 1;
    }

    /**
     * @notice Calculates floor(x << offset / y) with full precision
     * The result will be rounded down
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The offset needs to be strictly lower than 256
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param offset The number of bit to shift x as an uint256
     * @param denominator The divisor as an uint256
     * @return result The result as an uint256
     */
    function shiftDivRoundDown(uint256 x, uint8 offset, uint256 denominator) internal pure returns (uint256 result) {
        uint256 prod0;
        uint256 prod1;

        prod0 = x << offset; // Least significant 256 bits of the product
        unchecked {
            prod1 = x >> (256 - offset); // Most significant 256 bits of the product
        }

        return _getEndOfDivRoundDown(x, 1 << offset, denominator, prod0, prod1);
    }

    /**
     * @notice Calculates ceil(x << offset / y) with full precision
     * The result will be rounded up
     * @dev Credit to Remco Bloemen under MIT license https://xn--2-umb.com/21/muldiv
     * Requirements:
     * - The offset needs to be strictly lower than 256
     * - The result must fit within uint256
     * Caveats:
     * - This function does not work with fixed-point numbers
     * @param x The multiplicand as an uint256
     * @param offset The number of bit to shift x as an uint256
     * @param denominator The divisor as an uint256
     * @return result The result as an uint256
     */
    function shiftDivRoundUp(uint256 x, uint8 offset, uint256 denominator) internal pure returns (uint256 result) {
        result = shiftDivRoundDown(x, offset, denominator);
        if (mulmod(x, 1 << offset, denominator) != 0) result += 1;
    }

    /**
     * @notice Helper function to return the result of `x * y` as 2 uint256
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @return prod0 The least significant 256 bits of the product
     * @return prod1 The most significant 256 bits of the product
     */
    function _getMulProds(uint256 x, uint256 y) private pure returns (uint256 prod0, uint256 prod1) {
        // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
        // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
        // variables such that product = prod1 * 2^256 + prod0.
        assembly {
            let mm := mulmod(x, y, not(0))
            prod0 := mul(x, y)
            prod1 := sub(sub(mm, prod0), lt(mm, prod0))
        }
    }

    /**
     * @notice Helper function to return the result of `x * y / denominator` with full precision
     * @param x The multiplicand as an uint256
     * @param y The multiplier as an uint256
     * @param denominator The divisor as an uint256
     * @param prod0 The least significant 256 bits of the product
     * @param prod1 The most significant 256 bits of the product
     * @return result The result as an uint256
     */
    function _getEndOfDivRoundDown(uint256 x, uint256 y, uint256 denominator, uint256 prod0, uint256 prod1)
        private
        pure
        returns (uint256 result)
    {
        // Handle non-overflow cases, 256 by 256 division
        if (prod1 == 0) {
            unchecked {
                result = prod0 / denominator;
            }
        } else {
            // Make sure the result is less than 2^256. Also prevents denominator == 0
            if (prod1 >= denominator) revert Uint256x256Math__MulDivOverflow();

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1
            // See https://cs.stackexchange.com/q/138556/92363
            unchecked {
                // Does not overflow because the denominator cannot be zero at this stage in the function
                uint256 lpotdod = denominator & (~denominator + 1);
                assembly {
                    // Divide denominator by lpotdod.
                    denominator := div(denominator, lpotdod)

                    // Divide [prod1 prod0] by lpotdod.
                    prod0 := div(prod0, lpotdod)

                    // Flip lpotdod such that it is 2^256 / lpotdod. If lpotdod is zero, then it becomes one
                    lpotdod := add(div(sub(0, lpotdod), lpotdod), 1)
                }

                // Shift in bits from prod1 into prod0
                prod0 |= prod1 * lpotdod;

                // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
                // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
                // four bits. That is, denominator * inv = 1 mod 2^4
                uint256 inverse = (3 * denominator) ^ 2;

                // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
                // in modular arithmetic, doubling the correct bits in each step
                inverse *= 2 - denominator * inverse; // inverse mod 2^8
                inverse *= 2 - denominator * inverse; // inverse mod 2^16
                inverse *= 2 - denominator * inverse; // inverse mod 2^32
                inverse *= 2 - denominator * inverse; // inverse mod 2^64
                inverse *= 2 - denominator * inverse; // inverse mod 2^128
                inverse *= 2 - denominator * inverse; // inverse mod 2^256

                // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
                // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
                // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
                // is no longer required.
                result = prod0 * inverse;
            }
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Clone} from "joe-v2/libraries/Clone.sol";
import {ERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";
import {Uint256x256Math} from "joe-v2/libraries/math/Uint256x256Math.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SafeCast} from "joe-v2/libraries/math/SafeCast.sol";

import {IBaseVault} from "./interfaces/IBaseVault.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {IVaultFactory} from "./interfaces/IVaultFactory.sol";
import {IWNative} from "./interfaces/IWNative.sol";

/**
 * @title Liquidity Book Base Vault contract
 * @author Trader Joe
 * @notice This contract is used to interact with the Liquidity Book Pair contract. It should be inherited by a Vault
 * contract that defines the `_previewShares` function to calculate the amount of shares to mint.
 * The immutable data should be encoded as follows:
 * - 0x00: 20 bytes: The address of the LB pair.
 * - 0x14: 20 bytes: The address of the token X.
 * - 0x28: 20 bytes: The address of the token Y.
 * - 0x3C: 1 bytes: The decimals of the token X.
 * - 0x3D: 1 bytes: The decimals of the token Y.
 */
abstract contract BaseVault is Clone, ERC20Upgradeable, ReentrancyGuardUpgradeable, IBaseVault {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using Uint256x256Math for uint256;
    using SafeCast for uint256;

    uint8 internal constant _SHARES_DECIMALS = 6;
    uint256 internal constant _SHARES_PRECISION = 10 ** _SHARES_DECIMALS;

    IVaultFactory private immutable _factory;
    address private immutable _wnative;

    IStrategy private _strategy;
    bool private _depositsPaused;
    bool private _whitelistStatus;

    mapping(address => bool) private _whitelistedUsers;

    QueuedWithdrawal[] private _queuedWithdrawalsByRound;

    uint256 private _totalAmountX;
    uint256 private _totalAmountY;

    /**
     * @dev Modifier to check if the caller is the factory.
     */
    modifier onlyFactory() {
        if (msg.sender != address(_factory)) revert BaseVault__OnlyFactory();
        _;
    }

    /**
     * @dev Modifier to check if deposits are allowed for the sender.
     */
    modifier depositsAllowed() {
        if (_depositsPaused) revert BaseVault__DepositsPaused();
        if (_whitelistStatus && !_whitelistedUsers[msg.sender]) revert BaseVault__NotWhitelisted(msg.sender);
        _;
    }

    /**
     * @dev Modifier to check if one of the two vault tokens is the wrapped native token.
     */
    modifier onlyVaultWithNativeToken() {
        if (address(_tokenX()) != _wnative && address(_tokenY()) != _wnative) revert BaseVault__NoNativeToken();
        _;
    }

    /**
     * @dev Modifier to check if the recipient is not the address(0)
     */
    modifier onlyValidRecipient(address recipient) {
        if (recipient == address(0)) revert BaseVault__InvalidRecipient();
        _;
    }

    /**
     * @dev Modifier to check that the amount of shares is greater than zero.
     */
    modifier NonZeroShares(uint256 shares) {
        if (shares == 0) revert BaseVault__ZeroShares();
        _;
    }

    /**
     * @dev Constructor of the contract.
     * @param factory Address of the factory.
     */
    constructor(IVaultFactory factory) {
        _factory = factory;
        _wnative = factory.getWNative();
    }

    /**
     * @dev Receive function. Mainly added to silence the compiler warning.
     * Highly unlikely to be used as the base vault needs at least 62 bytes of immutable data added to the payload
     * (3 addresses and 2 bytes for length), so this function should never be called.
     */
    receive() external payable {
        if (msg.sender != _wnative) revert BaseVault__OnlyWNative();
    }

    /**
     * @notice Allows the contract to receive native tokens from the WNative contract.
     * @dev We can't use the `receive` function because the immutable clone library adds calldata to the payload
     * that are taken as a function signature and parameters.
     */
    fallback() external payable {
        if (msg.sender != _wnative) revert BaseVault__OnlyWNative();
    }

    /**
     * @dev Initializes the contract.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     */
    function initialize(string memory name, string memory symbol) public virtual override initializer {
        __ERC20_init(name, symbol);
        __ReentrancyGuard_init();

        // Initialize the first round of queued withdrawals.
        _queuedWithdrawalsByRound.push();
    }

    /**
     * @notice Returns the decimals of the vault token.
     * @return The decimals of the vault token.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimalsY() + _SHARES_DECIMALS;
    }

    /**
     * @dev Returns the address of the factory.
     * @return The address of the factory.
     */
    function getFactory() public view virtual override returns (IVaultFactory) {
        return _factory;
    }

    /**
     * @dev Returns the address of the pair.
     * @return The address of the pair.
     */
    function getPair() public pure virtual override returns (ILBPair) {
        return _pair();
    }

    /**
     * @dev Returns the address of the token X.
     * @return The address of the token X.
     */
    function getTokenX() public pure virtual override returns (IERC20Upgradeable) {
        return _tokenX();
    }

    /**
     * @dev Returns the address of the token Y.
     * @return The address of the token Y.
     */
    function getTokenY() public pure virtual override returns (IERC20Upgradeable) {
        return _tokenY();
    }

    /**
     * @dev Returns the address of the current strategy.
     * @return The address of the strategy
     */
    function getStrategy() public view virtual override returns (IStrategy) {
        return _strategy;
    }

    /**
     * @dev Returns the AUM annual fee of the strategy.
     * @return
     */
    function getAumAnnualFee() public view virtual override returns (uint256) {
        IStrategy strategy = _strategy;

        return address(strategy) == address(0) ? 0 : strategy.getAumAnnualFee();
    }

    /**
     * @dev Returns the range of the strategy.
     * @return low The lower bound of the range.
     * @return upper The upper bound of the range.
     */
    function getRange() public view virtual override returns (uint24 low, uint24 upper) {
        IStrategy strategy = _strategy;

        return address(strategy) == address(0) ? (0, 0) : strategy.getRange();
    }

    /**
     * @dev Returns operators of the strategy.
     * @return defaultOperator The default operator.
     * @return operator The operator.
     */
    function getOperators() public view virtual override returns (address defaultOperator, address operator) {
        IStrategy strategy = _strategy;

        defaultOperator = _factory.getDefaultOperator();
        operator = address(strategy) == address(0) ? address(0) : strategy.getOperator();
    }

    /**
     * @dev Returns the total balances of the pair.
     * @return amountX The total balance of token X.
     * @return amountY The total balance of token Y.
     */
    function getBalances() public view virtual override returns (uint256 amountX, uint256 amountY) {
        (amountX, amountY) = _getBalances(_strategy);
    }

    /**
     * @dev Preview the amount of shares to be minted.
     * @param amountX The amount of token X to be deposited.
     * @param amountY The amount of token Y to be deposited.
     * @return shares The amount of shares to be minted.
     * @return effectiveX The effective amount of token X to be deposited.
     * @return effectiveY The effective amount of token Y to be deposited.
     */
    function previewShares(uint256 amountX, uint256 amountY)
        public
        view
        virtual
        override
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY)
    {
        return _previewShares(_strategy, amountX, amountY);
    }

    /**
     * @dev Preview the amount of tokens to be redeemed on withdrawal.
     * @param shares The amount of shares to be redeemed.
     * @return amountX The amount of token X to be redeemed.
     * @return amountY The amount of token Y to be redeemed.
     */
    function previewAmounts(uint256 shares) public view virtual override returns (uint256 amountX, uint256 amountY) {
        return _previewAmounts(_strategy, shares, totalSupply());
    }

    /**
     * @notice Returns if the deposits are paused.
     * @return paused True if the deposits are paused.
     */
    function isDepositsPaused() public view virtual override returns (bool paused) {
        return _depositsPaused;
    }

    /**
     * @notice Returns if the vault is in whitelist mode.
     * @return whitelist True if the vault is in whitelist mode.
     */
    function isWhitelistedOnly() public view virtual override returns (bool whitelist) {
        return _whitelistStatus;
    }

    /**
     * @notice Returns true if the user is whitelisted or if the vault is not in whitelist mode.
     * @param user The user.
     * @return whitelisted True if the user is whitelisted or if the vault is not in whitelist mode.
     */
    function isWhitelisted(address user) public view virtual override returns (bool whitelisted) {
        return !_whitelistStatus || _whitelistedUsers[user];
    }

    /**
     * @notice Returns the current round of queued withdrawals.
     * @return round The current round of queued withdrawals.
     */
    function getCurrentRound() public view virtual override returns (uint256 round) {
        return _queuedWithdrawalsByRound.length - 1;
    }

    /**
     * @notice Returns the queued withdrawal of the round for an user.
     * @param round The round.
     * @param user The user.
     * @return shares The amount of shares that are queued for withdrawal.
     */
    function getQueuedWithdrawal(uint256 round, address user) public view virtual override returns (uint256 shares) {
        return _queuedWithdrawalsByRound[round].userWithdrawals[user];
    }

    /**
     * @notice Returns the total shares that were queued for the round.
     * @param round The round.
     * @return totalQueuedShares The total shares that were queued for the round.
     */
    function getTotalQueuedWithdrawal(uint256 round) public view virtual override returns (uint256 totalQueuedShares) {
        return _queuedWithdrawalsByRound[round].totalQueuedShares;
    }

    /**
     * @notice Returns the total shares that were queued for the current round.
     * @return totalQueuedShares The total shares that were queued for the current round.
     */
    function getCurrentTotalQueuedWithdrawal() public view virtual override returns (uint256 totalQueuedShares) {
        return _queuedWithdrawalsByRound[_queuedWithdrawalsByRound.length - 1].totalQueuedShares;
    }

    /**
     * @notice Returns the amounts that can be redeemed for an user on the round.
     * @param round The round.
     * @param user The user.
     * @return amountX The amount of token X that can be redeemed.
     * @return amountY The amount of token Y that can be redeemed.
     */
    function getRedeemableAmounts(uint256 round, address user)
        public
        view
        virtual
        override
        returns (uint256 amountX, uint256 amountY)
    {
        // Get the queued withdrawal of the round.
        QueuedWithdrawal storage queuedWithdrawal = _queuedWithdrawalsByRound[round];

        // Get the total amount of tokens that were queued for the round.
        uint256 totalAmountX = queuedWithdrawal.totalAmountX;
        uint256 totalAmountY = queuedWithdrawal.totalAmountY;

        // Get the shares that were queued for the user and the total of shares.
        uint256 shares = queuedWithdrawal.userWithdrawals[user];
        uint256 totalShares = queuedWithdrawal.totalQueuedShares;

        // Calculate the amounts to be redeemed.
        if (totalShares > 0) {
            amountX = totalAmountX.mulDivRoundDown(shares, totalShares);
            amountY = totalAmountY.mulDivRoundDown(shares, totalShares);
        }
    }

    /**
     * @dev Deposits tokens to the strategy.
     * @param amountX The amount of token X to be deposited.
     * @param amountY The amount of token Y to be deposited.
     * @return shares The amount of shares to be minted.
     * @return effectiveX The effective amount of token X to be deposited.
     * @return effectiveY The effective amount of token Y to be deposited.
     */
    function deposit(uint256 amountX, uint256 amountY)
        public
        virtual
        override
        nonReentrant
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY)
    {
        // Calculate the shares and effective amounts, also returns the strategy to save gas.
        IStrategy strategy;
        (strategy, shares, effectiveX, effectiveY) = _deposit(amountX, amountY);

        // Transfer the tokens to the strategy
        if (effectiveX > 0) _tokenX().safeTransferFrom(msg.sender, address(strategy), effectiveX);
        if (effectiveY > 0) _tokenY().safeTransferFrom(msg.sender, address(strategy), effectiveY);
    }

    /**
     * @dev Deposits native tokens and send the tokens to the strategy.
     * @param amountX The amount of token X to be deposited.
     * @param amountY The amount of token Y to be deposited.
     * @return shares The amount of shares to be minted.
     * @return effectiveX The effective amount of token X to be deposited.
     * @return effectiveY The effective amount of token Y to be deposited.
     */
    function depositNative(uint256 amountX, uint256 amountY)
        public
        payable
        virtual
        override
        nonReentrant
        onlyVaultWithNativeToken
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY)
    {
        (IERC20Upgradeable tokenX, IERC20Upgradeable tokenY) = (_tokenX(), _tokenY());

        address wnative = _wnative;
        bool isNativeX = address(tokenX) == wnative;

        // Check that the native token amount matches the amount of native tokens sent.
        if (isNativeX && amountX != msg.value || !isNativeX && amountY != msg.value) {
            revert BaseVault__InvalidNativeAmount();
        }

        // Calculate the shares and effective amounts
        IStrategy strategy;
        (strategy, shares, effectiveX, effectiveY) = _deposit(amountX, amountY);

        // Calculate the effective native amount and transfer the other token to the strategy.
        uint256 effectiveNative;
        if (isNativeX) {
            // Transfer the token Y to the strategy and cache the native amount.
            effectiveNative = effectiveX;
            if (effectiveY > 0) tokenY.safeTransferFrom(msg.sender, address(strategy), effectiveY);
        } else {
            // Transfer the token X to the strategy and cache the native amount.
            if (effectiveX > 0) tokenX.safeTransferFrom(msg.sender, address(strategy), effectiveX);
            effectiveNative = effectiveY;
        }

        // Deposit and send wnative to the strategy.
        if (effectiveNative > 0) {
            IWNative(wnative).deposit{value: effectiveNative}();
            IERC20Upgradeable(wnative).safeTransfer(address(strategy), effectiveNative);
        }

        // Refund dust native tokens, if any.
        if (msg.value > effectiveNative) {
            unchecked {
                _transferNative(msg.sender, msg.value - effectiveNative);
            }
        }
    }

    /**
     * @notice Queues withdrawal for `recipient`. The withdrawal will be effective after the next
     * rebalance. The user can withdraw the tokens after the rebalance, this allows users to withdraw
     * from LB positions without having to pay the gas price.
     * @param shares The shares to be queued for withdrawal.
     * @param recipient The address that will receive the withdrawn tokens after the rebalance.
     * @return round The round of the withdrawal.
     */
    function queueWithdrawal(uint256 shares, address recipient)
        public
        virtual
        override
        nonReentrant
        onlyValidRecipient(recipient)
        NonZeroShares(shares)
        returns (uint256 round)
    {
        // Check that the strategy is set.
        address strategy = address(_strategy);
        if (strategy == address(0)) revert BaseVault__InvalidStrategy();

        // Transfer the shares to the strategy, will revert if the user does not have enough shares.
        _transfer(msg.sender, strategy, shares);

        // Get the current round and the queued withdrawals for the round.
        round = _queuedWithdrawalsByRound.length - 1;
        QueuedWithdrawal storage queuedWithdrawals = _queuedWithdrawalsByRound[round];

        // Updates the total queued shares and the shares for the user.
        queuedWithdrawals.totalQueuedShares += shares;
        unchecked {
            // Can't overflow as the user can't have more shares than the total.
            queuedWithdrawals.userWithdrawals[recipient] += shares;
        }

        emit WithdrawalQueued(msg.sender, recipient, round, shares);
    }

    /**
     * @notice Cancels a queued withdrawal of `shares`. Cancelling a withdrawal is
     * only possible before the next rebalance. The user can cancel the withdrawal if they want to
     * stay in the vault. They will receive the vault shares back.
     * @param shares The shares to be cancelled for withdrawal.
     * @return round The round of the withdrawal that was cancelled.
     */
    function cancelQueuedWithdrawal(uint256 shares)
        public
        virtual
        override
        nonReentrant
        NonZeroShares(shares)
        returns (uint256 round)
    {
        // Check that the strategy is set.
        address strategy = address(_strategy);
        if (strategy == address(0)) revert BaseVault__InvalidStrategy();

        // Get the current round and the queued withdrawals for the round.
        round = _queuedWithdrawalsByRound.length - 1;
        QueuedWithdrawal storage queuedWithdrawals = _queuedWithdrawalsByRound[round];

        // Check that the user has enough shares queued for withdrawal.
        uint256 maxShares = queuedWithdrawals.userWithdrawals[msg.sender];
        if (shares > maxShares) revert BaseVault__MaxSharesExceeded();

        // Updates the total queued shares and the shares for the user.
        unchecked {
            // Can't underflow as the user can't have more shares than the total, and its shares
            // were already checked.
            queuedWithdrawals.userWithdrawals[msg.sender] = maxShares - shares;
            queuedWithdrawals.totalQueuedShares -= shares;
        }

        // Transfer the shares back to the user.
        _transfer(strategy, msg.sender, shares);

        emit WithdrawalCancelled(msg.sender, msg.sender, round, shares);
    }

    /**
     * @notice Redeems a queued withdrawal for `recipient`. The user can redeem the tokens after the
     * rebalance. This can be easily check by comparing the current round with the round of the
     * withdrawal, if they're equal, the withdrawal is still pending.
     * @param recipient The address that will receive the withdrawn tokens after the rebalance.
     * @return amountX The amount of token X to be withdrawn.
     * @return amountY The amount of token Y to be withdrawn.
     */
    function redeemQueuedWithdrawal(uint256 round, address recipient)
        public
        virtual
        override
        nonReentrant
        onlyValidRecipient(recipient)
        returns (uint256 amountX, uint256 amountY)
    {
        // Get the amounts to be redeemed.
        (amountX, amountY) = _redeemWithdrawal(round, recipient);

        // Transfer the tokens to the recipient.
        if (amountX > 0) _tokenX().safeTransfer(recipient, amountX);
        if (amountY > 0) _tokenY().safeTransfer(recipient, amountY);
    }

    /**
     * @notice Redeems a queued withdrawal for `recipient`. The user can redeem the tokens after the
     * rebalance. This can be easily check by comparing the current round with the round of the
     * withdrawal, if they're equal, the withdrawal is still pending.
     * The wrapped native token will be unwrapped and sent to the recipient.
     * @param recipient The address that will receive the withdrawn tokens after the rebalance.
     * @return amountX The amount of token X to be withdrawn.
     * @return amountY The amount of token Y to be withdrawn.
     */
    function redeemQueuedWithdrawalNative(uint256 round, address recipient)
        public
        virtual
        override
        nonReentrant
        onlyVaultWithNativeToken
        onlyValidRecipient(recipient)
        returns (uint256 amountX, uint256 amountY)
    {
        // Get the amounts to be redeemed.
        (amountX, amountY) = _redeemWithdrawal(round, recipient);

        // Transfer the tokens to the recipient.
        if (amountX > 0) _transferTokenOrNative(_tokenX(), recipient, amountX);
        if (amountY > 0) _transferTokenOrNative(_tokenY(), recipient, amountY);
    }

    /**
     * @notice Emergency withdraws from the vault and sends the tokens to the sender according to its share.
     * If the user had queued withdrawals, they will be claimable using the `redeemQueuedWithdrawal` and
     * `redeemQueuedWithdrawalNative` functions as usual. This function is only for users that didn't queue
     * any withdrawals and still have shares in the vault.
     * @dev This will only work if the vault is in emergency mode.
     */
    function emergencyWithdraw() public virtual override nonReentrant {
        // Check that the vault is in emergency mode.
        if (address(_strategy) != address(0)) revert BaseVault__NotInEmergencyMode();

        // Get the amount of shares the user has. If the user has no shares, it will revert.
        uint256 shares = balanceOf(msg.sender);
        if (shares == 0) revert BaseVault__ZeroShares();

        // Get the balances of the vault and the total shares.
        // The balances of the vault will not contain the executed withdrawals.
        (uint256 balanceX, uint256 balanceY) = _getBalances(IStrategy(address(0)));
        uint256 totalShares = totalSupply();

        // Calculate the amounts to be withdrawn.
        uint256 amountX = balanceX.mulDivRoundDown(shares, totalShares);
        uint256 amountY = balanceY.mulDivRoundDown(shares, totalShares);

        // Burn the shares of the user.
        _burn(msg.sender, shares);

        // Transfer the tokens to the user.
        if (amountX > 0) _tokenX().safeTransfer(msg.sender, amountX);
        if (amountY > 0) _tokenY().safeTransfer(msg.sender, amountY);

        emit EmergencyWithdrawal(msg.sender, shares, amountX, amountY);
    }

    /**
     * @notice Executes the queued withdrawals for the current round. The strategy should call this
     * function after having sent the queued withdrawals to the vault.
     * This function will burn the shares of the users that queued withdrawals and will update the
     * total amount of tokens in the vault and increase the round.
     * @dev Only the strategy can call this function.
     */
    function executeQueuedWithdrawals() public virtual override nonReentrant {
        // Check that the caller is the strategy, it also checks that the strategy was set.
        address strategy = address(_strategy);
        if (strategy != msg.sender) revert BaseVault__OnlyStrategy();

        // Get the current round and the queued withdrawals for that round.
        uint256 round = _queuedWithdrawalsByRound.length - 1;
        QueuedWithdrawal storage queuedWithdrawals = _queuedWithdrawalsByRound[round];

        // Check that the round has queued withdrawals, if none, the function will stop.
        uint256 totalQueuedShares = queuedWithdrawals.totalQueuedShares;
        if (totalQueuedShares == 0) return;

        // Burn the shares of the users that queued withdrawals and update the queued withdrawals.
        _burn(strategy, totalQueuedShares);
        _queuedWithdrawalsByRound.push();

        // Cache the total amounts of tokens in the vault.
        uint256 totalAmountX = _totalAmountX;
        uint256 totalAmountY = _totalAmountY;

        // Get the amount of tokens received by the vault after executing the withdrawals.
        uint256 receivedX = _tokenX().balanceOf(address(this)) - totalAmountX;
        uint256 receivedY = _tokenY().balanceOf(address(this)) - totalAmountY;

        // Update the total amounts of tokens in the vault.
        _totalAmountX = totalAmountX + receivedX;
        _totalAmountY = totalAmountY + receivedY;

        // Update the total amounts of tokens in the queued withdrawals.
        queuedWithdrawals.totalAmountX = uint128(receivedX);
        queuedWithdrawals.totalAmountY = uint128(receivedY);

        emit WithdrawalExecuted(round, totalQueuedShares, receivedX, receivedY);
    }

    /**
     * @dev Sets the address of the strategy.
     * Will send all tokens to the new strategy.
     * @param newStrategy The address of the new strategy.
     */
    function setStrategy(IStrategy newStrategy) public virtual override onlyFactory nonReentrant {
        IStrategy currentStrategy = _strategy;

        // Verify that the strategy is not the same as the current strategy
        if (currentStrategy == newStrategy) revert BaseVault__SameStrategy();

        // Verify that the strategy is valid, i.e. it is for this vault and for the correct pair and tokens.
        if (
            newStrategy.getVault() != address(this) || newStrategy.getPair() != _pair()
                || newStrategy.getTokenX() != _tokenX() || newStrategy.getTokenY() != _tokenY()
        ) revert BaseVault__InvalidStrategy();

        // Check if there is a strategy currently set, if so, withdraw all tokens from it.
        if (address(currentStrategy) != address(0)) {
            IStrategy(currentStrategy).withdrawAll();
        }

        // Get the balances of the vault, this will not contain the executed withdrawals.
        (uint256 balanceX, uint256 balanceY) = _getBalances(IStrategy(address(0)));

        // Transfer all balances to the new strategy
        if (balanceX > 0) _tokenX().safeTransfer(address(newStrategy), balanceX);
        if (balanceY > 0) _tokenY().safeTransfer(address(newStrategy), balanceY);

        // Set the new strategy
        _setStrategy(newStrategy);
    }

    /**
     * @dev Pauses deposits.
     */
    function pauseDeposits() public virtual override onlyFactory nonReentrant {
        _depositsPaused = true;

        emit DepositsPaused();
    }

    /**
     * @dev Resumes deposits.
     */
    function resumeDeposits() public virtual override onlyFactory nonReentrant {
        _depositsPaused = false;

        emit DepositsResumed();
    }

    /**
     * @dev Sets the whitelist state.
     * @param state The new whitelist state.
     */
    function setWhitelistState(bool state) public virtual override onlyFactory nonReentrant {
        if (_whitelistStatus == state) revert BaseVault__SameWhitelistState();

        _whitelistStatus = state;

        emit WhitelistStateChanged(state);
    }

    /**
     * @dev Adds addresses to the whitelist.
     * @param addresses The addresses to be added to the whitelist.
     */
    function addToWhitelist(address[] memory addresses) public virtual override onlyFactory nonReentrant {
        for (uint256 i = 0; i < addresses.length; ++i) {
            if (_whitelistedUsers[addresses[i]]) revert BaseVault__AlreadyWhitelisted(addresses[i]);

            _whitelistedUsers[addresses[i]] = true;
        }

        emit WhitelistAdded(addresses);
    }

    /**
     * @dev Removes addresses from the whitelist.
     * @param addresses The addresses to be removed from the whitelist.
     */
    function removeFromWhitelist(address[] memory addresses) public virtual override onlyFactory nonReentrant {
        for (uint256 i = 0; i < addresses.length; ++i) {
            if (!_whitelistedUsers[addresses[i]]) revert BaseVault__NotWhitelisted(addresses[i]);

            _whitelistedUsers[addresses[i]] = false;
        }

        emit WhitelistRemoved(addresses);
    }

    /**
     * @notice Sets the vault in emergency mode.
     * @dev This will pause deposits and withdraw all tokens from the strategy.
     */
    function setEmergencyMode() public virtual override onlyFactory nonReentrant {
        // Withdraw all tokens from the strategy.
        _strategy.withdrawAll();

        // Sets the strategy to the zero address, this will prevent any deposits.
        _setStrategy(IStrategy(address(0)));

        emit EmergencyMode();
    }

    /**
     * @dev Recovers ERC20 tokens sent to the vault.
     * @param token The address of the token to be recovered.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens to be recovered.
     */
    function recoverERC20(IERC20Upgradeable token, address recipient, uint256 amount)
        public
        virtual
        override
        nonReentrant
        onlyFactory
    {
        address strategy = address(_strategy);

        // Checks that the amount of token X to be recovered is not from any withdrawal. This will simply revert
        // if the vault is in emergency mode.
        if (token == _tokenX() && (strategy == address(0) || token.balanceOf(address(this)) < _totalAmountX + amount)) {
            revert BaseVault__InvalidToken();
        }

        // Checks that the amount of token Y to be recovered is not from any withdrawal. This will simply revert
        // if the vault is in emergency mode.
        if (token == _tokenY() && (strategy == address(0) || token.balanceOf(address(this)) < _totalAmountY + amount)) {
            revert BaseVault__InvalidToken();
        }

        if (token == this) {
            uint256 excessStrategy = balanceOf(strategy) - getCurrentTotalQueuedWithdrawal();

            // If the token is the vault's token, the remaining amount must be greater than the minimum shares.
            if (balanceOf(address(this)) + excessStrategy < amount + _SHARES_PRECISION) {
                revert BaseVault__BurnMinShares();
            }

            // Allow to recover vault tokens that were mistakenly sent to the strategy.
            if (excessStrategy > 0) {
                _transfer(strategy, address(this), excessStrategy);
            }
        }

        token.safeTransfer(recipient, amount);

        // Safety check for tokens with double entry points.
        if (
            strategy == address(0)
                && (
                    _tokenX().balanceOf(address(this)) < _totalAmountX || _tokenY().balanceOf(address(this)) < _totalAmountY
                )
        ) {
            revert BaseVault__InvalidToken();
        }

        emit Recovered(address(token), recipient, amount);
    }

    /**
     * @dev Returns the address of the pair.
     * @return The address of the pair.
     */
    function _pair() internal pure virtual returns (ILBPair) {
        return ILBPair(_getArgAddress(0));
    }

    /**
     * @dev Returns the address of the token X.
     * @return The address of the token X.
     */
    function _tokenX() internal pure virtual returns (IERC20Upgradeable) {
        return IERC20Upgradeable(_getArgAddress(20));
    }

    /**
     * @dev Returns the address of the token Y.
     * @return The address of the token Y.
     */
    function _tokenY() internal pure virtual returns (IERC20Upgradeable) {
        return IERC20Upgradeable(_getArgAddress(40));
    }

    /**
     * @dev Returns the decimals of the token X.
     * @return decimalsX The decimals of the token X.
     */
    function _decimalsX() internal pure virtual returns (uint8 decimalsX) {
        return _getArgUint8(60);
    }

    /**
     * @dev Returns the decimals of the token Y.
     * @return decimalsY The decimals of the token Y.
     */
    function _decimalsY() internal pure virtual returns (uint8 decimalsY) {
        return _getArgUint8(61);
    }

    /**
     * @dev Returns shares and amounts of token X and token Y to be deposited.
     * @param strategy The address of the strategy.
     * @param amountX The amount of token X to be deposited.
     * @param amountY The amount of token Y to be deposited.
     * @return shares The amount of shares to be minted.
     * @return effectiveX The amount of token X to be deposited.
     * @return effectiveY The amount of token Y to be deposited.
     */
    function _previewShares(IStrategy strategy, uint256 amountX, uint256 amountY)
        internal
        view
        virtual
        returns (uint256 shares, uint256, uint256);

    /**
     * @dev Returns amounts of token X and token Y to be withdrawn.
     * @param strategy The address of the strategy.
     * @param shares The amount of shares to be withdrawn.
     * @param totalShares The total amount of shares.
     * @return amountX The amount of token X to be withdrawn.
     * @return amountY The amount of token Y to be withdrawn.
     */
    function _previewAmounts(IStrategy strategy, uint256 shares, uint256 totalShares)
        internal
        view
        virtual
        returns (uint256 amountX, uint256 amountY)
    {
        if (shares == 0) return (0, 0);

        if (shares > totalShares) revert BaseVault__InvalidShares();

        // Get the total amount of tokens held in the strategy
        (uint256 totalX, uint256 totalY) = _getBalances(strategy);

        // Calculate the amount of tokens to be withdrawn, pro rata to the amount of shares
        amountX = totalX.mulDivRoundDown(shares, totalShares);
        amountY = totalY.mulDivRoundDown(shares, totalShares);
    }

    /**
     * @dev Returns the total amount of tokens held in the strategy. This includes the balance of the contract and the
     * amount of tokens deposited in LB.
     * Will return the balance of the vault if no strategy is set.
     * @param strategy The address of the strategy.
     * @return amountX The amount of token X held in the strategy.
     * @return amountY The amount of token Y held in the strategy.
     */
    function _getBalances(IStrategy strategy) internal view virtual returns (uint256 amountX, uint256 amountY) {
        return address(strategy) == address(0)
            ? (_tokenX().balanceOf(address(this)) - _totalAmountX, _tokenY().balanceOf(address(this)) - _totalAmountY)
            : strategy.getBalances();
    }

    /**
     * @dev Sets the address of the strategy.
     * @param strategy The address of the strategy.
     */
    function _setStrategy(IStrategy strategy) internal virtual {
        _strategy = strategy;

        emit StrategySet(strategy);
    }

    /**
     * @dev Calculate the effective amounts to take from the user and mint the shares.
     * Will not transfer the tokens from the user.
     * @param amountX The amount of token X to be deposited.
     * @param amountY The amount of token Y to be deposited.
     * @return strategy The address of the strategy.
     * @return shares The amount of shares to be minted.
     * @return effectiveX The amount of token X to be deposited.
     * @return effectiveY The amount of token Y to be deposited.
     */
    function _deposit(uint256 amountX, uint256 amountY)
        internal
        virtual
        depositsAllowed
        returns (IStrategy strategy, uint256 shares, uint256 effectiveX, uint256 effectiveY)
    {
        // Check that at least one token is being deposited
        if (amountX == 0 && amountY == 0) revert BaseVault__ZeroAmount();

        // Verify that the strategy is set
        strategy = _strategy;
        if (address(strategy) == address(0)) revert BaseVault__InvalidStrategy();

        // Calculate the effective amounts to take from the user and the amount of shares to mint
        (shares, effectiveX, effectiveY) = _previewShares(strategy, amountX, amountY);

        if (shares == 0) revert BaseVault__ZeroShares();

        if (totalSupply() == 0) {
            // Avoid exploit when very little shares, min of total shares will always be _SHARES_PRECISION (1e6)
            shares -= _SHARES_PRECISION;
            _mint(address(this), _SHARES_PRECISION);
        }

        // Mint the shares
        _mint(msg.sender, shares);

        emit Deposited(msg.sender, effectiveX, effectiveY, shares);
    }

    /**
     * @dev Redeems the queued withdrawal for a given round and a given user.
     * Does not transfer the tokens to the user.
     * @param user The address of the user.
     * @return amountX The amount of token X to be withdrawn.
     * @return amountY The amount of token Y to be withdrawn.
     */
    function _redeemWithdrawal(uint256 round, address user) internal returns (uint256 amountX, uint256 amountY) {
        // Prevent redeeming withdrawals for the current round that have not been executed yet
        uint256 currentRound = _queuedWithdrawalsByRound.length - 1;
        if (round >= currentRound) revert BaseVault__InvalidRound();

        QueuedWithdrawal storage queuedWithdrawals = _queuedWithdrawalsByRound[round];

        // Get the amount of shares to redeem, will revert if the user has no queued withdrawal
        uint256 shares = queuedWithdrawals.userWithdrawals[user];
        if (shares == 0) revert BaseVault__NoQueuedWithdrawal();

        // Only the user can redeem their withdrawal. The factory is also allowed as it batches withdrawals for users
        if (user != msg.sender && msg.sender != address(_factory)) revert BaseVault__Unauthorized();

        // Calculate the amount of tokens to be withdrawn, pro rata to the amount of shares
        uint256 totalQueuedShares = queuedWithdrawals.totalQueuedShares;
        queuedWithdrawals.userWithdrawals[user] = 0;

        amountX = uint256(queuedWithdrawals.totalAmountX).mulDivRoundDown(shares, totalQueuedShares);
        amountY = uint256(queuedWithdrawals.totalAmountY).mulDivRoundDown(shares, totalQueuedShares);

        if (amountX == 0 && amountY == 0) revert BaseVault__ZeroAmount();

        // Update the total amount of shares queued for withdrawal
        if (amountX != 0) _totalAmountX -= amountX;
        if (amountY != 0) _totalAmountY -= amountY;

        emit WithdrawalRedeemed(msg.sender, user, round, shares, amountX, amountY);
    }

    /**
     * @dev Helper function to transfer tokens to the recipient. If the token is the wrapped native token, it will be
     * unwrapped first and then transferred as native tokens.
     * @param token The address of the token to be transferred.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to be transferred.
     */
    function _transferTokenOrNative(IERC20Upgradeable token, address recipient, uint256 amount) internal {
        address wnative = _wnative;
        if (address(token) == wnative) {
            IWNative(wnative).withdraw(amount);
            _transferNative(recipient, amount);
        } else {
            token.safeTransfer(recipient, amount);
        }
    }

    /**
     * @dev Helper function to transfer native tokens to the recipient.
     * @param recipient The address to receive the tokens.
     * @param amount The amount of tokens to be transferred.
     */
    function _transferNative(address recipient, uint256 amount) internal virtual {
        (bool success,) = recipient.call{value: amount}("");
        if (!success) revert BaseVault__NativeTransferFailed();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";

import {IOneInchRouter} from "./IOneInchRouter.sol";
import {IVaultFactory} from "./IVaultFactory.sol";

/**
 * @title Strategy Interface
 * @author Trader Joe
 * @notice Interface used to interact with Liquidity Book Vaults' Strategies
 */
interface IStrategy {
    error Strategy__OnlyFactory();
    error Strategy__OnlyVault();
    error Strategy__OnlyOperators();
    error Strategy__ZeroAmounts();
    error Strategy__InvalidAmount();
    error Strategy__InvalidToken();
    error Strategy__InvalidReceiver();
    error Strategy__InvalidRange();
    error Strategy__InvalidFee();
    error Strategy__ActiveIdSlippage();
    error Strategy__RangeAlreadySet();
    error Strategy__RangeTooWide();
    error Strategy__InvalidLength();

    event OperatorSet(address operator);

    event AumFeeCollected(
        address indexed sender, uint256 totalBalanceX, uint256 totalBalanceY, uint256 feeX, uint256 feeY
    );

    event AumAnnualFeeSet(uint256 fee);

    event PendingAumAnnualFeeSet(uint256 fee);

    event PendingAumAnnualFeeReset();

    event RangeSet(uint24 low, uint24 upper);

    function getFactory() external view returns (IVaultFactory);

    function getVault() external pure returns (address);

    function getPair() external pure returns (ILBPair);

    function getTokenX() external pure returns (IERC20Upgradeable);

    function getTokenY() external pure returns (IERC20Upgradeable);

    function getRange() external view returns (uint24 low, uint24 upper);

    function getAumAnnualFee() external view returns (uint256 aumAnnualFee);

    function getLastRebalance() external view returns (uint256 lastRebalance);

    function getPendingAumAnnualFee() external view returns (bool isSet, uint256 pendingAumAnnualFee);

    function getOperator() external view returns (address);

    function getBalances() external view returns (uint256 amountX, uint256 amountY);

    function getIdleBalances() external view returns (uint256 amountX, uint256 amountY);

    function initialize() external;

    function withdrawAll() external;

    function rebalance(
        uint24 newLower,
        uint24 newUpper,
        uint24 desiredActiveId,
        uint24 slippageActiveId,
        uint256 amountX,
        uint256 amountY,
        bytes calldata distributions
    ) external;

    function swap(address executor, IOneInchRouter.SwapDescription memory desc, bytes memory data) external;

    function setOperator(address operator) external;

    function setPendingAumAnnualFee(uint16 pendingAumAnnualFee) external;

    function resetPendingAumAnnualFee() external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";

import {IStrategy} from "./IStrategy.sol";
import {IBaseVault} from "./IBaseVault.sol";
import {IAggregatorV3} from "./IAggregatorV3.sol";

/**
 * @title Oracle Vault Interface
 * @author Trader Joe
 * @notice Interface used to interact with Liquidity Book Oracle Vaults
 */
interface IOracleVault is IBaseVault {
    error OracleVault__InvalidPrice();
    error OracleVault__StalePrice();

    function getOracleX() external pure returns (IAggregatorV3 oracleX);

    function getOracleY() external pure returns (IAggregatorV3 oracleY);

    function getPrice() external view returns (uint256 price);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";

import {IAggregatorV3} from "./IAggregatorV3.sol";
import {IStrategy} from "./IStrategy.sol";
import {IBaseVault} from "./IBaseVault.sol";

/**
 * @title Vault Factory Interface
 * @author Trader Joe
 * @notice Interface used to interact with the Factory for Liquidity Book Vaults
 */
interface IVaultFactory {
    error VaultFactory__VaultImplementationNotSet(VaultType vType);
    error VaultFactory__StrategyImplementationNotSet(StrategyType sType);
    error VaultFactory__InvalidType();
    error VaultFactory__InvalidOraclePrice();
    error VaultFactory__InvalidStrategy();
    error VaultFactory__InvalidFeeRecipient();
    error VaultFactory__InvalidOwner();
    error VaultFactory__InvalidLength();
    error VaultFactory__InvalidDecimals();

    enum VaultType {
        None,
        Simple,
        Oracle
    }

    enum StrategyType {
        None,
        Default
    }

    event VaultCreated(
        VaultType indexed vType,
        address indexed vault,
        ILBPair indexed lbPair,
        uint256 vaultIndex,
        address tokenX,
        address tokenY
    );

    event StrategyCreated(
        StrategyType indexed sType,
        address indexed strategy,
        address indexed vault,
        ILBPair lbPair,
        uint256 strategyIndex
    );

    event VaultImplementationSet(VaultType indexed vType, address indexed vaultImplementation);

    event StrategyImplementationSet(StrategyType indexed sType, address indexed strategyImplementation);

    event DefaultOperatorSet(address indexed sender, address indexed defaultOperator);

    event FeeRecipientSet(address indexed sender, address indexed feeRecipient);

    function getWNative() external view returns (address);

    function getVaultAt(VaultType vType, uint256 index) external view returns (address);

    function getVaultType(address vault) external view returns (VaultType);

    function getStrategyAt(StrategyType sType, uint256 index) external view returns (address);

    function getStrategyType(address strategy) external view returns (StrategyType);

    function getNumberOfVaults(VaultType vType) external view returns (uint256);

    function getNumberOfStrategies(StrategyType sType) external view returns (uint256);

    function getDefaultOperator() external view returns (address);

    function getFeeRecipient() external view returns (address);

    function getVaultImplementation(VaultType vType) external view returns (address);

    function getStrategyImplementation(StrategyType sType) external view returns (address);

    function batchRedeemQueuedWithdrawals(
        address[] calldata vaults,
        uint256[] calldata rounds,
        bool[] calldata withdrawNative
    ) external;

    function setVaultImplementation(VaultType vType, address vaultImplementation) external;

    function setStrategyImplementation(StrategyType sType, address strategyImplementation) external;

    function setDefaultOperator(address defaultOperator) external;

    function setOperator(IStrategy strategy, address operator) external;

    function setPendingAumAnnualFee(IBaseVault vault, uint16 pendingAumAnnualFee) external;

    function resetPendingAumAnnualFee(IBaseVault vault) external;

    function setFeeRecipient(address feeRecipient) external;

    function createOracleVaultAndDefaultStrategy(ILBPair lbPair, IAggregatorV3 dataFeedX, IAggregatorV3 dataFeedY)
        external
        returns (address vault, address strategy);

    function createSimpleVaultAndDefaultStrategy(ILBPair lbPair) external returns (address vault, address strategy);

    function createOracleVault(ILBPair lbPair, IAggregatorV3 dataFeedX, IAggregatorV3 dataFeedY)
        external
        returns (address vault);

    function createSimpleVault(ILBPair lbPair) external returns (address vault);

    function createDefaultStrategy(IBaseVault vault) external returns (address strategy);

    function linkVaultToStrategy(IBaseVault vault, address strategy) external;

    function setWhitelistState(IBaseVault vault, bool state) external;

    function addToWhitelist(IBaseVault vault, address[] calldata addresses) external;

    function removeFromWhitelist(IBaseVault vault, address[] calldata addresses) external;

    function pauseDeposits(IBaseVault vault) external;

    function resumeDeposits(IBaseVault vault) external;

    function setEmergencyMode(IBaseVault vault) external;

    function recoverERC20(IBaseVault vault, IERC20Upgradeable token, address recipient, uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @title Aggregator V3 Interface
 * @author Trader Joe
 * @notice Interface used to interact with Chainlink datafeeds.
 */
interface IAggregatorV3 {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Clone
 * @notice Class with helper read functions for clone with immutable args.
 * @author Trader Joe
 * @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/Clone.sol)
 * @author Adapted from clones with immutable args by zefram.eth, Saw-mon & Natalie
 * (https://github.com/Saw-mon-and-Natalie/clones-with-immutable-args)
 */
abstract contract Clone {
    /**
     * @dev Reads an immutable arg with type bytes
     * @param argOffset The offset of the arg in the immutable args
     * @param length The length of the arg
     * @return arg The immutable bytes arg
     */
    function _getArgBytes(uint256 argOffset, uint256 length) internal pure returns (bytes memory arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            arg := mload(0x40)
            // Store the array length.
            mstore(arg, length)
            // Copy the array.
            calldatacopy(add(arg, 0x20), add(offset, argOffset), length)
            // Allocate the memory, rounded up to the next 32 byte boundary.
            mstore(0x40, and(add(add(arg, 0x3f), length), not(0x1f)))
        }
    }

    /**
     * @dev Reads an immutable arg with type address
     * @param argOffset The offset of the arg in the immutable args
     * @return arg The immutable address arg
     */
    function _getArgAddress(uint256 argOffset) internal pure returns (address arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0x60, calldataload(add(offset, argOffset)))
        }
    }

    /**
     * @dev Reads an immutable arg with type uint256
     * @param argOffset The offset of the arg in the immutable args
     * @return arg The immutable uint256 arg
     */
    function _getArgUint256(uint256 argOffset) internal pure returns (uint256 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := calldataload(add(offset, argOffset))
        }
    }

    /**
     * @dev Reads a uint256 array stored in the immutable args.
     * @param argOffset The offset of the arg in the immutable args
     * @param length The length of the arg
     * @return arg The immutable uint256 array arg
     */
    function _getArgUint256Array(uint256 argOffset, uint256 length) internal pure returns (uint256[] memory arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            // Grab the free memory pointer.
            arg := mload(0x40)
            // Store the array length.
            mstore(arg, length)
            // Copy the array.
            calldatacopy(add(arg, 0x20), add(offset, argOffset), shl(5, length))
            // Allocate the memory.
            mstore(0x40, add(add(arg, 0x20), shl(5, length)))
        }
    }

    /**
     * @dev Reads an immutable arg with type uint64
     * @param argOffset The offset of the arg in the immutable args
     * @return arg The immutable uint64 arg
     */
    function _getArgUint64(uint256 argOffset) internal pure returns (uint64 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0xc0, calldataload(add(offset, argOffset)))
        }
    }

    /**
     * @dev Reads an immutable arg with type uint16
     * @param argOffset The offset of the arg in the immutable args
     * @return arg The immutable uint16 arg
     */
    function _getArgUint16(uint256 argOffset) internal pure returns (uint16 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0xf0, calldataload(add(offset, argOffset)))
        }
    }

    /**
     * @dev Reads an immutable arg with type uint8
     * @param argOffset The offset of the arg in the immutable args
     * @return arg The immutable uint8 arg
     */
    function _getArgUint8(uint256 argOffset) internal pure returns (uint8 arg) {
        uint256 offset = _getImmutableArgsOffset();
        /// @solidity memory-safe-assembly
        assembly {
            arg := shr(0xf8, calldataload(add(offset, argOffset)))
        }
    }

    /**
     * @dev Reads the offset of the packed immutable args in calldata.
     * @return offset The offset of the packed immutable args in calldata.
     */
    function _getImmutableArgsOffset() internal pure returns (uint256 offset) {
        /// @solidity memory-safe-assembly
        assembly {
            offset := sub(calldatasize(), shr(0xf0, calldataload(sub(calldatasize(), 2))))
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20Upgradeable.sol";
import "./extensions/IERC20MetadataUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20Upgradeable is Initializable, ContextUpgradeable, IERC20Upgradeable, IERC20MetadataUpgradeable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    function __ERC20_init(string memory name_, string memory symbol_) internal onlyInitializing {
        __ERC20_init_unchained(name_, symbol_);
    }

    function __ERC20_init_unchained(string memory name_, string memory symbol_) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[45] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {ILBFactory} from "./ILBFactory.sol";
import {ILBFlashLoanCallback} from "./ILBFlashLoanCallback.sol";
import {ILBToken} from "./ILBToken.sol";

interface ILBPair is ILBToken {
    error LBPair__ZeroBorrowAmount();
    error LBPair__AddressZero();
    error LBPair__AlreadyInitialized();
    error LBPair__EmptyMarketConfigs();
    error LBPair__FlashLoanCallbackFailed();
    error LBPair__FlashLoanInsufficientAmount();
    error LBPair__InsufficientAmountIn();
    error LBPair__InsufficientAmountOut();
    error LBPair__InvalidInput();
    error LBPair__InvalidStaticFeeParameters();
    error LBPair__OnlyFactory();
    error LBPair__OnlyProtocolFeeRecipient();
    error LBPair__OutOfLiquidity();
    error LBPair__TokenNotSupported();
    error LBPair__ZeroAmount(uint24 id);
    error LBPair__ZeroAmountsOut(uint24 id);
    error LBPair__ZeroShares(uint24 id);
    error LBPair__MaxTotalFeeExceeded();

    struct MintArrays {
        uint256[] ids;
        bytes32[] amounts;
        uint256[] liquidityMinted;
    }

    event DepositedToBins(address indexed sender, address indexed to, uint256[] ids, bytes32[] amounts);

    event WithdrawnFromBins(address indexed sender, address indexed to, uint256[] ids, bytes32[] amounts);

    event CompositionFees(address indexed sender, uint24 id, bytes32 totalFees, bytes32 protocolFees);

    event CollectedProtocolFees(address indexed feeRecipient, bytes32 protocolFees);

    event Swap(
        address indexed sender,
        address indexed to,
        uint24 id,
        bytes32 amountsIn,
        bytes32 amountsOut,
        uint24 volatilityAccumulator,
        bytes32 totalFees,
        bytes32 protocolFees
    );

    event StaticFeeParametersSet(
        address indexed sender,
        uint16 baseFactor,
        uint16 filterPeriod,
        uint16 decayPeriod,
        uint16 reductionFactor,
        uint24 variableFeeControl,
        uint16 protocolShare,
        uint24 maxVolatilityAccumulator
    );

    event FlashLoan(
        address indexed sender,
        ILBFlashLoanCallback indexed receiver,
        uint24 activeId,
        bytes32 amounts,
        bytes32 totalFees,
        bytes32 protocolFees
    );

    event OracleLengthIncreased(address indexed sender, uint16 oracleLength);

    event ForcedDecay(address indexed sender, uint24 idReference, uint24 volatilityReference);

    function initialize(
        uint16 baseFactor,
        uint16 filterPeriod,
        uint16 decayPeriod,
        uint16 reductionFactor,
        uint24 variableFeeControl,
        uint16 protocolShare,
        uint24 maxVolatilityAccumulator,
        uint24 activeId
    ) external;

    function getFactory() external view returns (ILBFactory factory);

    function getTokenX() external view returns (IERC20 tokenX);

    function getTokenY() external view returns (IERC20 tokenY);

    function getBinStep() external view returns (uint16 binStep);

    function getReserves() external view returns (uint128 reserveX, uint128 reserveY);

    function getActiveId() external view returns (uint24 activeId);

    function getBin(uint24 id) external view returns (uint128 binReserveX, uint128 binReserveY);

    function getNextNonEmptyBin(bool swapForY, uint24 id) external view returns (uint24 nextId);

    function getProtocolFees() external view returns (uint128 protocolFeeX, uint128 protocolFeeY);

    function getStaticFeeParameters()
        external
        view
        returns (
            uint16 baseFactor,
            uint16 filterPeriod,
            uint16 decayPeriod,
            uint16 reductionFactor,
            uint24 variableFeeControl,
            uint16 protocolShare,
            uint24 maxVolatilityAccumulator
        );

    function getVariableFeeParameters()
        external
        view
        returns (uint24 volatilityAccumulator, uint24 volatilityReference, uint24 idReference, uint40 timeOfLastUpdate);

    function getOracleParameters()
        external
        view
        returns (uint8 sampleLifetime, uint16 size, uint16 activeSize, uint40 lastUpdated, uint40 firstTimestamp);

    function getOracleSampleAt(uint40 lookupTimestamp)
        external
        view
        returns (uint64 cumulativeId, uint64 cumulativeVolatility, uint64 cumulativeBinCrossed);

    function getPriceFromId(uint24 id) external view returns (uint256 price);

    function getIdFromPrice(uint256 price) external view returns (uint24 id);

    function getSwapIn(uint128 amountOut, bool swapForY)
        external
        view
        returns (uint128 amountIn, uint128 amountOutLeft, uint128 fee);

    function getSwapOut(uint128 amountIn, bool swapForY)
        external
        view
        returns (uint128 amountInLeft, uint128 amountOut, uint128 fee);

    function swap(bool swapForY, address to) external returns (bytes32 amountsOut);

    function flashLoan(ILBFlashLoanCallback receiver, bytes32 amounts, bytes calldata data) external;

    function mint(address to, bytes32[] calldata liquidityConfigs, address refundTo)
        external
        returns (bytes32 amountsReceived, bytes32 amountsLeft, uint256[] memory liquidityMinted);

    function burn(address from, address to, uint256[] calldata ids, uint256[] calldata amountsToBurn)
        external
        returns (bytes32[] memory amounts);

    function collectProtocolFees() external returns (bytes32 collectedProtocolFees);

    function increaseOracleLength(uint16 newLength) external;

    function setStaticFeeParameters(
        uint16 baseFactor,
        uint16 filterPeriod,
        uint16 decayPeriod,
        uint16 reductionFactor,
        uint24 variableFeeControl,
        uint16 protocolShare,
        uint24 maxVolatilityAccumulator
    ) external;

    function forceDecay() external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuardUpgradeable is Initializable {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
import "../extensions/draft-IERC20PermitUpgradeable.sol";
import "../../../utils/AddressUpgradeable.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20Upgradeable {
    using AddressUpgradeable for address;

    function safeTransfer(
        IERC20Upgradeable token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20Upgradeable token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20Upgradeable token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    function safePermit(
        IERC20PermitUpgradeable token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Safe Cast Library
 * @author Trader Joe
 * @notice This library contains functions to safely cast uint256 to different uint types.
 */
library SafeCast {
    error SafeCast__Exceeds248Bits();
    error SafeCast__Exceeds240Bits();
    error SafeCast__Exceeds232Bits();
    error SafeCast__Exceeds224Bits();
    error SafeCast__Exceeds216Bits();
    error SafeCast__Exceeds208Bits();
    error SafeCast__Exceeds200Bits();
    error SafeCast__Exceeds192Bits();
    error SafeCast__Exceeds184Bits();
    error SafeCast__Exceeds176Bits();
    error SafeCast__Exceeds168Bits();
    error SafeCast__Exceeds160Bits();
    error SafeCast__Exceeds152Bits();
    error SafeCast__Exceeds144Bits();
    error SafeCast__Exceeds136Bits();
    error SafeCast__Exceeds128Bits();
    error SafeCast__Exceeds120Bits();
    error SafeCast__Exceeds112Bits();
    error SafeCast__Exceeds104Bits();
    error SafeCast__Exceeds96Bits();
    error SafeCast__Exceeds88Bits();
    error SafeCast__Exceeds80Bits();
    error SafeCast__Exceeds72Bits();
    error SafeCast__Exceeds64Bits();
    error SafeCast__Exceeds56Bits();
    error SafeCast__Exceeds48Bits();
    error SafeCast__Exceeds40Bits();
    error SafeCast__Exceeds32Bits();
    error SafeCast__Exceeds24Bits();
    error SafeCast__Exceeds16Bits();
    error SafeCast__Exceeds8Bits();

    /**
     * @dev Returns x on uint248 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint248
     */
    function safe248(uint256 x) internal pure returns (uint248 y) {
        if ((y = uint248(x)) != x) revert SafeCast__Exceeds248Bits();
    }

    /**
     * @dev Returns x on uint240 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint240
     */
    function safe240(uint256 x) internal pure returns (uint240 y) {
        if ((y = uint240(x)) != x) revert SafeCast__Exceeds240Bits();
    }

    /**
     * @dev Returns x on uint232 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint232
     */
    function safe232(uint256 x) internal pure returns (uint232 y) {
        if ((y = uint232(x)) != x) revert SafeCast__Exceeds232Bits();
    }

    /**
     * @dev Returns x on uint224 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint224
     */
    function safe224(uint256 x) internal pure returns (uint224 y) {
        if ((y = uint224(x)) != x) revert SafeCast__Exceeds224Bits();
    }

    /**
     * @dev Returns x on uint216 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint216
     */
    function safe216(uint256 x) internal pure returns (uint216 y) {
        if ((y = uint216(x)) != x) revert SafeCast__Exceeds216Bits();
    }

    /**
     * @dev Returns x on uint208 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint208
     */
    function safe208(uint256 x) internal pure returns (uint208 y) {
        if ((y = uint208(x)) != x) revert SafeCast__Exceeds208Bits();
    }

    /**
     * @dev Returns x on uint200 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint200
     */
    function safe200(uint256 x) internal pure returns (uint200 y) {
        if ((y = uint200(x)) != x) revert SafeCast__Exceeds200Bits();
    }

    /**
     * @dev Returns x on uint192 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint192
     */
    function safe192(uint256 x) internal pure returns (uint192 y) {
        if ((y = uint192(x)) != x) revert SafeCast__Exceeds192Bits();
    }

    /**
     * @dev Returns x on uint184 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint184
     */
    function safe184(uint256 x) internal pure returns (uint184 y) {
        if ((y = uint184(x)) != x) revert SafeCast__Exceeds184Bits();
    }

    /**
     * @dev Returns x on uint176 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint176
     */
    function safe176(uint256 x) internal pure returns (uint176 y) {
        if ((y = uint176(x)) != x) revert SafeCast__Exceeds176Bits();
    }

    /**
     * @dev Returns x on uint168 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint168
     */
    function safe168(uint256 x) internal pure returns (uint168 y) {
        if ((y = uint168(x)) != x) revert SafeCast__Exceeds168Bits();
    }

    /**
     * @dev Returns x on uint160 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint160
     */
    function safe160(uint256 x) internal pure returns (uint160 y) {
        if ((y = uint160(x)) != x) revert SafeCast__Exceeds160Bits();
    }

    /**
     * @dev Returns x on uint152 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint152
     */
    function safe152(uint256 x) internal pure returns (uint152 y) {
        if ((y = uint152(x)) != x) revert SafeCast__Exceeds152Bits();
    }

    /**
     * @dev Returns x on uint144 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint144
     */
    function safe144(uint256 x) internal pure returns (uint144 y) {
        if ((y = uint144(x)) != x) revert SafeCast__Exceeds144Bits();
    }

    /**
     * @dev Returns x on uint136 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint136
     */
    function safe136(uint256 x) internal pure returns (uint136 y) {
        if ((y = uint136(x)) != x) revert SafeCast__Exceeds136Bits();
    }

    /**
     * @dev Returns x on uint128 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint128
     */
    function safe128(uint256 x) internal pure returns (uint128 y) {
        if ((y = uint128(x)) != x) revert SafeCast__Exceeds128Bits();
    }

    /**
     * @dev Returns x on uint120 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint120
     */
    function safe120(uint256 x) internal pure returns (uint120 y) {
        if ((y = uint120(x)) != x) revert SafeCast__Exceeds120Bits();
    }

    /**
     * @dev Returns x on uint112 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint112
     */
    function safe112(uint256 x) internal pure returns (uint112 y) {
        if ((y = uint112(x)) != x) revert SafeCast__Exceeds112Bits();
    }

    /**
     * @dev Returns x on uint104 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint104
     */
    function safe104(uint256 x) internal pure returns (uint104 y) {
        if ((y = uint104(x)) != x) revert SafeCast__Exceeds104Bits();
    }

    /**
     * @dev Returns x on uint96 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint96
     */
    function safe96(uint256 x) internal pure returns (uint96 y) {
        if ((y = uint96(x)) != x) revert SafeCast__Exceeds96Bits();
    }

    /**
     * @dev Returns x on uint88 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint88
     */
    function safe88(uint256 x) internal pure returns (uint88 y) {
        if ((y = uint88(x)) != x) revert SafeCast__Exceeds88Bits();
    }

    /**
     * @dev Returns x on uint80 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint80
     */
    function safe80(uint256 x) internal pure returns (uint80 y) {
        if ((y = uint80(x)) != x) revert SafeCast__Exceeds80Bits();
    }

    /**
     * @dev Returns x on uint72 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint72
     */
    function safe72(uint256 x) internal pure returns (uint72 y) {
        if ((y = uint72(x)) != x) revert SafeCast__Exceeds72Bits();
    }

    /**
     * @dev Returns x on uint64 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint64
     */
    function safe64(uint256 x) internal pure returns (uint64 y) {
        if ((y = uint64(x)) != x) revert SafeCast__Exceeds64Bits();
    }

    /**
     * @dev Returns x on uint56 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint56
     */
    function safe56(uint256 x) internal pure returns (uint56 y) {
        if ((y = uint56(x)) != x) revert SafeCast__Exceeds56Bits();
    }

    /**
     * @dev Returns x on uint48 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint48
     */
    function safe48(uint256 x) internal pure returns (uint48 y) {
        if ((y = uint48(x)) != x) revert SafeCast__Exceeds48Bits();
    }

    /**
     * @dev Returns x on uint40 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint40
     */
    function safe40(uint256 x) internal pure returns (uint40 y) {
        if ((y = uint40(x)) != x) revert SafeCast__Exceeds40Bits();
    }

    /**
     * @dev Returns x on uint32 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint32
     */
    function safe32(uint256 x) internal pure returns (uint32 y) {
        if ((y = uint32(x)) != x) revert SafeCast__Exceeds32Bits();
    }

    /**
     * @dev Returns x on uint24 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint24
     */
    function safe24(uint256 x) internal pure returns (uint24 y) {
        if ((y = uint24(x)) != x) revert SafeCast__Exceeds24Bits();
    }

    /**
     * @dev Returns x on uint16 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint16
     */
    function safe16(uint256 x) internal pure returns (uint16 y) {
        if ((y = uint16(x)) != x) revert SafeCast__Exceeds16Bits();
    }

    /**
     * @dev Returns x on uint8 and check that it does not overflow
     * @param x The value as an uint256
     * @return y The value as an uint8
     */
    function safe8(uint256 x) internal pure returns (uint8 y) {
        if ((y = uint8(x)) != x) revert SafeCast__Exceeds8Bits();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ILBPair} from "joe-v2/interfaces/ILBPair.sol";

import {IStrategy} from "./IStrategy.sol";
import {IVaultFactory} from "./IVaultFactory.sol";

/**
 * @title Base Vault Interface
 * @author Trader Joe
 * @notice Interface used to interact with Liquidity Book Vaults
 */
interface IBaseVault is IERC20Upgradeable {
    error BaseVault__AlreadyWhitelisted(address user);
    error BaseVault__BurnMinShares();
    error BaseVault__DepositsPaused();
    error BaseVault__InvalidNativeAmount();
    error BaseVault__InvalidRecipient();
    error BaseVault__InvalidShares();
    error BaseVault__InvalidStrategy();
    error BaseVault__InvalidToken();
    error BaseVault__NoNativeToken();
    error BaseVault__NoQueuedWithdrawal();
    error BaseVault__MaxSharesExceeded();
    error BaseVault__NativeTransferFailed();
    error BaseVault__NotInEmergencyMode();
    error BaseVault__NotWhitelisted(address user);
    error BaseVault__OnlyFactory();
    error BaseVault__OnlyWNative();
    error BaseVault__OnlyStrategy();
    error BaseVault__SameStrategy();
    error BaseVault__SameWhitelistState();
    error BaseVault__ZeroAmount();
    error BaseVault__ZeroShares();
    error BaseVault__InvalidRound();
    error BaseVault__Unauthorized();

    struct QueuedWithdrawal {
        mapping(address => uint256) userWithdrawals;
        uint256 totalQueuedShares;
        uint128 totalAmountX;
        uint128 totalAmountY;
    }

    event Deposited(address indexed user, uint256 amountX, uint256 amountY, uint256 shares);

    event WithdrawalQueued(address indexed sender, address indexed user, uint256 indexed round, uint256 shares);

    event WithdrawalCancelled(address indexed sender, address indexed recipient, uint256 indexed round, uint256 shares);

    event WithdrawalRedeemed(
        address indexed sender,
        address indexed recipient,
        uint256 indexed round,
        uint256 shares,
        uint256 amountX,
        uint256 amountY
    );

    event WithdrawalExecuted(uint256 indexed round, uint256 totalQueuedQhares, uint256 amountX, uint256 amountY);

    event StrategySet(IStrategy strategy);

    event WhitelistStateChanged(bool state);

    event WhitelistAdded(address[] addresses);

    event WhitelistRemoved(address[] addresses);

    event Recovered(address token, address recipient, uint256 amount);

    event DepositsPaused();

    event DepositsResumed();

    event EmergencyMode();

    event EmergencyWithdrawal(address indexed sender, uint256 shares, uint256 amountX, uint256 amountY);

    function getFactory() external view returns (IVaultFactory);

    function getPair() external view returns (ILBPair);

    function getTokenX() external view returns (IERC20Upgradeable);

    function getTokenY() external view returns (IERC20Upgradeable);

    function getStrategy() external view returns (IStrategy);

    function getAumAnnualFee() external view returns (uint256);

    function getRange() external view returns (uint24 low, uint24 upper);

    function getOperators() external view returns (address defaultOperator, address operator);

    function getBalances() external view returns (uint256 amountX, uint256 amountY);

    function previewShares(uint256 amountX, uint256 amountY)
        external
        view
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY);

    function previewAmounts(uint256 shares) external view returns (uint256 amountX, uint256 amountY);

    function isDepositsPaused() external view returns (bool);

    function isWhitelistedOnly() external view returns (bool);

    function isWhitelisted(address user) external view returns (bool);

    function getCurrentRound() external view returns (uint256 round);

    function getQueuedWithdrawal(uint256 round, address user) external view returns (uint256 shares);

    function getTotalQueuedWithdrawal(uint256 round) external view returns (uint256 totalQueuedShares);

    function getCurrentTotalQueuedWithdrawal() external view returns (uint256 totalQueuedShares);

    function getRedeemableAmounts(uint256 round, address user)
        external
        view
        returns (uint256 amountX, uint256 amountY);

    function deposit(uint256 amountX, uint256 amountY)
        external
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY);

    function depositNative(uint256 amountX, uint256 amountY)
        external
        payable
        returns (uint256 shares, uint256 effectiveX, uint256 effectiveY);

    function queueWithdrawal(uint256 shares, address recipient) external returns (uint256 round);

    function cancelQueuedWithdrawal(uint256 shares) external returns (uint256 round);

    function redeemQueuedWithdrawal(uint256 round, address recipient)
        external
        returns (uint256 amountX, uint256 amountY);

    function redeemQueuedWithdrawalNative(uint256 round, address recipient)
        external
        returns (uint256 amountX, uint256 amountY);

    function emergencyWithdraw() external;

    function executeQueuedWithdrawals() external;

    function initialize(string memory name, string memory symbol) external;

    function setStrategy(IStrategy newStrategy) external;

    function setWhitelistState(bool state) external;

    function addToWhitelist(address[] calldata addresses) external;

    function removeFromWhitelist(address[] calldata addresses) external;

    function pauseDeposits() external;

    function resumeDeposits() external;

    function setEmergencyMode() external;

    function recoverERC20(IERC20Upgradeable token, address recipient, uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Wrapped Native Interface
 * @author Trader Joe
 * @notice Interface used to interact with wNative tokens
 */
interface IWNative is IERC20Upgradeable {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IERC20Upgradeable} from "openzeppelin-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IOneInchRouter {
    struct SwapDescription {
        IERC20Upgradeable srcToken;
        IERC20Upgradeable dstToken;
        address payable srcReceiver;
        address payable dstReceiver;
        uint256 amount;
        uint256 minReturnAmount;
        uint256 flags;
    }

    function swap(address executor, SwapDescription calldata desc, bytes calldata permit, bytes calldata data)
        external
        payable
        returns (uint256 returnAmount, uint256 spentAmount);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20MetadataUpgradeable is IERC20Upgradeable {
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
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.1) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
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

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {ILBPair} from "./ILBPair.sol";
import {IPendingOwnable} from "./IPendingOwnable.sol";

/**
 * @title Liquidity Book Factory Interface
 * @author Trader Joe
 * @notice Required interface of LBFactory contract
 */
interface ILBFactory is IPendingOwnable {
    error LBFactory__IdenticalAddresses(IERC20 token);
    error LBFactory__QuoteAssetNotWhitelisted(IERC20 quoteAsset);
    error LBFactory__QuoteAssetAlreadyWhitelisted(IERC20 quoteAsset);
    error LBFactory__AddressZero();
    error LBFactory__LBPairAlreadyExists(IERC20 tokenX, IERC20 tokenY, uint256 _binStep);
    error LBFactory__LBPairDoesNotExist(IERC20 tokenX, IERC20 tokenY, uint256 binStep);
    error LBFactory__LBPairNotCreated(IERC20 tokenX, IERC20 tokenY, uint256 binStep);
    error LBFactory__FlashLoanFeeAboveMax(uint256 fees, uint256 maxFees);
    error LBFactory__BinStepTooLow(uint256 binStep);
    error LBFactory__PresetIsLockedForUsers(address user, uint256 binStep);
    error LBFactory__LBPairIgnoredIsAlreadyInTheSameState();
    error LBFactory__BinStepHasNoPreset(uint256 binStep);
    error LBFactory__PresetOpenStateIsAlreadyInTheSameState();
    error LBFactory__SameFeeRecipient(address feeRecipient);
    error LBFactory__SameFlashLoanFee(uint256 flashLoanFee);
    error LBFactory__LBPairSafetyCheckFailed(address LBPairImplementation);
    error LBFactory__SameImplementation(address LBPairImplementation);
    error LBFactory__ImplementationNotSet();

    /**
     * @dev Structure to store the LBPair information, such as:
     * binStep: The bin step of the LBPair
     * LBPair: The address of the LBPair
     * createdByOwner: Whether the pair was created by the owner of the factory
     * ignoredForRouting: Whether the pair is ignored for routing or not. An ignored pair will not be explored during routes finding
     */
    struct LBPairInformation {
        uint16 binStep;
        ILBPair LBPair;
        bool createdByOwner;
        bool ignoredForRouting;
    }

    event LBPairCreated(
        IERC20 indexed tokenX, IERC20 indexed tokenY, uint256 indexed binStep, ILBPair LBPair, uint256 pid
    );

    event FeeRecipientSet(address oldRecipient, address newRecipient);

    event FlashLoanFeeSet(uint256 oldFlashLoanFee, uint256 newFlashLoanFee);

    event LBPairImplementationSet(address oldLBPairImplementation, address LBPairImplementation);

    event LBPairIgnoredStateChanged(ILBPair indexed LBPair, bool ignored);

    event PresetSet(
        uint256 indexed binStep,
        uint256 baseFactor,
        uint256 filterPeriod,
        uint256 decayPeriod,
        uint256 reductionFactor,
        uint256 variableFeeControl,
        uint256 protocolShare,
        uint256 maxVolatilityAccumulator
    );

    event PresetOpenStateChanged(uint256 indexed binStep, bool indexed isOpen);

    event PresetRemoved(uint256 indexed binStep);

    event QuoteAssetAdded(IERC20 indexed quoteAsset);

    event QuoteAssetRemoved(IERC20 indexed quoteAsset);

    function getMinBinStep() external pure returns (uint256);

    function getFeeRecipient() external view returns (address);

    function getMaxFlashLoanFee() external pure returns (uint256);

    function getFlashLoanFee() external view returns (uint256);

    function getLBPairImplementation() external view returns (address);

    function getNumberOfLBPairs() external view returns (uint256);

    function getLBPairAtIndex(uint256 id) external returns (ILBPair);

    function getNumberOfQuoteAssets() external view returns (uint256);

    function getQuoteAssetAtIndex(uint256 index) external view returns (IERC20);

    function isQuoteAsset(IERC20 token) external view returns (bool);

    function getLBPairInformation(IERC20 tokenX, IERC20 tokenY, uint256 binStep)
        external
        view
        returns (LBPairInformation memory);

    function getPreset(uint256 binStep)
        external
        view
        returns (
            uint256 baseFactor,
            uint256 filterPeriod,
            uint256 decayPeriod,
            uint256 reductionFactor,
            uint256 variableFeeControl,
            uint256 protocolShare,
            uint256 maxAccumulator,
            bool isOpen
        );

    function getAllBinSteps() external view returns (uint256[] memory presetsBinStep);

    function getOpenBinSteps() external view returns (uint256[] memory openBinStep);

    function getAllLBPairs(IERC20 tokenX, IERC20 tokenY)
        external
        view
        returns (LBPairInformation[] memory LBPairsBinStep);

    function setLBPairImplementation(address lbPairImplementation) external;

    function createLBPair(IERC20 tokenX, IERC20 tokenY, uint24 activeId, uint16 binStep)
        external
        returns (ILBPair pair);

    function setLBPairIgnored(IERC20 tokenX, IERC20 tokenY, uint16 binStep, bool ignored) external;

    function setPreset(
        uint16 binStep,
        uint16 baseFactor,
        uint16 filterPeriod,
        uint16 decayPeriod,
        uint16 reductionFactor,
        uint24 variableFeeControl,
        uint16 protocolShare,
        uint24 maxVolatilityAccumulator,
        bool isOpen
    ) external;

    function setPresetOpenState(uint16 binStep, bool isOpen) external;

    function removePreset(uint16 binStep) external;

    function setFeesParametersOnPair(
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        uint16 baseFactor,
        uint16 filterPeriod,
        uint16 decayPeriod,
        uint16 reductionFactor,
        uint24 variableFeeControl,
        uint16 protocolShare,
        uint24 maxVolatilityAccumulator
    ) external;

    function setFeeRecipient(address feeRecipient) external;

    function setFlashLoanFee(uint256 flashLoanFee) external;

    function addQuoteAsset(IERC20 quoteAsset) external;

    function removeQuoteAsset(IERC20 quoteAsset) external;

    function forceDecay(ILBPair lbPair) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

/// @title Liquidity Book Flashloan Callback Interface
/// @author Trader Joe
/// @notice Required interface to interact with LB flash loans
interface ILBFlashLoanCallback {
    function LBFlashLoanCallback(
        address sender,
        IERC20 tokenX,
        IERC20 tokenY,
        bytes32 amounts,
        bytes32 totalFees,
        bytes calldata data
    ) external returns (bytes32);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Token Interface
 * @author Trader Joe
 * @notice Interface to interact with the LBToken.
 */
interface ILBToken {
    error LBToken__AddressThisOrZero();
    error LBToken__InvalidLength();
    error LBToken__SelfApproval(address owner);
    error LBToken__SpenderNotApproved(address from, address spender);
    error LBToken__TransferExceedsBalance(address from, uint256 id, uint256 amount);
    error LBToken__BurnExceedsBalance(address from, uint256 id, uint256 amount);

    event TransferBatch(
        address indexed sender, address indexed from, address indexed to, uint256[] ids, uint256[] amounts
    );

    event ApprovalForAll(address indexed account, address indexed sender, bool approved);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function totalSupply(uint256 id) external view returns (uint256);

    function balanceOf(address account, uint256 id) external view returns (uint256);

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    function isApprovedForAll(address owner, address spender) external view returns (bool);

    function approveForAll(address spender, bool approved) external;

    function batchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts) external;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20PermitUpgradeable {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

/**
 * @title Liquidity Book Pending Ownable Interface
 * @author Trader Joe
 * @notice Required interface of Pending Ownable contract used for LBFactory
 */
interface IPendingOwnable {
    error PendingOwnable__AddressZero();
    error PendingOwnable__NoPendingOwner();
    error PendingOwnable__NotOwner();
    error PendingOwnable__NotPendingOwner();
    error PendingOwnable__PendingOwnerAlreadySet();

    event PendingOwnerSet(address indexed pendingOwner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function setPendingOwner(address pendingOwner) external;

    function revokePendingOwner() external;

    function becomeOwner() external;

    function renounceOwnership() external;
}