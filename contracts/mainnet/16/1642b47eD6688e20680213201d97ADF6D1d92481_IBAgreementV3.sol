// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IComptroller.sol";
import "./interfaces/IConverter.sol";
import "./interfaces/IIToken.sol";
import "./interfaces/IPriceFeed.sol";
import "./interfaces/IPriceOracle.sol";

contract IBAgreementV3 is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    address public immutable executor;
    address public immutable borrower;
    address public immutable governor;
    IComptroller public immutable comptroller;
    IERC20 public immutable collateral;
    uint256 public immutable collateralFactor;
    uint256 public immutable liquidationFactor;
    uint256 public immutable closeFactor;
    uint256 public collateralCap;
    IPriceFeed public priceFeed;
    mapping(IIToken => IConverter) public converters;

    event Liquidated(
        address collateral,
        uint256 collateralAmount,
        address market,
        uint256 repayAmount
    );
    event CollateralCapUpdated(uint256 oldCap, uint256 newCap);
    event PriceFeedUpdated(address oldFeed, address newFeed);
    event ConverterUpdated(
        address market,
        address oldConverter,
        address newConverter
    );
    event TokenSeized(address token, uint256 amount);

    modifier onlyBorrower() {
        require(msg.sender == borrower, "caller is not the borrower");
        _;
    }

    modifier onlyExecutor() {
        require(msg.sender == executor, "caller is not the executor");
        _;
    }

    modifier onlyGovernor() {
        require(msg.sender == governor, "caller is not the governor");
        _;
    }

    /**
     * @dev Sets the values for {executor}, {borrower}, {governor}, {comptroller}, {collateral}, {priceFeed}, {collateralFactor}, {liquidationFactor}, {closeFactor}, and {collateralCap}.
     *
     * {collateral} must be a vanilla ERC20 token.
     *
     * All of these values except {priceFeed} and {collateralCap} are immutable: they can only be set once during construction.
     */
    constructor(
        address _executor,
        address _borrower,
        address _governor,
        address _comptroller,
        address _collateral,
        address _priceFeed,
        uint256 _collateralFactor,
        uint256 _liquidationFactor,
        uint256 _closeFactor,
        uint256 _collateralCap
    ) {
        executor = _executor;
        borrower = _borrower;
        governor = _governor;
        comptroller = IComptroller(_comptroller);
        collateral = IERC20(_collateral);
        priceFeed = IPriceFeed(_priceFeed);
        collateralFactor = _collateralFactor;
        liquidationFactor = _liquidationFactor;
        closeFactor = _closeFactor;
        collateralCap = _collateralCap;

        require(_collateral == priceFeed.getToken(), "mismatch price feed");
        require(
            _collateralFactor > 0 && _collateralFactor <= 1e18,
            "invalid collateral factor"
        );
        require(
            _liquidationFactor >= _collateralFactor &&
                _liquidationFactor <= 1e18,
            "invalid liquidation factor"
        );
        require(
            _closeFactor > 0 && _closeFactor <= 1e18,
            "invalid close factor"
        );
    }

    /**
     * @notice Get the current debt in USD value of this contract
     * @return The borrow balance in USD value
     */
    function debtUSD() external view returns (uint256) {
        return getHypotheticalDebtValue(address(0), 0);
    }

    /**
     * @notice Get the hypothetical debt in USD value of this contract after borrow
     * @param market The market
     * @param borrowAmount The hypothetical borrow amount
     * @return The hypothetical debt in USD value
     */
    function hypotheticalDebtUSD(IIToken market, uint256 borrowAmount)
        external
        view
        returns (uint256)
    {
        return getHypotheticalDebtValue(address(market), borrowAmount);
    }

    /**
     * @notice Get the max value in USD to use for borrow in this contract
     * @return The USD value
     */
    function collateralUSD() external view returns (uint256) {
        uint256 value = getHypotheticalCollateralValue(0);
        return (value * collateralFactor) / 1e18;
    }

    /**
     * @notice Get the hypothetical max value in USD to use for borrow in this contract after withdraw
     * @param withdrawAmount The hypothetical withdraw amount
     * @return The hypothetical USD value
     */
    function hypotheticalCollateralUSD(uint256 withdrawAmount)
        external
        view
        returns (uint256)
    {
        uint256 value = getHypotheticalCollateralValue(withdrawAmount);
        return (value * collateralFactor) / 1e18;
    }

    /**
     * @notice Get the lquidation threshold. It represents the max value of collateral that we recongized.
     * @dev If the debt is greater than the liquidation threshold, this agreement is liquidatable.
     * @return The lquidation threshold
     */
    function liquidationThreshold() external view returns (uint256) {
        uint256 value = getHypotheticalCollateralValue(0);
        return (value * liquidationFactor) / 1e18;
    }

    /**
     * @notice Borrow from market if the collateral is sufficient
     * @param market The market
     * @param amount The borrow amount
     */
    function borrow(IIToken market, uint256 amount)
        external
        nonReentrant
        whenNotPaused
        onlyBorrower
    {
        borrowInternal(market, amount);
    }

    /**
     * @notice Borrow max from market with current price
     * @param market The market
     */
    function borrowMax(IIToken market)
        external
        nonReentrant
        whenNotPaused
        onlyBorrower
    {
        (, , uint256 borrowBalance, ) = market.getAccountSnapshot(
            address(this)
        );

        IPriceOracle oracle = IPriceOracle(comptroller.oracle());

        uint256 maxBorrowAmount = (this.collateralUSD() * 1e18) /
            oracle.getUnderlyingPrice(address(market));
        require(maxBorrowAmount > borrowBalance, "undercollateralized");
        borrowInternal(market, maxBorrowAmount - borrowBalance);
    }

    /**
     * @notice Withdraw the collateral if sufficient
     * @param amount The withdraw amount
     */
    function withdraw(uint256 amount) external nonReentrant onlyBorrower {
        uint256 debt = this.debtUSD();
        if (debt != 0) {
            // If there is still debt, must be unpaused and undercollateralized to withdraw.
            _requireNotPaused();
            require(
                debt <= this.hypotheticalCollateralUSD(amount),
                "undercollateralized"
            );
        }
        collateral.safeTransfer(borrower, amount);
    }

    /**
     * @notice Repay the debts
     * @param market The market
     * @param amount The repay amount
     */
    function repay(IIToken market, uint256 amount)
        external
        nonReentrant
        onlyBorrower
    {
        IERC20 underlying = IERC20(market.underlying());
        underlying.safeTransferFrom(msg.sender, address(this), amount);
        repayInternal(market, amount);
    }

    /**
     * @notice Fully repay the debts
     * @param market The market
     */
    function repayFull(IIToken market) external nonReentrant onlyBorrower {
        // Get the current borrow balance including interests.
        uint256 borrowBalance = market.borrowBalanceCurrent(address(this));

        IERC20 underlying = IERC20(market.underlying());
        underlying.safeTransferFrom(msg.sender, address(this), borrowBalance);
        repayInternal(market, borrowBalance);
    }

    /**
     * @notice Seize the tokens
     * @param token The token
     * @param amount The amount
     */
    function seize(IERC20 token, uint256 amount) external onlyExecutor {
        require(
            address(token) != address(collateral),
            "seize collateral not allow"
        );
        token.safeTransfer(executor, amount);
        emit TokenSeized(address(token), amount);
    }

    /**
     * @notice Liquidate with exact collateral amount for a given market
     * @param market The market
     * @param collateralAmount The collateral amount for liquidation
     * @param repayAmountMin The min repay amount after conversion
     */
    function liquidateWithExactCollateralAmount(
        IIToken market,
        uint256 collateralAmount,
        uint256 repayAmountMin
    ) external onlyExecutor {
        checkLiquidatable(market);

        require(
            collateralAmount <=
                (getHypotheticalCollateralBalance(0) * closeFactor) / 1e18,
            "liquidate too much"
        );

        // Approve and convert.
        IERC20(collateral).safeIncreaseAllowance(
            address(converters[market]),
            collateralAmount
        );
        uint256 amountOut = converters[market].convertExactTokensForTokens(
            collateralAmount,
            repayAmountMin
        );

        emit Liquidated(
            address(collateral),
            collateralAmount,
            address(market),
            amountOut
        );

        // Repay the debts.
        repayInternal(market, amountOut);
    }

    /**
     * @notice Liquidate for exact repay amount for a given market
     * @param market The market
     * @param repayAmount The desired repay amount
     * @param collateralAmountMax The max collateral amount for liquidation
     */
    function liquidateForExactRepayAmount(
        IIToken market,
        uint256 repayAmount,
        uint256 collateralAmountMax
    ) external onlyExecutor {
        checkLiquidatable(market);

        uint256 amountIn = converters[market].getAmountIn(repayAmount);
        require(amountIn <= collateralAmountMax, "too much collateral needed");

        require(
            amountIn <=
                (getHypotheticalCollateralBalance(0) * closeFactor) / 1e18,
            "liquidate too much"
        );

        // Approve and convert.
        IERC20(collateral).safeIncreaseAllowance(
            address(converters[market]),
            amountIn
        );
        converters[market].convertTokensForExactTokens(
            repayAmount,
            collateralAmountMax
        );

        emit Liquidated(
            address(collateral),
            amountIn,
            address(market),
            repayAmount
        );

        // Repay the debts.
        repayInternal(market, repayAmount);
    }

    /**
     * @notice Set the converter for liquidation
     * @param _markets The markets
     * @param _converters The converters
     */
    function setConverter(
        IIToken[] calldata _markets,
        IConverter[] calldata _converters
    ) external onlyExecutor {
        require(_markets.length == _converters.length, "length mismatch");
        for (uint256 i = 0; i < _markets.length; i++) {
            require(address(_converters[i]) != address(0), "empty converter");
            require(
                _converters[i].source() == address(collateral),
                "mismatch source token"
            );
            require(
                _converters[i].destination() == _markets[i].underlying(),
                "mismatch destination token"
            );
            address oldConverter = address(converters[_markets[i]]);
            converters[_markets[i]] = IConverter(_converters[i]);

            emit ConverterUpdated(
                address(_markets[i]),
                oldConverter,
                address(_converters[i])
            );
        }
    }

    /**
     * @notice Pause the IB Agreement
     */
    function pause() external onlyExecutor {
        _pause();
    }

    /**
     * @notice Unpause the IB Agreement
     */
    function unpause() external onlyExecutor {
        _unpause();
    }

    /**
     * @notice Set the collateral cap
     * @param _collateralCap The new cap
     */
    function setCollateralCap(uint256 _collateralCap) external onlyGovernor {
        uint256 oldCap = collateralCap;
        collateralCap = _collateralCap;

        emit CollateralCapUpdated(oldCap, _collateralCap);
    }

    /**
     * @notice Set the price feed of the collateral
     * @param _priceFeed The new price feed
     */
    function setPriceFeed(address _priceFeed) external onlyGovernor {
        require(
            address(collateral) == IPriceFeed(_priceFeed).getToken(),
            "mismatch price feed"
        );

        address oldFeed = address(priceFeed);
        priceFeed = IPriceFeed(_priceFeed);
        emit PriceFeedUpdated(oldFeed, _priceFeed);
    }

    /* Internal functions */

    /**
     * @notice Get the current collateral balance, min(balance, cap)
     * @param withdrawAmount The hypothetical withdraw amount
     * @return The collateral balance
     */
    function getHypotheticalCollateralBalance(uint256 withdrawAmount)
        internal
        view
        returns (uint256)
    {
        uint256 balance = collateral.balanceOf(address(this)) - withdrawAmount;
        if (collateralCap != 0 && collateralCap <= balance) {
            balance = collateralCap;
        }
        return balance;
    }

    /**
     * @notice Get the current debt of this contract
     * @param borrowMarket The hypothetical borrow market
     * @param borrowAmount The hypothetical borrow amount
     * @return The borrow balance
     */
    function getHypotheticalDebtValue(
        address borrowMarket,
        uint256 borrowAmount
    ) internal view returns (uint256) {
        uint256 debt;
        address[] memory borrowedAssets = comptroller.getAssetsIn(
            address(this)
        );
        IPriceOracle oracle = IPriceOracle(comptroller.oracle());
        for (uint256 i = 0; i < borrowedAssets.length; i++) {
            IIToken market = IIToken(borrowedAssets[i]);
            uint256 amount;
            (, , uint256 borrowBalance, ) = market.getAccountSnapshot(
                address(this)
            );
            if (address(market) == borrowMarket) {
                amount = borrowBalance + borrowAmount;
            } else {
                amount = borrowBalance;
            }
            debt +=
                (amount * oracle.getUnderlyingPrice(address(market))) /
                1e18;
        }
        return debt;
    }

    /**
     * @notice Get the hypothetical collateral in USD value in this contract after withdraw
     * @param withdrawAmount The hypothetical withdraw amount
     * @return The hypothetical collateral in USD value
     */
    function getHypotheticalCollateralValue(uint256 withdrawAmount)
        internal
        view
        returns (uint256)
    {
        uint256 balance = getHypotheticalCollateralBalance(withdrawAmount);
        uint8 decimals = IERC20Metadata(address(collateral)).decimals();
        uint256 normalizedBalance = balance * 10**(18 - decimals);
        return (normalizedBalance * priceFeed.getPrice()) / 1e18;
    }

    /**
     * @notice Check if the market is liquidatable
     * @param market The market
     */
    function checkLiquidatable(IIToken market) internal view {
        IERC20 underlying = IERC20(market.underlying());
        require(
            this.debtUSD() > this.liquidationThreshold(),
            "not liquidatable"
        );
        require(address(converters[market]) != address(0), "empty converter");
        require(
            converters[market].source() == address(collateral),
            "mismatch source token"
        );
        require(
            converters[market].destination() == address(underlying),
            "mismatch destination token"
        );
    }

    /**
     * @notice Borrow from market
     * @param market The market
     * @param _amount The borrow amount
     */
    function borrowInternal(IIToken market, uint256 _amount) internal {
        require(
            getHypotheticalDebtValue(address(market), _amount) <=
                this.collateralUSD(),
            "undercollateralized"
        );
        require(market.borrow(_amount) == 0, "borrow failed");
        IERC20(market.underlying()).safeTransfer(borrower, _amount);
    }

    /**
     * @notice Repay the debts
     * @param _amount The repay amount
     */
    function repayInternal(IIToken market, uint256 _amount) internal {
        IERC20(market.underlying()).safeIncreaseAllowance(
            address(market),
            _amount
        );
        require(market.repayBorrow(_amount) == 0, "repay failed");
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
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
        IERC20 token,
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
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
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
        IERC20Permit token,
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
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IComptroller {
    function oracle() external view returns (address);

    function getAssetsIn(address account)
        external
        view
        returns (address[] memory);

    function isMarketListed(address cTokenAddress) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IConverter {
    function convertExactTokensForTokens(uint256 amountIn, uint256 amountOutMin)
        external
        returns (uint256);

    function convertTokensForExactTokens(uint256 amountOut, uint256 amountInMax)
        external
        returns (uint256);

    function getAmountOut(uint256 amountIn) external returns (uint256);

    function getAmountIn(uint256 amountOut) external returns (uint256);

    function source() external view returns (address);

    function destination() external view returns (address);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IIToken {
    function borrow(uint256 borrowAmount) external returns (uint256);

    function repayBorrow(uint256 repayAmount) external returns (uint256);

    function underlying() external view returns (address);

    function getAccountSnapshot(address account)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function comptroller() external view returns (address);

    function borrowBalanceCurrent(address account) external returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceFeed {
    function getToken() external view returns (address);

    function getPrice() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
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
interface IERC20Permit {
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
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
        return functionCall(target, data, "Address: low-level call failed");
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
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
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
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
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
}