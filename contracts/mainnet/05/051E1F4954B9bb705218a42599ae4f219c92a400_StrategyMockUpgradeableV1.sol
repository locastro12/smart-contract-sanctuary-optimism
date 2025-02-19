//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Lyra
import {LyraAdapterUpgradeable} from "./LyraAdapterUpgradeable.sol";

// Libraries & Interfaces
import {IERC20} from "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import {IOptionMarket} from "@lyrafinance/protocol/contracts/interfaces/IOptionMarket.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";

contract StrategyMockUpgradeableV1 is LyraAdapterUpgradeable {
    using DecimalMath for uint256;
    using SignedDecimalMath for int256;

    address public vault;
    uint256[] public activeStrikeIds;
    mapping(uint256 => uint256) public strikeToPositionId;
    mapping(uint256 => uint256) public lastTradeTimestamp;

    function initialize(address _vault) public virtual initializer {
        __StrategyMockUpgradeableV1_init(_vault);
    }

    function __StrategyMockUpgradeableV1_init(address _vault)
        internal
        onlyInitializing
    {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __LyraAdapterUpgradeable_init_unchained();
        __StrategyMockUpgradeableV1_init_unchained(_vault);
    }

    function __StrategyMockUpgradeableV1_init_unchained(address _vault)
        internal
        onlyInitializing
    {
        vault = _vault;
    }

    modifier onlyVault() virtual {
        require(_msgSender() == vault, "!vault");
        _;
    }

    function initAdapter(
        address _lyraRegistry,
        address _optionMarket,
        address _curveSwap,
        address _feeCounter
    ) external onlyOwner {
        // set addresses for LyraVaultAdapter
        setLyraAddresses(_lyraRegistry, _optionMarket, _curveSwap, _feeCounter);
        quoteAsset.approve(vault, type(uint256).max);
        baseAsset.approve(vault, type(uint256).max);
    }

    ///////////////////////////////////
    //            ADMIN             //
    /////////////////////////////////

    function returnFundsToVault() external onlyVault {
        uint256 baseBalance = baseAsset.balanceOf(address(this));
        if (baseBalance > 0) {
            baseAsset.transfer(vault, baseBalance);
        }
        uint256 quoteBalance = quoteAsset.balanceOf(address(this));
        if (quoteBalance > 0) {
            quoteAsset.transfer(vault, quoteBalance);
        }
    }

    function clearAllActiveStrikes() external onlyVault {
        if (activeStrikeIds.length != 0) {
            for (uint256 i = 0; i < activeStrikeIds.length; i++) {
                uint256 strikeId = activeStrikeIds[i];
                delete strikeToPositionId[strikeId];
                delete lastTradeTimestamp[strikeId];
            }
            delete activeStrikeIds;
        }
    }

    ///////////////////////////////////
    //          STRATEGY            //
    /////////////////////////////////

    struct StrategyStrike {
        uint256 strikeId;
        OptionType optionType;
        uint256 positionSize;
        uint256 minMaxVolatility;
        uint256 collateralPercent;
    }

    StrategyStrike[] private _strategyStrikes;

    function strategySetStrikes(StrategyStrike[] memory strategyStrikes)
        external
        onlyVault
    {
        delete _strategyStrikes;
        for (uint256 i = 0; i < strategyStrikes.length; i++) {
            _strategyStrikes.push(strategyStrikes[i]);
        }
    }

    function strategyGetStrikes(uint256 index)
        external
        view
        returns (StrategyStrike memory)
    {
        return _strategyStrikes[index];
    }

    function strategyExecute(uint256 sizeMultiplier) external onlyVault {
        for (uint256 i = 0; i < _strategyStrikes.length; i++) {
            StrategyStrike memory strike = _strategyStrikes[i];
            if (_isLong(strike.optionType)) {
                _buyStrike(
                    BuyStrikeParams(
                        strike.optionType,
                        strike.strikeId,
                        strike.positionSize.multiplyDecimal(sizeMultiplier),
                        strike.minMaxVolatility,
                        address(0)
                    )
                );
            } else {
                _sellStrike(
                    SellStrikeParams(
                        strike.optionType,
                        strike.strikeId,
                        strike.positionSize.multiplyDecimal(sizeMultiplier),
                        strike.minMaxVolatility,
                        strike.collateralPercent,
                        address(0)
                    )
                );
            }
        }
    }

    ///////////////////////////////////
    //            LONG              //
    /////////////////////////////////

    /**
     * @dev Performs LONG_CALL trade
     */
    function do_LONG_CALL(
        uint256 strikeId,
        uint256 size,
        uint256 maxVol
    ) external onlyVault returns (uint256 positionId, uint256 premiumPayed) {
        OptionType optionType = OptionType.LONG_CALL;
        (positionId, premiumPayed) = _buyStrike(
            BuyStrikeParams(optionType, strikeId, size, maxVol, address(0))
        );
    }

    /**
     * @dev Performs LONG_PUT trade
     */
    function do_LONG_PUT(
        uint256 strikeId,
        uint256 size,
        uint256 maxVol
    ) external onlyVault returns (uint256 positionId, uint256 premiumPayed) {
        OptionType optionType = OptionType.LONG_PUT;
        (positionId, premiumPayed) = _buyStrike(
            BuyStrikeParams(optionType, strikeId, size, maxVol, address(0))
        );
    }

    struct BuyStrikeParams {
        OptionType optionType;
        uint256 strikeId;
        uint256 size;
        uint256 maxVol;
        address lyraRewardRecipient;
    }

    function _buyStrike(BuyStrikeParams memory params)
        internal
        returns (uint256, uint256)
    {
        Strike memory strike = _getStrikes(_toDynamic(params.strikeId))[0];

        uint256 maxExpectedPremium = _getPremiumLimit(
            params.optionType,
            strike,
            params.size,
            params.maxVol
        );

        uint256 currentBalance = quoteAsset.balanceOf(address(this));
        if (maxExpectedPremium > currentBalance) {
            require(
                quoteAsset.transferFrom(
                    address(vault),
                    address(this),
                    maxExpectedPremium - currentBalance
                ),
                "Collateral transfer from the vault failed"
            );
        }

        TradeResult memory result = _openPosition(
            TradeInputParameters({
                strikeId: strike.id,
                positionId: strikeToPositionId[strike.id],
                iterations: 3,
                optionType: params.optionType,
                amount: params.size,
                setCollateralTo: 0,
                minTotalCost: 0,
                maxTotalCost: maxExpectedPremium,
                rewardRecipient: params.lyraRewardRecipient
            })
        );

        _setLastTradedAt(strike.id, block.timestamp);
        _addActiveStrike(strike.id, result.positionId);

        require(
            result.totalCost <= maxExpectedPremium,
            "Premium paid is above max expected premium"
        );

        return (result.positionId, result.totalCost);
    }

    ///////////////////////////////////
    //            SHORT             //
    /////////////////////////////////

    /**
     * @dev Performs SHORT_CALL_QUOTE trade
     */
    function do_SHORT_CALL_BASE(
        uint256 strikeId,
        uint256 size,
        uint256 minVol,
        uint256 collateralPercent
    ) external onlyVault returns (uint256 positionId, uint256 premiumReceived) {
        OptionType optionType = OptionType.SHORT_CALL_BASE;
        (positionId, premiumReceived) = _sellStrike(
            SellStrikeParams(
                optionType,
                strikeId,
                size,
                minVol,
                collateralPercent,
                address(0)
            )
        );
    }

    /**
     * @dev Performs SHORT_CALL_QUOTE trade
     */
    function do_SHORT_CALL_QUOTE(
        uint256 strikeId,
        uint256 size,
        uint256 minVol,
        uint256 collateralPercent
    ) external onlyVault returns (uint256 positionId, uint256 premiumReceived) {
        OptionType optionType = OptionType.SHORT_CALL_QUOTE;
        (positionId, premiumReceived) = _sellStrike(
            SellStrikeParams(
                optionType,
                strikeId,
                size,
                minVol,
                collateralPercent,
                address(0)
            )
        );
    }

    /**
     * @dev Performs SHORT_PUT_QUOTE trade
     */
    function do_SHORT_PUT_QUOTE(
        uint256 strikeId,
        uint256 size,
        uint256 minVol,
        uint256 collateralPercent
    ) external onlyVault returns (uint256 positionId, uint256 premiumReceived) {
        OptionType optionType = OptionType.SHORT_PUT_QUOTE;
        (positionId, premiumReceived) = _sellStrike(
            SellStrikeParams(
                optionType,
                strikeId,
                size,
                minVol,
                collateralPercent,
                address(0)
            )
        );
    }

    struct SellStrikeParams {
        OptionType optionType;
        uint256 strikeId;
        uint256 size;
        uint256 minVol;
        uint256 collateralPercent;
        address lyraRewardRecipient;
    }

    function _sellStrike(SellStrikeParams memory params)
        internal
        returns (uint256, uint256)
    {
        Strike memory strike = _getStrikes(_toDynamic(params.strikeId))[0];

        IERC20 collateralAsset = _isBaseCollat(params.optionType)
            ? baseAsset
            : quoteAsset;

        (
            uint256 collateralToAdd,
            uint256 setCollateralTo
        ) = _getRequiredCollateral(
                params.optionType,
                strike,
                params.size,
                params.collateralPercent
            );

        uint256 currentBalance = collateralAsset.balanceOf(address(this));

        if (collateralToAdd > currentBalance) {
            require(
                collateralAsset.transferFrom(
                    address(vault),
                    address(this),
                    collateralToAdd - currentBalance
                ),
                "Collateral transfer from the vault failed"
            );
        }

        uint256 minExpectedPremium = _getPremiumLimit(
            params.optionType,
            strike,
            params.size,
            params.minVol
        );

        TradeResult memory result = _openPosition(
            TradeInputParameters({
                strikeId: strike.id,
                positionId: strikeToPositionId[strike.id],
                iterations: 3,
                optionType: params.optionType,
                amount: params.size,
                setCollateralTo: setCollateralTo,
                minTotalCost: minExpectedPremium,
                maxTotalCost: type(uint256).max,
                rewardRecipient: params.lyraRewardRecipient
            })
        );

        _setLastTradedAt(strike.id, block.timestamp);
        _addActiveStrike(strike.id, result.positionId);

        require(
            result.totalCost >= minExpectedPremium,
            "Premium received is below min expected premium"
        );

        return (result.positionId, result.totalCost);
    }

    ///////////////////////////////////
    //            VIEWS             //
    /////////////////////////////////

    /**
     * @dev Calculates the minimum premium that the vault should receive
     */
    function getPremiumLimit(
        OptionType optionType,
        uint256 strikeId,
        uint256 size,
        uint256 maxVol
    ) external view returns (uint256 limitPremium) {
        Strike memory strike = _getStrikes(_toDynamic(strikeId))[0];
        limitPremium = _getPremiumLimit(optionType, strike, size, maxVol);
    }

    /**
     * @dev Calculates the required collateral to add in the next trade
     */
    function getRequiredCollateral(
        OptionType optionType,
        uint256 strikeId,
        uint256 size,
        uint256 collateralPercent
    ) external view returns (uint256 collateralToAdd, uint256 setCollateralTo) {
        Strike memory strike = _getStrikes(_toDynamic(strikeId))[0];
        (collateralToAdd, setCollateralTo) = _getRequiredCollateral(
            optionType,
            strike,
            size,
            collateralPercent
        );
    }

    /**
     * @dev Returns option market params
     */
    function lyraGetOptionMarketParams()
        external
        view
        returns (IOptionMarket.OptionMarketParameters memory params)
    {
        params = optionMarket.getOptionMarketParams();
    }

    /**
     * @dev Returns the list of live board ids
     */
    function lyraGetLiveBoards()
        external
        view
        returns (uint256[] memory liveBoards)
    {
        liveBoards = optionMarket.getLiveBoards();
    }

    /**
     * @dev Returns the number of current live boards
     */
    function lyraGetNumLiveBoards()
        external
        view
        returns (uint256 numLiveBoards)
    {
        numLiveBoards = optionMarket.getNumLiveBoards();
    }

    /**
     * @dev Returns the strike and expiry for a given strikeId
     */
    function lyraGetStrikeAndExpiry(uint256 strikeId)
        external
        view
        returns (uint256 strikePrice, uint256 expiry)
    {
        (strikePrice, expiry) = optionMarket.getStrikeAndExpiry(strikeId);
    }

    /**
     * @dev Returns the strike ids for a given `boardId`
     * @param boardId The id of the relevant OptionBoard
     */
    function lyraGetBoardStrikes(uint256 boardId)
        external
        view
        returns (uint256[] memory strikeIds)
    {
        strikeIds = optionMarket.getBoardStrikes(boardId);
    }

    /**
     * @dev Returns the Strike struct for a given strikeId
     */
    function lyraGetStrike(uint256 strikeId)
        external
        view
        returns (IOptionMarket.Strike memory strike)
    {
        strike = optionMarket.getStrike(strikeId);
    }

    /**
     * @dev Returns the OptionBoard struct for a given boardId
     */
    function lyraGetOptionBoard(uint256 boardId)
        external
        view
        returns (IOptionMarket.OptionBoard memory board)
    {
        board = optionMarket.getOptionBoard(boardId);
    }

    /**
     * @dev Returns the Strike and OptionBoard structs for a given strikeId
     */
    function lyraGetStrikeAndBoard(uint256 strikeId)
        external
        view
        returns (
            IOptionMarket.Strike memory strike,
            IOptionMarket.OptionBoard memory board
        )
    {
        (strike, board) = optionMarket.getStrikeAndBoard(strikeId);
    }

    /**
     * @dev Returns board and strike details given a boardId
     * @return board the OptionBoard struct
     * @return strikes the list of board strikes
     * @return strikesToBaseReturnedRatio the list of strike to base returned ratios
     * @return boardToPriceAtExpiry the board to price at expiry
     */
    function lyraGetBoardAndStrikeDetails(uint256 boardId)
        external
        view
        returns (
            IOptionMarket.OptionBoard memory board,
            IOptionMarket.Strike[] memory strikes,
            uint256[] memory strikesToBaseReturnedRatio,
            uint256 boardToPriceAtExpiry
        )
    {
        (
            board,
            strikes,
            strikesToBaseReturnedRatio,
            boardToPriceAtExpiry
        ) = optionMarket.getBoardAndStrikeDetails(boardId);
    }

    /**
     * @dev Get position info for given positionIds
     */
    function lyraGetPositions(uint256[] memory positionIds)
        internal
        view
        returns (OptionPosition[] memory positions)
    {
        positions = _getPositions(positionIds);
    }

    ///////////////////////////////////
    //           INTERNAL           //
    /////////////////////////////////

    /**
     * @dev Calculates the premium limit
     */
    function _getPremiumLimit(
        OptionType optionType,
        Strike memory strike,
        uint256 size,
        uint256 vol
    ) internal view returns (uint256 limitPremium) {
        ExchangeRateParams memory exchangeParams = _getExchangeParams();

        (uint256 callPremium, uint256 putPremium) = _getPurePremium(
            _getSecondsToExpiry(strike.expiry),
            vol,
            exchangeParams.spotPrice,
            strike.strikePrice
        );

        limitPremium = _isCall(optionType)
            ? callPremium.multiplyDecimal(size)
            : putPremium.multiplyDecimal(size);
    }

    /**
     * @dev Calculates the required collateral to add in the next trade
     */
    function _getRequiredCollateral(
        OptionType optionType,
        Strike memory strike,
        uint256 size,
        uint256 collateralPercent
    ) internal view returns (uint256 collateralToAdd, uint256 setCollateralTo) {
        uint256 existingCollateral = 0;
        if (_isActiveStrike(strike.id)) {
            existingCollateral = _getPositions(
                _toDynamic(strikeToPositionId[strike.id])
            )[0].collateral;
        }

        collateralToAdd = _isBaseCollat(optionType)
            ? size.multiplyDecimal(collateralPercent)
            : size.multiplyDecimal(strike.strikePrice).multiplyDecimal(
                collateralPercent
            );

        setCollateralTo = existingCollateral + collateralToAdd;
    }

    /**
     * @dev Adds strike id to activeStrikeIds array
     */
    function _addActiveStrike(uint256 strikeId, uint256 tradedPositionId)
        internal
    {
        if (!_isActiveStrike(strikeId)) {
            strikeToPositionId[strikeId] = tradedPositionId;
            activeStrikeIds.push(strikeId);
        }
    }

    /**
     * @dev Adds the last traded timestamp for a specific strike
     */
    function _setLastTradedAt(uint256 strikeId, uint256 timestamp) internal {
        lastTradeTimestamp[strikeId] = timestamp;
    }

    function _getSecondsToExpiry(uint256 expiry)
        internal
        view
        returns (uint256)
    {
        require(block.timestamp <= expiry, "Timestamp expired");
        return expiry - block.timestamp;
    }

    function _isActiveStrike(uint256 strikeId)
        internal
        view
        returns (bool isActive)
    {
        isActive = strikeToPositionId[strikeId] != 0;
    }

    function _isCall(OptionType optionType)
        internal
        pure
        returns (bool isCall)
    {
        isCall = (optionType == OptionType.SHORT_PUT_QUOTE ||
            optionType == OptionType.LONG_PUT)
            ? false
            : true;
    }

    function _isBaseCollat(OptionType optionType)
        internal
        pure
        returns (bool isBase)
    {
        isBase = (optionType == OptionType.SHORT_CALL_BASE) ? true : false;
    }

    function _abs(int256 val) internal pure returns (uint256) {
        return val >= 0 ? uint256(val) : uint256(-val);
    }

    function _min(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x < y) ? x : y;
    }

    function _max(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y) ? x : y;
    }

    // temporary fix - eth core devs promised Q2 2022 fix
    function _toDynamic(uint256 val)
        internal
        pure
        returns (uint256[] memory dynamicArray)
    {
        dynamicArray = new uint256[](1);
        dynamicArray[0] = val;
    }
}

//SPDX-License-Identifier:ISC
pragma solidity ^0.8.9;

// Libraries
import "@lyrafinance/protocol/contracts/libraries/GWAV.sol";
import "@lyrafinance/protocol/contracts/libraries/BlackScholes.sol";
import "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";

// Inherited
import "openzeppelin-contracts-upgradeable-4.5.1/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

// Interfaces
import "@lyrafinance/protocol/contracts/interfaces/IOptionToken.sol";
import "@lyrafinance/protocol/contracts/interfaces/IOptionMarket.sol";
import "@lyrafinance/protocol/contracts/interfaces/ILiquidityPool.sol";
import "@lyrafinance/protocol/contracts/interfaces/IShortCollateral.sol";
import "@lyrafinance/protocol/contracts/interfaces/IOptionGreekCache.sol";
import "@lyrafinance/protocol/contracts/interfaces/ISynthetixAdapter.sol";
import "@lyrafinance/protocol/contracts/interfaces/IDelegateApprovals.sol";
import "@lyrafinance/protocol/contracts/interfaces/ICurve.sol";
import "@lyrafinance/protocol/contracts/interfaces/IGWAVOracle.sol";
import "@lyrafinance/protocol/contracts/interfaces/ILyraRegistry.sol";
import "@lyrafinance/protocol/contracts/periphery/BasicFeeCounter.sol";

/**
 * @title LyraAdapter
 * @author Lyra
 * @dev Provides helpful functions for any Lyra trading/market data/vault related actions in one contract
 *      To earn trading rewards, integrators must request to be whitelisted by Lyra
 */

contract LyraAdapterUpgradeable is OwnableUpgradeable {
  using DecimalMath for uint;

  ///////////////////////
  // Abstract Contract //
  ///////////////////////

  struct Strike {
    // strike listing identifier
    uint id;
    // expiry of strike
    uint expiry;
    // strike price
    uint strikePrice;
    // volatility component specific to the strike listing (boardIv * skew = vol of strike)
    uint skew;
    // volatility component specific to the board (boardIv * skew = vol of strike)
    uint boardIv;
  }

  struct Board {
    // board identifier
    uint id;
    // expiry of all strikes belong to
    uint expiry;
    // volatility component specific to the board (boardIv * skew = vol of strike)
    uint boardIv;
    // all strikes belonging to board
    uint[] strikeIds;
  }

  struct OptionPosition {
    // OptionToken ERC721 identifier for position
    uint positionId;
    // strike identifier
    uint strikeId;
    // LONG_CALL | LONG_PUT | SHORT_CALL_BASE | SHORT_CALL_QUOTE | SHORT_PUT_QUOTE
    OptionType optionType;
    // number of options contract owned by position
    uint amount;
    // collateral held in position (only applies to shorts)
    uint collateral;
    // EMPTY | ACTIVE | CLOSED | LIQUIDATED | SETTLED | MERGED
    PositionState state;
  }

  enum OptionType {
    LONG_CALL,
    LONG_PUT,
    SHORT_CALL_BASE,
    SHORT_CALL_QUOTE,
    SHORT_PUT_QUOTE
  }

  enum PositionState {
    EMPTY,
    ACTIVE,
    CLOSED,
    LIQUIDATED,
    SETTLED,
    MERGED
  }

  struct TradeInputParameters {
    // id of strike
    uint strikeId;
    // OptionToken ERC721 id for position (set to 0 for new positions)
    uint positionId;
    // number of sub-orders to break order into (reduces slippage)
    uint iterations;
    // type of option to trade
    OptionType optionType;
    // number of contracts to trade
    uint amount;
    // final amount of collateral to leave in OptionToken position
    uint setCollateralTo;
    // revert trade if totalCost is below this value
    uint minTotalCost;
    // revert trade if totalCost is above this value
    uint maxTotalCost;
    // address of recipient for Lyra trading rewards (must request Lyra to be whitelisted for rewards)
    address rewardRecipient;
  }

  struct TradeResult {
    // OptionToken ERC721 id for position
    uint positionId;
    // total option cost paid/received during trade including premium and totalFee
    uint totalCost;
    // trading fees as determined in OptionMarketPricer.sol
    uint totalFee;
  }

  struct Liquidity {
    // Amount of liquidity available for option collateral and premiums
    uint freeLiquidity;
    // Amount of liquidity available for withdrawals - different to freeLiquidity
    uint burnableLiquidity;
    // Amount of liquidity reserved for long options sold to traders
    uint usedCollatLiquidity;
    // Portion of liquidity reserved for delta hedging (quote outstanding)
    uint pendingDeltaLiquidity;
    // Current value of delta hedge
    uint usedDeltaLiquidity;
    // Net asset value, including everything and netOptionValue
    uint NAV;
  }

  struct MarketParams {
    // The amount of options traded to move baseIv for the board up or down 1 point (depending on trade direction)
    uint standardSize;
    // Determines relative move of skew for a given strike compared to shift in baseIv
    uint skewAdjustmentParam;
    // Interest/risk free rate used in BlackScholes
    int rateAndCarry;
    // Delta cutoff past which options can be traded (optionD > minD && optionD < 1 - minD) - can use forceClose to bypass
    int deltaCutOff;
    // Time when trading closes - can use forceClose to bypass
    uint tradingCutoff;
    // Delta cutoff at which forceClose can be called (optionD < minD || optionD > 1 - minD) - using call delta
    int minForceCloseDelta;
  }

  struct ExchangeRateParams {
    // current snx oracle base price
    uint spotPrice;
    // snx spot exchange rate from quote to base
    uint quoteBaseFeeRate;
    // snx spot exchange rate from base to quote
    uint baseQuoteFeeRate;
  }

  ///////////////
  // Variables //
  ///////////////

  ILyraRegistry public lyraRegistry;
  ISynthetixAdapter internal synthetixAdapter;
  IOptionMarket public optionMarket;
  IOptionToken public optionToken;
  ILiquidityPool public liquidityPool;
  IShortCollateral public shortCollateral;
  IGWAVOracle public gwavOracle;
  IOptionMarketPricer public optionPricer;
  IOptionGreekCache public greekCache;
  IERC20 public quoteAsset;
  IERC20 public baseAsset;

  ICurve public curveSwap;
  BasicFeeCounter public feeCounter;
  bytes32 private constant SNX_ADAPTER = "SYNTHETIX_ADAPTER";

  ///////////
  // Admin //
  ///////////

  function __LyraAdapterUpgradeable_init() internal onlyInitializing {
    __Context_init_unchained();
    __Ownable_init_unchained();
    __LyraAdapterUpgradeable_init_unchained();
  }

  function __LyraAdapterUpgradeable_init_unchained() internal onlyInitializing {
  }

  /**
   * @dev Assigns all lyra contracts

   * @param _lyraRegistry LyraRegistry address which holds latest market and global addressess
   * @param _optionMarket OptionMarket address
   * @param _curveSwap Curve pool address for swapping sUSD and other stables via `exchange_with_best_rate`
   * @param _feeCounter Fee counter addressu used to determine Lyra trading rewards
   */

  function setLyraAddresses(
    address _lyraRegistry,
    address _optionMarket,
    address _curveSwap,
    address _feeCounter
  ) public onlyOwner {
    // remove allowance from old assets
    if (address(quoteAsset) != address(0)) {
      quoteAsset.approve(address(optionMarket), 0);
    }
    if (address(baseAsset) != address(0)) {
      baseAsset.approve(address(optionMarket), 0);
    }

    optionMarket = IOptionMarket(_optionMarket);

    // Get market & global addresses via LyraRegistry
    lyraRegistry = ILyraRegistry(_lyraRegistry);
    synthetixAdapter = ISynthetixAdapter(lyraRegistry.getGlobalAddress(SNX_ADAPTER));
    _assignLyraRegistryMarketAddresses();

    // assign curve and Lyra reward counter
    curveSwap = ICurve(_curveSwap);
    feeCounter = BasicFeeCounter(_feeCounter);

    // Do approvals
    IDelegateApprovals(synthetixAdapter.delegateApprovals()).approveExchangeOnBehalf(address(synthetixAdapter));
    quoteAsset.approve(address(optionMarket), type(uint).max);
    baseAsset.approve(address(optionMarket), type(uint).max);
  }

  /// @notice In case of an update to the synthetix contract that revokes the approval
  function updateDelegateApproval() external onlyOwner {
    IDelegateApprovals(synthetixAdapter.delegateApprovals()).approveExchangeOnBehalf(address(synthetixAdapter));
  }

  ////////////////////
  // Market Actions //
  ////////////////////

  /**
   * @notice Attempts to open positions within cost bounds.
   * @dev If a positionId is specified params.amount will be added to the position
   * @dev params.amount can be zero when adjusting an existing position
   *
   * @param params The parameters for the requested trade
   */
  function _openPosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.openPosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  /**
   * @notice Attempt close under normal condition or forceClose
   *          if position is outside of delta or too close to expiry.
   *
   * @param params The parameters for the requested trade
   */
  function _closeOrForceClosePosition(TradeInputParameters memory params)
    internal
    returns (TradeResult memory tradeResult)
  {
    if (!_isOutsideDeltaCutoff(params.strikeId) && !_isWithinTradingCutoff(params.strikeId)) {
      return _closePosition(params);
    } else {
      // will pay less competitive price to close position but bypasses Lyra delta/trading cutoffs
      return _forceClosePosition(params);
    }
  }

  /**
   * @notice Attempts to close an existing position within cost bounds.
   * @dev If a positionId is specified params.amount will be subtracted from the position
   * @dev params.amount can be zero when adjusting an existing position
   *
   * @param params The parameters for the requested trade
   */
  function _closePosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.closePosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  /**
   * @notice Attempts to close an existing position outside of the delta or trading cutoffs (as specified in MarketParams).
   * @dev This market action will charge higher fees than the standard `closePosition()`
   *
   * @param params The parameters for the requested trade
   */
  function _forceClosePosition(TradeInputParameters memory params) internal returns (TradeResult memory tradeResult) {
    IOptionMarket.Result memory result = optionMarket.forceClosePosition(_convertParams(params));
    if (params.rewardRecipient != address(0)) {
      feeCounter.trackFee(
        address(optionMarket),
        params.rewardRecipient,
        _convertParams(params).amount,
        result.totalCost,
        result.totalFee
      );
    }
    return TradeResult({positionId: result.positionId, totalCost: result.totalCost, totalFee: result.totalFee});
  }

  //////////////
  // Exchange //
  //////////////

  /// @notice Exchange an exact amount of quote for a minimum amount of base (revert otherwise)
  function _exchangeFromExactQuote(uint amountQuote, uint minBaseReceived) internal returns (uint baseReceived) {
    baseReceived = synthetixAdapter.exchangeFromExactQuote(address(optionMarket), amountQuote);
    if (baseReceived < minBaseReceived) {
      revert ExchangerBaseReceivedTooLow(address(this), minBaseReceived, baseReceived);
    }
  }

  /// @notice Exchange to an exact amount of quote for a maximum amount of base (revert otherwise)
  function _exchangeToExactQuote(uint amountQuote, uint maxBaseUsed) internal returns (uint quoteReceived) {
    ISynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));
    (, quoteReceived) = synthetixAdapter.exchangeToExactQuoteWithLimit(
      exchangeParams,
      address(optionMarket),
      amountQuote,
      maxBaseUsed
    );
  }

  /// @notice Exchange an exact amount of base for a minimum amount of quote (revert otherwise)
  function _exchangeFromExactBase(uint amountBase, uint minQuoteReceived) internal returns (uint quoteReceived) {
    quoteReceived = synthetixAdapter.exchangeFromExactBase(address(optionMarket), amountBase);
    if (quoteReceived < minQuoteReceived) {
      revert ExchangerQuoteReceivedTooLow(address(this), minQuoteReceived, quoteReceived);
    }
  }

  /// @notice Exchange to an exact amount of base for a maximum amount of quote (revert otherwise)
  function _exchangeToExactBase(uint amountBase, uint maxQuoteUsed) internal returns (uint baseReceived) {
    ISynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));
    (, baseReceived) = synthetixAdapter.exchangeToExactBaseWithLimit(
      exchangeParams,
      address(optionMarket),
      amountBase,
      maxQuoteUsed
    );
  }

  /// @notice Returns the ExchangeParams for current market.
  function _getExchangeParams() internal view returns (ExchangeRateParams memory) {
    ISynthetixAdapter.ExchangeParams memory params = synthetixAdapter.getExchangeParams(address(optionMarket));
    return
      ExchangeRateParams({
        spotPrice: params.spotPrice,
        quoteBaseFeeRate: params.quoteBaseFeeRate,
        baseQuoteFeeRate: params.baseQuoteFeeRate
      });
  }

  /**
   * @notice WARNING: ENSURE CURVE HAS SUFFICIENT sUSD LIQUIDITY
   *         Exchange between stables within the curveSwap sUSD pool.
   *
   * @param from start ERC20
   * @param to destination ERC20
   * @param amount amount of "from" currency to exchange
   * @param expected minimum expected amount of "to" currency
   * @param receiver address of recipient of "to" currency
   *
   * @return amountOut received amount
   */
  function _swapStables(
    address from,
    address to,
    uint amount,
    uint expected,
    address receiver
  ) internal returns (uint amountOut) {
    amountOut = curveSwap.exchange_with_best_rate(from, to, amount, expected, receiver);
  }

  //////////////////////////
  // Option Token Actions //
  //////////////////////////

  /// @notice Get position info for given positionIds
  function _getPositions(uint[] memory positionIds) internal view returns (OptionPosition[] memory) {
    IOptionToken.OptionPosition[] memory positions = optionToken.getOptionPositions(positionIds);

    uint positionsLen = positions.length;
    OptionPosition[] memory convertedPositions = new OptionPosition[](positionsLen);
    for (uint i = 0; i < positionsLen; ++i) {
      convertedPositions[i] = OptionPosition({
        positionId: positions[i].positionId,
        strikeId: positions[i].strikeId,
        optionType: OptionType(uint(positions[i].optionType)),
        amount: positions[i].amount,
        collateral: positions[i].collateral,
        state: PositionState(uint(positions[i].state))
      });
    }

    return convertedPositions;
  }

  /**
   * @notice Allows a user to split a curent position into two. The amount of the original position will
   *         be subtracted from and a new position will be minted with the desired amount and collateral.
   * @dev Only ACTIVE positions can be owned by users, so status does not need to be checked
   * @dev Both resulting positions must not be liquidatable
   *
   * @param positionId the positionId of the original position to be split
   * @param newAmount the amount in the new position
   * @param newCollateral the amount of collateral for the new position
   * @param recipient recipient of new position
   */
  function _splitPosition(
    uint positionId,
    uint newAmount,
    uint newCollateral,
    address recipient
  ) internal returns (uint newPositionId) {
    newPositionId = optionToken.split(positionId, newAmount, newCollateral, recipient);
  }

  /**
   * @notice User can merge many positions with matching strike and optionType into a single position
   * @dev Only ACTIVE positions can be owned by users, so status does not need to be checked.
   * @dev Merged position must not be liquidatable.
   *
   * @param positionIds the positionIds to be merged together
   */
  function _mergePositions(uint[] memory positionIds) internal {
    optionToken.merge(positionIds);
  }

  ////////////////////
  // Market Getters //
  ////////////////////

  /// @notice Returns the list of live board ids.
  function _getLiveBoards() internal view returns (uint[] memory liveBoards) {
    liveBoards = optionMarket.getLiveBoards();
  }

  /// @notice Returns Board struct for a given boardId
  function _getBoard(uint boardId) internal view returns (Board memory) {
    IOptionMarket.OptionBoard memory board = optionMarket.getOptionBoard(boardId);
    return Board({id: board.id, expiry: board.expiry, boardIv: board.iv, strikeIds: board.strikeIds});
  }

  /// @notice Returns all Strike structs for a list of strikeIds
  function _getStrikes(uint[] memory strikeIds) internal view returns (Strike[] memory allStrikes) {
    uint strikesLen = strikeIds.length;

    allStrikes = new Strike[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
        strikeIds[i]
      );

      allStrikes[i] = Strike({
        id: strike.id,
        expiry: board.expiry,
        strikePrice: strike.strikePrice,
        skew: strike.skew,
        boardIv: board.iv
      });
    }
    return allStrikes;
  }

  /// @notice Returns current spot volatilities for given strikeIds (boardIv * skew)
  function _getVols(uint[] memory strikeIds) internal view returns (uint[] memory vols) {
    uint strikesLen = strikeIds.length;

    vols = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
        strikeIds[i]
      );

      vols[i] = board.iv.multiplyDecimal(strike.skew);
    }
    return vols;
  }

  /// @notice Returns current spot deltas for given strikeIds (using BlackScholes and spot volatilities)
  function _getDeltas(uint[] memory strikeIds) internal view returns (int[] memory callDeltas) {
    uint strikesLen = strikeIds.length;

    callDeltas = new int[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeIds[i]);
      (callDeltas[i], ) = BlackScholes.delta(bsInput);
    }
  }

  /// @notice Returns current spot vegas for given strikeIds (using BlackScholes and spot volatilities)
  function _getVegas(uint[] memory strikeIds) internal view returns (uint[] memory vegas) {
    uint strikesLen = strikeIds.length;

    vegas = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeIds[i]);
      vegas[i] = BlackScholes.vega(bsInput);
    }
  }

  /// @notice Calculate the pure black-scholes premium for given params
  function _getPurePremium(
    uint secondsToExpiry,
    uint vol,
    uint spotPrice,
    uint strikePrice
  ) internal view returns (uint call, uint put) {
    BlackScholes.BlackScholesInputs memory bsInput = BlackScholes.BlackScholesInputs({
      timeToExpirySec: secondsToExpiry,
      volatilityDecimal: vol,
      spotDecimal: spotPrice,
      strikePriceDecimal: strikePrice,
      rateDecimal: greekCache.getGreekCacheParams().rateAndCarry
    });
    (call, put) = BlackScholes.optionPrices(bsInput);
  }

  /// @notice Calculate the spot black-scholes premium for a given strike
  /// @dev Does not include slippage or trading fees
  function _getPurePremiumForStrike(uint strikeId) internal view returns (uint call, uint put) {
    BlackScholes.BlackScholesInputs memory bsInput = _getBsInput(strikeId);
    (call, put) = BlackScholes.optionPrices(bsInput);
  }

  /// @notice Returns the breakdown of current liquidity usage (see Liquidity struct)
  function _getLiquidity() internal view returns (Liquidity memory) {
    ILiquidityPool.Liquidity memory liquidity = liquidityPool.getCurrentLiquidity();
    return
      Liquidity({
        freeLiquidity: liquidity.freeLiquidity,
        burnableLiquidity: liquidity.burnableLiquidity,
        usedCollatLiquidity: liquidity.usedCollatLiquidity,
        pendingDeltaLiquidity: liquidity.pendingDeltaLiquidity,
        usedDeltaLiquidity: liquidity.usedDeltaLiquidity,
        NAV: liquidity.NAV
      });
  }

  /// @notice Returns the amount of liquidity available for trading
  function _getFreeLiquidity() internal view returns (uint freeLiquidity) {
    freeLiquidity = liquidityPool.getCurrentLiquidity().freeLiquidity;
  }

  /// @notice Returns the most critical Lyra market trading parameters that determine pricing/slippage/trading restrictions
  function _getMarketParams() internal view returns (MarketParams memory) {
    IOptionMarketPricer.PricingParameters memory pricingParams = optionPricer.getPricingParams();
    IOptionMarketPricer.TradeLimitParameters memory tradeLimitParams = optionPricer.getTradeLimitParams();
    return
      MarketParams({
        standardSize: pricingParams.standardSize,
        skewAdjustmentParam: pricingParams.skewAdjustmentFactor,
        rateAndCarry: greekCache.getGreekCacheParams().rateAndCarry,
        deltaCutOff: tradeLimitParams.minDelta,
        tradingCutoff: tradeLimitParams.tradingCutoff,
        minForceCloseDelta: tradeLimitParams.minForceCloseDelta
      });
  }

  /// @notice use latest optionMarket delta cutoff to determine whether trade delta is out of bounds
  function _isOutsideDeltaCutoff(uint strikeId) internal view returns (bool) {
    MarketParams memory marketParams = _getMarketParams();
    uint[] memory dynamicArray = new uint[](1);
    dynamicArray[0] = strikeId;

    int callDelta = _getDeltas(dynamicArray)[0];
    return callDelta > (int(DecimalMath.UNIT) - marketParams.deltaCutOff) || callDelta < marketParams.deltaCutOff;
  }

  /// @notice use latest optionMarket trading cutoff to determine whether trade is too close to expiry
  function _isWithinTradingCutoff(uint strikeId) internal view returns (bool) {
    MarketParams memory marketParams = _getMarketParams();
    uint[] memory dynamicArray = new uint[](1);
    dynamicArray[0] = strikeId;

    Strike memory strike = _getStrikes(dynamicArray)[0];
    return strike.expiry - block.timestamp <= marketParams.tradingCutoff;
  }

  ////////////////////////
  // Minimum Collateral //
  ////////////////////////

  /// @notice Estimate minimum collateral required for given parameters
  /// @dev Position is liquidatable when position.collateral < minCollateral
  function _getMinCollateral(
    OptionType optionType,
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) internal view returns (uint) {
    return
      greekCache.getMinCollateral(IOptionMarket.OptionType(uint(optionType)), strikePrice, expiry, spotPrice, amount);
  }

  /// @notice Estimate minimum collateral required for an existing position
  function _getMinCollateralForPosition(uint positionId) internal view returns (uint) {
    IOptionToken.PositionWithOwner memory position = optionToken.getPositionWithOwner(positionId);
    if (_isLong(OptionType(uint(position.optionType)))) return 0;

    uint strikePrice;
    uint expiry;
    (strikePrice, expiry) = optionMarket.getStrikeAndExpiry(position.strikeId);

    return
      _getMinCollateral(
        OptionType(uint(position.optionType)),
        strikePrice,
        expiry,
        synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
        position.amount
      );
  }

  /// @notice Estimate minimum collateral required for a given strike with manual amount
  function _getMinCollateralForStrike(
    OptionType optionType,
    uint strikeId,
    uint amount
  ) internal view returns (uint) {
    if (_isLong(optionType)) return 0;

    uint strikePrice;
    uint expiry;
    (strikePrice, expiry) = optionMarket.getStrikeAndExpiry(strikeId);

    return
      _getMinCollateral(
        optionType,
        strikePrice,
        expiry,
        synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
        amount
      );
  }

  /////////////////
  // GWAV Oracle //
  /////////////////

  /// @notice the `baseIv` GWAV for a given `boardId` with GWAV interval `secondsAgo`
  function _ivGWAV(uint boardId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.ivGWAV(boardId, secondsAgo);
  }

  /// @notice the volatility `skew` GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _skewGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.skewGWAV(strikeId, secondsAgo);
  }

  /// @notice the resultant volatility =`skew` * 'baseIv' for a given `strikeId` with GWAV interval `secondsAgo`
  function _volGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.volGWAV(strikeId, secondsAgo);
  }

  /// @notice the delta GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _deltaGWAV(uint strikeId, uint secondsAgo) internal view returns (int callDelta) {
    return gwavOracle.deltaGWAV(strikeId, secondsAgo);
  }

  /// @notice the non-normalized vega GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _vegaGWAV(uint strikeId, uint secondsAgo) internal view returns (uint) {
    return gwavOracle.vegaGWAV(strikeId, secondsAgo);
  }

  /// @notice the option price GWAV for a given `strikeId` with GWAV interval `secondsAgo`
  function _optionPriceGWAV(uint strikeId, uint secondsAgo) internal view returns (uint callPrice, uint putPrice) {
    return gwavOracle.optionPriceGWAV(strikeId, secondsAgo);
  }

  //////////
  // Misc //
  //////////

  /// @dev format all strike related params before input into BlackScholes
  function _getBsInput(uint strikeId) internal view returns (BlackScholes.BlackScholesInputs memory bsInput) {
    (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(
      strikeId
    );
    bsInput = BlackScholes.BlackScholesInputs({
      timeToExpirySec: board.expiry - block.timestamp,
      volatilityDecimal: board.iv.multiplyDecimal(strike.skew),
      spotDecimal: synthetixAdapter.getSpotPriceForMarket(address(optionMarket)),
      strikePriceDecimal: strike.strikePrice,
      rateDecimal: greekCache.getGreekCacheParams().rateAndCarry
    });
  }

  /// @dev Check if position is long
  function _isLong(OptionType optionType) internal pure returns (bool) {
    return (optionType < OptionType.SHORT_CALL_BASE);
  }

  /// @dev Convert LyraAdapter.TradeInputParameters into OptionMarket.TradeInputParameters
  function _convertParams(TradeInputParameters memory _params)
    internal
    pure
    returns (IOptionMarket.TradeInputParameters memory)
  {
    return
      IOptionMarket.TradeInputParameters({
        strikeId: _params.strikeId,
        positionId: _params.positionId,
        iterations: _params.iterations,
        optionType: IOptionMarket.OptionType(uint(_params.optionType)),
        amount: _params.amount,
        setCollateralTo: _params.setCollateralTo,
        minTotalCost: _params.minTotalCost,
        maxTotalCost: _params.maxTotalCost
      });
  }

  /// @dev get lyra market addresses from LyraRegistry
  function _assignLyraRegistryMarketAddresses() internal {
    ILyraRegistry.OptionMarketAddresses memory addresses = lyraRegistry.getMarketAddresses(address(optionMarket));

    liquidityPool = ILiquidityPool(addresses.liquidityPool);
    greekCache = IOptionGreekCache(addresses.greekCache);
    optionPricer = IOptionMarketPricer(addresses.optionMarketPricer);
    optionToken = IOptionToken(addresses.optionToken);
    shortCollateral = IShortCollateral(addresses.shortCollateral);
    gwavOracle = IGWAVOracle(addresses.gwavOracle);
    quoteAsset = addresses.quoteAsset;
    baseAsset = addresses.baseAsset;
  }

  ////////////
  // Errors //
  ////////////

  error ExchangerBaseReceivedTooLow(address thrower, uint baseExpected, uint baseReceived);
  error ExchangerQuoteReceivedTooLow(address thrower, uint quoteExpected, uint quoteReceived);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./ILiquidityPool.sol";
import "./ISynthetixAdapter.sol";
import "./IOptionMarketPricer.sol";


// For full documentation refer to @lyrafinance/protocol/contracts/OptionMarket.sol";
interface IOptionMarket {

  enum TradeDirection {
    OPEN,
    CLOSE,
    LIQUIDATE
  }

  enum OptionType {
    LONG_CALL,
    LONG_PUT,
    SHORT_CALL_BASE,
    SHORT_CALL_QUOTE,
    SHORT_PUT_QUOTE
  }

  /// @notice For returning more specific errors
  enum NonZeroValues {
    BASE_IV,
    SKEW,
    STRIKE_PRICE,
    ITERATIONS,
    STRIKE_ID
  }

  ///////////////////
  // Internal Data //
  ///////////////////

  struct Strike {
    // strike listing identifier
    uint id;
    // strike price
    uint strikePrice;
    // volatility component specific to the strike listing (boardIv * skew = vol of strike)
    uint skew;
    // total user long call exposure
    uint longCall;
    // total user short call (base collateral) exposure
    uint shortCallBase;
    // total user short call (quote collateral) exposure
    uint shortCallQuote;
    // total user long put exposure
    uint longPut;
    // total user short put (quote collateral) exposure
    uint shortPut;
    // id of board to which strike belongs
    uint boardId;
  }

  struct OptionBoard {
    // board identifier
    uint id;
    // expiry of all strikes belonging to board
    uint expiry;
    // volatility component specific to board (boardIv * skew = vol of strike)
    uint iv;
    // admin settable flag blocking all trading on this board
    bool frozen;
    // list of all strikes belonging to this board
    uint[] strikeIds;
  }

  ///////////////
  // In-memory //
  ///////////////

  struct OptionMarketParameters {
    // max allowable expiry of added boards
    uint maxBoardExpiry;
    // security module address
    address securityModule;
    // fee portion reserved for Lyra DAO
    uint feePortionReserved;
    // expected fee charged to LPs, used for pricing short_call_base settlement
    uint staticBaseSettlementFee;
  }

  struct TradeInputParameters {
    // id of strike
    uint strikeId;
    // OptionToken ERC721 id for position (set to 0 for new positions)
    uint positionId;
    // number of sub-orders to break order into (reduces slippage)
    uint iterations;
    // type of option to trade
    OptionType optionType;
    // number of contracts to trade
    uint amount;
    // final amount of collateral to leave in OptionToken position
    uint setCollateralTo;
    // revert trade if totalCost is below this value
    uint minTotalCost;
    // revert trade if totalCost is above this value
    uint maxTotalCost;
  }

  struct TradeParameters {
    bool isBuy;
    bool isForceClose;
    TradeDirection tradeDirection;
    OptionType optionType;
    uint amount;
    uint expiry;
    uint strikePrice;
    ILiquidityPool.Liquidity liquidity;
    ISynthetixAdapter.ExchangeParams exchangeParams;
  }

  struct TradeEventData {
    uint expiry;
    uint strikePrice;
    OptionType optionType;
    TradeDirection tradeDirection;
    uint amount;
    uint setCollateralTo;
    bool isForceClose;
    uint spotPrice;
    uint reservedFee;
    uint totalCost;
  }

  struct LiquidationEventData {
    address rewardBeneficiary;
    address caller;
    uint returnCollateral; // quote || base
    uint lpPremiums; // quote || base
    uint lpFee; // quote || base
    uint liquidatorFee; // quote || base
    uint smFee; // quote || base
    uint insolventAmount; // quote
  }

  struct Result {
    uint positionId;
    uint totalCost;
    uint totalFee;
  }

  ///////////////
  // Variables //
  ///////////////

  /// @notice claim all reserved option fees
  function smClaim() external;

  ///////////
  // Views //
  ///////////

  function getOptionMarketParams() external view returns (OptionMarketParameters memory);

  function getLiveBoards() external view returns (uint[] memory _liveBoards);

  function getNumLiveBoards() external view returns (uint numLiveBoards);

  function getStrikeAndExpiry(uint strikeId) external view returns (uint strikePrice, uint expiry);

  function getBoardStrikes(uint boardId) external view returns (uint[] memory strikeIds);

  function getStrike(uint strikeId) external view returns (Strike memory);

  function getOptionBoard(uint boardId) external view returns (OptionBoard memory);

  function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory);

  function getBoardAndStrikeDetails(uint boardId)
    external
    view
    returns (
      OptionBoard memory,
      Strike[] memory,
      uint[] memory,
      uint
    );

  ////////////////////
  // User functions //
  ////////////////////

  function openPosition(TradeInputParameters memory params) external returns (Result memory result);

  function closePosition(TradeInputParameters memory params) external returns (Result memory result);

  /**
   * @notice Attempts to reduce or fully close position within cost bounds while ignoring delta trading cutoffs.
   *
   * @param params The parameters for the requested trade
   */
  function forceClosePosition(TradeInputParameters memory params) external returns (Result memory result);

  function addCollateral(uint positionId, uint amountCollateral) external;

  function liquidatePosition(uint positionId, address rewardBeneficiary) external;


  /////////////////////////////////
  // Board Expiry and settlement //
  /////////////////////////////////

  function settleExpiredBoard(uint boardId) external;

  function getSettlementParameters(uint strikeId)
    external
    view
    returns (
      uint strikePrice,
      uint priceAtExpiry,
      uint strikeToBaseReturned
    );

  ////////////
  // Events //
  ////////////

  /**
   * @dev Emitted when a Board is created.
   */
  event BoardCreated(uint indexed boardId, uint expiry, uint baseIv, bool frozen);

  /**
   * @dev Emitted when a Board frozen is updated.
   */
  event BoardFrozen(uint indexed boardId, bool frozen);

  /**
   * @dev Emitted when a Board new baseIv is set.
   */
  event BoardBaseIvSet(uint indexed boardId, uint baseIv);

  /**
   * @dev Emitted when a Strike new skew is set.
   */
  event StrikeSkewSet(uint indexed strikeId, uint skew);

  /**
   * @dev Emitted when a Strike is added to a board
   */
  event StrikeAdded(uint indexed boardId, uint indexed strikeId, uint strikePrice, uint skew);

  /**
   * @dev Emitted when parameters for the option market are adjusted
   */
  event OptionMarketParamsSet(OptionMarketParameters optionMarketParams);

  /**
   * @dev Emitted whenever the security module claims their portion of fees
   */
  event SMClaimed(address securityModule, uint quoteAmount, uint baseAmount);

  /**
   * @dev Emitted when a Position is opened, closed or liquidated.
   */
  event Trade(
    address indexed trader,
    uint indexed strikeId,
    uint indexed positionId,
    TradeEventData trade,
    IOptionMarketPricer.TradeResult[] tradeResults,
    LiquidationEventData liquidation,
    uint timestamp
  );

  /**
   * @dev Emitted when a Board is liquidated.
   */
  event BoardSettled(
    uint indexed boardId,
    uint spotPriceAtExpiry,
    uint totalUserLongProfitQuote,
    uint totalBoardLongCallCollateral,
    uint totalBoardLongPutCollateral,
    uint totalAMMShortCallProfitBase,
    uint totalAMMShortCallProfitQuote,
    uint totalAMMShortPutProfitQuote
  );

  ////////////
  // Errors //
  ////////////
  // General purpose
  error ExpectedNonZeroValue(address thrower, NonZeroValues valueType);

  // Admin
  error InvalidOptionMarketParams(address thrower, OptionMarketParameters optionMarketParams);

  // Board related
  error InvalidBoardId(address thrower, uint boardId);
  error InvalidExpiryTimestamp(address thrower, uint currentTime, uint expiry, uint maxBoardExpiry);
  error BoardNotFrozen(address thrower, uint boardId);
  error BoardAlreadySettled(address thrower, uint boardId);
  error BoardNotExpired(address thrower, uint boardId);

  // Strike related
  error InvalidStrikeId(address thrower, uint strikeId);
  error StrikeSkewLengthMismatch(address thrower, uint strikesLength, uint skewsLength);

  // Trade
  error TotalCostOutsideOfSpecifiedBounds(address thrower, uint totalCost, uint minCost, uint maxCost);
  error BoardIsFrozen(address thrower, uint boardId);
  error BoardExpired(address thrower, uint boardId, uint boardExpiry, uint currentTime);
  error TradeIterationsHasRemainder(
    address thrower,
    uint iterations,
    uint expectedAmount,
    uint tradeAmount,
    uint totalAmount
  );

  // Access
  error OnlySecurityModule(address thrower, address caller, address securityModule);

  // Token transfers
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title DecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
 */

library DecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  uint public constant UNIT = 10**uint(decimals);

  /* The number representing 1.0 for higher fidelity numbers. */
  uint public constant PRECISE_UNIT = 10**uint(highPrecisionDecimals);
  uint private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = 10**uint(highPrecisionDecimals - decimals);

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (uint) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (uint) {
    return PRECISE_UNIT;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(uint x, uint y) internal pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    uint quotientTimesTen = (x * y) / (precisionUnit / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(uint x, uint y) internal pure returns (uint) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    uint x,
    uint y,
    uint precisionUnit
  ) private pure returns (uint) {
    uint resultTimesTen = (x * (precisionUnit * 10)) / y;

    if (resultTimesTen % 10 >= 5) {
      resultTimesTen += 10;
    }

    return resultTimesTen / 10;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(uint x, uint y) internal pure returns (uint) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(uint i) internal pure returns (uint) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(uint i) internal pure returns (uint) {
    uint quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title SignedDecimalMath
 * @author Lyra
 * @dev Modified synthetix SafeSignedDecimalMath to include internal arithmetic underflow/overflow.
 * @dev https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
 */
library SignedDecimalMath {
  /* Number of decimal places in the representations. */
  uint8 public constant decimals = 18;
  uint8 public constant highPrecisionDecimals = 27;

  /* The number representing 1.0. */
  int public constant UNIT = int(10**uint(decimals));

  /* The number representing 1.0 for higher fidelity numbers. */
  int public constant PRECISE_UNIT = int(10**uint(highPrecisionDecimals));
  int private constant UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR = int(10**uint(highPrecisionDecimals - decimals));

  /**
   * @return Provides an interface to UNIT.
   */
  function unit() external pure returns (int) {
    return UNIT;
  }

  /**
   * @return Provides an interface to PRECISE_UNIT.
   */
  function preciseUnit() external pure returns (int) {
    return PRECISE_UNIT;
  }

  /**
   * @dev Rounds an input with an extra zero of precision, returning the result without the extra zero.
   * Half increments round away from zero; positive numbers at a half increment are rounded up,
   * while negative such numbers are rounded down. This behaviour is designed to be consistent with the
   * unsigned version of this library (SafeDecimalMath).
   */
  function _roundDividingByTen(int valueTimesTen) private pure returns (int) {
    int increment;
    if (valueTimesTen % 10 >= 5) {
      increment = 10;
    } else if (valueTimesTen % 10 <= -5) {
      increment = -10;
    }
    return (valueTimesTen + increment) / 10;
  }

  /**
   * @return The result of multiplying x and y, interpreting the operands as fixed-point
   * decimals.
   *
   * @dev A unit factor is divided out after the product of x and y is evaluated,
   * so that product must be less than 2**256. As this is an integer division,
   * the internal division always rounds down. This helps save on gas. Rounding
   * is more expensive on gas.
   */
  function multiplyDecimal(int x, int y) internal pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    return (x * y) / UNIT;
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of the specified precision unit.
   *
   * @dev The operands should be in the form of a the specified unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function _multiplyDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    /* Divide by UNIT to remove the extra factor introduced by the product. */
    int quotientTimesTen = (x * y) / (precisionUnit / 10);
    return _roundDividingByTen(quotientTimesTen);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a precise unit.
   *
   * @dev The operands should be in the precise unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @return The result of safely multiplying x and y, interpreting the operands
   * as fixed-point decimals of a standard unit.
   *
   * @dev The operands should be in the standard unit factor which will be
   * divided out after the product of x and y is evaluated, so that product must be
   * less than 2**256.
   *
   * Unlike multiplyDecimal, this function rounds the result to the nearest increment.
   * Rounding is useful when you need to retain fidelity for small decimal numbers
   * (eg. small fractions or percentages).
   */
  function multiplyDecimalRound(int x, int y) internal pure returns (int) {
    return _multiplyDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is a high
   * precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and UNIT must be less than 2**256. As
   * this is an integer division, the result is always rounded down.
   * This helps save on gas. Rounding is more expensive on gas.
   */
  function divideDecimal(int x, int y) internal pure returns (int) {
    /* Reintroduce the UNIT factor that will be divided out by y. */
    return (x * UNIT) / y;
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * decimal in the precision unit specified in the parameter.
   *
   * @dev y is divided after the product of x and the specified precision unit
   * is evaluated, so the product of x and the specified precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function _divideDecimalRound(
    int x,
    int y,
    int precisionUnit
  ) private pure returns (int) {
    int resultTimesTen = (x * (precisionUnit * 10)) / y;
    return _roundDividingByTen(resultTimesTen);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * standard precision decimal.
   *
   * @dev y is divided after the product of x and the standard precision unit
   * is evaluated, so the product of x and the standard precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRound(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, UNIT);
  }

  /**
   * @return The result of safely dividing x and y. The return value is as a rounded
   * high precision decimal.
   *
   * @dev y is divided after the product of x and the high precision unit
   * is evaluated, so the product of x and the high precision unit must
   * be less than 2**256. The result is rounded to the nearest increment.
   */
  function divideDecimalRoundPrecise(int x, int y) internal pure returns (int) {
    return _divideDecimalRound(x, y, PRECISE_UNIT);
  }

  /**
   * @dev Convert a standard decimal representation to a high precision one.
   */
  function decimalToPreciseDecimal(int i) internal pure returns (int) {
    return i * UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR;
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);
    return _roundDividingByTen(quotientTimesTen);
  }
}

// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "../synthetix/SignedDecimalMath.sol";
import "../synthetix/DecimalMath.sol";
import "./FixedPointMathLib.sol";

/**
 * @title Geometric Moving Average Oracle
 * @author Lyra
 * @dev Instances of stored oracle data, "observations", are collected in the oracle array
 *
 * The GWAV values are calculated from the blockTimestamps and "q" accumulator values of two Observations. When
 * requested the closest observations are scaled to the requested timestamp.
 */
library GWAV {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  /// @dev Stores all past Observations and the current index
  struct Params {
    Observation[] observations;
    uint index;
  }

  /// @dev An observation holds the cumulative log value of all historic observations (accumulator)
  /// and other relevant fields for computing the next accumulator value.
  /// @dev A pair of oracle Observations is used to deduce the GWAV TWAP
  struct Observation {
    int q; // accumulator value used to compute GWAV
    uint nextVal; // value at the time the observation was made, used to calculate the next q value
    uint blockTimestamp;
  }

  /////////////
  // Setters //
  /////////////

  /**
   * @notice Initialize the oracle array by writing the first Observation.
   * @dev Called once for the lifecycle of the observations array
   * @dev First Observation uses blockTimestamp as the time interval to prevent manipulation of the GWAV immediately
   * after initialization
   * @param self Stores past Observations and the index of the latest Observation
   * @param newVal First observed value for blockTimestamp
   * @param blockTimestamp Timestamp of first Observation
   */
  function _initialize(
    Params storage self,
    uint newVal,
    uint blockTimestamp
  ) internal {
    // if Observation older than blockTimestamp is used for GWAV,
    // _getFirstBefore() will scale the first Observation "q" accordingly
    _initializeWithManualQ(self, FixedPointMathLib.ln((int(newVal))) * int(blockTimestamp), newVal, blockTimestamp);
  }

  /**
   * @notice Writes an oracle Observation to the GWAV array
   * @dev Writable at most once per block. BlockTimestamp must be > last.blockTimestamp
   * @param self Stores past Observations and the index of the latest Observation
   * @param nextVal Value at given blockTimestamp
   * @param blockTimestamp Current blockTimestamp
   */
  function _write(
    Params storage self,
    uint nextVal,
    uint blockTimestamp
  ) internal {
    Observation memory last = self.observations[self.index];

    // Ensure entries are sequential
    if (blockTimestamp < last.blockTimestamp) {
      revert InvalidBlockTimestamp(address(this), blockTimestamp, last.blockTimestamp);
    }

    // early return if we've already written an observation this block
    if (last.blockTimestamp == blockTimestamp) {
      self.observations[self.index].nextVal = nextVal;
      return;
    }
    // No reason to record an entry if it's the same as the last one
    if (last.nextVal == nextVal) return;

    // update accumulator value
    // assumes the market value between the previous and current blockTimstamps was "last.nextVal"
    uint timestampDelta = blockTimestamp - last.blockTimestamp;
    int newQ = last.q + FixedPointMathLib.ln((int(last.nextVal))) * int(timestampDelta);

    // update latest index and store Observation
    uint indexUpdated = (self.index + 1);
    self.observations.push(_transform(newQ, nextVal, blockTimestamp));
    self.index = indexUpdated;
  }

  /////////////
  // Getters //
  /////////////

  /**
   * @notice Calculates the geometric moving average between two Observations A & B. These observations are scaled to
   * the requested timestamps
   * @dev For the current GWAV value, "0" may be passed in for secondsAgo
   * @dev If timestamps A==B, returns the value at A/B.
   * @param self Stores past Observations and the index of the latest Observation
   * @param secondsAgoA Seconds from blockTimestamp to Observation A
   * @param secondsAgoB Seconds from blockTimestamp to Observation B
   */
  function getGWAVForPeriod(
    Params storage self,
    uint secondsAgoA,
    uint secondsAgoB
  ) public view returns (uint) {
    (int q0, uint t0) = queryFirstBeforeAndScale(self, block.timestamp, secondsAgoA);
    (int q1, uint t1) = queryFirstBeforeAndScale(self, block.timestamp, secondsAgoB);

    if (t0 == t1) {
      return uint(FixedPointMathLib.exp(q1 / int(t1)));
    }

    return uint(FixedPointMathLib.exp((q1 - q0) / int(t1 - t0)));
  }

  /**
   * @notice Returns the GWAV accumulator/timestamps values for each "secondsAgo" in the array `secondsAgos[]`
   * @param currentBlockTimestamp Timestamp of current block
   * @param secondsAgos Array of all timestamps for which to export accumulator/timestamp values
   */
  function observe(
    Params storage self,
    uint currentBlockTimestamp,
    uint[] memory secondsAgos
  ) public view returns (int[] memory qCumulatives, uint[] memory timestamps) {
    uint secondsAgosLength = secondsAgos.length;
    qCumulatives = new int[](secondsAgosLength);
    timestamps = new uint[](secondsAgosLength);
    for (uint i = 0; i < secondsAgosLength; ++i) {
      (qCumulatives[i], timestamps[i]) = queryFirstBefore(self, currentBlockTimestamp, secondsAgos[i]);
    }
  }

  //////////////////////////////////////////////////////
  // Querying observation closest to target timestamp //
  //////////////////////////////////////////////////////

  /**
   * @notice Finds the first observation before a timestamp "secondsAgo" from the "currentBlockTimestamp"
   * @dev If target falls between two Observations, the older one is returned
   * @dev See _queryFirstBefore() for edge cases where target lands
   * after the newest Observation or before the oldest Observation
   * @dev Reverts if secondsAgo exceeds the currentBlockTimestamp
   * @param self Stores past Observations and the index of the latest Observation
   * @param currentBlockTimestamp Timestamp of current block
   * @param secondsAgo Seconds from currentBlockTimestamp to target Observation
   */
  function queryFirstBefore(
    Params storage self,
    uint currentBlockTimestamp,
    uint secondsAgo
  ) internal view returns (int qCumulative, uint timestamp) {
    uint target = currentBlockTimestamp - secondsAgo;
    Observation memory beforeOrAt = _queryFirstBefore(self, target);

    return (beforeOrAt.q, beforeOrAt.blockTimestamp);
  }

  function queryFirstBeforeAndScale(
    Params storage self,
    uint currentBlockTimestamp,
    uint secondsAgo
  ) internal view returns (int qCumulative, uint timestamp) {
    uint target = currentBlockTimestamp - secondsAgo;
    Observation memory beforeOrAt = _queryFirstBefore(self, target);

    int timestampDelta = int(target - beforeOrAt.blockTimestamp);

    return (beforeOrAt.q + (FixedPointMathLib.ln(int(beforeOrAt.nextVal)) * timestampDelta), target);
  }

  /**
   * @notice Finds the first observation before the "target" timestamp
   * @dev Checks for trivial scenarios before entering _binarySearch()
   * @dev Assumes _initialize() has been called
   * @param self Stores past Observations and the index of the latest Observation
   * @param target BlockTimestamp of target Observation
   */
  function _queryFirstBefore(Params storage self, uint target) private view returns (Observation memory beforeOrAt) {
    // Case 1: target blockTimestamp is at or after the most recent Observation
    beforeOrAt = self.observations[self.index];
    if (beforeOrAt.blockTimestamp <= target) {
      return (beforeOrAt);
    }

    // Now, set to the oldest observation
    beforeOrAt = self.observations[0];

    // Case 2: target blockTimestamp is older than the oldest Observation
    // The observation is scaled to the target using the nextVal
    if (beforeOrAt.blockTimestamp > target) {
      return _transform((beforeOrAt.q * int(target)) / int(beforeOrAt.blockTimestamp), beforeOrAt.nextVal, target);
    }

    // Case 3: target is within the recorded Observations.
    return self.observations[_binarySearch(self, target)];
  }

  /**
   * @notice Finds closest Observation before target using binary search and returns its index
   * @dev Used when the target is located within the stored observation boundaries
   * e.g. Older than the most recent observation and younger, or the same age as, the oldest observation
   * @return foundIndex Returns the Observation which is older than target (instead of newer)
   * @param self Stores past Observations and the index of the latest Observation
   * @param target BlockTimestamp of target Observation
   */
  function _binarySearch(Params storage self, uint target) internal view returns (uint) {
    uint oldest = 0; // oldest observation
    uint newest = self.index; // newest observation
    uint i;
    while (true) {
      i = (oldest + newest) / 2;
      uint beforeOrAtTimestamp = self.observations[i].blockTimestamp;

      uint atOrAfterTimestamp = self.observations[i + 1].blockTimestamp;
      bool targetAtOrAfter = beforeOrAtTimestamp <= target;

      // check if we've found the answer!
      if (targetAtOrAfter && target <= atOrAfterTimestamp) break;

      if (!targetAtOrAfter) {
        newest = i - 1;
      } else {
        oldest = i + 1;
      }
    }

    return i;
  }

  /////////////
  // Utility //
  /////////////

  /**
   * @notice Creates the first Observation with manual Q accumulator value.
   * @param qVal Initial GWAV accumulator value
   * @param nextVal First observed value for blockTimestamp
   * @param blockTimestamp Timestamp of Observation
   */
  function _initializeWithManualQ(
    Params storage self,
    int qVal,
    uint nextVal,
    uint blockTimestamp
  ) internal {
    self.observations.push(Observation({q: qVal, nextVal: nextVal, blockTimestamp: blockTimestamp}));
  }

  /**
   * @dev Creates an Observation given a GWAV accumulator, latest value, and a blockTimestamp
   */
  function _transform(
    int newQ,
    uint nextVal,
    uint blockTimestamp
  ) private pure returns (Observation memory) {
    return Observation({q: newQ, nextVal: nextVal, blockTimestamp: blockTimestamp});
  }

  ////////////
  // Errors //
  ////////////
  error InvalidBlockTimestamp(address thrower, uint timestamp, uint lastObservedTimestamp);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "../synthetix/SignedDecimalMath.sol";
import "../synthetix/DecimalMath.sol";
import "./FixedPointMathLib.sol";

/**
 * @title BlackScholes
 * @author Lyra
 * @dev Contract to compute the black scholes price of options. Where the unit is unspecified, it should be treated as a
 * PRECISE_DECIMAL, which has 1e27 units of precision. The default decimal matches the ethereum standard of 1e18 units
 * of precision.
 */
library BlackScholes {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  struct PricesDeltaStdVega {
    uint callPrice;
    uint putPrice;
    int callDelta;
    int putDelta;
    uint vega;
    uint stdVega;
  }

  /**
   * @param timeToExpirySec Number of seconds to the expiry of the option
   * @param volatilityDecimal Implied volatility over the period til expiry as a percentage
   * @param spotDecimal The current price of the base asset
   * @param strikePriceDecimal The strikePrice price of the option
   * @param rateDecimal The percentage risk free rate + carry cost
   */
  struct BlackScholesInputs {
    uint timeToExpirySec;
    uint volatilityDecimal;
    uint spotDecimal;
    uint strikePriceDecimal;
    int rateDecimal;
  }

  uint private constant SECONDS_PER_YEAR = 31536000;
  /// @dev Internally this library uses 27 decimals of precision
  uint private constant PRECISE_UNIT = 1e27;
  uint private constant SQRT_TWOPI = 2506628274631000502415765285;
  /// @dev Below this value, return 0
  int private constant MIN_CDF_STD_DIST_INPUT = (int(PRECISE_UNIT) * -45) / 10; // -4.5
  /// @dev Above this value, return 1
  int private constant MAX_CDF_STD_DIST_INPUT = int(PRECISE_UNIT) * 10;
  /// @dev Value to use to avoid any division by 0 or values near 0
  uint private constant MIN_T_ANNUALISED = PRECISE_UNIT / SECONDS_PER_YEAR; // 1 second
  uint private constant MIN_VOLATILITY = PRECISE_UNIT / 10000; // 0.001%
  uint private constant VEGA_STANDARDISATION_MIN_DAYS = 7 days;
  /// @dev Magic numbers for normal CDF
  uint private constant SPLIT = 7071067811865470000000000000;
  uint private constant N0 = 220206867912376000000000000000;
  uint private constant N1 = 221213596169931000000000000000;
  uint private constant N2 = 112079291497871000000000000000;
  uint private constant N3 = 33912866078383000000000000000;
  uint private constant N4 = 6373962203531650000000000000;
  uint private constant N5 = 700383064443688000000000000;
  uint private constant N6 = 35262496599891100000000000;
  uint private constant M0 = 440413735824752000000000000000;
  uint private constant M1 = 793826512519948000000000000000;
  uint private constant M2 = 637333633378831000000000000000;
  uint private constant M3 = 296564248779674000000000000000;
  uint private constant M4 = 86780732202946100000000000000;
  uint private constant M5 = 16064177579207000000000000000;
  uint private constant M6 = 1755667163182640000000000000;
  uint private constant M7 = 88388347648318400000000000;

  /////////////////////////////////////
  // Option Pricing public functions //
  /////////////////////////////////////

  /**
   * @dev Returns call and put prices for options with given parameters.
   */
  function optionPrices(BlackScholesInputs memory bsInput) public pure returns (uint call, uint put) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();
    uint strikePricePrecise = bsInput.strikePriceDecimal.decimalToPreciseDecimal();
    int ratePrecise = bsInput.rateDecimal.decimalToPreciseDecimal();
    (int d1, int d2) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      strikePricePrecise,
      ratePrecise
    );
    (call, put) = _optionPrices(tAnnualised, spotPrecise, strikePricePrecise, ratePrecise, d1, d2);
    return (call.preciseDecimalToDecimal(), put.preciseDecimalToDecimal());
  }

  /**
   * @dev Returns call/put prices and delta/stdVega for options with given parameters.
   */
  function pricesDeltaStdVega(BlackScholesInputs memory bsInput) public pure returns (PricesDeltaStdVega memory) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, int d2) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );
    (uint callPrice, uint putPrice) = _optionPrices(
      tAnnualised,
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal(),
      d1,
      d2
    );
    (uint vegaPrecise, uint stdVegaPrecise) = _standardVega(d1, spotPrecise, bsInput.timeToExpirySec);
    (int callDelta, int putDelta) = _delta(d1);

    return
      PricesDeltaStdVega(
        callPrice.preciseDecimalToDecimal(),
        putPrice.preciseDecimalToDecimal(),
        callDelta.preciseDecimalToDecimal(),
        putDelta.preciseDecimalToDecimal(),
        vegaPrecise.preciseDecimalToDecimal(),
        stdVegaPrecise.preciseDecimalToDecimal()
      );
  }

  /**
   * @dev Returns call delta given parameters.
   */

  function delta(BlackScholesInputs memory bsInput) public pure returns (int callDeltaDecimal, int putDeltaDecimal) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, ) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );

    (int callDelta, int putDelta) = _delta(d1);
    return (callDelta.preciseDecimalToDecimal(), putDelta.preciseDecimalToDecimal());
  }

  /**
   * @dev Returns non-normalized vega given parameters. Quoted in cents.
   */
  function vega(BlackScholesInputs memory bsInput) public pure returns (uint vegaDecimal) {
    uint tAnnualised = _annualise(bsInput.timeToExpirySec);
    uint spotPrecise = bsInput.spotDecimal.decimalToPreciseDecimal();

    (int d1, ) = _d1d2(
      tAnnualised,
      bsInput.volatilityDecimal.decimalToPreciseDecimal(),
      spotPrecise,
      bsInput.strikePriceDecimal.decimalToPreciseDecimal(),
      bsInput.rateDecimal.decimalToPreciseDecimal()
    );
    return _vega(tAnnualised, spotPrecise, d1).preciseDecimalToDecimal();
  }

  //////////////////////
  // Computing Greeks //
  //////////////////////

  /**
   * @dev Returns internal coefficients of the Black-Scholes call price formula, d1 and d2.
   * @param tAnnualised Number of years to expiry
   * @param volatility Implied volatility over the period til expiry as a percentage
   * @param spot The current price of the base asset
   * @param strikePrice The strikePrice price of the option
   * @param rate The percentage risk free rate + carry cost
   */
  function _d1d2(
    uint tAnnualised,
    uint volatility,
    uint spot,
    uint strikePrice,
    int rate
  ) internal pure returns (int d1, int d2) {
    // Set minimum values for tAnnualised and volatility to not break computation in extreme scenarios
    // These values will result in option prices reflecting only the difference in stock/strikePrice, which is expected.
    // This should be caught before calling this function, however the function shouldn't break if the values are 0.
    tAnnualised = tAnnualised < MIN_T_ANNUALISED ? MIN_T_ANNUALISED : tAnnualised;
    volatility = volatility < MIN_VOLATILITY ? MIN_VOLATILITY : volatility;

    int vtSqrt = int(volatility.multiplyDecimalRoundPrecise(_sqrtPrecise(tAnnualised)));
    int log = FixedPointMathLib.lnPrecise(int(spot.divideDecimalRoundPrecise(strikePrice)));
    int v2t = (int(volatility.multiplyDecimalRoundPrecise(volatility) / 2) + rate).multiplyDecimalRoundPrecise(
      int(tAnnualised)
    );
    d1 = (log + v2t).divideDecimalRoundPrecise(vtSqrt);
    d2 = d1 - vtSqrt;
  }

  /**
   * @dev Internal coefficients of the Black-Scholes call price formula.
   * @param tAnnualised Number of years to expiry
   * @param spot The current price of the base asset
   * @param strikePrice The strikePrice price of the option
   * @param rate The percentage risk free rate + carry cost
   * @param d1 Internal coefficient of Black-Scholes
   * @param d2 Internal coefficient of Black-Scholes
   */
  function _optionPrices(
    uint tAnnualised,
    uint spot,
    uint strikePrice,
    int rate,
    int d1,
    int d2
  ) internal pure returns (uint call, uint put) {
    uint strikePricePV = strikePrice.multiplyDecimalRoundPrecise(
      FixedPointMathLib.expPrecise(int(-rate.multiplyDecimalRoundPrecise(int(tAnnualised))))
    );
    uint spotNd1 = spot.multiplyDecimalRoundPrecise(_stdNormalCDF(d1));
    uint strikePriceNd2 = strikePricePV.multiplyDecimalRoundPrecise(_stdNormalCDF(d2));

    // We clamp to zero if the minuend is less than the subtrahend
    // In some scenarios it may be better to compute put price instead and derive call from it depending on which way
    // around is more precise.
    call = strikePriceNd2 <= spotNd1 ? spotNd1 - strikePriceNd2 : 0;
    put = call + strikePricePV;
    put = spot <= put ? put - spot : 0;
  }

  /*
   * Greeks
   */

  /**
   * @dev Returns the option's delta value
   * @param d1 Internal coefficient of Black-Scholes
   */
  function _delta(int d1) internal pure returns (int callDelta, int putDelta) {
    callDelta = int(_stdNormalCDF(d1));
    putDelta = callDelta - int(PRECISE_UNIT);
  }

  /**
   * @dev Returns the option's vega value based on d1. Quoted in cents.
   *
   * @param d1 Internal coefficient of Black-Scholes
   * @param tAnnualised Number of years to expiry
   * @param spot The current price of the base asset
   */
  function _vega(
    uint tAnnualised,
    uint spot,
    int d1
  ) internal pure returns (uint) {
    return _sqrtPrecise(tAnnualised).multiplyDecimalRoundPrecise(_stdNormal(d1).multiplyDecimalRoundPrecise(spot));
  }

  /**
   * @dev Returns the option's vega value with expiry modified to be at least VEGA_STANDARDISATION_MIN_DAYS
   * @param d1 Internal coefficient of Black-Scholes
   * @param spot The current price of the base asset
   * @param timeToExpirySec Number of seconds to expiry
   */
  function _standardVega(
    int d1,
    uint spot,
    uint timeToExpirySec
  ) internal pure returns (uint, uint) {
    uint tAnnualised = _annualise(timeToExpirySec);
    uint normalisationFactor = _getVegaNormalisationFactorPrecise(timeToExpirySec);
    uint vegaPrecise = _vega(tAnnualised, spot, d1);
    return (vegaPrecise, vegaPrecise.multiplyDecimalRoundPrecise(normalisationFactor));
  }

  function _getVegaNormalisationFactorPrecise(uint timeToExpirySec) internal pure returns (uint) {
    timeToExpirySec = timeToExpirySec < VEGA_STANDARDISATION_MIN_DAYS ? VEGA_STANDARDISATION_MIN_DAYS : timeToExpirySec;
    uint daysToExpiry = timeToExpirySec / 1 days;
    uint thirty = 30 * PRECISE_UNIT;
    return _sqrtPrecise(thirty / daysToExpiry) / 100;
  }

  /////////////////////
  // Math Operations //
  /////////////////////

  /**
   * @dev Compute the absolute value of `val`.
   *
   * @param val The number to absolute value.
   */
  function _abs(int val) internal pure returns (uint) {
    return uint(val < 0 ? -val : val);
  }

  /// @notice Calculates the square root of x, rounding down (borrowed from https://github.com/paulrberg/prb-math)
  /// @dev Uses the Babylonian method https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method.
  /// @param x The uint256 number for which to calculate the square root.
  /// @return result The result as an uint256.
  function _sqrt(uint x) internal pure returns (uint result) {
    if (x == 0) {
      return 0;
    }

    // Calculate the square root of the perfect square of a power of two that is the closest to x.
    uint xAux = uint(x);
    result = 1;
    if (xAux >= 0x100000000000000000000000000000000) {
      xAux >>= 128;
      result <<= 64;
    }
    if (xAux >= 0x10000000000000000) {
      xAux >>= 64;
      result <<= 32;
    }
    if (xAux >= 0x100000000) {
      xAux >>= 32;
      result <<= 16;
    }
    if (xAux >= 0x10000) {
      xAux >>= 16;
      result <<= 8;
    }
    if (xAux >= 0x100) {
      xAux >>= 8;
      result <<= 4;
    }
    if (xAux >= 0x10) {
      xAux >>= 4;
      result <<= 2;
    }
    if (xAux >= 0x8) {
      result <<= 1;
    }

    // The operations can never overflow because the result is max 2^127 when it enters this block.
    unchecked {
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1;
      result = (result + x / result) >> 1; // Seven iterations should be enough
      uint roundedDownResult = x / result;
      return result >= roundedDownResult ? roundedDownResult : result;
    }
  }

  /**
   * @dev Returns the square root of the value using Newton's method.
   */
  function _sqrtPrecise(uint x) internal pure returns (uint) {
    // Add in an extra unit factor for the square root to gobble;
    // otherwise, sqrt(x * UNIT) = sqrt(x) * sqrt(UNIT)
    return _sqrt(x * PRECISE_UNIT);
  }

  /**
   * @dev The standard normal distribution of the value.
   */
  function _stdNormal(int x) internal pure returns (uint) {
    return
      FixedPointMathLib.expPrecise(int(-x.multiplyDecimalRoundPrecise(x / 2))).divideDecimalRoundPrecise(SQRT_TWOPI);
  }

  /**
   * @dev The standard normal cumulative distribution of the value.
   * borrowed from a C++ implementation https://stackoverflow.com/a/23119456
   */
  function _stdNormalCDF(int x) public pure returns (uint) {
    uint z = _abs(x);
    int c;

    if (z <= 37 * PRECISE_UNIT) {
      uint e = FixedPointMathLib.expPrecise(-int(z.multiplyDecimalRoundPrecise(z / 2)));
      if (z < SPLIT) {
        c = int(
          (_stdNormalCDFNumerator(z).divideDecimalRoundPrecise(_stdNormalCDFDenom(z)).multiplyDecimalRoundPrecise(e))
        );
      } else {
        uint f = (z +
          PRECISE_UNIT.divideDecimalRoundPrecise(
            z +
              (2 * PRECISE_UNIT).divideDecimalRoundPrecise(
                z +
                  (3 * PRECISE_UNIT).divideDecimalRoundPrecise(
                    z + (4 * PRECISE_UNIT).divideDecimalRoundPrecise(z + ((PRECISE_UNIT * 13) / 20))
                  )
              )
          ));
        c = int(e.divideDecimalRoundPrecise(f.multiplyDecimalRoundPrecise(SQRT_TWOPI)));
      }
    }
    return uint((x <= 0 ? c : (int(PRECISE_UNIT) - c)));
  }

  /**
   * @dev Helper for _stdNormalCDF
   */
  function _stdNormalCDFNumerator(uint z) internal pure returns (uint) {
    uint numeratorInner = ((((((N6 * z) / PRECISE_UNIT + N5) * z) / PRECISE_UNIT + N4) * z) / PRECISE_UNIT + N3);
    return (((((numeratorInner * z) / PRECISE_UNIT + N2) * z) / PRECISE_UNIT + N1) * z) / PRECISE_UNIT + N0;
  }

  /**
   * @dev Helper for _stdNormalCDF
   */
  function _stdNormalCDFDenom(uint z) internal pure returns (uint) {
    uint denominatorInner = ((((((M7 * z) / PRECISE_UNIT + M6) * z) / PRECISE_UNIT + M5) * z) / PRECISE_UNIT + M4);
    return
      (((((((denominatorInner * z) / PRECISE_UNIT + M3) * z) / PRECISE_UNIT + M2) * z) / PRECISE_UNIT + M1) * z) /
      PRECISE_UNIT +
      M0;
  }

  /**
   * @dev Converts an integer number of seconds to a fractional number of years.
   */
  function _annualise(uint secs) internal pure returns (uint yearFraction) {
    return secs.divideDecimalRoundPrecise(SECONDS_PER_YEAR);
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Interfaces
import "./IOptionMarket.sol";
import "./ISynthetixAdapter.sol";
import "./IOptionGreekCache.sol";
import "openzeppelin-contracts-4.4.1/token/ERC721/IERC721.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionToken.sol";
interface IOptionToken is IERC721 {

  enum PositionState {
    EMPTY,
    ACTIVE,
    CLOSED,
    LIQUIDATED,
    SETTLED,
    MERGED
  }

  enum PositionUpdatedType {
    OPENED,
    ADJUSTED,
    CLOSED,
    SPLIT_FROM,
    SPLIT_INTO,
    MERGED,
    MERGED_INTO,
    SETTLED,
    LIQUIDATED,
    TRANSFER
  }

  struct OptionPosition {
    uint positionId;
    uint strikeId;
    IOptionMarket.OptionType optionType;
    uint amount;
    uint collateral;
    PositionState state;
  }


  struct PartialCollateralParameters {
    // Percent of collateral used for penalty (amm + sm + liquidator fees)
    uint penaltyRatio;
    // Percent of penalty used for amm fees
    uint liquidatorFeeRatio;
    // Percent of penalty used for SM fees
    uint smFeeRatio;
    // Minimal value of quote that is used to charge a fee
    uint minLiquidationFee;
  }

  struct PositionWithOwner {
    uint positionId;
    uint strikeId;
    IOptionMarket.OptionType optionType;
    uint amount;
    uint collateral;
    PositionState state;
    address owner;
  }

  struct LiquidationFees {
    uint returnCollateral; // quote || base
    uint lpPremiums; // quote || base
    uint lpFee; // quote || base
    uint liquidatorFee; // quote || base
    uint smFee; // quote || base
    uint insolventAmount; // quote
  }

  function positions(uint positionId) external view returns (OptionPosition memory);

  function nextId() external view returns (uint);

  function partialCollatParams() external view returns (PartialCollateralParameters memory);

  function baseURI() external view returns (string memory);

  function canLiquidate(
    OptionPosition memory position,
    uint expiry,
    uint strikePrice,
    uint spotPrice
  ) external view returns (bool);

  function getLiquidationFees(
    uint gwavPremium, // quote || base
    uint userPositionCollateral, // quote || base
    uint convertedMinLiquidationFee, // quote || base
    uint insolvencyMultiplier // 1 for quote || spotPrice for base
  ) external view returns (LiquidationFees memory liquidationFees);

  ///////////////
  // Transfers //
  ///////////////

  function split(
    uint positionId,
    uint newAmount,
    uint newCollateral,
    address recipient
  ) external returns (uint newPositionId);

  function merge(uint[] memory positionIds) external;

  //////////
  // View //
  //////////


  /// @dev Returns the PositionState of a given positionId
  function getPositionState(uint positionId) external view returns (PositionState);

  /// @dev Returns an OptionPosition struct of a given positionId
  function getOptionPosition(uint positionId) external view returns (OptionPosition memory);

  /// @dev Returns an array of OptionPosition structs given an array of positionIds
  function getOptionPositions(uint[] memory positionIds) external view returns (OptionPosition[] memory);

  /// @dev Returns a PositionWithOwner struct of a given positionId (same as OptionPosition but with owner)
  function getPositionWithOwner(uint positionId) external view returns (PositionWithOwner memory);

  /// @dev Returns an array of PositionWithOwner structs given an array of positionIds
  function getPositionsWithOwner(uint[] memory positionIds) external view returns (PositionWithOwner[] memory);

  /// @notice Returns an array of OptionPosition structs owned by a given address
  /// @dev Meant to be used offchain as it can run out of gas
  function getOwnerPositions(address target) external view returns (OptionPosition[] memory);

  /// @dev returns PartialCollateralParameters struct
  function getPartialCollatParams() external view returns (PartialCollateralParameters memory);

  ////////////
  // Events //
  ///////////

  /**
   * @dev Emitted when the URI is modified
   */
  event URISet(string URI);

  /**
   * @dev Emitted when partial collateral parameters are modified
   */
  event PartialCollateralParamsSet(PartialCollateralParameters partialCollateralParams);

  /**
   * @dev Emitted when a position is minted, adjusted, burned, merged or split.
   */
  event PositionUpdated(
    uint indexed positionId,
    address indexed owner,
    PositionUpdatedType indexed updatedType,
    OptionPosition position,
    uint timestamp
  );

  ////////////
  // Errors //
  ////////////

  // Admin
  error InvalidPartialCollateralParameters(address thrower, PartialCollateralParameters partialCollatParams);

  // Adjusting
  error AdjustmentResultsInMinimumCollateralNotBeingMet(address thrower, OptionPosition position, uint spotPrice);
  error CannotClosePositionZero(address thrower);
  error CannotOpenZeroAmount(address thrower);
  error CannotAdjustInvalidPosition(
    address thrower,
    uint positionId,
    bool invalidPositionId,
    bool positionInactive,
    bool strikeMismatch,
    bool optionTypeMismatch
  );
  error OnlyOwnerCanAdjustPosition(address thrower, uint positionId, address trader, address owner);
  error FullyClosingWithNonZeroSetCollateral(address thrower, uint positionId, uint setCollateralTo);
  error AddingCollateralToInvalidPosition(
    address thrower,
    uint positionId,
    bool invalidPositionId,
    bool positionInactive,
    bool isShort
  );

  // Liquidation
  error PositionNotLiquidatable(address thrower, OptionPosition position, uint spotPrice);

  // Splitting
  error SplittingUnapprovedPosition(address thrower, address caller, uint positionId);
  error InvalidSplitAmount(address thrower, uint originalPositionAmount, uint splitAmount);
  error ResultingOriginalPositionLiquidatable(address thrower, OptionPosition position, uint spotPrice);
  error ResultingNewPositionLiquidatable(address thrower, OptionPosition position, uint spotPrice);

  // Merging
  error MustMergeTwoOrMorePositions(address thrower);
  error MergingUnapprovedPosition(address thrower, address caller, uint positionId);
  error PositionMismatchWhenMerging(
    address thrower,
    OptionPosition firstPosition,
    OptionPosition nextPosition,
    bool ownerMismatch,
    bool strikeMismatch,
    bool optionTypeMismatch,
    bool duplicatePositionId
  );

  // Access
  error StrikeIsSettled(address thrower, uint strikeId);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyShortCollateral(address thrower, address caller, address shortCollateral);
}

//SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

// For full documentation refer to @lyrafinance/protocol/contracts/LiquidityPool.sol";
interface ILiquidityPool {
  struct Collateral {
    uint quote;
    uint base;
  }

  /// These values are all in quoteAsset amounts.
  struct Liquidity {
    // Amount of liquidity available for option collateral and premiums
    uint freeLiquidity;
    // Amount of liquidity available for withdrawals - different to freeLiquidity
    uint burnableLiquidity;
    // Amount of liquidity reserved for long options sold to traders
    uint usedCollatLiquidity;
    // Portion of liquidity reserved for delta hedging (quote outstanding)
    uint pendingDeltaLiquidity;
    // Current value of delta hedge
    uint usedDeltaLiquidity;
    // Net asset value, including everything and netOptionValue
    uint NAV;
  }

  struct QueuedDeposit {
    uint id;
    // Who will receive the LiquidityToken minted for this deposit after the wait time
    address beneficiary;
    // The amount of quoteAsset deposited to be converted to LiquidityToken after wait time
    uint amountLiquidity;
    // The amount of LiquidityToken minted. Will equal to 0 if not processed
    uint mintedTokens;
    uint depositInitiatedTime;
  }

  struct QueuedWithdrawal {
    uint id;
    // Who will receive the quoteAsset returned after burning the LiquidityToken
    address beneficiary;
    // The amount of LiquidityToken being burnt after the wait time
    uint amountTokens;
    // The amount of quote transferred. Will equal to 0 if process not started
    uint quoteSent;
    uint withdrawInitiatedTime;
  }

  struct LiquidityPoolParameters {
    // The minimum amount of quoteAsset for a deposit, or the amount of LiquidityToken for a withdrawal
    uint minDepositWithdraw;
    // Time between initiating a deposit and when it can be processed
    uint depositDelay;
    // Time between initiating a withdrawal and when it can be processed
    uint withdrawalDelay;
    // Fee charged on withdrawn funds
    uint withdrawalFee;
    // Percentage of NAV below which the liquidity CB fires
    uint liquidityCBThreshold;
    // Length of time after the liq. CB stops firing during which deposits/withdrawals are still blocked
    uint liquidityCBTimeout;
    // Difference between the spot and GWAV baseline IVs after which point the vol CB will fire
    uint ivVarianceCBThreshold;
    // Difference between the spot and GWAV skew ratios after which point the vol CB will fire
    uint skewVarianceCBThreshold;
    // Length of time after the (base) vol. CB stops firing during which deposits/withdrawals are still blocked
    uint ivVarianceCBTimeout;
    // Length of time after the (skew) vol. CB stops firing during which deposits/withdrawals are still blocked
    uint skewVarianceCBTimeout;
    // The address of the "guardian"
    address guardianMultisig;
    // Length of time a deposit/withdrawal since initiation for before a guardian can force process their transaction
    uint guardianDelay;
    // When a new board is listed, block deposits/withdrawals
    uint boardSettlementCBTimeout;
    // When exchanging, don't exchange if fee is above this value
    uint maxFeePaid;
  }

  function poolHedger() external view returns (address);
  function queuedDeposits(uint id) external view returns (QueuedDeposit memory);
  function totalQueuedDeposits() external view returns (uint);
  function queuedDepositHead() external view returns (uint);
  function nextQueuedDepositId() external view returns (uint);
  function queuedWithdrawals(uint id) external view returns (QueuedWithdrawal memory);
  function totalQueuedWithdrawals() external view returns (uint);
  function queuedWithdrawalHead() external view returns (uint);
  function nextQueuedWithdrawalId() external view returns (uint);
  function CBTimestamp() external view returns (uint);

  /// @dev Amount of collateral locked for outstanding calls and puts sold to users
  function lockedCollateral() external view returns (Collateral memory);

  /// @dev Total amount of quoteAsset reserved for all settled options that have yet to be paid out
  function totalOutstandingSettlements() external view returns (uint);

  /// @dev Total value not transferred to this contract for all shorts that didn't have enough collateral after expiry
  function insolventSettlementAmount() external view returns (uint);

  /// @dev Total value not transferred to this contract for all liquidations that didn't have enough collateral when liquidated
  function liquidationInsolventAmount() external view returns (uint);

  function initiateDeposit(address beneficiary, uint amountQuote) external;

  function initiateWithdraw(address beneficiary, uint amountLiquidityToken) external;

  function processDepositQueue(uint limit) external;

  function processWithdrawalQueue(uint limit) external; 

  function updateCBs() external;

  function getTotalTokenSupply() external view returns (uint);

  function getTokenPriceWithCheck()
    external
    view
    returns (
      uint tokenPrice,
      bool isStale,
      uint circuitBreakerExpiry
    );

  function getTokenPrice() external view returns (uint);

  function getCurrentLiquidity() external view returns (Liquidity memory);

  function getLiquidity(uint spotPrice) external view returns (Liquidity memory);

  function getTotalPoolValueQuote() external view returns (uint);

  function exchangeBase() external;

  function getLpParams() external view returns (LiquidityPoolParameters memory);

  ////////////
  // Events //
  ////////////

  /// @dev Emitted whenever the pool paramters are updated
  event LiquidityPoolParametersUpdated(LiquidityPoolParameters lpParams);

  /// @dev Emitted whenever the poolHedger address is modified
  event PoolHedgerUpdated(address poolHedger);

  /// @dev Emitted when quote is locked.
  event QuoteLocked(uint quoteLocked, uint lockedCollateralQuote);

  /// @dev Emitted when quote is freed.
  event QuoteFreed(uint quoteFreed, uint lockedCollateralQuote);

  /// @dev Emitted when base is locked.
  event BaseLocked(uint baseLocked, uint lockedCollateralBase);

  /// @dev Emitted when base is freed.
  event BaseFreed(uint baseFreed, uint lockedCollateralBase);

  /// @dev Emitted when a board is settled.
  event BoardSettlement(uint insolventSettlementAmount, uint amountQuoteReserved, uint totalOutstandingSettlements);

  /// @dev Emitted when reserved quote is sent.
  event OutstandingSettlementSent(address indexed user, uint amount, uint totalOutstandingSettlements);

  /// @dev Emitted whenever quote is exchanged for base
  event BasePurchased(uint quoteSpent, uint baseReceived);

  /// @dev Emitted whenever base is exchanged for quote
  event BaseSold(uint amountBase, uint quoteReceived);

  /// @dev Emitted whenever premium is sent to a trader closing their position
  event PremiumTransferred(address indexed recipient, uint recipientPortion, uint optionMarketPortion);

  /// @dev Emitted whenever quote is sent to the PoolHedger
  event QuoteTransferredToPoolHedger(uint amountQuote);

  /// @dev Emitted whenever the insolvent settlement amount is updated (settlement and excess)
  event InsolventSettlementAmountUpdated(uint amountQuoteAdded, uint totalInsolventSettlementAmount);

  /// @dev Emitted whenever a user deposits and enters the queue.
  event DepositQueued(
    address indexed depositor,
    address indexed beneficiary,
    uint indexed depositQueueId,
    uint amountDeposited,
    uint totalQueuedDeposits,
    uint timestamp
  );

  /// @dev Emitted whenever a deposit gets processed. Note, can be processed without being queued.
  ///  QueueId of 0 indicates it was not queued.
  event DepositProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed depositQueueId,
    uint amountDeposited,
    uint tokenPrice,
    uint tokensReceived,
    uint timestamp
  );

  /// @dev Emitted whenever a deposit gets processed. Note, can be processed without being queued.
  ///  QueueId of 0 indicates it was not queued.
  event WithdrawProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint tokenPrice,
    uint quoteReceived,
    uint totalQueuedWithdrawals,
    uint timestamp
  );
  event WithdrawPartiallyProcessed(
    address indexed caller,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint tokenPrice,
    uint quoteReceived,
    uint totalQueuedWithdrawals,
    uint timestamp
  );
  event WithdrawQueued(
    address indexed withdrawer,
    address indexed beneficiary,
    uint indexed withdrawalQueueId,
    uint amountWithdrawn,
    uint totalQueuedWithdrawals,
    uint timestamp
  );

  /// @dev Emitted whenever the CB timestamp is updated
  event CircuitBreakerUpdated(
    uint newTimestamp,
    bool ivVarianceThresholdCrossed,
    bool skewVarianceThresholdCrossed,
    bool liquidityThresholdCrossed
  );

  /// @dev Emitted whenever the CB timestamp is updated from a board settlement
  event BoardSettlementCircuitBreakerUpdated(uint newTimestamp);

  /// @dev Emitted whenever a queue item is checked for the ability to be processed
  event CheckingCanProcess(uint entryId, bool boardNotStale, bool validEntry, bool guardianBypass, bool delaysExpired);

  ////////////
  // Errors //
  ////////////

  // Admin
  error InvalidLiquidityPoolParameters(address thrower, LiquidityPoolParameters lpParams);

  // Deposits and withdrawals
  error InvalidBeneficiaryAddress(address thrower, address beneficiary);
  error MinimumDepositNotMet(address thrower, uint amountQuote, uint minDeposit);
  error MinimumWithdrawNotMet(address thrower, uint amountLiquidityToken, uint minWithdraw);

  // Liquidity and accounting
  error LockingMoreQuoteThanIsFree(address thrower, uint quoteToLock, uint freeLiquidity, Collateral lockedCollateral);
  error SendPremiumNotEnoughCollateral(address thrower, uint premium, uint reservedFee, uint freeLiquidity);
  error NotEnoughFreeToReclaimInsolvency(address thrower, uint amountQuote, Liquidity liquidity);
  error OptionValueDebtExceedsTotalAssets(address thrower, int totalAssetValue, int optionValueDebt);
  error InsufficientFreeLiquidityForBaseExchange(
    address thrower,
    uint pendingBase,
    uint estimatedExchangeCost,
    uint freeLiquidity
  );

  // Access
  error OnlyPoolHedger(address thrower, address caller, address poolHedger);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyShortCollateral(address thrower, address caller, address poolHedger);

  // Token transfers
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
}

//SPDX-License-Identifier: ISC

pragma solidity 0.8.9;

// Interfaces
import "./IOptionMarket.sol";
import "./IOptionToken.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/ShortCollateral.sol";

interface IShortCollateral {
  // The amount the SC underpaid the LP due to insolvency.
  // The SC will take this much less from the LP when settling insolvent positions.
  function LPBaseExcess() external view returns (uint);
  function LPQuoteExcess() external view returns (uint);

  /////////////////////////
  // Position Settlement //
  /////////////////////////

  function settleOptions(uint[] memory positionIds) external;

  ////////////
  // Events //
  ////////////

  /// @dev Emitted when a board is settled
  event BoardSettlementCollateralSent(
    uint amountBaseSent,
    uint amountQuoteSent,
    uint lpBaseInsolvency,
    uint lpQuoteInsolvency,
    uint LPBaseExcess,
    uint LPQuoteExcess
  );

  /**
   * @dev Emitted when an Option is settled.
   */
  event PositionSettled(
    uint indexed positionId,
    address indexed settler,
    address indexed optionOwner,
    uint strikePrice,
    uint priceAtExpiry,
    IOptionMarket.OptionType optionType,
    uint amount,
    uint settlementAmount,
    uint insolventAmount
  );

  /**
   * @dev Emitted when quote is sent to either a user or the LiquidityPool
   */
  event QuoteSent(address indexed receiver, uint amount);
  /**
   * @dev Emitted when base is sent to either a user or the LiquidityPool
   */
  event BaseSent(address indexed receiver, uint amount);

  event BaseExchangedAndQuoteSent(address indexed recipient, uint amountBase, uint quoteReceived);

  ////////////
  // Errors //
  ////////////

  // Collateral transfers
  error OutOfQuoteCollateralForTransfer(address thrower, uint balance, uint amount);
  error OutOfBaseCollateralForTransfer(address thrower, uint balance, uint amount);
  error OutOfBaseCollateralForExchangeAndTransfer(address thrower, uint balance, uint amount);

  // Token transfers
  error BaseTransferFailed(address thrower, address from, address to, uint amount);
  error QuoteTransferFailed(address thrower, address from, address to, uint amount);

  // Access
  error BoardMustBeSettled(address thrower, IOptionToken.PositionWithOwner position);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IOptionMarket.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/interfaces/IOptionGreekCache.sol";
interface IOptionGreekCache {

  struct GreekCacheParameters {
    // Cap the number of strikes per board to avoid hitting gasLimit constraints
    uint maxStrikesPerBoard;
    // How much spot price can move since last update before deposits/withdrawals are blocked
    uint acceptableSpotPricePercentMove;
    // How much time has passed since last update before deposits/withdrawals are blocked
    uint staleUpdateDuration;
    // Length of the GWAV for the baseline volatility used to fire the vol circuit breaker
    uint varianceIvGWAVPeriod;
    // Length of the GWAV for the skew ratios used to fire the vol circuit breaker
    uint varianceSkewGWAVPeriod;
    // Length of the GWAV for the baseline used to determine the NAV of the pool
    uint optionValueIvGWAVPeriod;
    // Length of the GWAV for the skews used to determine the NAV of the pool
    uint optionValueSkewGWAVPeriod;
    // Minimum skew that will be fed into the GWAV calculation
    // Prevents near 0 values being used to heavily manipulate the GWAV
    uint gwavSkewFloor;
    // Maximum skew that will be fed into the GWAV calculation
    uint gwavSkewCap;
    // Interest/risk free rate
    int rateAndCarry;
  }

  struct ForceCloseParameters {
    // Length of the GWAV for the baseline vol used in ForceClose() and liquidations
    uint ivGWAVPeriod;
    // Length of the GWAV for the skew ratio used in ForceClose() and liquidations
    uint skewGWAVPeriod;
    // When a user buys back an option using ForceClose() we increase the GWAV vol to penalise the trader
    uint shortVolShock;
    // Increase the penalty when within the trading cutoff
    uint shortPostCutoffVolShock;
    // When a user sells back an option to the AMM using ForceClose(), we decrease the GWAV to penalise the seller
    uint longVolShock;
    // Increase the penalty when within the trading cutoff
    uint longPostCutoffVolShock;
    // Same justification as shortPostCutoffVolShock
    uint liquidateVolShock;
    // Increase the penalty when within the trading cutoff
    uint liquidatePostCutoffVolShock;
    // Minimum price the AMM will sell back an option at for force closes (as a % of current spot)
    uint shortSpotMin;
    // Minimum price the AMM will sell back an option at for liquidations (as a % of current spot)
    uint liquidateSpotMin;
  }

  struct MinCollateralParameters {
    // Minimum collateral that must be posted for a short to be opened (denominated in quote)
    uint minStaticQuoteCollateral;
    // Minimum collateral that must be posted for a short to be opened (denominated in base)
    uint minStaticBaseCollateral;
    /* Shock Vol:
     * Vol used to compute the minimum collateral requirements for short positions.
     * This value is derived from the following chart, created by using the 4 values listed below.
     *
     *     vol
     *      |
     * volA |____
     *      |    \
     * volB |     \___
     *      |___________ time to expiry
     *         A   B
     */
    uint shockVolA;
    uint shockVolPointA;
    uint shockVolB;
    uint shockVolPointB;
    // Static percentage shock to the current spot price for calls
    uint callSpotPriceShock;
    // Static percentage shock to the current spot price for puts
    uint putSpotPriceShock;
  }

  ///////////////////
  // Cache storage //
  ///////////////////
  struct GlobalCache {
    uint minUpdatedAt;
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    uint maxSkewVariance;
    uint maxIvVariance;
    NetGreeks netGreeks;
  }

  struct OptionBoardCache {
    uint id;
    uint[] strikes;
    uint expiry;
    uint iv;
    NetGreeks netGreeks;
    uint updatedAt;
    uint updatedAtPrice;
    uint maxSkewVariance;
    uint ivVariance;
  }

  struct StrikeCache {
    uint id;
    uint boardId;
    uint strikePrice;
    uint skew;
    StrikeGreeks greeks;
    int callExposure; // long - short
    int putExposure; // long - short
    uint skewVariance; // (GWAVSkew - skew)
  }

  // These are based on GWAVed iv
  struct StrikeGreeks {
    int callDelta;
    int putDelta;
    uint stdVega;
    uint callPrice;
    uint putPrice;
  }

  // These are based on GWAVed iv
  struct NetGreeks {
    int netDelta;
    int netStdVega;
    int netOptionValue;
  }

  ///////////////
  // In-memory //
  ///////////////
  struct TradePricing {
    uint optionPrice;
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    int callDelta;
    uint volTraded;
    uint ivVariance;
    uint vega;
  }

  struct BoardGreeksView {
    NetGreeks boardGreeks;
    uint ivGWAV;
    StrikeGreeks[] strikeGreeks;
    uint[] skewGWAVs;
  }

  
  function getPriceForForceClose(
    IOptionMarket.TradeParameters memory trade,
    IOptionMarket.Strike memory strike,
    uint expiry,
    uint newVol,
    bool isPostCutoff
  ) external view returns (uint optionPrice, uint forceCloseVol);
  
  function getMinCollateral(
    IOptionMarket.OptionType optionType,
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) external view returns (uint minCollateral);

  function getShockVol(uint timeToMaturity) external view returns (uint);
  
  function updateBoardCachedGreeks(uint boardId) external;

  function isGlobalCacheStale(uint spotPrice) external view returns (bool);

  function isBoardCacheStale(uint boardId) external view returns (bool);

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  /// @notice Get the current cached global netDelta exposure.
  function getGlobalNetDelta() external view returns (int);

  /// @notice Get the current global net option value
  function getGlobalOptionValue() external view returns (int);

  /// @notice Returns the BoardGreeksView struct given a specific boardId
  function getBoardGreeksView(uint boardId) external view returns (BoardGreeksView memory);

  /// @notice Get StrikeCache given a specific strikeId
  function getStrikeCache(uint strikeId) external view returns (StrikeCache memory);

  /// @notice Get OptionBoardCache given a specific boardId
  function getOptionBoardCache(uint boardId) external view returns (OptionBoardCache memory);

  /// @notice Get the global cache
  function getGlobalCache() external view returns (GlobalCache memory);

  /// @notice Returns ivGWAV for a given boardId and GWAV time interval
  function getIvGWAV(uint boardId, uint secondsAgo) external view returns (uint ivGWAV);

  /// @notice Returns skewGWAV for a given strikeId and GWAV time interval
  function getSkewGWAV(uint strikeId, uint secondsAgo) external view returns (uint skewGWAV);

  /// @notice Get the GreekCacheParameters
  function getGreekCacheParams() external view returns (GreekCacheParameters memory);

  /// @notice Get the ForceCloseParamters
  function getForceCloseParams() external view returns (ForceCloseParameters memory);

  /// @notice Get the MinCollateralParamters
  function getMinCollatParams() external view returns (MinCollateralParameters memory);


  ////////////
  // Events //
  ////////////

  event GreekCacheParametersSet(GreekCacheParameters params);
  event ForceCloseParametersSet(ForceCloseParameters params);
  event MinCollateralParametersSet(MinCollateralParameters params);

  event StrikeCacheUpdated(StrikeCache strikeCache);
  event BoardCacheUpdated(OptionBoardCache boardCache);
  event GlobalCacheUpdated(GlobalCache globalCache);

  event BoardCacheRemoved(uint boardId);
  event StrikeCacheRemoved(uint strikeId);
  event BoardIvUpdated(uint boardId, uint newIv, uint globalMaxIvVariance);
  event StrikeSkewUpdated(uint strikeId, uint newSkew, uint globalMaxSkewVariance);

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidGreekCacheParameters(address thrower, GreekCacheParameters greekCacheParams);
  error InvalidForceCloseParameters(address thrower, ForceCloseParameters forceCloseParams);
  error InvalidMinCollatParams(address thrower, MinCollateralParameters minCollatParams);

  // Board related
  error BoardStrikeLimitExceeded(address thrower, uint boardId, uint newStrikesLength, uint maxStrikesPerBoard);
  error InvalidBoardId(address thrower, uint boardId);
  error CannotUpdateExpiredBoard(address thrower, uint boardId, uint expiry, uint currentTimestamp);

  // Access
  error OnlyIOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyIOptionMarketPricer(address thrower, address caller, address optionMarketPricer);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IAddressResolver.sol";
import "./ISynthetix.sol";
import "./IExchanger.sol";
import "./IExchangeRates.sol";
import "./IDelegateApprovals.sol";


// For full documentation refer to @lyrafinance/protocol/contracts/SynthetixAdapter.sol";
interface ISynthetixAdapter {

  struct ExchangeParams {
    // snx oracle exchange rate for base
    uint spotPrice;
    // snx quote asset identifier key
    bytes32 quoteKey;
    // snx base asset identifier key
    bytes32 baseKey;
    // snx spot exchange rate from quote to base
    uint quoteBaseFeeRate;
    // snx spot exchange rate from base to quote
    uint baseQuoteFeeRate;
  }

  /// @dev Pause the whole system. Note; this will not pause settling previously expired options.
  function isMarketPaused(address market) external view returns (bool);
  function isGlobalPaused() external view returns (bool);

  function addressResolver() external view returns (address);
  function synthetix() external view returns (address);
  function exchanger() external view returns (address);
  function exchangeRates() external view returns (address);
  function delegateApprovals() external view returns (address);

  // Variables related to calculating premium/fees
  function quoteKey(address market) external view returns (bytes32);
  function baseKey(address market) external view returns (bytes32);
  function rewardAddress(address market) external view returns (bytes32);
  function trackingCode(address market) external view returns (bytes32);


  function updateSynthetixAddresses() external;

  /////////////
  // Getters //
  /////////////
  
  function getSpotPriceForMarket(address _contractAddress)
    external
    view
    returns (uint spotPrice);

  function getSpotPrice(bytes32 to) external view returns (uint);
  
  function getExchangeParams(address optionMarket)
    external
    view
    returns (ExchangeParams memory exchangeParams);

  function requireNotGlobalPaused(address optionMarket) external view;

  /////////////////////////////////////////
  // Exchanging QuoteAsset for BaseAsset //
  /////////////////////////////////////////

  function exchangeFromExactQuote(address optionMarket, uint amountQuote) external returns (uint baseReceived);

  function exchangeToExactBase(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase
  ) external returns (uint quoteSpent, uint baseReceived);
  
  function exchangeToExactBaseWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase,
    uint quoteLimit
  ) external returns (uint quoteSpent, uint baseReceived);
  
  function estimateExchangeToExactBase(ExchangeParams memory exchangeParams, uint amountBase)
    external
    pure
    returns (uint quoteNeeded);

  /////////////////////////////////////////
  // Exchanging BaseAsset for QuoteAsset //
  /////////////////////////////////////////

  function exchangeFromExactBase(address optionMarket, uint amountBase) external returns (uint quoteReceived);
  
  function exchangeToExactQuote(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote
  ) external returns (uint baseSpent, uint quoteReceived);

  function exchangeToExactQuoteWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote,
    uint baseLimit
  ) external returns (uint baseSpent, uint quoteReceived);

  function estimateExchangeToExactQuote(ExchangeParams memory exchangeParams, uint amountQuote)
    external
    pure
    returns (uint baseNeeded);

  ////////////
  // Events //
  ////////////

  /**
   * @dev Emitted when the address resolver is set.
   */
  event AddressResolverSet(IAddressResolver addressResolver);
  /**
   * @dev Emitted when synthetix contracts are updated.
   */
  event SynthetixAddressesUpdated(
    ISynthetix synthetix,
    IExchanger exchanger,
    IExchangeRates exchangeRates,
    IDelegateApprovals delegateApprovals
  );
  /**
   * @dev Emitted when values for a given option market are set.
   */
  event GlobalsSetForContract(
    address indexed market,
    bytes32 quoteKey,
    bytes32 baseKey,
    address rewardAddress,
    bytes32 trackingCode
  );
  /**
   * @dev Emitted when GlobalPause.
   */
  event GlobalPausedSet(bool isPaused);
  /**
   * @dev Emitted when single market paused.
   */
  event MarketPausedSet(address contractAddress, bool isPaused);
  /**
   * @dev Emitted when an exchange for base to quote occurs.
   * Which base and quote were swapped can be determined by the given marketAddress.
   */
  event BaseSwappedForQuote(
    address indexed marketAddress,
    address indexed exchanger,
    uint baseSwapped,
    uint quoteReceived
  );
  /**
   * @dev Emitted when an exchange for quote to base occurs.
   * Which base and quote were swapped can be determined by the given marketAddress.
   */
  event QuoteSwappedForBase(
    address indexed marketAddress,
    address indexed exchanger,
    uint quoteSwapped,
    uint baseReceived
  );

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidRewardAddress(address thrower, address rewardAddress);

  // Market Paused
  error AllMarketsPaused(address thrower, address marketAddress);
  error MarketIsPaused(address thrower, address marketAddress);

  // Exchanging
  error ReceivedZeroFromExchange(
    address thrower,
    bytes32 fromKey,
    bytes32 toKey,
    uint amountSwapped,
    uint amountReceived
  );
  error QuoteBaseExchangeExceedsLimit(
    address thrower,
    uint amountBaseRequested,
    uint quoteToSpend,
    uint quoteLimit,
    uint spotPrice,
    bytes32 quoteKey,
    bytes32 baseKey
  );
  error BaseQuoteExchangeExceedsLimit(
    address thrower,
    uint amountQuoteRequested,
    uint baseToSpend,
    uint baseLimit,
    uint spotPrice,
    bytes32 baseKey,
    bytes32 quoteKey
  );
  error RateIsInvalid(address thrower, uint spotPrice, bool invalid);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface IDelegateApprovals {
  function approveExchangeOnBehalf(address delegate) external;

  function canExchangeOnBehalf(address exchanger, address beneficiary) external view returns (bool);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface ICurve {
  function exchange_with_best_rate(
    address _from,
    address _to,
    uint _amount,
    uint _expected,
    address _receiver
  ) external payable returns (uint amountOut);

  function exchange_underlying(
    int128 _from,
    int128 _to,
    uint _amount,
    uint _expected
  ) external payable returns (uint amountOut);

  function get_best_rate(
    address _from,
    address _to,
    uint _amount
  ) external view returns (address pool, uint amountOut);
}

//SPDX-License-Identifier:ISC

pragma solidity 0.8.9;

// For full documentation refer to @lyrafinance/protocol/contracts/periphery/GWAVOracle.sol";

interface IGWAVOracle {
  function ivGWAV(uint boardId, uint secondsAgo) external view returns (uint);

  function skewGWAV(uint strikeId, uint secondsAgo) external view returns (uint);

  function volGWAV(uint strikeId, uint secondsAgo) external view returns (uint);

  function deltaGWAV(uint strikeId, uint secondsAgo) external view returns (int callDelta);

  function vegaGWAV(uint strikeId, uint secondsAgo) external view returns (uint vega);

  function optionPriceGWAV(uint strikeId, uint secondsAgo) external view returns (uint callPrice, uint putPrice);

}

//SPDX-License-Identifier:ISC

pragma solidity 0.8.9;

import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/periphery/LyraRegistry.sol";
/// @dev inputs/returns that contain Lyra contracts replaced with addresses (as opposed to LyraRegistry.sol)
///      so that interacting contracts are not required to import Lyra contracts 
interface ILyraRegistry {
  struct OptionMarketAddresses {
    address liquidityPool;
    address liquidityToken;
    address greekCache;
    address optionMarket;
    address optionMarketPricer;
    address optionToken;
    address poolHedger;
    address shortCollateral;
    address gwavOracle;
    IERC20 quoteAsset;
    IERC20 baseAsset;
  }

  function optionMarkets() external view returns (address[] memory);

  function marketAddress(address market) external view returns (OptionMarketAddresses memory);

  function globalAddresses(bytes32 name) external view returns (address);

  function getMarketAddresses(address optionMarket) external view returns (OptionMarketAddresses memory);

  function getGlobalAddress(bytes32 contractName) external view returns (address globalContract);

  event GlobalAddressUpdated(bytes32 indexed name, address addr);

  event MarketUpdated(address indexed optionMarket, OptionMarketAddresses market);

  event MarketRemoved(address indexed market);

  error RemovingInvalidMarket(address thrower, address market);

  error NonExistentMarket(address optionMarket);

  error NonExistentGlobalContract(bytes32 contractName);
}

//SPDX-License-Identifier:ISC
pragma solidity 0.8.9;

import "../synthetix/Owned.sol";
import "../interfaces/IFeeCounter.sol";

/**
 * @title BasicFeeCounter
 */
contract BasicFeeCounter is IFeeCounter, Owned {
  mapping(address => bool) public trustedCounter;
  mapping(address => mapping(address => uint)) public totalFeesPerMarket;

  constructor() Owned() {}

  function setTrustedCounter(address counter, bool isTrusted) external onlyOwner {
    trustedCounter[counter] = isTrusted;
  }

  function trackFee(
    address market,
    address trader,
    uint,
    uint,
    uint totalFee
  ) external onlyTrustedCounter {
    totalFeesPerMarket[market][trader] += totalFee;
  }

  modifier onlyTrustedCounter() {
    require(trustedCounter[msg.sender], "not trusted counter");
    _;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

// Slightly modified version of:
// - https://github.com/recmo/experiment-solexp/blob/605738f3ed72d6c67a414e992be58262fbc9bb80/src/FixedPointMathLib.sol
library FixedPointMathLib {
  /// @dev Computes ln(x) for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function lnPrecise(int x) internal pure returns (int r) {
    return ln(x / 1e9) * 1e9;
  }

  /// @dev Computes e ^ x for a 1e27 fixed point. Loses 9 last significant digits of precision.
  function expPrecise(int x) internal pure returns (uint r) {
    return exp(x / 1e9) * 1e9;
  }

  // Computes ln(x) in 1e18 fixed point.
  // Reverts if x is negative or zero.
  // Consumes 670 gas.
  function ln(int x) internal pure returns (int r) {
    unchecked {
      if (x < 1) {
        if (x < 0) revert LnNegativeUndefined();
        revert Overflow();
      }

      // We want to convert x from 10**18 fixed point to 2**96 fixed point.
      // We do this by multiplying by 2**96 / 10**18.
      // But since ln(x * C) = ln(x) + ln(C), we can simply do nothing here
      // and add ln(2**96 / 10**18) at the end.

      // Reduce range of x to (1, 2) * 2**96
      // ln(2^k * x) = k * ln(2) + ln(x)
      // Note: inlining ilog2 saves 8 gas.
      int k = int(ilog2(uint(x))) - 96;
      x <<= uint(159 - k);
      x = int(uint(x) >> 159);

      // Evaluate using a (8, 8)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 3273285459638523848632254066296;
      p = ((p * x) >> 96) + 24828157081833163892658089445524;
      p = ((p * x) >> 96) + 43456485725739037958740375743393;
      p = ((p * x) >> 96) - 11111509109440967052023855526967;
      p = ((p * x) >> 96) - 45023709667254063763336534515857;
      p = ((p * x) >> 96) - 14706773417378608786704636184526;
      p = p * x - (795164235651350426258249787498 << 96);
      //emit log_named_int("p", p);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // q is monic by convention
      int q = x + 5573035233440673466300451813936;
      q = ((q * x) >> 96) + 71694874799317883764090561454958;
      q = ((q * x) >> 96) + 283447036172924575727196451306956;
      q = ((q * x) >> 96) + 401686690394027663651624208769553;
      q = ((q * x) >> 96) + 204048457590392012362485061816622;
      q = ((q * x) >> 96) + 31853899698501571402653359427138;
      q = ((q * x) >> 96) + 909429971244387300277376558375;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r is in the range (0, 0.125) * 2**96

      // Finalization, we need to
      // * multiply by the scale factor s = 5.549…
      // * add ln(2**96 / 10**18)
      // * add k * ln(2)
      // * multiply by 10**18 / 2**96 = 5**18 >> 78
      // mul s * 5e18 * 2**96, base is now 5**18 * 2**192
      r *= 1677202110996718588342820967067443963516166;
      // add ln(2) * k * 5e18 * 2**192
      r += 16597577552685614221487285958193947469193820559219878177908093499208371 * k;
      // add ln(2**96 / 10**18) * 5e18 * 2**192
      r += 600920179829731861736702779321621459595472258049074101567377883020018308;
      // base conversion: mul 2**18 / 2**192
      r >>= 174;
    }
  }

  // Integer log2
  // @returns floor(log2(x)) if x is nonzero, otherwise 0. This is the same
  //          as the location of the highest set bit.
  // Consumes 232 gas. This could have been an 3 gas EVM opcode though.
  function ilog2(uint x) internal pure returns (uint r) {
    assembly {
      r := shl(7, lt(0xffffffffffffffffffffffffffffffff, x))
      r := or(r, shl(6, lt(0xffffffffffffffff, shr(r, x))))
      r := or(r, shl(5, lt(0xffffffff, shr(r, x))))
      r := or(r, shl(4, lt(0xffff, shr(r, x))))
      r := or(r, shl(3, lt(0xff, shr(r, x))))
      r := or(r, shl(2, lt(0xf, shr(r, x))))
      r := or(r, shl(1, lt(0x3, shr(r, x))))
      r := or(r, lt(0x1, shr(r, x)))
    }
  }

  // Computes e^x in 1e18 fixed point.
  function exp(int x) internal pure returns (uint r) {
    unchecked {
      // Input x is in fixed point format, with scale factor 1/1e18.

      // When the result is < 0.5 we return zero. This happens when
      // x <= floor(log(0.5e18) * 1e18) ~ -42e18
      if (x <= -42139678854452767551) {
        return 0;
      }

      // When the result is > (2**255 - 1) / 1e18 we can not represent it
      // as an int256. This happens when x >= floor(log((2**255 -1) / 1e18) * 1e18) ~ 135.
      if (x >= 135305999368893231589) revert ExpOverflow();

      // x is now in the range (-42, 136) * 1e18. Convert to (-42, 136) * 2**96
      // for more intermediate precision and a binary basis. This base conversion
      // is a multiplication by 1e18 / 2**96 = 5**18 / 2**78.
      x = (x << 78) / 5**18;

      // Reduce range of x to (-½ ln 2, ½ ln 2) * 2**96 by factoring out powers of two
      // such that exp(x) = exp(x') * 2**k, where k is an integer.
      // Solving this gives k = round(x / log(2)) and x' = x - k * log(2).
      int k = ((x << 96) / 54916777467707473351141471128 + 2**95) >> 96;
      x = x - k * 54916777467707473351141471128;
      // k is in the range [-61, 195].

      // Evaluate using a (6, 7)-term rational approximation
      // p is made monic, we will multiply by a scale factor later
      int p = x + 2772001395605857295435445496992;
      p = ((p * x) >> 96) + 44335888930127919016834873520032;
      p = ((p * x) >> 96) + 398888492587501845352592340339721;
      p = ((p * x) >> 96) + 1993839819670624470859228494792842;
      p = p * x + (4385272521454847904632057985693276 << 96);
      // We leave p in 2**192 basis so we don't need to scale it back up for the division.
      // Evaluate using using Knuth's scheme from p. 491.
      int z = x + 750530180792738023273180420736;
      z = ((z * x) >> 96) + 32788456221302202726307501949080;
      int w = x - 2218138959503481824038194425854;
      w = ((w * z) >> 96) + 892943633302991980437332862907700;
      int q = z + w - 78174809823045304726920794422040;
      q = ((q * w) >> 96) + 4203224763890128580604056984195872;
      assembly {
        // Div in assembly because solidity adds a zero check despite the `unchecked`.
        // The q polynomial is known not to have zeros in the domain. (All roots are complex)
        // No scaling required because p is already 2**96 too large.
        r := sdiv(p, q)
      }
      // r should be in the range (0.09, 0.25) * 2**96.

      // We now need to multiply r by
      //  * the scale factor s = ~6.031367120...,
      //  * the 2**k factor from the range reduction, and
      //  * the 1e18 / 2**96 factor for base converison.
      // We do all of this at once, with an intermediate result in 2**213 basis
      // so the final right shift is always by a positive amount.
      r = (uint(r) * 3822833074963236453042738258902158003155416615667) >> uint(195 - k);
    }
  }

  error Overflow();
  error ExpOverflow();
  error LnNegativeUndefined();
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
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
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
 * contract, which may impact the proxy. To initialize the implementation contract, you can either invoke the
 * initializer manually, or you can include a constructor to automatically mark it as initialized when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() initializer {}
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     */
    bool private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Modifier to protect an initializer function from being invoked twice.
     */
    modifier initializer() {
        // If the contract is initializing we ignore whether _initialized is set in order to support multiple
        // inheritance patterns, but we only do this in the context of a constructor, because in other contexts the
        // contract may have been reentered.
        require(_initializing ? _isConstructor() : !_initialized, "Initializable: contract is already initialized");

        bool isTopLevelCall = !_initializing;
        if (isTopLevelCall) {
            _initializing = true;
            _initialized = true;
        }

        _;

        if (isTopLevelCall) {
            _initializing = false;
        }
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} modifier, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    function _isConstructor() private view returns (bool) {
        return !AddressUpgradeable.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

import "./IOptionMarket.sol";
import "./IOptionGreekCache.sol";

// For full documentation refer to @lyrafinance/protocol/contracts/OptionMarketPricer.sol";
interface IOptionMarketPricer {

  struct PricingParameters {
    // Percentage of option price that is charged as a fee
    uint optionPriceFeeCoefficient;
    // Refer to: getTimeWeightedFee()
    uint optionPriceFee1xPoint;
    uint optionPriceFee2xPoint;
    // Percentage of spot price that is charged as a fee per option
    uint spotPriceFeeCoefficient;
    // Refer to: getTimeWeightedFee()
    uint spotPriceFee1xPoint;
    uint spotPriceFee2xPoint;
    // Refer to: getVegaUtilFee()
    uint vegaFeeCoefficient;
    // The amount of options traded to move baseIv for the board up or down 1 point (depending on trade direction)
    uint standardSize;
    // The relative move of skew for a given strike based on standard sizes traded
    uint skewAdjustmentFactor;
  }

  struct TradeLimitParameters {
    // Delta cutoff past which no options can be traded (optionD > minD && optionD < 1 - minD) - using call delta
    int minDelta;
    // Delta cutoff at which ForceClose can be called (optionD < minD || optionD > 1 - minD) - using call delta
    int minForceCloseDelta;
    // Time when trading closes. Only ForceClose can be called after this
    uint tradingCutoff;
    // Lowest baseIv for a board that can be traded for regular option opens/closes
    uint minBaseIV;
    // Maximal baseIv for a board that can be traded for regular option opens/closes
    uint maxBaseIV;
    // Lowest skew for a strike that can be traded for regular option opens/closes
    uint minSkew;
    // Maximal skew for a strike that can be traded for regular option opens/closes
    uint maxSkew;
    // Minimal vol traded for regular option opens/closes (baseIv * skew)
    uint minVol;
    // Maximal vol traded for regular option opens/closes (baseIv * skew)
    uint maxVol;
    // Absolute lowest skew that ForceClose can go to
    uint absMinSkew;
    // Absolute highest skew that ForceClose can go to
    uint absMaxSkew;
    // Cap the skew the abs max/min skews - only relevant to liquidations
    bool capSkewsToAbs;
  }

  struct VarianceFeeParameters {
    uint defaultVarianceFeeCoefficient;
    uint forceCloseVarianceFeeCoefficient;
    // coefficient that allows the skew component of the fee to be scaled up
    uint skewAdjustmentCoefficient;
    // measures the difference of the skew to a reference skew
    uint referenceSkew;
    // constant to ensure small vega terms have a fee
    uint minimumStaticSkewAdjustment;
    // coefficient that allows the vega component of the fee to be scaled up
    uint vegaCoefficient;
    // constant to ensure small vega terms have a fee
    uint minimumStaticVega;
    // coefficient that allows the ivVariance component of the fee to be scaled up
    uint ivVarianceCoefficient;
    // constant to ensure small variance terms have a fee
    uint minimumStaticIvVariance;
  }

  ///////////////
  // In-memory //
  ///////////////
  struct TradeResult {
    uint amount;
    uint premium;
    uint optionPriceFee;
    uint spotPriceFee;
    VegaUtilFeeComponents vegaUtilFee;
    VarianceFeeComponents varianceFee;
    uint totalFee;
    uint totalCost;
    uint volTraded;
    uint newBaseIv;
    uint newSkew;
  }

  struct VegaUtilFeeComponents {
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    uint vegaUtil;
    uint volTraded;
    uint NAV;
    uint vegaUtilFee;
  }

  struct VarianceFeeComponents {
    uint varianceFeeCoefficient;
    uint vega;
    uint vegaCoefficient;
    uint skew;
    uint skewCoefficient;
    uint ivVariance;
    uint ivVarianceCoefficient;
    uint varianceFee;
  }

  struct VolComponents {
    uint vol;
    uint baseIv;
    uint skew;
  }

  ///////////////
  // Variables //
  ///////////////

  function pricingParams() external view returns (PricingParameters memory);
  function tradeLimitParams() external view returns (TradeLimitParameters memory);
  function varianceFeeParams() external view returns (VarianceFeeParameters memory);

  function ivImpactForTrade(
    IOptionMarket.TradeParameters memory trade,
    uint boardBaseIv,
    uint strikeSkew
  ) external view returns (uint newBaseIv, uint newSkew);

  function getTradeResult(
    IOptionMarket.TradeParameters memory trade,
    IOptionGreekCache.TradePricing memory pricing,
    uint newBaseIv,
    uint newSkew
  ) external view returns (TradeResult memory tradeResult);
  
  function getTimeWeightedFee(
    uint expiry,
    uint pointA,
    uint pointB,
    uint coefficient
  ) external view returns (uint timeWeightedFee);

  function getVegaUtilFee(IOptionMarket.TradeParameters memory trade, IOptionGreekCache.TradePricing memory pricing)
    external
    view
    returns (VegaUtilFeeComponents memory vegaUtilFeeComponents);

  function getVarianceFee(
    IOptionMarket.TradeParameters memory trade,
    IOptionGreekCache.TradePricing memory pricing,
    uint skew
  ) external view returns (VarianceFeeComponents memory varianceFeeComponents);

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  function getPricingParams() external view returns (PricingParameters memory pricingParameters);

  function getTradeLimitParams() external view returns (TradeLimitParameters memory tradeLimitParameters);

  function getVarianceFeeParams() external view returns (VarianceFeeParameters memory varianceFeeParameters);

  ////////////
  // Events //
  ////////////

  event PricingParametersSet(PricingParameters pricingParams);
  event TradeLimitParametersSet(TradeLimitParameters tradeLimitParams);
  event VarianceFeeParametersSet(VarianceFeeParameters varianceFeeParams);

  ////////////
  // Errors //
  ////////////
  // Admin
  error InvalidTradeLimitParameters(address thrower, TradeLimitParameters tradeLimitParams);
  error InvalidPricingParameters(address thrower, PricingParameters pricingParams);

  // Trade limitations
  error TradingCutoffReached(address thrower, uint tradingCutoff, uint boardExpiry, uint currentTime);
  error ForceCloseSkewOutOfRange(address thrower, bool isBuy, uint newSkew, uint minSkew, uint maxSkew);
  error VolSkewOrBaseIvOutsideOfTradingBounds(
    address thrower,
    bool isBuy,
    VolComponents currentVol,
    VolComponents newVol,
    VolComponents tradeBounds
  );
  error TradeDeltaOutOfRange(address thrower, int strikeCallDelta, int minDelta, int maxDelta);
  error ForceCloseDeltaOutOfRange(address thrower, int strikeCallDelta, int minDelta, int maxDelta);

  // Access
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
  function getAddress(bytes32 name) external view returns (address);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface ISynthetix {
  function exchange(
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);

  function exchangeOnBehalfWithTracking(
    address exchangeForAddress,
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey,
    address rewardAddress,
    bytes32 trackingCode
  ) external returns (uint amountReceived);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
  function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
    external
    view
    returns (uint exchangeFeeRate);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

import "./AbstractOwned.sol";

/**
 * @title Owned
 * @author Synthetix
 * @dev Slightly modified Synthetix owned contract, so that first owner is msg.sender
 * @dev https://docs.synthetix.io/contracts/source/contracts/owned
 */
contract Owned is AbstractOwned {
  constructor() {
    owner = msg.sender;
    emit OwnerChanged(address(0), msg.sender);
  }
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface IFeeCounter {
  function trackFee(
    address market,
    address trader,
    uint amount,
    uint totalCost,
    uint totalFee
  ) external;
}

//SPDX-License-Identifier: MIT
//
//Copyright (c) 2019 Synthetix
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

pragma solidity ^0.8.9;

/**
 * @title Owned
 * @author Synthetix
 * @dev Synthetix owned contract without constructor and custom errors
 * @dev https://docs.synthetix.io/contracts/source/contracts/owned
 */
abstract contract AbstractOwned {
  address public owner;
  address public nominatedOwner;

  function nominateNewOwner(address _owner) external onlyOwner {
    nominatedOwner = _owner;
    emit OwnerNominated(_owner);
  }

  function acceptOwnership() external {
    if (msg.sender != nominatedOwner) {
      revert OnlyNominatedOwner(address(this), msg.sender, nominatedOwner);
    }
    emit OwnerChanged(owner, nominatedOwner);
    owner = nominatedOwner;
    nominatedOwner = address(0);
  }

  modifier onlyOwner() {
    _onlyOwner();
    _;
  }

  function _onlyOwner() private view {
    if (msg.sender != owner) {
      revert OnlyOwner(address(this), msg.sender, owner);
    }
  }

  event OwnerNominated(address newOwner);
  event OwnerChanged(address oldOwner, address newOwner);

  ////////////
  // Errors //
  ////////////
  error OnlyOwner(address thrower, address caller, address owner);
  error OnlyNominatedOwner(address thrower, address caller, address nominatedOwner);
}