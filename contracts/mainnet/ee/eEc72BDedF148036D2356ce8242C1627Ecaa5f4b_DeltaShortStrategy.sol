// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// standard strategy interface
import "../interfaces/IStrategy.sol";

// Libraries
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StrandsLyraVault} from "../core/StrandsLyraVault.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import  "@lyrafinance/protocol/contracts/OptionToken.sol";
import {OwnableAdmins} from "../core/OwnableAdmins.sol";
import "hardhat/console.sol";

// StrategyBase to inherit
import {StrategyBase} from "./StrategyBase.sol";

contract DeltaShortStrategy is StrategyBase, IStrategy,OwnableAdmins {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  // Example parameters for a delta short strategy
  struct DeltaShortStrategyDetail {
    uint minTimeToExpiry; // minimum board expiry
    uint maxTimeToExpiry; // maximum board expiry
    int targetDelta; // ideal option delta to trade
    uint maxDeltaGap; // max diff between targetDelta and option delta
    uint minVol; // min option volatility required
    uint maxVol; // max option volatility required
    uint minTradeInterval; // min seconds between StrandsLyraVault.trade() calls
    uint maxVolVariance; // max deviation from GWAV vol and option volatility
    uint gwavPeriod; // gwav period used when calculating GWAV vol
    uint collatBuffer; // multiple of vaultAdapter.minCollateral(): 1.1 -> 110% * minCollat
    uint collatPercent; // partial collateral: 0.9 -> 90% * fullCollat
  }

  DeltaShortStrategyDetail public strategyDetail;
  uint public roundEnds;

  ///////////
  // ADMIN //
  ///////////

  constructor(StrandsLyraVault _vault, OptionType _optionType) StrategyBase(_vault, _optionType) {}

  /**
   * @dev update the strategy detail for the new round.
   */
  function setStrategyDetail(DeltaShortStrategyDetail memory _deltaStrategy) external onlyAdmins {
    strategyDetail = _deltaStrategy;
  }

  /**
   * @dev set the board id that will be traded for the next round
   * @param boardId lyra board Id.
   */
  function setBoard(uint boardId) external onlyVault returns (uint){
    Board memory board = _getBoard(boardId);
    require(_isValidExpiry(board.expiry), "invalid board");
    roundEnds=board.expiry;
    return roundEnds;
  }

  ///////////////////
  // VAULT ACTIONS //
  ///////////////////

  /**
   * @dev convert premium in quote asset into collateral asset and send it back to the vault.
   */
  function returnFundsAndClearStrikes() external onlyVault {
    // exchange asset back to collateral asset and send it back to the vault
    _returnFundsToVault();

    // keep internal storage data on old strikes and positions ids
    _clearAllActiveStrikes();
  }

  /**
   * @notice Sell a fixed amount of options and collect premium
   * @dev the vault should pass in a strike id, and the strategy would verify if the strike is valid on-chain.
   * @param strikeId lyra strikeId to trade
   * @param lyraRewardRecipient address to receive trading reward. This need to be whitelisted
   * @return positionId
   * @return premiumReceived
   */
  function doTrade(uint strikeId, uint sellAmount,address lyraRewardRecipient)
    external
    onlyVault
    returns (
      uint positionId,
      uint premiumReceived,
      uint collateralToAdd
    )
  {
    // validate trade
    require(
      lastTradeTimestamp[strikeId] + strategyDetail.minTradeInterval <= block.timestamp,
      "min time interval not passed"
    );
    require(_isValidVolVariance(strikeId), "vol variance exceeded");

    Strike memory strike = _getStrikes(_toDynamic(strikeId))[0];
    require(isValidStrike(strike), "invalid strike");

    uint setCollateralTo;
    (collateralToAdd, setCollateralTo) = getRequiredCollateral(strike, sellAmount);

    require(
      collateralAsset.transferFrom(address(vault), address(this), collateralToAdd),
      "collateral transfer from vault failed");

    (positionId, premiumReceived) = _sellStrike(strike, sellAmount, setCollateralTo, lyraRewardRecipient);
  }

 
  function getRequiredCollateral(Strike memory strike, uint sellAmount)
    public
    view
    returns (uint collateralToAdd, uint setCollateralTo)
  {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();

    // get existing position info if active
    uint existingAmount = 0;
    uint existingCollateral = 0;
    if (_isActiveStrike(strike.id)) {
      OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strike.id]))[0];
      existingCollateral = position.collateral;
      existingAmount = position.amount;
    }

    // gets minBufferCollat for the whole position
    uint minBufferCollateral = _getBufferCollateral(
      strike.strikePrice,
      strike.expiry,
      exchangeParams.spotPrice,
      existingAmount + sellAmount
    );

    // get targetCollat for this trade instance
    // prevents vault from adding excess collat just to meet targetCollat
    uint targetCollat = existingCollateral +
      _getFullCollateral(strike.strikePrice, sellAmount).multiplyDecimal(strategyDetail.collatPercent);

    // if excess collateral, keep in position to encourage more option selling
    setCollateralTo = _max(_max(minBufferCollateral, targetCollat), existingCollateral);

    // existingCollateral is never > setCollateralTo
    collateralToAdd = setCollateralTo - existingCollateral;
  }

  /**
   * @dev perform the trade
   * @param strike strike detail
   * @param setCollateralTo target collateral amount
   * @param lyraRewardRecipient address to receive lyra trading reward
   * @return positionId
   * @return premiumReceived
   */
  function _sellStrike(
    Strike memory strike,
    uint sellAmount,
    uint setCollateralTo,
    address lyraRewardRecipient
  ) internal returns (uint, uint) {
    // get minimum expected premium based on minIv
    uint minExpectedPremium = _getPremiumLimit(strike, strategyDetail.minVol, sellAmount);
    // perform trade
    TradeResult memory result = _openPosition(
      TradeInputParameters({
        strikeId: strike.id,
        positionId: strikeToPositionId[strike.id],
        iterations: 3,
        optionType: optionType,
        amount: sellAmount,
        setCollateralTo: setCollateralTo,
        minTotalCost: minExpectedPremium,
        maxTotalCost: type(uint).max,
        rewardRecipient: lyraRewardRecipient // set to zero address if don't want to wait for whitelist
      })
    );
    lastTradeTimestamp[strike.id] = block.timestamp;

    // update active strikes
    _addActiveStrike(strike.id, result.positionId);

    require(result.totalCost >= minExpectedPremium, "premium received is below min expected premium");

    return (result.positionId, result.totalCost);
  }

  function reducePosition(
    uint positionId,
    uint closeAmount,
    address lyraRewardRecipient
  ) external onlyVault {
    OptionPosition memory position = _getPositions(_toDynamic(positionId))[0];
    Strike memory strike = _getStrikes(_toDynamic(position.strikeId))[0];

    require(strikeToPositionId[position.strikeId] == positionId, "invalid positionId");

    // closes excess position with premium balance
    uint maxExpectedPremium = _getPremiumLimit(strike, strategyDetail.maxVol, closeAmount);
    _formatedCloseOrForceClosePosition(position, closeAmount, 0, maxExpectedPremium, lyraRewardRecipient);

    // return closed collateral amount
    if (_isBaseCollat()) {
      uint currentBal = baseAsset.balanceOf(address(this));
      baseAsset.transfer(address(vault), currentBal);
    } else {
      // quote collateral
      quoteAsset.transfer(address(vault), closeAmount);
    }
  }

  /**
   * @dev close all outstanding positions regardless of collat and send funds back to vault
   */
  function emergencyCloseAll(address lyraRewardRecipient) external onlyVault {
    // the vault might not hold enough sUSD to close all positions, will need someone to tapup before doing so.
    for (uint i = 0; i < activeStrikeIds.length; i++) {
      uint strikeId = activeStrikeIds[i];
      if (strikeId==0) continue;

      OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strikeId]))[0];
      console.log("positionId=",position.positionId);
      // revert if position state is not settled
      _formatedCloseOrForceClosePosition(position, position.amount, 0, type(uint).max, lyraRewardRecipient);

      delete strikeToPositionId[strikeId];
      delete lastTradeTimestamp[strikeId];
    }
    _clearAllActiveStrikes();
    _returnFundsToVault();
  }


  function hasOpenPosition() external view returns (bool) {
    for (uint i = 0; i < activeStrikeIds.length; i++) {
        uint strikeId = activeStrikeIds[i];
        OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strikeId]))[0];
        if (position.state== PositionState.ACTIVE) return true;
    }
    return false;
  }

  /**
   * @dev calculates the position amount required to stay above the buffer collateral
   */
  function getAllowedCloseAmount(
    OptionPosition memory position,
    uint strikePrice,
    uint strikeExpiry
  ) public view returns (uint closeAmount) {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    uint minCollatPerAmount = _getBufferCollateral(strikePrice, strikeExpiry, exchangeParams.spotPrice, 1e18);

    closeAmount = position.collateral < minCollatPerAmount.multiplyDecimal(position.amount)
      ? position.amount - position.collateral.divideDecimal(minCollatPerAmount)
      : 0;
  }

  /////////////////////////////
  // Trade Parameter Helpers //
  /////////////////////////////

  function _getFullCollateral(uint strikePrice, uint amount) internal view returns (uint fullCollat) {
    // calculate required collat based on collatBuffer and collatPercent
    fullCollat = _isBaseCollat() ? amount : amount.multiplyDecimal(strikePrice);
  }

  /**
   * @dev get amount of collateral needed for shorting {amount} of strike, according to the strategy
   */
  function _getBufferCollateral(
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) internal view returns (uint) {
    uint minCollat = _getMinCollateral(optionType, strikePrice, expiry, spotPrice, amount);
    uint minCollatWithBuffer = minCollat.multiplyDecimal(strategyDetail.collatBuffer);

    uint fullCollat = _getFullCollateral(strikePrice, amount);

    return _min(minCollatWithBuffer, fullCollat);
  }

  /////////////////
  // Validation ///
  /////////////////

  /**
   * @dev verify if the strike is valid for the strategy
   * @return isValid true if vol is withint [minVol, maxVol] and delta is within targetDelta +- maxDeltaGap
   */
  function isValidStrike(Strike memory strike) public view returns (bool isValid) {
    if (roundEnds != strike.expiry) {
      console.log("strike expiry doesnt match board expiry");
      return false;
    }

    uint[] memory strikeId = _toDynamic(strike.id);
    uint vol = _getVols(strikeId)[0];
    int callDelta = _getDeltas(strikeId)[0];
    int delta = _isCall() ? callDelta : callDelta - SignedDecimalMath.UNIT;
    uint deltaGap = _abs(strategyDetail.targetDelta - delta);

    if (deltaGap >= strategyDetail.maxDeltaGap) {
      console.log("callDelta=%s/100",uint(callDelta)/10**16);
      console.log("deltaGap=%s/100",deltaGap/10**16);
      console.log("strategyDetail.maxDeltaGap=%s/100",strategyDetail.maxDeltaGap/10**16);  
    }

    if (vol < strategyDetail.minVol || vol > strategyDetail.maxVol) {
      console.log("vol for strike=%s/100",vol/10**16);
      console.log("strategyDetail.maxVol=%s/100",strategyDetail.maxVol/10**16);
      console.log("strategyDetail.minVol=%s/100",strategyDetail.minVol/10**16);
    }

    return vol >= strategyDetail.minVol && vol <= strategyDetail.maxVol && deltaGap < strategyDetail.maxDeltaGap;
  }

  /**
   * @dev Check if the vol variance for the given strike is within certain range
   */
  function _isValidVolVariance(uint strikeId) internal view returns (bool isValid) {
    uint volGWAV = _volGWAV(strikeId, strategyDetail.gwavPeriod);
    uint volSpot = _getVols(_toDynamic(strikeId))[0];

    uint volDiff = (volGWAV >= volSpot) ? volGWAV - volSpot : volSpot - volGWAV;

    return isValid = volDiff < strategyDetail.maxVolVariance;
  }

  /**
   * @dev check if the expiry of the board is valid according to the strategy
   */
  function _isValidExpiry(uint expiry) public view returns (bool isValid) {
    uint secondsToExpiry = _getSecondsToExpiry(expiry);
    // todo: `minTimeToExpiry` and `maxTimeToExpiry` must be changed prior to
    //       the start of a new round
    isValid = (secondsToExpiry >= strategyDetail.minTimeToExpiry && secondsToExpiry <= strategyDetail.maxTimeToExpiry);
  }

}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

interface IStrategy {

  function setBoard(uint boardId) external returns (uint roundEnds);

  function doTrade(uint strikeId, uint sellAmount,address rewardRecipient)
    external
    returns (
      uint positionId,
      uint premium,
      uint collateralAdded
    );

  function reducePosition(
    uint positionId,
    uint closeAmount,
    address rewardRecipient
  ) external;

  function hasOpenPosition() external view returns (bool);

  function emergencyCloseAll(address lyraRewardRecipient) external;

  function returnFundsAndClearStrikes() external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Vault {
  /************************************************
   *  IMMUTABLES & CONSTANTS
   ***********************************************/

  // Fees are 6-decimal places. For example: 20 * 10**6 = 20%
  uint internal constant FEE_MULTIPLIER = 10**6;

  struct VaultParams {
    // Token decimals for vault shares
    uint8 decimals;
    // Vault cap
    uint104 cap;
    // Asset used in Theta / Delta Vault
    address asset;
  }

  struct VaultState {
    // 32 byte slot 1
    //  Current round number. `round` represents the number of `period`s elapsed.
    uint16 round;
    // Amount that is currently locked for the strategy
    uint104 lockedAmount;
    // Amount that was locked for strategy in the previous round
    // used for calculating performance fee deduction
    uint104 lastLockedAmount;
    // locked amount left to be used for collateral;
    uint lockedAmountLeft;
    // 32 byte slot 2
    // Stores the total tally of how much of `asset` there is
    // to be used to mint Vault tokens
    uint128 totalPending;
    // Amount locked for scheduled withdrawals;
    uint128 queuedWithdrawShares;
    // The timestamp next round will be ready to start
    uint nextRoundReadyTimestamp;
    // true if the current round is in progress, false if the round is idle
    bool roundInProgress;
  }

  struct DepositReceipt {
    // Maximum of 65535 rounds. Assuming 1 round is 7 days, maximum is 1256 years.
    uint16 round;
    // Deposit amount, max 20,282,409,603,651 or 20 trillion ETH deposit
    uint104 amount;
    // Unredeemed shares balance
    uint128 unredeemedShares;
  }

  struct Withdrawal {
    // Maximum of 65535 rounds. Assuming 1 round is 7 days, maximum is 1256 years.
    uint16 round;
    // Number of shares withdrawn
    uint128 shares;
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {OptionMarket} from "@lyrafinance/protocol/contracts/OptionMarket.sol";
import {BaseVault} from "./BaseVault.sol";
import {Vault} from "../libraries/Vault.sol";
import {IStrategy} from "../interfaces/IStrategy.sol";
import "hardhat/console.sol";

/// @notice StrandsLyraVault help users run option-selling strategies on Lyra AMM.
contract StrandsLyraVault is BaseVault {
  IERC20 public immutable premiumAsset;
  IERC20 public immutable collateralAsset;
  uint internal roundDelay = 1 minutes;
  IStrategy public strategy;
  address public lyraRewardRecipient;
  uint public roundEnds;

  // Amount locked for scheduled withdrawals last week;
  uint public lastQueuedWithdrawAmount;
  // % of funds to be used for weekly option purchase
  uint public optionAllocation;

  event StrategyUpdated(address strategy);

  event Trade(address user, uint positionId, uint premium, uint capitalUsed);

  event RoundStarted(uint16 roundId, uint104 lockAmount,uint newPricePerShare,uint roundEnds);

  event RoundClosed(uint16 roundId, uint104 lockAmount);

  constructor(
    address _susd,
    address _feeRecipient,
    uint _roundDuration,
    string memory _tokenName,
    string memory _tokenSymbol,
    Vault.VaultParams memory _vaultParams
  ) BaseVault(_feeRecipient, _roundDuration, _tokenName, _tokenSymbol, _vaultParams) {
    premiumAsset = IERC20(_susd);
    collateralAsset = IERC20(_vaultParams.asset);
  }

  /// @dev set strategy contract. This function can only be called by owner.
  /// @param _strategy new strategy contract address
  function setStrategy(address _strategy) external onlyAdmins {
    if (address(strategy) != address(0)) {
      collateralAsset.approve(address(strategy), 0);
    }
    strategy = IStrategy(_strategy);
    collateralAsset.approve(_strategy, type(uint).max);
    emit StrategyUpdated(_strategy);
  }

  /// @param strikeId the strike id to sell
  function trade(uint strikeId,uint sellAmount) external onlyAdmins {
    require(vaultState.roundInProgress, "round closed");

    require(sellAmount<=vaultState.lockedAmountLeft, "not enough left to complete trade");
    // perform trade through strategy
    (uint positionId, uint premiumReceived, uint capitalUsed) = strategy.doTrade(strikeId, sellAmount, lyraRewardRecipient);

    // update the remaining locked amount
    vaultState.lockedAmountLeft = vaultState.lockedAmountLeft - capitalUsed;
    
    // todo: udpate events
    emit Trade(msg.sender, positionId, premiumReceived, capitalUsed);
  }

  /// @dev anyone close part of the position with premium made by the strategy if a position is dangerous
  /// @param positionId the positiion to close
  function reducePosition(uint positionId, uint closeAmount) external {
    strategy.reducePosition(positionId, closeAmount, lyraRewardRecipient);
    vaultState.lockedAmountLeft = vaultState.lockedAmountLeft + closeAmount;
    console.log("vaultState.lockedAmountLeft after reducePosition",vaultState.lockedAmountLeft);
  }

  /// @dev close the current round, enable user to deposit for the next round
  function closeRound() external {
    require(!strategy.hasOpenPosition(),"still has activeStrikeIds");
    require(vaultState.roundInProgress, "round closed");

    uint104 lockAmount = vaultState.lockedAmount;
    vaultState.lastLockedAmount = lockAmount;
    vaultState.lockedAmountLeft = 0;
    vaultState.lockedAmount = 0;
    vaultState.nextRoundReadyTimestamp = block.timestamp + roundDelay;
    vaultState.roundInProgress = false;

    // won't be able to close if positions are not settled
    strategy.returnFundsAndClearStrikes();

    emit RoundClosed(vaultState.round, lockAmount);
  }

  /// @dev Close the current round, enable user to deposit for the next round
  //       Can call multiple times before round starts to close all positions
  function emergencyCloseRound() external onlyAdmins {
    require(vaultState.roundInProgress, "round closed");

    uint104 lockAmount = vaultState.lockedAmount;
    vaultState.lastLockedAmount = lockAmount;
    vaultState.lockedAmountLeft = 0;
    vaultState.lockedAmount = 0;
    vaultState.nextRoundReadyTimestamp = block.timestamp + roundDelay;
    vaultState.roundInProgress = false;

    strategy.emergencyCloseAll(lyraRewardRecipient);
    emit RoundClosed(vaultState.round, lockAmount);
  }

  /// @notice start the next round
  /// @param boardId board id (asset + expiry) for next round.
  function startNextRound(uint boardId) external onlyAdmins {
    require(!vaultState.roundInProgress, "round in progress");
    require(block.timestamp > vaultState.nextRoundReadyTimestamp, "Delay between rounds not elapsed");

    roundEnds = strategy.setBoard(boardId);

    (uint lockedBalance, uint queuedWithdrawAmount, uint newPricePerShare) = _rollToNextRound();

    vaultState.lockedAmount = uint104(lockedBalance);
    vaultState.lockedAmountLeft = lockedBalance;
    vaultState.roundInProgress = true;
    lastQueuedWithdrawAmount = queuedWithdrawAmount;

    emit RoundStarted(vaultState.round, uint104(lockedBalance),newPricePerShare,roundEnds);
  }

  /// @notice set new address to receive Lyra trading reward on behalf of the vault
  /// @param recipient recipient address
  function setLyraRewardRecipient(address recipient) external onlyAdmins {
    lyraRewardRecipient = recipient;
  }

  /// @notice set minimal time between stop and start of rounds
  /// @param _roundDelay in seconds
  function setRoundDelay(uint _roundDelay) external onlyAdmins {
    roundDelay = _roundDelay;
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";

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
abstract contract OwnableAdmins {
  address[] private _admins;

  event AdminAdded(address indexed newAdmin);
  event AdminRemoved(address indexed oldAdmin);

  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  constructor() {
    _addAdmin(msg.sender);
  }

  modifier onlyAdmins() {
    require(isAdmin(address(msg.sender)), "Caller is not Admin");
    _;
  }

  function isAdmin(address _Admin) public view virtual returns (bool) {
    uint8 numOfAdmins=uint8(_admins.length);
    for (uint8 i = 0; i < numOfAdmins;) {
      if (_admins[i] == _Admin) return true;
      unchecked {i++;}
    }
    return false;
  }

  function removeAdmin(address oldAdmin) public virtual onlyAdmins {
    uint8 numOfAdmins=uint8(_admins.length);
    for (uint8 i = 0; i < numOfAdmins;) {
      if (_admins[i] == oldAdmin) {
        _admins[i] = _admins[numOfAdmins-1];
        _admins.pop();
        break;
      }
      unchecked {i++;}
    }
    emit AdminRemoved(oldAdmin);
  }

  function addAdmin(address newAdmin) public virtual onlyAdmins {
    uint8 numOfAdmins=uint8(_admins.length);
    for (uint8 i = 0; i < numOfAdmins; i++) {
      if (_admins[i] == newAdmin) return;
      unchecked {i++;}
    }
    _addAdmin(newAdmin);
  }

  function _addAdmin(address newAdmin) internal virtual {
    _admins.push(newAdmin);
    emit AdminAdded(newAdmin);
  }
}

//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Lyra
import {LyraAdapter} from "@lyrafinance/protocol/contracts/periphery/LyraAdapter.sol";

// Libraries
import {Vault} from "../libraries/Vault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StrandsLyraVault} from "../core/StrandsLyraVault.sol";
import {DecimalMath} from "@lyrafinance/protocol/contracts/synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "@lyrafinance/protocol/contracts/synthetix/SignedDecimalMath.sol";
import "hardhat/console.sol";

contract StrategyBase is LyraAdapter {
  using DecimalMath for uint;
  using SignedDecimalMath for int;

  StrandsLyraVault public immutable vault;
  OptionType public immutable optionType;

  /// @dev asset used as collateral in AMM to sell. Should be the same as vault asset
  IERC20 public collateralAsset;

  mapping(uint => uint) public lastTradeTimestamp;

  uint[] public activeStrikeIds;
  mapping(uint => uint) public strikeToPositionId;

  ///////////
  // ADMIN //
  ///////////

  modifier onlyVault() virtual {
    require(msg.sender == address(vault), "only Vault");
    _;
  }

  constructor(StrandsLyraVault _vault, OptionType _optionType) LyraAdapter() {
    vault = _vault;
    optionType = _optionType;
  }

  function initAdapter(
    address _lyraRegistry,
    address _optionMarket,
    address _curveSwap,
    address _feeCounter
  ) external onlyOwner {
    // set addresses for LyraAdapter
    setLyraAddresses(_lyraRegistry, _optionMarket, _curveSwap, _feeCounter);

    quoteAsset.approve(address(vault), type(uint).max);
    baseAsset.approve(address(vault), type(uint).max);
    collateralAsset = _isBaseCollat() ? IERC20(address(baseAsset)) : IERC20(address(quoteAsset));
  }

  ///////////////////
  // VAULT ACTIONS //
  ///////////////////

  /**
   * @dev exchange asset back to collateral asset and send it back to the vault
   * @dev override this function if you want to customize asset management flow
   */
  function _returnFundsToVault() internal virtual {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    uint quoteBal = quoteAsset.balanceOf(address(this));

    if (_isBaseCollat()) {
      // exchange quote asset to base asset, and send base asset back to vault
      uint baseBal = baseAsset.balanceOf(address(this));
      uint minQuoteExpected = quoteBal.divideDecimal(exchangeParams.spotPrice).multiplyDecimal(
        DecimalMath.UNIT - exchangeParams.baseQuoteFeeRate
      );
      uint baseReceived = _exchangeFromExactQuote(quoteBal, minQuoteExpected);
      require(baseAsset.transfer(address(vault), baseBal + baseReceived), "failed to return funds from strategy");
    } else {
      // send quote balance directly
      require(quoteAsset.transfer(address(vault), quoteBal), "failed to return funds from strategy");
    }
  }

  /////////////////////////////
  // Trade Parameter Helpers //
  /////////////////////////////

  /**
   * @dev Automatically decide between close and forceClose
   * depending on whether deltaCutoff or tradingCutoff are crossed
   */

  function _formatedCloseOrForceClosePosition(
    OptionPosition memory position,
    uint closeAmount,
    uint minTotalCost,
    uint maxTotalCost,
    address lyraRewardRecipient
  ) internal {
    // closes excess position with premium balance

    uint setCollateralTo;
    // if it's a full close, take out our collateral as well.
    if (position.amount==closeAmount) {
      delete strikeToPositionId[position.strikeId];
      for (uint i = 0; i < activeStrikeIds.length; i++) {
        if (activeStrikeIds[i]==position.strikeId) delete activeStrikeIds[i];
      }
    } else {
      setCollateralTo=position.collateral-closeAmount;
    }

    TradeInputParameters memory tradeParams = TradeInputParameters({
      strikeId: position.strikeId,
      positionId: position.positionId,
      iterations: 3,
      optionType: optionType,
      amount: closeAmount,
      setCollateralTo: setCollateralTo,
      minTotalCost: minTotalCost,
      maxTotalCost: maxTotalCost,
      rewardRecipient: lyraRewardRecipient // set to zero address if don't want to wait for whitelist
    });

    // if forceClosed, will pay less competitive price to close position but bypasses Lyra delta/trading cutoffs
    TradeResult memory result = _closeOrForceClosePosition(tradeParams);
    require(result.totalCost <= maxTotalCost, "premium paid is above max expected premium");
  }

  /**
   * @dev get minimum premium that the vault should receive.
   * param listingId lyra option listing id
   * param size size of trade in Lyra standard sizes
   */
  function _getPremiumLimit(
    Strike memory strike,
    uint vol,
    uint size
  ) internal view returns (uint limitPremium) {
    ExchangeRateParams memory exchangeParams = _getExchangeParams();
    (uint callPremium, uint putPremium) = _getPurePremium(
      _getSecondsToExpiry(strike.expiry),
      vol,
      exchangeParams.spotPrice,
      strike.strikePrice
    );

    limitPremium = _isCall() ? callPremium.multiplyDecimal(size) : putPremium.multiplyDecimal(size);
  }

  //////////////////////////////
  // Active Strike Management //
  //////////////////////////////

  /**
   * @dev add strike id to activeStrikeIds array
   */
  function _addActiveStrike(uint strikeId, uint tradedPositionId) internal {
    if (!_isActiveStrike(strikeId)) {
      strikeToPositionId[strikeId] = tradedPositionId;
      activeStrikeIds.push(strikeId);
    }
  }

  /**
   * @dev add the last traded timestamp for a specific strike.
   */
  function _setLastTradedAt(uint strikeId, uint timestamp) internal {
    lastTradeTimestamp[strikeId] = timestamp;
  }

  /**
   * @dev remove position data opened in the current round.
   * this can only be called after the position is settled by lyra
   **/
  function _clearAllActiveStrikes() internal {
    if (activeStrikeIds.length != 0) {
      for (uint i = 0; i < activeStrikeIds.length; i++) {
        uint strikeId = activeStrikeIds[i];
        OptionPosition memory position = _getPositions(_toDynamic(strikeToPositionId[strikeId]))[0];
        // revert if position state is not settled
        require(position.state != PositionState.ACTIVE, "cannot clear active position");
        delete strikeToPositionId[strikeId];
        delete lastTradeTimestamp[strikeId];
      }
      delete activeStrikeIds;
    }
  }

  function _isActiveStrike(uint strikeId) internal view returns (bool isActive) {
    isActive = strikeToPositionId[strikeId] != 0;
  }

  //////////
  // Misc //
  //////////


  function getDeltas(uint[] memory strikeIds) external view returns (int[] memory callDeltas) {
    return _getDeltas(strikeIds);
  }

  function _isBaseCollat() internal view returns (bool isBase) {
    isBase = (optionType == OptionType.SHORT_CALL_BASE) ? true : false;
  }

  function _isCall() internal view returns (bool isCall) {
    isCall = (optionType == OptionType.SHORT_PUT_QUOTE || optionType == OptionType.LONG_PUT) ? false : true;
  }

  function _getSecondsToExpiry(uint expiry) internal view returns (uint) {
    require(block.timestamp <= expiry, "timestamp expired");
    return expiry - block.timestamp;
  }

  function _abs(int val) internal pure returns (uint) {
    return val >= 0 ? uint(val) : uint(-val);
  }

  function _min(uint x, uint y) internal pure returns (uint) {
    return (x < y) ? x : y;
  }

  function _max(uint x, uint y) internal pure returns (uint) {
    return (x > y) ? x : y;
  }

  // temporary fix - eth core devs promised Q2 2022 fix
  function _toDynamic(uint val) internal pure returns (uint[] memory dynamicArray) {
    dynamicArray = new uint[](1);
    dynamicArray[0] = val;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 <0.9.0;

library console {
	address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

	function _sendLogPayload(bytes memory payload) private view {
		uint256 payloadLength = payload.length;
		address consoleAddress = CONSOLE_ADDRESS;
		assembly {
			let payloadStart := add(payload, 32)
			let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
		}
	}

	function log() internal view {
		_sendLogPayload(abi.encodeWithSignature("log()"));
	}

	function logInt(int256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(int256)", p0));
	}

	function logUint(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function logString(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function logBool(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function logAddress(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function logBytes(bytes memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
	}

	function logBytes1(bytes1 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes1)", p0));
	}

	function logBytes2(bytes2 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes2)", p0));
	}

	function logBytes3(bytes3 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes3)", p0));
	}

	function logBytes4(bytes4 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes4)", p0));
	}

	function logBytes5(bytes5 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes5)", p0));
	}

	function logBytes6(bytes6 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes6)", p0));
	}

	function logBytes7(bytes7 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes7)", p0));
	}

	function logBytes8(bytes8 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes8)", p0));
	}

	function logBytes9(bytes9 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes9)", p0));
	}

	function logBytes10(bytes10 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes10)", p0));
	}

	function logBytes11(bytes11 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes11)", p0));
	}

	function logBytes12(bytes12 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes12)", p0));
	}

	function logBytes13(bytes13 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes13)", p0));
	}

	function logBytes14(bytes14 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes14)", p0));
	}

	function logBytes15(bytes15 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes15)", p0));
	}

	function logBytes16(bytes16 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes16)", p0));
	}

	function logBytes17(bytes17 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes17)", p0));
	}

	function logBytes18(bytes18 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes18)", p0));
	}

	function logBytes19(bytes19 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes19)", p0));
	}

	function logBytes20(bytes20 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes20)", p0));
	}

	function logBytes21(bytes21 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes21)", p0));
	}

	function logBytes22(bytes22 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes22)", p0));
	}

	function logBytes23(bytes23 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes23)", p0));
	}

	function logBytes24(bytes24 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes24)", p0));
	}

	function logBytes25(bytes25 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes25)", p0));
	}

	function logBytes26(bytes26 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes26)", p0));
	}

	function logBytes27(bytes27 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes27)", p0));
	}

	function logBytes28(bytes28 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes28)", p0));
	}

	function logBytes29(bytes29 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes29)", p0));
	}

	function logBytes30(bytes30 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes30)", p0));
	}

	function logBytes31(bytes31 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes31)", p0));
	}

	function logBytes32(bytes32 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bytes32)", p0));
	}

	function log(uint256 p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256)", p0));
	}

	function log(string memory p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string)", p0));
	}

	function log(bool p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool)", p0));
	}

	function log(address p0) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address)", p0));
	}

	function log(uint256 p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256)", p0, p1));
	}

	function log(uint256 p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string)", p0, p1));
	}

	function log(uint256 p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool)", p0, p1));
	}

	function log(uint256 p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address)", p0, p1));
	}

	function log(string memory p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256)", p0, p1));
	}

	function log(string memory p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string)", p0, p1));
	}

	function log(string memory p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool)", p0, p1));
	}

	function log(string memory p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address)", p0, p1));
	}

	function log(bool p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256)", p0, p1));
	}

	function log(bool p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string)", p0, p1));
	}

	function log(bool p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool)", p0, p1));
	}

	function log(bool p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address)", p0, p1));
	}

	function log(address p0, uint256 p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256)", p0, p1));
	}

	function log(address p0, string memory p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string)", p0, p1));
	}

	function log(address p0, bool p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool)", p0, p1));
	}

	function log(address p0, address p1) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address)", p0, p1));
	}

	function log(uint256 p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool)", p0, p1, p2));
	}

	function log(uint256 p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool)", p0, p1, p2));
	}

	function log(uint256 p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool)", p0, p1, p2));
	}

	function log(uint256 p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool)", p0, p1, p2));
	}

	function log(string memory p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool)", p0, p1, p2));
	}

	function log(string memory p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool)", p0, p1, p2));
	}

	function log(string memory p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address)", p0, p1, p2));
	}

	function log(string memory p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256)", p0, p1, p2));
	}

	function log(string memory p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string)", p0, p1, p2));
	}

	function log(string memory p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool)", p0, p1, p2));
	}

	function log(string memory p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool)", p0, p1, p2));
	}

	function log(bool p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool)", p0, p1, p2));
	}

	function log(bool p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address)", p0, p1, p2));
	}

	function log(bool p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256)", p0, p1, p2));
	}

	function log(bool p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string)", p0, p1, p2));
	}

	function log(bool p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool)", p0, p1, p2));
	}

	function log(bool p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address)", p0, p1, p2));
	}

	function log(bool p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256)", p0, p1, p2));
	}

	function log(bool p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string)", p0, p1, p2));
	}

	function log(bool p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool)", p0, p1, p2));
	}

	function log(bool p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool)", p0, p1, p2));
	}

	function log(address p0, uint256 p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address)", p0, p1, p2));
	}

	function log(address p0, string memory p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256)", p0, p1, p2));
	}

	function log(address p0, string memory p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string)", p0, p1, p2));
	}

	function log(address p0, string memory p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool)", p0, p1, p2));
	}

	function log(address p0, string memory p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address)", p0, p1, p2));
	}

	function log(address p0, bool p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256)", p0, p1, p2));
	}

	function log(address p0, bool p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string)", p0, p1, p2));
	}

	function log(address p0, bool p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool)", p0, p1, p2));
	}

	function log(address p0, bool p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address)", p0, p1, p2));
	}

	function log(address p0, address p1, uint256 p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256)", p0, p1, p2));
	}

	function log(address p0, address p1, string memory p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string)", p0, p1, p2));
	}

	function log(address p0, address p1, bool p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool)", p0, p1, p2));
	}

	function log(address p0, address p1, address p2) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address)", p0, p1, p2));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,string,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,bool,address,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,string,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,bool,address)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,string)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,bool)", p0, p1, p2, p3));
	}

	function log(uint256 p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(uint256,address,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,string,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,bool,address,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,string,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,bool,address)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,string)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,bool)", p0, p1, p2, p3));
	}

	function log(string memory p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(string,address,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,string,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,bool,address,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,string,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,bool,address)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,string)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,bool)", p0, p1, p2, p3));
	}

	function log(bool p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(bool,address,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, uint256 p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,uint256,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, string memory p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,string,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, bool p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,bool,address,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, uint256 p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,uint256,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, string memory p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,string,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, bool p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,bool,address)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, uint256 p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,uint256)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, string memory p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,string)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, bool p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,bool)", p0, p1, p2, p3));
	}

	function log(address p0, address p1, address p2, address p3) internal view {
		_sendLogPayload(abi.encodeWithSignature("log(address,address,address,address)", p0, p1, p2, p3));
	}

}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";

// Inherited
import "openzeppelin-contracts-4.4.1/token/ERC721/extensions/ERC721Enumerable.sol";
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";
import "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";

// Interfaces
import "./OptionMarket.sol";
import "./SynthetixAdapter.sol";
import "./OptionGreekCache.sol";

/**
 * @title OptionToken
 * @author Lyra
 * @dev Provides a tokenized representation of each trade position including amount of options and collateral.
 */
contract OptionToken is Owned, SimpleInitializeable, ReentrancyGuard, ERC721Enumerable {
  using DecimalMath for uint;

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
    OptionMarket.OptionType optionType;
    uint amount;
    uint collateral;
    PositionState state;
  }

  ///////////////
  // Parameters //
  ///////////////

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

  ///////////////
  // In-memory //
  ///////////////
  struct PositionWithOwner {
    uint positionId;
    uint strikeId;
    OptionMarket.OptionType optionType;
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

  ///////////////
  // Variables //
  ///////////////
  OptionMarket internal optionMarket;
  OptionGreekCache internal greekCache;
  address internal shortCollateral;
  SynthetixAdapter internal synthetixAdapter;

  mapping(uint => OptionPosition) public positions;
  uint public nextId = 1;

  PartialCollateralParameters public partialCollatParams;

  string public baseURI;

  ///////////
  // Setup //
  ///////////

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Owned() {}

  /**
   * @notice Initialise the contract.
   *
   * @param _optionMarket The OptionMarket contract address.
   */
  function init(
    OptionMarket _optionMarket,
    OptionGreekCache _greekCache,
    address _shortCollateral,
    SynthetixAdapter _synthetixAdapter
  ) external onlyOwner initializer {
    optionMarket = _optionMarket;
    greekCache = _greekCache;
    shortCollateral = _shortCollateral;
    synthetixAdapter = _synthetixAdapter;
  }

  ///////////
  // Admin //
  ///////////

  /// @notice set PartialCollateralParameters
  function setPartialCollateralParams(PartialCollateralParameters memory _partialCollatParams) external onlyOwner {
    if (
      _partialCollatParams.penaltyRatio > DecimalMath.UNIT ||
      (_partialCollatParams.liquidatorFeeRatio + _partialCollatParams.smFeeRatio) > DecimalMath.UNIT
    ) {
      revert InvalidPartialCollateralParameters(address(this), _partialCollatParams);
    }

    partialCollatParams = _partialCollatParams;
    emit PartialCollateralParamsSet(partialCollatParams);
  }

  /**
   * @param newURI The new uri definition for the contract.
   */
  function setURI(string memory newURI) external onlyOwner {
    baseURI = newURI;
    emit URISet(baseURI);
  }

  function _baseURI() internal view override returns (string memory) {
    return baseURI;
  }

  /////////////////////////
  // Adjusting positions //
  /////////////////////////

  /**
   * @notice Adjusts position amount and collateral when position is:
   * - opened
   * - closed
   * - forceClosed
   * - liquidated
   *
   * @param trade TradeParameters as defined in OptionMarket.
   * @param strikeId id of strike for adjusted position.
   * @param trader owner of position.
   * @param positionId id of position.
   * @param optionCost totalCost of closing or opening position.
   * @param setCollateralTo final collateral to leave in position.
   * @param isOpen whether order is to increase or decrease position.amount.
   *
   * @return uint positionId of position being adjusted (relevant for new positions)
   * @return pendingCollateral amount of additional quote to receive from msg.sender
   */
  function adjustPosition(
    OptionMarket.TradeParameters memory trade,
    uint strikeId,
    address trader,
    uint positionId,
    uint optionCost,
    uint setCollateralTo,
    bool isOpen
  ) external onlyOptionMarket returns (uint, int pendingCollateral) {
    OptionPosition storage position;
    bool newPosition = false;
    if (positionId == 0) {
      if (!isOpen) {
        revert CannotClosePositionZero(address(this));
      }
      if (trade.amount == 0) {
        revert CannotOpenZeroAmount(address(this));
      }

      positionId = nextId++;
      _mint(trader, positionId);
      position = positions[positionId];

      position.positionId = positionId;
      position.strikeId = strikeId;
      position.optionType = trade.optionType;
      position.state = PositionState.ACTIVE;

      newPosition = true;
    } else {
      position = positions[positionId];
    }

    if (
      position.positionId == 0 ||
      position.state != PositionState.ACTIVE ||
      position.strikeId != strikeId ||
      position.optionType != trade.optionType
    ) {
      revert CannotAdjustInvalidPosition(
        address(this),
        positionId,
        position.positionId == 0,
        position.state != PositionState.ACTIVE,
        position.strikeId != strikeId,
        position.optionType != trade.optionType
      );
    }
    if (trader != ownerOf(position.positionId)) {
      revert OnlyOwnerCanAdjustPosition(address(this), positionId, trader, ownerOf(position.positionId));
    }

    if (isOpen) {
      position.amount += trade.amount;
    } else {
      position.amount -= trade.amount;
    }

    if (position.amount == 0) {
      if (setCollateralTo != 0) {
        revert FullyClosingWithNonZeroSetCollateral(address(this), position.positionId, setCollateralTo);
      }
      // return all collateral to the user if they fully close the position
      pendingCollateral = -(SafeCast.toInt256(position.collateral));
      if (
        trade.optionType == OptionMarket.OptionType.SHORT_CALL_QUOTE ||
        trade.optionType == OptionMarket.OptionType.SHORT_PUT_QUOTE
      ) {
        // Add the optionCost to the inverted collateral (subtract from collateral)
        pendingCollateral += SafeCast.toInt256(optionCost);
      }
      position.collateral = 0;
      position.state = PositionState.CLOSED;
      _burn(position.positionId); // burn tokens that have been closed.
      emit PositionUpdated(position.positionId, trader, PositionUpdatedType.CLOSED, position, block.timestamp);
      return (position.positionId, pendingCollateral);
    }

    if (_isShort(trade.optionType)) {
      uint preCollateral = position.collateral;
      if (trade.optionType != OptionMarket.OptionType.SHORT_CALL_BASE) {
        if (isOpen) {
          preCollateral += optionCost;
        } else {
          // This will only throw if the position is insolvent
          preCollateral -= optionCost;
        }
      }
      pendingCollateral = SafeCast.toInt256(setCollateralTo) - SafeCast.toInt256(preCollateral);
      position.collateral = setCollateralTo;
      if (canLiquidate(position, trade.expiry, trade.strikePrice, trade.exchangeParams.spotPrice)) {
        revert AdjustmentResultsInMinimumCollateralNotBeingMet(address(this), position, trade.exchangeParams.spotPrice);
      }
    }
    // if long, pendingCollateral is 0 - ignore

    emit PositionUpdated(
      position.positionId,
      trader,
      newPosition ? PositionUpdatedType.OPENED : PositionUpdatedType.ADJUSTED,
      position,
      block.timestamp
    );

    return (position.positionId, pendingCollateral);
  }

  /**
   * @notice Only allows increase to position.collateral
   *
   * @param positionId id of position.
   * @param amountCollateral amount of collateral to add to position.
   *
   * @return optionType OptionType of adjusted position
   */
  function addCollateral(uint positionId, uint amountCollateral)
    external
    onlyOptionMarket
    returns (OptionMarket.OptionType optionType)
  {
    OptionPosition storage position = positions[positionId];

    if (position.positionId == 0 || position.state != PositionState.ACTIVE || !_isShort(position.optionType)) {
      revert AddingCollateralToInvalidPosition(
        address(this),
        positionId,
        position.positionId == 0,
        position.state != PositionState.ACTIVE,
        !_isShort(position.optionType)
      );
    }

    _requireStrikeNotExpired(position.strikeId);

    position.collateral += amountCollateral;

    emit PositionUpdated(
      position.positionId,
      ownerOf(positionId),
      PositionUpdatedType.ADJUSTED,
      position,
      block.timestamp
    );

    return position.optionType;
  }

  /**
   * @notice burns and updates position.state when board is settled
   * @dev invalid positions get caught when trying to query owner for event (or in burn)
   *
   * @param positionIds array of position ids to settle
   */
  function settlePositions(uint[] memory positionIds) external onlyShortCollateral {
    uint positionsLength = positionIds.length;
    for (uint i = 0; i < positionsLength; ++i) {
      positions[positionIds[i]].state = PositionState.SETTLED;

      emit PositionUpdated(
        positionIds[i],
        ownerOf(positionIds[i]),
        PositionUpdatedType.SETTLED,
        positions[positionIds[i]],
        block.timestamp
      );

      _burn(positionIds[i]);
    }
  }

  /////////////////
  // Liquidation //
  /////////////////

  /**
   * @notice checks of liquidation is valid, burns liquidation position and determines fee distribution
   * @dev called when 'OptionMarket.liquidatePosition()' is called
   *
   * @param positionId position id to liquidate
   * @param trade TradeParameters as defined in OptionMarket
   * @param totalCost totalCost paid to LiquidityPool from position.collateral (excludes liquidation fees)
   */
  function liquidate(
    uint positionId,
    OptionMarket.TradeParameters memory trade,
    uint totalCost
  ) external onlyOptionMarket returns (LiquidationFees memory liquidationFees) {
    OptionPosition storage position = positions[positionId];

    if (!canLiquidate(position, trade.expiry, trade.strikePrice, trade.exchangeParams.spotPrice)) {
      revert PositionNotLiquidatable(address(this), position, trade.exchangeParams.spotPrice);
    }

    uint convertedMinLiquidationFee = partialCollatParams.minLiquidationFee;
    uint insolvencyMultiplier = DecimalMath.UNIT;
    if (trade.optionType == OptionMarket.OptionType.SHORT_CALL_BASE) {
      totalCost = synthetixAdapter.estimateExchangeToExactQuote(trade.exchangeParams, totalCost);
      convertedMinLiquidationFee = partialCollatParams.minLiquidationFee.divideDecimal(trade.exchangeParams.spotPrice);
      insolvencyMultiplier = trade.exchangeParams.spotPrice;
    }

    position.state = PositionState.LIQUIDATED;

    emit PositionUpdated(
      position.positionId,
      ownerOf(position.positionId),
      PositionUpdatedType.LIQUIDATED,
      position,
      block.timestamp
    );

    _burn(positionId);

    return getLiquidationFees(totalCost, position.collateral, convertedMinLiquidationFee, insolvencyMultiplier);
  }

  /**
   * @notice checks whether position is valid and position.collateral < minimum required collateral
   * @dev useful for estimating liquidatability in different spot/strike/expiry scenarios
   *
   * @param position any OptionPosition struct (does not need to be an existing position)
   * @param expiry expiry of option (does not need to match position.strikeId expiry)
   * @param strikePrice strike price of position
   * @param spotPrice spot price of base
   */
  function canLiquidate(
    OptionPosition memory position,
    uint expiry,
    uint strikePrice,
    uint spotPrice
  ) public view returns (bool) {
    if (!_isShort(position.optionType)) {
      return false;
    }
    if (position.state != PositionState.ACTIVE) {
      return false;
    }

    // Option expiry is checked in optionMarket._doTrade()
    // Will revert if called post expiry
    uint minCollateral = greekCache.getMinCollateral(
      position.optionType,
      strikePrice,
      expiry,
      spotPrice,
      position.amount
    );

    return position.collateral < minCollateral;
  }

  /**
   * @notice gets breakdown of fee distribution during liquidation event
   * @dev useful for estimating fees earned by all parties during liquidation
   *
   * @param gwavPremium totalCost paid to LiquidityPool from position.collateral to close position
   * @param userPositionCollateral total collateral in position
   * @param convertedMinLiquidationFee minimum static liquidation fee (defined in partialCollatParams.minLiquidationFee)
   * @param insolvencyMultiplier used to denominate insolveny in quote in case of base collateral insolvencies
   */
  function getLiquidationFees(
    uint gwavPremium, // quote || base
    uint userPositionCollateral, // quote || base
    uint convertedMinLiquidationFee, // quote || base
    uint insolvencyMultiplier // 1 for quote || spotPrice for base
  ) public view returns (LiquidationFees memory liquidationFees) {
    // User is fully solvent
    uint minOwed = gwavPremium + convertedMinLiquidationFee;
    uint totalCollatPenalty;

    if (userPositionCollateral >= minOwed) {
      uint remainingCollateral = userPositionCollateral - gwavPremium;
      totalCollatPenalty = remainingCollateral.multiplyDecimal(partialCollatParams.penaltyRatio);
      if (totalCollatPenalty < convertedMinLiquidationFee) {
        totalCollatPenalty = convertedMinLiquidationFee;
      }
      liquidationFees.returnCollateral = remainingCollateral - totalCollatPenalty;
    } else {
      // user is insolvent
      liquidationFees.returnCollateral = 0;
      // edge case where short call base collat < minLiquidationFee
      if (userPositionCollateral >= convertedMinLiquidationFee) {
        totalCollatPenalty = convertedMinLiquidationFee;
        liquidationFees.insolventAmount = (minOwed - userPositionCollateral).multiplyDecimal(insolvencyMultiplier);
      } else {
        totalCollatPenalty = userPositionCollateral;
        liquidationFees.insolventAmount = (gwavPremium).multiplyDecimal(insolvencyMultiplier);
      }
    }
    liquidationFees.smFee = totalCollatPenalty.multiplyDecimal(partialCollatParams.smFeeRatio);
    liquidationFees.liquidatorFee = totalCollatPenalty.multiplyDecimal(partialCollatParams.liquidatorFeeRatio);
    liquidationFees.lpFee = totalCollatPenalty - (liquidationFees.smFee + liquidationFees.liquidatorFee);
    liquidationFees.lpPremiums = userPositionCollateral - totalCollatPenalty - liquidationFees.returnCollateral;
  }

  ///////////////
  // Transfers //
  ///////////////

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
  function split(
    uint positionId,
    uint newAmount,
    uint newCollateral,
    address recipient
  ) external nonReentrant notGlobalPaused returns (uint newPositionId) {
    OptionPosition storage originalPosition = positions[positionId];

    // Will both check whether position is valid and whether approved to split
    // Will revert if it is an invalid positionId or inactive position (as they cannot be owned)
    if (!_isApprovedOrOwner(msg.sender, originalPosition.positionId)) {
      revert SplittingUnapprovedPosition(address(this), msg.sender, originalPosition.positionId);
    }

    _requireStrikeNotExpired(originalPosition.strikeId);

    // Do not allow splits that result in originalPosition.amount = 0 && newPosition.amount = 0;
    if (newAmount >= originalPosition.amount || newAmount == 0) {
      revert InvalidSplitAmount(address(this), originalPosition.amount, newAmount);
    }

    originalPosition.amount -= newAmount;

    // Create new position
    newPositionId = nextId++;
    _mint(recipient, newPositionId);

    OptionPosition storage newPosition = positions[newPositionId];
    newPosition.positionId = newPositionId;
    newPosition.amount = newAmount;
    newPosition.strikeId = originalPosition.strikeId;
    newPosition.optionType = originalPosition.optionType;
    newPosition.state = PositionState.ACTIVE;

    if (_isShort(originalPosition.optionType)) {
      // only change collateral if partial option type
      originalPosition.collateral -= newCollateral;
      newPosition.collateral = newCollateral;

      (uint strikePrice, uint expiry) = optionMarket.getStrikeAndExpiry(originalPosition.strikeId);
      uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));

      if (canLiquidate(originalPosition, expiry, strikePrice, spotPrice)) {
        revert ResultingOriginalPositionLiquidatable(address(this), originalPosition, spotPrice);
      }
      if (canLiquidate(newPosition, expiry, strikePrice, spotPrice)) {
        revert ResultingNewPositionLiquidatable(address(this), newPosition, spotPrice);
      }
    }
    emit PositionUpdated(
      newPosition.positionId,
      recipient,
      PositionUpdatedType.SPLIT_INTO,
      newPosition,
      block.timestamp
    );
    emit PositionUpdated(
      originalPosition.positionId,
      ownerOf(positionId),
      PositionUpdatedType.SPLIT_FROM,
      originalPosition,
      block.timestamp
    );
  }

  /**
   * @notice User can merge many positions with matching strike and optionType into a single position
   * @dev Only ACTIVE positions can be owned by users, so status does not need to be checked.
   * @dev Merged position must not be liquidatable.
   *
   * @param positionIds the positionIds to be merged together
   */
  function merge(uint[] memory positionIds) external nonReentrant notGlobalPaused {
    uint positionsLen = positionIds.length;
    if (positionsLen < 2) {
      revert MustMergeTwoOrMorePositions(address(this));
    }

    OptionPosition storage firstPosition = positions[positionIds[0]];
    if (!_isApprovedOrOwner(msg.sender, firstPosition.positionId)) {
      revert MergingUnapprovedPosition(address(this), msg.sender, firstPosition.positionId);
    }
    _requireStrikeNotExpired(firstPosition.strikeId);

    address positionOwner = ownerOf(firstPosition.positionId);

    OptionPosition storage nextPosition;
    for (uint i = 1; i < positionsLen; ++i) {
      nextPosition = positions[positionIds[i]];

      if (!_isApprovedOrOwner(msg.sender, nextPosition.positionId)) {
        revert MergingUnapprovedPosition(address(this), msg.sender, nextPosition.positionId);
      }

      if (
        positionOwner != ownerOf(nextPosition.positionId) ||
        firstPosition.strikeId != nextPosition.strikeId ||
        firstPosition.optionType != nextPosition.optionType ||
        firstPosition.positionId == nextPosition.positionId
      ) {
        revert PositionMismatchWhenMerging(
          address(this),
          firstPosition,
          nextPosition,
          positionOwner != ownerOf(nextPosition.positionId),
          firstPosition.strikeId != nextPosition.strikeId,
          firstPosition.optionType != nextPosition.optionType,
          firstPosition.positionId == nextPosition.positionId
        );
      }

      firstPosition.amount += nextPosition.amount;
      firstPosition.collateral += nextPosition.collateral;
      nextPosition.collateral = 0;
      nextPosition.amount = 0;
      nextPosition.state = PositionState.MERGED;

      // By burning the position, if the position owner is queried again, it will revert.
      _burn(positionIds[i]);

      emit PositionUpdated(
        nextPosition.positionId,
        positionOwner,
        PositionUpdatedType.MERGED,
        nextPosition,
        block.timestamp
      );
    }

    // make sure final position is not liquidatable
    if (_isShort(firstPosition.optionType)) {
      (uint strikePrice, uint expiry) = optionMarket.getStrikeAndExpiry(firstPosition.strikeId);
      uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
      if (canLiquidate(firstPosition, expiry, strikePrice, spotPrice)) {
        revert ResultingNewPositionLiquidatable(address(this), firstPosition, spotPrice);
      }
    }

    emit PositionUpdated(
      firstPosition.positionId,
      positionOwner,
      PositionUpdatedType.MERGED_INTO,
      firstPosition,
      block.timestamp
    );
  }

  //////////
  // Util //
  //////////

  /// @dev Returns bool on whether the optionType is SHORT_CALL_BASE, SHORT_CALL_QUOTE or SHORT_PUT_QUOTE
  function _isShort(OptionMarket.OptionType optionType) internal pure returns (bool shortPosition) {
    shortPosition = (uint(optionType) >= uint(OptionMarket.OptionType.SHORT_CALL_BASE)) ? true : false;
  }

  /// @dev Returns the PositionState of a given positionId
  function getPositionState(uint positionId) external view returns (PositionState) {
    return positions[positionId].state;
  }

  /// @dev Returns an OptionPosition struct of a given positionId
  function getOptionPosition(uint positionId) external view returns (OptionPosition memory) {
    return positions[positionId];
  }

  /// @dev Returns an array of OptionPosition structs given an array of positionIds
  function getOptionPositions(uint[] memory positionIds) external view returns (OptionPosition[] memory) {
    uint positionsLen = positionIds.length;

    OptionPosition[] memory result = new OptionPosition[](positionsLen);
    for (uint i = 0; i < positionsLen; ++i) {
      result[i] = positions[positionIds[i]];
    }
    return result;
  }

  /// @dev Returns a PositionWithOwner struct of a given positionId (same as OptionPosition but with owner)
  function getPositionWithOwner(uint positionId) external view returns (PositionWithOwner memory) {
    return _getPositionWithOwner(positionId);
  }

  /// @dev Returns an array of PositionWithOwner structs given an array of positionIds
  function getPositionsWithOwner(uint[] memory positionIds) external view returns (PositionWithOwner[] memory) {
    uint positionsLen = positionIds.length;

    PositionWithOwner[] memory result = new PositionWithOwner[](positionsLen);
    for (uint i = 0; i < positionsLen; ++i) {
      result[i] = _getPositionWithOwner(positionIds[i]);
    }
    return result;
  }

  /// @notice Returns an array of OptionPosition structs owned by a given address
  /// @dev Meant to be used offchain as it can run out of gas
  function getOwnerPositions(address target) external view returns (OptionPosition[] memory) {
    uint balance = balanceOf(target);
    OptionPosition[] memory result = new OptionPosition[](balance);
    for (uint i = 0; i < balance; ++i) {
      result[i] = positions[ERC721Enumerable.tokenOfOwnerByIndex(target, i)];
    }
    return result;
  }

  function _getPositionWithOwner(uint positionId) internal view returns (PositionWithOwner memory) {
    OptionPosition memory position = positions[positionId];
    return
      PositionWithOwner({
        positionId: position.positionId,
        strikeId: position.strikeId,
        optionType: position.optionType,
        amount: position.amount,
        collateral: position.collateral,
        state: position.state,
        owner: ownerOf(positionId)
      });
  }

  /// @dev returns PartialCollateralParameters struct
  function getPartialCollatParams() external view returns (PartialCollateralParameters memory) {
    return partialCollatParams;
  }

  function _requireStrikeNotExpired(uint strikeId) internal view {
    (, uint priceAtExpiry, ) = optionMarket.getSettlementParameters(strikeId);
    if (priceAtExpiry != 0) {
      revert StrikeIsSettled(address(this), strikeId);
    }
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyOptionMarket() {
    if (msg.sender != address(optionMarket)) {
      revert OnlyOptionMarket(address(this), msg.sender, address(optionMarket));
    }
    _;
  }
  modifier onlyShortCollateral() {
    if (msg.sender != address(shortCollateral)) {
      revert OnlyShortCollateral(address(this), msg.sender, address(shortCollateral));
    }
    _;
  }

  modifier notGlobalPaused() {
    synthetixAdapter.requireNotGlobalPaused(address(optionMarket));
    _;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint tokenId
  ) internal override {
    super._beforeTokenTransfer(from, to, tokenId);

    if (from != address(0) && to != address(0)) {
      emit PositionUpdated(tokenId, to, PositionUpdatedType.TRANSFER, positions[tokenId], block.timestamp);
    }
  }

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {Vault} from "../libraries/Vault.sol";
import {VaultLifecycle} from "../libraries/VaultLifecycle.sol";
import {ShareMath} from "../libraries/ShareMath.sol";
import {OwnableAdmins} from "./OwnableAdmins.sol";
import "hardhat/console.sol";

contract BaseVault is ReentrancyGuard, OwnableAdmins, Ownable, ERC20, Initializable {
  using SafeMath for uint;
  using SafeERC20 for IERC20;
  using ShareMath for Vault.DepositReceipt;

  bool depositEnabled = true;

  /************************************************
   *  NON UPGRADEABLE STORAGE
   ***********************************************/

  /// @notice Stores the user's pending deposit for the round
  mapping(address => Vault.DepositReceipt) public depositReceipts;

  /// @notice On every round's close, the pricePerShare value of the Vault's
  //          token is stored
  /// This is used to determine the number of shares to be returned
  /// to a user with their DepositReceipt.depositAmount
  mapping(uint => uint) public roundPricePerShare;

  /// @notice Stores pending user withdrawals
  mapping(address => Vault.Withdrawal) public withdrawals;

  /// @notice Vault's parameters like cap, decimals
  Vault.VaultParams public vaultParams;

  /// @notice Vault's lifecycle state like round and locked amounts
  Vault.VaultState public vaultState;

  /// @notice Fee recipient for the license fees
  address public feeRecipient;

  /// @notice License fee charged on entire AUM in rollToNextOption. 
  uint public licenseFeeRate;

  // Gap is left to avoid storage collisions. Though RibbonVault is not upgradeable, we add this as a safety measure.
  uint[30] private ____gap;

  // *IMPORTANT* NO NEW STORAGE VARIABLES SHOULD BE ADDED HERE
  // This is to prevent storage collisions. All storage variables should be appended to RibbonThetaVaultStorage
  // or RibbonDeltaVaultStorage instead. Read this documentation to learn more:
  // https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable#modifying-your-contracts

  /************************************************
   *  IMMUTABLES & CONSTANTS
   ***********************************************/

  // Round per year scaled up FEE_MULTIPLIER
  uint private immutable roundPerYear;

  /************************************************
   *  EVENTS
   ***********************************************/

  //amount=amount for this deposit
  //walletDepositAmount=total pending deposit so far this round for wallet
  //vaultTotalPending=total pending deposit so far this round for entire vault
  event Deposit(address indexed account, uint amount,uint walletDepositAmount, uint vaultTotalPending, uint round);

  //shares=shares for this initial withdraw
  //walletWithdrawalShares=total withdraw initiated so far per wallet
  event InitiateWithdraw(address indexed account, uint shares, uint walletWithdrawalShares, uint round);

  event Redeem(address indexed account, uint share, uint round);

  event LicenseFeeRateSet(uint licenseFeeRate, uint newLicenseFeeRate);

  event CapSet(uint oldCap, uint newCap, address manager);

  event Withdraw(address indexed account, uint amount, uint shares);

  event CollectVaultFees(uint vaultFee, uint round, address indexed feeRecipient);

  /************************************************
   *  CONSTRUCTOR & INITIALIZATION
   ***********************************************/

  /**
   * @notice Initializes the contract with immutable variables
   */
  constructor(
    address _feeRecipient,
    uint _roundDuration,
    string memory _tokenName,
    string memory _tokenSymbol,
    Vault.VaultParams memory _vaultParams
  ) ERC20(_tokenName, _tokenSymbol) {
    feeRecipient = _feeRecipient;
    uint _roundPerYear = (uint(365 days) * Vault.FEE_MULTIPLIER) / _roundDuration;
    roundPerYear = _roundPerYear;
    vaultParams = _vaultParams;

    uint assetBalance = IERC20(vaultParams.asset).balanceOf(address(this));
    ShareMath.assertUint104(assetBalance);
    vaultState.lastLockedAmount = uint104(assetBalance);
    vaultState.round = 1;
  }

  /************************************************
   *  SETTERS
   ***********************************************/

  /**
   * @notice Sets the new fee recipient
   * @param newFeeRecipient is the address of the new fee recipient
   */
  function setFeeRecipient(address newFeeRecipient) external onlyAdmins {
    require(newFeeRecipient != address(0), "!newFeeRecipient");
    require(newFeeRecipient != feeRecipient, "Must be new feeRecipient");
    feeRecipient = newFeeRecipient;
  }

  /**
   * @notice Sets the license fee rate for the vault
   * @param newLicenseFeeRate is the license fee (6 decimals). ex: 2 * 10 ** 6 = 2%
   */
  function setLicenseFeeRate(uint newLicenseFeeRate) external onlyAdmins {
    require(newLicenseFeeRate < 100 * Vault.FEE_MULTIPLIER, "Invalid license fee rate");

    emit LicenseFeeRateSet(licenseFeeRate, newLicenseFeeRate);

    console.log("annualizedNewFeeRate=%s",newLicenseFeeRate);
    // We are dividing annualized license fee by number of rounds in a year
    licenseFeeRate = (newLicenseFeeRate * Vault.FEE_MULTIPLIER) / roundPerYear;
    console.log("newFeeRate=%s",licenseFeeRate);
  }

  /**
   * @notice Sets a new cap for deposits
   * @param newCap is the new cap for deposits
   */
  function setCap(uint newCap) external onlyAdmins {
    require(newCap > 0, "!newCap");

    emit CapSet(vaultParams.cap, newCap, msg.sender);

    ShareMath.assertUint104(newCap);
    vaultParams.cap = uint104(newCap);
  }

  function setDepositEnabled(bool _depositEnabled) external onlyAdmins {
    depositEnabled=_depositEnabled;
  }

  /************************************************
   *  DEPOSIT & WITHDRAWALS
   ***********************************************/

  /**
   * @notice Deposits the `asset` from msg.sender.
   * @param amount is the amount of `asset` to deposit
   */
  function deposit(uint amount) external nonReentrant {
    require(amount > 0, "!amount");

    _depositFor(amount, msg.sender);

    // An approve() by the msg.sender is required beforehand
    IERC20(vaultParams.asset).safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Deposits the `asset` from msg.sender added to `creditor`'s deposit.
   * @notice Used for vault -> vault deposits on the user's behalf
   * @param amount is the amount of `asset` to deposit
   * @param creditor is the address that can claim/withdraw deposited amount
   */
  function depositFor(uint amount, address creditor) external nonReentrant {
    require(amount > 0, "!amount");
    require(creditor != address(0), "!creditor");

    _depositFor(amount, creditor);

    // An approve() by the msg.sender is required beforehand
    IERC20(vaultParams.asset).safeTransferFrom(msg.sender, address(this), amount);
  }

  /**
   * @notice Mints the vault shares to the creditor
   * @param amount is the amount of `asset` deposited
   * @param creditor is the address to receieve the deposit
   */
  function _depositFor(uint amount, address creditor) private {
    uint currentRound = vaultState.round;
    uint totalWithDepositedAmount = totalBalance() + amount;

    require(totalWithDepositedAmount <= vaultParams.cap, "Exceed cap");
    require(depositEnabled,"Deposit not enabled");

    Vault.DepositReceipt memory depositReceipt = depositReceipts[creditor];

    // process unprocessed pending deposit from the previous rounds
    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      currentRound,
      roundPricePerShare[depositReceipt.round],
      vaultParams.decimals
    );

    uint walletDepositAmount = amount;

    // If we have a pending deposit in the current round, we add on to the pending deposit
    if (currentRound == depositReceipt.round) {
      uint newAmount = uint(depositReceipt.amount) + amount;
      walletDepositAmount = newAmount;
    }

    ShareMath.assertUint104(walletDepositAmount);

    depositReceipts[creditor] = Vault.DepositReceipt({
      round: uint16(currentRound),
      amount: uint104(walletDepositAmount),
      unredeemedShares: uint128(unredeemedShares)
    });

    uint vaultTotalPending = uint(vaultState.totalPending) + amount;
    ShareMath.assertUint128(vaultTotalPending);


    emit Deposit(creditor, amount, walletDepositAmount, vaultTotalPending,currentRound);

    vaultState.totalPending = uint128(vaultTotalPending);
  }


  function initiateWithdraw(uint numShares) external nonReentrant {
    _initiateWithdraw(msg.sender,numShares,false);
  }

  function initiateWithdrawFor(address[] memory accounts) external onlyAdmins {
    for (uint i;i<accounts.length;i++) {
      _initiateWithdraw(accounts[i],0,true);
    }
  }

  /**
   * @notice Initiates a withdrawal that can be processed once the round completes
   * @param numShares is the number of shares to withdraw
   */
  function _initiateWithdraw(address account,uint numShares,bool isMax) private {
    if (numShares ==0 && !isMax) {
      console.log("zero shares");
      return;
    }

    // We do a max redeem before initiating a withdrawal
    // But we check if they must first have unredeemed shares
    if (depositReceipts[account].amount > 0 || depositReceipts[account].unredeemedShares > 0) {
      _redeem(account,0, true);
    }

    // This caches the `round` variable used in shareBalances
    uint currentRound = vaultState.round;
    Vault.Withdrawal storage withdrawal = withdrawals[account];

    bool withdrawalIsSameRound = withdrawal.round == currentRound;
    uint existingWithdrawalShares = uint(withdrawal.shares);
    console.log("initiateWithdraw for %s",account);
    //console.log("existingWithdrawalShares=%s/100, round=%s",existingWithdrawalShares/10**16,withdrawal.round);
    //console.log("withdrawalIsSameRound=%s",withdrawalIsSameRound);
    numShares = isMax ? shares(account) : numShares;

    //console.log('numShares = %s/100',numShares/10**16);
    if (numShares == 0) {
      return;
    } else if (numShares>shares(account)) {
      numShares = shares(account);
    }

    uint walletWithdrawalShares;
    if (withdrawalIsSameRound) {
        walletWithdrawalShares = existingWithdrawalShares + numShares;
    } else {
      if (existingWithdrawalShares > 0) {
        console.log("%s has existing withdraw",account);
        return;
      }
      walletWithdrawalShares = numShares;
      withdrawals[account].round = uint16(currentRound);
    }

    console.log("withdraw amount=%s/100",numShares/10**16);

    ShareMath.assertUint128(walletWithdrawalShares);
    withdrawals[account].shares = uint128(walletWithdrawalShares);

    uint newQueuedWithdrawShares = uint(vaultState.queuedWithdrawShares) + numShares;
    ShareMath.assertUint128(newQueuedWithdrawShares);
    vaultState.queuedWithdrawShares = uint128(newQueuedWithdrawShares);

    emit InitiateWithdraw(account, numShares, walletWithdrawalShares, currentRound);

    _transfer(account, address(this), numShares);
  }


  function completeWithdraw() external nonReentrant {
    _completeWithdraw(msg.sender);
  }

  function completeWithdrawFor(address[] memory accounts) external onlyAdmins {
    for (uint i;i<accounts.length;i++) {
      _completeWithdraw(accounts[i]);
    }
  }

  /**
   * @notice Completes a scheduled withdrawal from a past round. Uses finalized pps for the round
   */
  function _completeWithdraw(address account) private {
    Vault.Withdrawal storage withdrawal = withdrawals[account];

    uint withdrawalShares = withdrawal.shares;
    uint withdrawalRound = withdrawal.round;

    // This checks if there is a withdrawal
    if (withdrawalShares == 0) {
      console.log("Not initiated for %s",account);
    } else if (withdrawalRound == vaultState.round) {
      console.log("%s needs to wait till next round",account);
    } else {
      // We leave the round number as non-zero to save on gas for subsequent writes
      withdrawals[account].shares = 0;
      vaultState.queuedWithdrawShares = uint128(uint(vaultState.queuedWithdrawShares) - withdrawalShares);

      uint withdrawAmount = ShareMath.sharesToAsset(withdrawalShares,roundPricePerShare[withdrawalRound],
        vaultParams.decimals);

      emit Withdraw(account, withdrawAmount, withdrawalShares);

      _burn(address(this), withdrawalShares);

      require(withdrawAmount > 0, "!withdrawAmount");

      _transferAsset(account, withdrawAmount);
    }
  }

  /**
   * @notice Redeems shares that are owed to the account
   * @param numShares is the number of shares to redeem
   */
  function redeem(uint numShares) external nonReentrant {
    require(numShares > 0, "!numShares");
    _redeem(msg.sender,numShares, false);
  }

  /**
   * @notice Redeems the entire unredeemedShares balance that is owed to the account
   */
  function maxRedeem() external nonReentrant {
    _redeem(msg.sender,0, true);
  }

  /**
   * @notice Redeems shares that are owed to the account
   * @param numShares is the number of shares to redeem, could be 0 when isMax=true
   * @param isMax is flag for when callers do a max redemption
   */
  function _redeem(address account,uint numShares, bool isMax) internal {
    Vault.DepositReceipt memory depositReceipt = depositReceipts[account];

    // This handles the null case when depositReceipt.round = 0
    // Because we start with round = 1 at `initialize`
    uint currentRound = vaultState.round;

    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      currentRound,roundPricePerShare[depositReceipt.round],vaultParams.decimals);


    numShares = isMax ? unredeemedShares : numShares;
    if (numShares == 0) {
      return;
    } else if (numShares>unredeemedShares) {
      numShares = unredeemedShares;
    }

    // If we have a depositReceipt on the same round, BUT we have some unredeemed shares
    // we debit from the unredeemedShares, but leave the amount field intact
    // If the round has past, with no new deposits, we just zero it out for new deposits.
    depositReceipts[account].amount = depositReceipt.round < currentRound ? 0 : depositReceipt.amount;

    ShareMath.assertUint128(numShares);
    depositReceipts[account].unredeemedShares = uint128(unredeemedShares - numShares);

    emit Redeem(account, numShares, depositReceipt.round);

    _transfer(address(this), account, numShares);
  }

  /************************************************
   *  VAULT OPERATIONS
   ***********************************************/

  /*
   * @notice Helper function that performs most administrative tasks
   * such as setting next option, minting new shares, getting vault fees, etc.
   * @param lastQueuedWithdrawAmount is old queued withdraw amount
   * @return lockedBalance is the new balance used to calculate next option purchase size or collateral size
   * @return queuedWithdrawAmount is the new queued withdraw amount for this round
   */
  function _rollToNextRound() internal returns (uint, uint,uint) {
    _collectVaultFees();
    (uint lockedBalance, uint queuedWithdrawAmount, uint newPricePerShare, uint mintShares) = VaultLifecycle.rollover(
      totalSupply(),
      vaultParams.asset,
      vaultParams.decimals,
      uint(vaultState.totalPending),
      vaultState.queuedWithdrawShares
    );

    // Finalize the pricePerShare at the end of the round
    uint currentRound = vaultState.round;
    roundPricePerShare[currentRound] = newPricePerShare;

    // update round info
    vaultState.totalPending = 0;
    vaultState.round = uint16(currentRound + 1);

    _mint(address(this), mintShares);

    return (lockedBalance, queuedWithdrawAmount,newPricePerShare);
  }

  function _collectVaultFees() internal returns (uint) {
    uint vaultFee = uint(vaultState.lastLockedAmount).mul(licenseFeeRate).div(100 * Vault.FEE_MULTIPLIER);

    if (vaultFee > 0) {
      _transferAsset(payable(feeRecipient), vaultFee);
      emit CollectVaultFees(vaultFee, vaultState.round, feeRecipient);
    }

    return vaultFee;
  }

  /**
   * @notice Helper function to make either an ETH transfer or ERC20 transfer
   * @param recipient is the receiving address
   * @param amount is the transfer amount
   */
  function _transferAsset(address recipient, uint amount) internal {
    address asset = vaultParams.asset;
    IERC20(asset).safeTransfer(recipient, amount);
  }

  /************************************************
   *  GETTERS
   ***********************************************/

  /**
   * @notice Returns the asset balance held on the vault for the account
   * @param account is the address to lookup balance for
   * @return the amount of `asset` custodied by the vault for the user
   */
  function accountVaultBalance(address account) external view returns (uint) {
    uint _decimals = vaultParams.decimals;
    uint assetPerShare = ShareMath.pricePerShare(totalSupply(), totalBalance(), vaultState.totalPending, _decimals);
    return ShareMath.sharesToAsset(shares(account), assetPerShare, _decimals);
  }

  /**
   * @notice Getter for returning the account's share balance including unredeemed shares
   * @param account is the account to lookup share balance for
   * @return the share balance
   */
  function shares(address account) public view returns (uint) {
    (uint heldByAccount, uint heldByVault) = shareBalances(account);
    return heldByAccount + heldByVault;
  }

  /**
   * @notice Getter for returning the account's share balance split between account and vault holdings
   * @param account is the account to lookup share balance for
   * @return heldByAccount is the shares held by account
   * @return heldByVault is the shares held on the vault (unredeemedShares)
   */
  function shareBalances(address account) public view returns (uint heldByAccount, uint heldByVault) {
    Vault.DepositReceipt memory depositReceipt = depositReceipts[account];

    if (depositReceipt.round == 0) {
      return (balanceOf(account), 0);
    }

    uint unredeemedShares = depositReceipt.getSharesFromReceipt(
      vaultState.round,
      roundPricePerShare[depositReceipt.round],
      vaultParams.decimals
    );

    return (balanceOf(account), unredeemedShares);
  }

  /**
   * @notice The price of a unit of share denominated in the `asset`
   */
  function pricePerShare() external view returns (uint) {
    return ShareMath.pricePerShare(totalSupply(), totalBalance(), vaultState.totalPending, vaultParams.decimals);
  }

  /**
   * @notice Returns the vault's total balance, including the amounts locked into a short position
   * @return total balance of the vault, including the amounts locked in third party protocols
   */
  function totalBalance() public view returns (uint) {
    return
      uint(vaultState.lockedAmount - vaultState.lockedAmountLeft) + IERC20(vaultParams.asset).balanceOf(address(this));
  }

  /**
   * @notice Returns the token decimals
   */
  function decimals() public view override returns (uint8) {
    return vaultParams.decimals;
  }
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";
import "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";

// Inherited
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";

// Interfaces
import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";
import "./SynthetixAdapter.sol";
import "./LiquidityPool.sol";
import "./OptionToken.sol";
import "./OptionGreekCache.sol";
import "./SynthetixAdapter.sol";
import "./ShortCollateral.sol";
import "./OptionMarketPricer.sol";

/**
 * @title OptionMarket
 * @author Lyra
 * @dev An AMM which allows users to trade options. Supports both buying and selling options. Also handles liquidating
 * short positions.
 */
contract OptionMarket is Owned, SimpleInitializeable, ReentrancyGuard {
  using DecimalMath for uint;

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
    LiquidityPool.Liquidity liquidity;
    SynthetixAdapter.ExchangeParams exchangeParams;
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

  SynthetixAdapter internal synthetixAdapter;
  LiquidityPool internal liquidityPool;
  OptionMarketPricer internal optionPricer;
  OptionGreekCache internal greekCache;
  ShortCollateral internal shortCollateral;
  OptionToken internal optionToken;
  IERC20 internal quoteAsset;
  IERC20 internal baseAsset;

  uint internal nextStrikeId = 1;
  uint internal nextBoardId = 1;
  uint[] internal liveBoards;

  OptionMarketParameters internal optionMarketParams;

  mapping(uint => OptionBoard) internal optionBoards;
  mapping(uint => Strike) internal strikes;
  mapping(uint => uint) public boardToPriceAtExpiry;
  mapping(uint => uint) internal strikeToBaseReturnedRatio;

  constructor() Owned() {}

  /**
   * @dev Initialize the contract.
   */
  function init(
    SynthetixAdapter _synthetixAdapter,
    LiquidityPool _liquidityPool,
    OptionMarketPricer _optionPricer,
    OptionGreekCache _greekCache,
    ShortCollateral _shortCollateral,
    OptionToken _optionToken,
    IERC20 _quoteAsset,
    IERC20 _baseAsset
  ) external onlyOwner initializer {
    synthetixAdapter = _synthetixAdapter;
    liquidityPool = _liquidityPool;
    optionPricer = _optionPricer;
    greekCache = _greekCache;
    shortCollateral = _shortCollateral;
    optionToken = _optionToken;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
  }

  /////////////////////
  // Admin functions //
  /////////////////////

  /**
   * @notice Creates a new OptionBoard with defined strikePrices and initial skews.
   *
   * @param expiry The timestamp when the board expires.
   * @param baseIV The initial value for baseIv (baseIv * skew = strike volatility).
   * @param strikePrices The array of strikePrices offered for this expiry.
   * @param skews The array of initial skews for each strikePrice.
   * @param frozen Whether the board is frozen or not at creation.
   */
  function createOptionBoard(
    uint expiry,
    uint baseIV,
    uint[] memory strikePrices,
    uint[] memory skews,
    bool frozen
  ) external onlyOwner returns (uint boardId) {
    uint strikePricesLength = strikePrices.length;
    // strikePrice and skew length must match and must have at least 1
    if (strikePricesLength != skews.length || strikePricesLength == 0) {
      revert StrikeSkewLengthMismatch(address(this), strikePricesLength, skews.length);
    }

    if (expiry <= block.timestamp || expiry > block.timestamp + optionMarketParams.maxBoardExpiry) {
      revert InvalidExpiryTimestamp(address(this), block.timestamp, expiry, optionMarketParams.maxBoardExpiry);
    }

    if (baseIV == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.BASE_IV);
    }

    boardId = nextBoardId++;
    OptionBoard storage board = optionBoards[boardId];
    board.id = boardId;
    board.expiry = expiry;
    board.iv = baseIV;
    board.frozen = frozen;

    liveBoards.push(boardId);

    emit BoardCreated(boardId, expiry, baseIV, frozen);

    Strike[] memory newStrikes = new Strike[](strikePricesLength);
    for (uint i = 0; i < strikePricesLength; ++i) {
      newStrikes[i] = _addStrikeToBoard(board, strikePrices[i], skews[i]);
    }

    greekCache.addBoard(board, newStrikes);

    return boardId;
  }

  /**
   * @notice Sets the frozen state of an OptionBoard, preventing or allowing all trading on board.
   * @param boardId The id of the OptionBoard.
   * @param frozen Whether the board will be frozen or not.
   */
  function setBoardFrozen(uint boardId, bool frozen) external onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    if (board.id != boardId || board.id == 0) {
      revert InvalidBoardId(address(this), boardId);
    }
    optionBoards[boardId].frozen = frozen;
    emit BoardFrozen(boardId, frozen);
  }

  /**
   * @notice Sets the baseIv of a frozen OptionBoard.
   *
   * @param boardId The id of the OptionBoard.
   * @param baseIv The new baseIv value.
   */
  function setBoardBaseIv(uint boardId, uint baseIv) external onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    if (board.id != boardId || board.id == 0) {
      revert InvalidBoardId(address(this), boardId);
    }
    if (baseIv == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.BASE_IV);
    }
    if (!board.frozen) {
      revert BoardNotFrozen(address(this), boardId);
    }

    board.iv = baseIv;
    greekCache.setBoardIv(boardId, baseIv);
    emit BoardBaseIvSet(boardId, baseIv);
  }

  /**
   * @notice Sets the skew of a Strike of a frozen OptionBoard.
   *
   * @param strikeId The id of the strike being modified.
   * @param skew The new skew value.
   */
  function setStrikeSkew(uint strikeId, uint skew) external onlyOwner {
    Strike storage strike = strikes[strikeId];
    if (strike.id != strikeId) {
      revert InvalidStrikeId(address(this), strikeId);
    }
    if (skew == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.SKEW);
    }

    OptionBoard memory board = optionBoards[strike.boardId];
    if (!board.frozen) {
      revert BoardNotFrozen(address(this), board.id);
    }

    strike.skew = skew;
    greekCache.setStrikeSkew(strikeId, skew);
    emit StrikeSkewSet(strikeId, skew);
  }

  /**
   * @notice Add a strike to an existing board in the OptionMarket.
   *
   * @param boardId The id of the board which the strike will be added
   * @param strikePrice The strike price of the strike being added
   * @param skew Skew of the Strike
   */
  function addStrikeToBoard(
    uint boardId,
    uint strikePrice,
    uint skew
  ) external onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    if (board.id != boardId || board.id == 0) {
      revert InvalidBoardId(address(this), boardId);
    }
    Strike memory strike = _addStrikeToBoard(board, strikePrice, skew);
    greekCache.addStrikeToBoard(boardId, strike.id, strikePrice, skew);
  }

  /// @dev Add a strike to an existing board.
  function _addStrikeToBoard(
    OptionBoard storage board,
    uint strikePrice,
    uint skew
  ) internal returns (Strike memory) {
    if (strikePrice == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.STRIKE_PRICE);
    }
    if (skew == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.SKEW);
    }

    uint strikeId = nextStrikeId++;
    strikes[strikeId] = Strike(strikeId, strikePrice, skew, 0, 0, 0, 0, 0, board.id);
    board.strikeIds.push(strikeId);
    emit StrikeAdded(board.id, strikeId, strikePrice, skew);
    return strikes[strikeId];
  }

  /**
   * @notice Force settle all open options before expiry.
   * @dev Only used during emergency situations.
   *
   * @param boardId The id of the board to settle
   */
  function forceSettleBoard(uint boardId) external onlyOwner {
    OptionBoard memory board = optionBoards[boardId];
    if (board.id != boardId || board.id == 0) {
      revert InvalidBoardId(address(this), boardId);
    }
    if (!board.frozen) {
      revert BoardNotFrozen(address(this), boardId);
    }
    _clearAndSettleBoard(board);
  }

  /// @notice set OptionMarketParams
  function setOptionMarketParams(OptionMarketParameters memory _optionMarketParams) external onlyOwner {
    if (_optionMarketParams.feePortionReserved > DecimalMath.UNIT) {
      revert InvalidOptionMarketParams(address(this), _optionMarketParams);
    }
    optionMarketParams = _optionMarketParams;
    emit OptionMarketParamsSet(optionMarketParams);
  }

  /// @notice claim all reserved option fees
  function smClaim() external notGlobalPaused {
    if (msg.sender != optionMarketParams.securityModule) {
      revert OnlySecurityModule(address(this), msg.sender, optionMarketParams.securityModule);
    }
    uint quoteBal = quoteAsset.balanceOf(address(this));
    if (quoteBal > 0 && !quoteAsset.transfer(msg.sender, quoteBal)) {
      revert QuoteTransferFailed(address(this), address(this), msg.sender, quoteBal);
    }
    // While fees cannot accrue in base, this can help reclaim any accidental transfers into this contract
    uint baseBal = baseAsset.balanceOf(address(this));
    if (baseBal > 0 && !baseAsset.transfer(msg.sender, baseBal)) {
      revert BaseTransferFailed(address(this), address(this), msg.sender, baseBal);
    }
    emit SMClaimed(msg.sender, quoteBal, baseBal);
  }

  ///////////
  // Views //
  ///////////

  function getOptionMarketParams() external view returns (OptionMarketParameters memory) {
    return optionMarketParams;
  }

  /**
   * @notice Returns the list of live board ids.
   */
  function getLiveBoards() external view returns (uint[] memory _liveBoards) {
    uint liveBoardsLen = liveBoards.length;
    _liveBoards = new uint[](liveBoardsLen);
    for (uint i = 0; i < liveBoardsLen; ++i) {
      _liveBoards[i] = liveBoards[i];
    }
    return _liveBoards;
  }

  /// @notice Returns the number of current live boards
  function getNumLiveBoards() external view returns (uint numLiveBoards) {
    return liveBoards.length;
  }

  /// @notice Returns the strike and expiry for a given strikeId
  function getStrikeAndExpiry(uint strikeId) external view returns (uint strikePrice, uint expiry) {
    return (strikes[strikeId].strikePrice, optionBoards[strikes[strikeId].boardId].expiry);
  }

  /**
   * @notice Returns the strike ids for a given `boardId`.
   *
   * @param boardId The id of the relevant OptionBoard.
   */
  function getBoardStrikes(uint boardId) external view returns (uint[] memory strikeIds) {
    uint strikeIdsLen = optionBoards[boardId].strikeIds.length;
    strikeIds = new uint[](strikeIdsLen);
    for (uint i = 0; i < strikeIdsLen; ++i) {
      strikeIds[i] = optionBoards[boardId].strikeIds[i];
    }
    return strikeIds;
  }

  /// @notice Returns the Strike struct for a given strikeId
  function getStrike(uint strikeId) external view returns (Strike memory) {
    return strikes[strikeId];
  }

  /// @notice Returns the OptionBoard struct for a given boardId
  function getOptionBoard(uint boardId) external view returns (OptionBoard memory) {
    return optionBoards[boardId];
  }

  /// @notice Returns the Strike and OptionBoard structs for a given strikeId
  function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory) {
    Strike memory strike = strikes[strikeId];
    return (strike, optionBoards[strike.boardId]);
  }

  /**
   * @notice Returns board and strike details given a boardId
   *
   * @return OptionBoard the OptionBoard struct
   * @return Strike[] the list of board strikes
   * @return uint[] the list of strike to base returned ratios
   * @return uint the board to price at expiry
   */
  function getBoardAndStrikeDetails(uint boardId)
    external
    view
    returns (
      OptionBoard memory,
      Strike[] memory,
      uint[] memory,
      uint
    )
  {
    OptionBoard memory board = optionBoards[boardId];

    uint strikesLen = board.strikeIds.length;
    Strike[] memory boardStrikes = new Strike[](strikesLen);
    uint[] memory strikeToBaseReturnedRatios = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      boardStrikes[i] = strikes[board.strikeIds[i]];
      strikeToBaseReturnedRatios[i] = strikeToBaseReturnedRatio[board.strikeIds[i]];
    }
    return (board, boardStrikes, strikeToBaseReturnedRatios, boardToPriceAtExpiry[boardId]);
  }

  ////////////////////
  // User functions //
  ////////////////////

  /**
   * @notice Attempts to open positions within cost bounds.
   * @dev If a positionId is specified that position is adjusted accordingly
   *
   * @param params The parameters for the requested trade
   */
  function openPosition(TradeInputParameters memory params) external nonReentrant returns (Result memory result) {
    result = _openPosition(params);
    _checkCostInBounds(result.totalCost, params.minTotalCost, params.maxTotalCost);
  }

  /**
   * @notice Attempts to reduce or fully close position within cost bounds.
   *
   * @param params The parameters for the requested trade
   */
  function closePosition(TradeInputParameters memory params) external nonReentrant returns (Result memory result) {
    result = _closePosition(params, false);
    _checkCostInBounds(result.totalCost, params.minTotalCost, params.maxTotalCost);
  }

  /**
   * @notice Attempts to reduce or fully close position within cost bounds while ignoring delta trading cutoffs.
   *
   * @param params The parameters for the requested trade
   */
  function forceClosePosition(TradeInputParameters memory params) external nonReentrant returns (Result memory result) {
    result = _closePosition(params, true);
    _checkCostInBounds(result.totalCost, params.minTotalCost, params.maxTotalCost);
  }

  /**
   * @notice Add collateral of size amountCollateral onto a short position (long or call) specified by positionId;
   *         this transfers tokens (which may be denominated in the quote or the base asset). This allows you to
   *         further collateralise a short position in order to, say, prevent imminent liquidation.
   *
   * @param positionId id of OptionToken to add collateral to
   * @param amountCollateral the amount of collateral to be added
   */
  function addCollateral(uint positionId, uint amountCollateral) external nonReentrant notGlobalPaused {
    int pendingCollateral = SafeCast.toInt256(amountCollateral);
    OptionType optionType = optionToken.addCollateral(positionId, amountCollateral);
    _routeUserCollateral(optionType, pendingCollateral);
  }

  function _checkCostInBounds(
    uint totalCost,
    uint minCost,
    uint maxCost
  ) internal view {
    if (totalCost < minCost || totalCost > maxCost) {
      revert TotalCostOutsideOfSpecifiedBounds(address(this), totalCost, minCost, maxCost);
    }
  }

  /////////////////////////
  // Opening and Closing //
  /////////////////////////

  /**
   * @dev Opens a position, which may be long call, long put, short call or short put.
   */
  function _openPosition(TradeInputParameters memory params) internal returns (Result memory result) {
    (TradeParameters memory trade, Strike storage strike, OptionBoard storage board) = _composeTrade(
      params.strikeId,
      params.optionType,
      params.amount,
      TradeDirection.OPEN,
      params.iterations,
      false
    );
    OptionMarketPricer.TradeResult[] memory tradeResults;
    (trade.amount, result.totalCost, result.totalFee, tradeResults) = _doTrade(
      strike,
      board,
      trade,
      params.iterations,
      params.amount
    );

    int pendingCollateral;
    // collateral logic happens within optionToken
    (result.positionId, pendingCollateral) = optionToken.adjustPosition(
      trade,
      params.strikeId,
      msg.sender,
      params.positionId,
      result.totalCost,
      params.setCollateralTo,
      true
    );

    uint reservedFee = result.totalFee.multiplyDecimal(optionMarketParams.feePortionReserved);

    _routeLPFundsOnOpen(trade, result.totalCost, reservedFee);
    _routeUserCollateral(trade.optionType, pendingCollateral);
    liquidityPool.updateCBs();

    emit Trade(
      msg.sender,
      params.strikeId,
      result.positionId,
      TradeEventData({
        expiry: trade.expiry,
        strikePrice: trade.strikePrice,
        optionType: params.optionType,
        tradeDirection: TradeDirection.OPEN,
        amount: trade.amount,
        setCollateralTo: params.setCollateralTo,
        isForceClose: false,
        spotPrice: trade.exchangeParams.spotPrice,
        reservedFee: reservedFee,
        totalCost: result.totalCost
      }),
      tradeResults,
      LiquidationEventData(address(0), address(0), 0, 0, 0, 0, 0, 0),
      block.timestamp
    );
  }

  /**
   * @dev Closes some amount of an open position. The user does not have to close the whole position.
   *
   */
  function _closePosition(TradeInputParameters memory params, bool forceClose) internal returns (Result memory result) {
    (TradeParameters memory trade, Strike storage strike, OptionBoard storage board) = _composeTrade(
      params.strikeId,
      params.optionType,
      params.amount,
      TradeDirection.CLOSE,
      params.iterations,
      forceClose
    );

    OptionMarketPricer.TradeResult[] memory tradeResults;
    (trade.amount, result.totalCost, result.totalFee, tradeResults) = _doTrade(
      strike,
      board,
      trade,
      params.iterations,
      params.amount
    );

    int pendingCollateral;
    // collateral logic happens within optionToken
    (result.positionId, pendingCollateral) = optionToken.adjustPosition(
      trade,
      params.strikeId,
      msg.sender,
      params.positionId,
      result.totalCost,
      params.setCollateralTo,
      false
    );

    uint reservedFee = result.totalFee.multiplyDecimal(optionMarketParams.feePortionReserved);

    _routeUserCollateral(trade.optionType, pendingCollateral);
    _routeLPFundsOnClose(trade, result.totalCost, reservedFee);
    liquidityPool.updateCBs();

    emit Trade(
      msg.sender,
      params.strikeId,
      result.positionId,
      TradeEventData({
        expiry: trade.expiry,
        strikePrice: trade.strikePrice,
        optionType: params.optionType,
        tradeDirection: TradeDirection.CLOSE,
        amount: params.amount,
        setCollateralTo: params.setCollateralTo,
        isForceClose: forceClose,
        reservedFee: reservedFee,
        spotPrice: trade.exchangeParams.spotPrice,
        totalCost: result.totalCost
      }),
      tradeResults,
      LiquidationEventData(address(0), address(0), 0, 0, 0, 0, 0, 0),
      block.timestamp
    );
  }

  /**
   * @dev Compile all trade related details
   */
  function _composeTrade(
    uint strikeId,
    OptionType optionType,
    uint amount,
    TradeDirection _tradeDirection,
    uint iterations,
    bool isForceClose
  )
    internal
    view
    returns (
      TradeParameters memory trade,
      Strike storage strike,
      OptionBoard storage board
    )
  {
    if (strikeId == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.STRIKE_ID);
    }
    if (iterations == 0) {
      revert ExpectedNonZeroValue(address(this), NonZeroValues.ITERATIONS);
    }

    strike = strikes[strikeId];
    if (strike.id != strikeId) {
      revert InvalidStrikeId(address(this), strikeId);
    }
    board = optionBoards[strike.boardId];

    if (boardToPriceAtExpiry[board.id] != 0) {
      revert BoardAlreadySettled(address(this), board.id);
    }

    bool isBuy = (_tradeDirection == TradeDirection.OPEN) ? _isLong(optionType) : !_isLong(optionType);

    SynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(this));

    trade = TradeParameters({
      isBuy: isBuy,
      isForceClose: isForceClose,
      tradeDirection: _tradeDirection,
      optionType: optionType,
      amount: amount / iterations,
      expiry: board.expiry,
      strikePrice: strike.strikePrice,
      exchangeParams: exchangeParams,
      liquidity: liquidityPool.getLiquidity(exchangeParams.spotPrice)
    });
  }

  function _isLong(OptionType optionType) internal pure returns (bool) {
    return (optionType == OptionType.LONG_CALL || optionType == OptionType.LONG_PUT);
  }

  /**
   * @dev Determine the cost of the trade and update the system's iv/skew/exposure parameters.
   *
   * @param strike The currently traded Strike.
   * @param board The currently traded OptionBoard.
   * @param trade The trade parameters struct, informing the trade the caller wants to make.
   */
  function _doTrade(
    Strike storage strike,
    OptionBoard storage board,
    TradeParameters memory trade,
    uint iterations,
    uint expectedAmount
  )
    internal
    returns (
      uint totalAmount,
      uint totalCost,
      uint totalFee,
      OptionMarketPricer.TradeResult[] memory tradeResults
    )
  {
    // don't engage AMM if only collateral is added/removed
    if (trade.amount == 0) {
      if (expectedAmount != 0) {
        revert TradeIterationsHasRemainder(address(this), iterations, expectedAmount, 0, 0);
      }
      return (0, 0, 0, new OptionMarketPricer.TradeResult[](0));
    }

    if (board.frozen) {
      revert BoardIsFrozen(address(this), board.id);
    }
    if (block.timestamp >= board.expiry) {
      revert BoardExpired(address(this), board.id, board.expiry, block.timestamp);
    }

    tradeResults = new OptionMarketPricer.TradeResult[](iterations);

    for (uint i = 0; i < iterations; ++i) {
      if (i == iterations - 1) {
        trade.amount = expectedAmount - totalAmount;
      }
      _updateExposure(trade.amount, trade.optionType, strike, trade.tradeDirection == TradeDirection.OPEN);

      OptionMarketPricer.TradeResult memory tradeResult = optionPricer.updateCacheAndGetTradeResult(
        strike,
        trade,
        board.iv,
        board.expiry
      );

      board.iv = tradeResult.newBaseIv;
      strike.skew = tradeResult.newSkew;

      totalCost += tradeResult.totalCost;
      totalFee += tradeResult.totalFee;
      totalAmount += trade.amount;

      tradeResults[i] = tradeResult;
    }

    return (totalAmount, totalCost, totalFee, tradeResults);
  }

  /////////////////
  // Liquidation //
  /////////////////

  /**
   * @dev Allows anyone to liquidate an underwater position
   *
   * @param positionId the position to be liquidated
   * @param rewardBeneficiary the address to receive the liquidator fee in either quote or base
   */
  function liquidatePosition(uint positionId, address rewardBeneficiary) external nonReentrant {
    OptionToken.PositionWithOwner memory position = optionToken.getPositionWithOwner(positionId);

    (TradeParameters memory trade, Strike storage strike, OptionBoard storage board) = _composeTrade(
      position.strikeId,
      position.optionType,
      position.amount,
      TradeDirection.LIQUIDATE,
      1,
      true
    );

    // updating AMM but disregarding the spotCost
    (, uint totalCost, , OptionMarketPricer.TradeResult[] memory tradeResults) = _doTrade(
      strike,
      board,
      trade,
      1,
      position.amount
    );

    OptionToken.LiquidationFees memory liquidationFees = optionToken.liquidate(positionId, trade, totalCost);

    if (liquidationFees.insolventAmount > 0) {
      liquidityPool.updateLiquidationInsolvency(liquidationFees.insolventAmount);
    }

    shortCollateral.routeLiquidationFunds(position.owner, rewardBeneficiary, position.optionType, liquidationFees);
    liquidityPool.updateCBs();

    emit Trade(
      position.owner,
      position.strikeId,
      positionId,
      TradeEventData({
        expiry: trade.expiry,
        strikePrice: trade.strikePrice,
        optionType: position.optionType,
        tradeDirection: TradeDirection.LIQUIDATE,
        amount: position.amount,
        setCollateralTo: 0,
        isForceClose: true,
        spotPrice: trade.exchangeParams.spotPrice,
        reservedFee: 0,
        totalCost: totalCost
      }),
      tradeResults,
      LiquidationEventData({
        caller: msg.sender,
        rewardBeneficiary: rewardBeneficiary,
        returnCollateral: liquidationFees.returnCollateral,
        lpPremiums: liquidationFees.lpPremiums,
        lpFee: liquidationFees.lpFee,
        liquidatorFee: liquidationFees.liquidatorFee,
        smFee: liquidationFees.smFee,
        insolventAmount: liquidationFees.insolventAmount
      }),
      block.timestamp
    );
  }

  //////////////////
  // Fund routing //
  //////////////////

  /// @dev send/receive quote or base to/from LiquidityPool on position open
  function _routeLPFundsOnOpen(
    TradeParameters memory trade,
    uint totalCost,
    uint feePortion
  ) internal {
    if (trade.amount == 0) {
      return;
    }

    if (trade.optionType == OptionType.LONG_CALL) {
      liquidityPool.lockBase(trade.amount, trade.exchangeParams, trade.liquidity.freeLiquidity);
      _transferFromQuote(msg.sender, address(liquidityPool), totalCost - feePortion);
      _transferFromQuote(msg.sender, address(this), feePortion);
    } else if (trade.optionType == OptionType.LONG_PUT) {
      liquidityPool.lockQuote(trade.amount.multiplyDecimal(trade.strikePrice), trade.liquidity.freeLiquidity);
      _transferFromQuote(msg.sender, address(liquidityPool), totalCost - feePortion);
      _transferFromQuote(msg.sender, address(this), feePortion);
    } else if (trade.optionType == OptionType.SHORT_CALL_BASE) {
      liquidityPool.sendShortPremium(msg.sender, totalCost, trade.liquidity.freeLiquidity, feePortion);
    } else {
      // OptionType.SHORT_CALL_QUOTE || OptionType.SHORT_PUT_QUOTE
      liquidityPool.sendShortPremium(address(shortCollateral), totalCost, trade.liquidity.freeLiquidity, feePortion);
    }
  }

  /// @dev send/receive quote or base to/from LiquidityPool on position close
  function _routeLPFundsOnClose(
    TradeParameters memory trade,
    uint totalCost,
    uint reservedFee
  ) internal {
    if (trade.amount == 0) {
      return;
    }

    if (trade.optionType == OptionType.LONG_CALL) {
      liquidityPool.liquidateBaseAndSendPremium(trade.amount, msg.sender, totalCost, reservedFee);
    } else if (trade.optionType == OptionType.LONG_PUT) {
      liquidityPool.freeQuoteCollateralAndSendPremium(
        trade.amount.multiplyDecimal(trade.strikePrice),
        msg.sender,
        totalCost,
        reservedFee
      );
    } else if (trade.optionType == OptionType.SHORT_CALL_BASE) {
      _transferFromQuote(msg.sender, address(liquidityPool), totalCost - reservedFee);
      _transferFromQuote(msg.sender, address(this), reservedFee);
    } else {
      // OptionType.SHORT_CALL_QUOTE || OptionType.SHORT_PUT_QUOTE
      shortCollateral.sendQuoteCollateral(address(liquidityPool), totalCost - reservedFee);
      shortCollateral.sendQuoteCollateral(address(this), reservedFee);
    }
  }

  /// @dev route collateral to/from msg.sender when short positions are adjusted
  function _routeUserCollateral(OptionType optionType, int pendingCollateral) internal {
    if (pendingCollateral == 0) {
      return;
    }

    if (optionType == OptionType.SHORT_CALL_BASE) {
      if (pendingCollateral > 0) {
        if (!baseAsset.transferFrom(msg.sender, address(shortCollateral), uint(pendingCollateral))) {
          revert BaseTransferFailed(address(this), msg.sender, address(shortCollateral), uint(pendingCollateral));
        }
      } else {
        shortCollateral.sendBaseCollateral(msg.sender, uint(-pendingCollateral));
      }
    } else {
      // quote collateral
      if (pendingCollateral > 0) {
        _transferFromQuote(msg.sender, address(shortCollateral), uint(pendingCollateral));
      } else {
        shortCollateral.sendQuoteCollateral(msg.sender, uint(-pendingCollateral));
      }
    }
  }

  /// @dev update all exposures per strike and optionType
  function _updateExposure(
    uint amount,
    OptionType optionType,
    Strike storage strike,
    bool isOpen
  ) internal {
    int exposure = isOpen ? SafeCast.toInt256(amount) : -SafeCast.toInt256(amount);

    if (optionType == OptionType.LONG_CALL) {
      exposure += SafeCast.toInt256(strike.longCall);
      strike.longCall = SafeCast.toUint256(exposure);
    } else if (optionType == OptionType.LONG_PUT) {
      exposure += SafeCast.toInt256(strike.longPut);
      strike.longPut = SafeCast.toUint256(exposure);
    } else if (optionType == OptionType.SHORT_CALL_BASE) {
      exposure += SafeCast.toInt256(strike.shortCallBase);
      strike.shortCallBase = SafeCast.toUint256(exposure);
    } else if (optionType == OptionType.SHORT_CALL_QUOTE) {
      exposure += SafeCast.toInt256(strike.shortCallQuote);
      strike.shortCallQuote = SafeCast.toUint256(exposure);
    } else {
      // OptionType.SHORT_PUT_QUOTE
      exposure += SafeCast.toInt256(strike.shortPut);
      strike.shortPut = SafeCast.toUint256(exposure);
    }
  }

  /////////////////////////////////
  // Board Expiry and settlement //
  /////////////////////////////////

  /**
   * @notice Settles an expired board.
   * - Transfers all AMM profits for user shorts from ShortCollateral to LiquidityPool.
   * - Reserves all user profits for user longs in LiquidityPool.
   * - Records any profits that AMM did not receive due to user insolvencies
   *
   * @param boardId The relevant OptionBoard.
   */
  function settleExpiredBoard(uint boardId) external nonReentrant {
    OptionBoard memory board = optionBoards[boardId];
    if (board.id != boardId || board.id == 0) {
      revert InvalidBoardId(address(this), boardId);
    }
    if (block.timestamp < board.expiry) {
      revert BoardNotExpired(address(this), boardId);
    }
    _clearAndSettleBoard(board);
  }

  function _clearAndSettleBoard(OptionBoard memory board) internal {
    bool popped = false;
    uint liveBoardsLen = liveBoards.length;

    // Find and remove the board from the list of live boards
    for (uint i = 0; i < liveBoardsLen; ++i) {
      if (liveBoards[i] == board.id) {
        liveBoards[i] = liveBoards[liveBoardsLen - 1];
        liveBoards.pop();
        popped = true;
        break;
      }
    }
    // prevent old boards being liquidated
    if (!popped) {
      revert BoardAlreadySettled(address(this), board.id);
    }

    _settleExpiredBoard(board);
    greekCache.removeBoard(board.id);
  }

  function _settleExpiredBoard(OptionBoard memory board) internal {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(this));

    uint totalUserLongProfitQuote;
    uint totalBoardLongCallCollateral;
    uint totalBoardLongPutCollateral;
    uint totalAMMShortCallProfitBase;
    uint totalAMMShortCallProfitQuote;
    uint totalAMMShortPutProfitQuote;

    // Store the price now for when users come to settle their options
    boardToPriceAtExpiry[board.id] = spotPrice;
    uint strikesLen = board.strikeIds.length;

    for (uint i = 0; i < strikesLen; ++i) {
      Strike memory strike = strikes[board.strikeIds[i]];

      totalBoardLongCallCollateral += strike.longCall;
      totalBoardLongPutCollateral += strike.longPut.multiplyDecimal(strike.strikePrice);

      if (spotPrice > strike.strikePrice) {
        // For long calls
        totalUserLongProfitQuote += strike.longCall.multiplyDecimal(spotPrice - strike.strikePrice);

        // Per unit of shortCalls
        uint baseReturnedRatio = (spotPrice - strike.strikePrice).divideDecimal(spotPrice).divideDecimal(
          DecimalMath.UNIT - optionMarketParams.staticBaseSettlementFee
        );

        // This is impossible unless the baseAsset price has gone up ~900%+
        baseReturnedRatio = baseReturnedRatio > DecimalMath.UNIT ? DecimalMath.UNIT : baseReturnedRatio;

        totalAMMShortCallProfitBase += baseReturnedRatio.multiplyDecimal(strike.shortCallBase);
        totalAMMShortCallProfitQuote += (spotPrice - strike.strikePrice).multiplyDecimal(strike.shortCallQuote);
        strikeToBaseReturnedRatio[strike.id] = baseReturnedRatio;
      } else if (spotPrice < strike.strikePrice) {
        // if amount > 0 can be skipped as it will be multiplied by 0
        totalUserLongProfitQuote += strike.longPut.multiplyDecimal(strike.strikePrice - spotPrice);
        totalAMMShortPutProfitQuote += (strike.strikePrice - spotPrice).multiplyDecimal(strike.shortPut);
      }
    }

    (uint lpBaseInsolvency, uint lpQuoteInsolvency) = shortCollateral.boardSettlement(
      totalAMMShortCallProfitBase,
      totalAMMShortPutProfitQuote + totalAMMShortCallProfitQuote
    );

    // This will batch all base we want to convert to quote and sell it in one transaction
    liquidityPool.boardSettlement(
      lpQuoteInsolvency + lpBaseInsolvency.multiplyDecimal(spotPrice),
      totalBoardLongPutCollateral,
      totalUserLongProfitQuote,
      totalBoardLongCallCollateral
    );

    emit BoardSettled(
      board.id,
      spotPrice,
      totalUserLongProfitQuote,
      totalBoardLongCallCollateral,
      totalBoardLongPutCollateral,
      totalAMMShortCallProfitBase,
      totalAMMShortCallProfitQuote,
      totalAMMShortPutProfitQuote
    );
  }

  /// @dev Returns the strike price, price at expiry, and profit ratio for user shorts post expiry
  function getSettlementParameters(uint strikeId)
    external
    view
    returns (
      uint strikePrice,
      uint priceAtExpiry,
      uint strikeToBaseReturned
    )
  {
    return (
      strikes[strikeId].strikePrice,
      boardToPriceAtExpiry[strikes[strikeId].boardId],
      strikeToBaseReturnedRatio[strikeId]
    );
  }

  //////////
  // Misc //
  //////////

  function _transferFromQuote(
    address from,
    address to,
    uint amount
  ) internal {
    if (!quoteAsset.transferFrom(from, to, amount)) {
      revert QuoteTransferFailed(address(this), from, to, amount);
    }
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier notGlobalPaused() {
    synthetixAdapter.requireNotGlobalPaused(address(this));
    _;
  }

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
    OptionMarketPricer.TradeResult[] tradeResults,
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vault} from "./Vault.sol";
import {ShareMath} from "./ShareMath.sol";

import {IERC20Detailed} from "../interfaces/IERC20Detailed.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "hardhat/console.sol";

/**
 * @dev copied from Ribbon's VaultLifeCycle, changed to internal library for gas optimization
 */
library VaultLifecycle {
  using SafeMath for uint;
  using SafeERC20 for IERC20;

  /**
   * @notice Calculate the shares to mint, new price per share,
   *         and amount of funds to re-allocate as collateral for the new round
   * @param currentShareSupply is the total supply of shares
   * @param asset is the address of the vault's asset
   * @param decimals is the decimals of the asset
   * @param pendingAmount is the amount of funds pending from recent deposits
   * @return newLockedAmount is the amount of funds to allocate for the new round
   * @return queuedWithdrawAmount is the amount of funds set aside for withdrawal
   * @return newPricePerShare is the price per share of the new round
   * @return mintShares is the amount of shares to mint from deposits
   */
  function rollover(
    uint currentShareSupply,
    address asset,
    uint decimals,
    uint pendingAmount,
    uint queuedWithdrawShares
  )
    internal
    view
    returns (
      uint newLockedAmount,
      uint queuedWithdrawAmount,
      uint newPricePerShare,
      uint mintShares
    )
  {
    uint currentBalance = IERC20(asset).balanceOf(address(this));
    console.log("LC currentShareSupply=%s/100  currentBalance=%s/100  pendingAmount=%s/100",
        currentShareSupply/10**16,currentBalance/10**16,pendingAmount/10**16);

    newPricePerShare = ShareMath.pricePerShare(currentShareSupply, currentBalance, pendingAmount, decimals);
    console.log("newPricePerShare=%s/100",newPricePerShare/10**16);

    // After closing the short, if the options expire in-the-money
    // vault pricePerShare would go down because vault's asset balance decreased.
    // This ensures that the newly-minted shares do not take on the loss.
    uint _mintShares = ShareMath.assetToShares(pendingAmount, newPricePerShare, decimals);

    uint newSupply = currentShareSupply.add(_mintShares);

    uint queuedWithdraw = newSupply > 0 ? ShareMath.sharesToAsset(queuedWithdrawShares, newPricePerShare, decimals) : 0;

    return (currentBalance.sub(queuedWithdraw), queuedWithdraw, newPricePerShare, _mintShares);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {Vault} from "./Vault.sol";

library ShareMath {
  function assetToShares(
    uint assetAmount,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint) {
    // If this throws, it means that vault's roundPricePerShare[currentRound] has not been set yet
    // which should never happen.
    require(assetPerShare > 0, "Invalid assetPerShare");

    return (assetAmount * (10**decimals)) / (assetPerShare);
  }

  function sharesToAsset(
    uint shares,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint) {
    // If this throws, it means that vault's roundPricePerShare[currentRound] has not been set yet
    // which should never happen.
    require(assetPerShare > 0, "Invalid assetPerShare");

    return (shares * assetPerShare) / (10**decimals);
  }

  /**
   * @notice Returns the shares unredeemed by the user given their DepositReceipt
   * @param depositReceipt is the user's deposit receipt
   * @param currentRound is the `round` stored on the vault
   * @param assetPerShare is the price in asset per share
   * @param decimals is the number of decimals the asset/shares use
   * @return unredeemedShares is the user's virtual balance of shares that are owed
   */
  function getSharesFromReceipt(
    Vault.DepositReceipt memory depositReceipt,
    uint currentRound,
    uint assetPerShare,
    uint decimals
  ) internal pure returns (uint unredeemedShares) {
    if (depositReceipt.round > 0 && depositReceipt.round < currentRound) {
      uint sharesFromRound = assetToShares(depositReceipt.amount, assetPerShare, decimals);

      return uint(depositReceipt.unredeemedShares) + sharesFromRound;
    }
    return depositReceipt.unredeemedShares;
  }

  function pricePerShare(
    uint totalSupply,
    uint totalBalance,
    uint pendingAmount,
    uint decimals
  ) internal pure returns (uint) {
    uint singleShare = 10**decimals;
    return totalSupply > 0 ? (singleShare * (totalBalance - pendingAmount)) / (totalSupply) : singleShare;
  }

  /************************************************
   *  HELPERS
   ***********************************************/

  function assertUint104(uint num) internal pure {
    require(num <= type(uint104).max, "Overflow uint104");
  }

  function assertUint128(uint num) internal pure {
    require(num <= type(uint128).max, "Overflow uint128");
  }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
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
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.0;

import "../../utils/Address.sol";

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
        return !Address.isContract(address(this));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
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
contract ERC20 is Context, IERC20, IERC20Metadata {
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
    constructor(string memory name_, string memory symbol_) {
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
        _approve(owner, spender, _allowances[owner][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[owner][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
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
        }
        _balances[to] += amount;

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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
     * @dev Spend `amount` form the allowance of `owner` toward `spender`.
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
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
// OpenZeppelin Contracts v4.4.1 (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
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
pragma solidity ^0.8.9;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Detailed is IERC20 {
  function decimals() external view returns (uint8);

  function symbol() external view returns (string calldata);

  function name() external view returns (string calldata);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/Address.sol)

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

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";

// Inherited
import "./synthetix/OwnedUpgradeable.sol";

// Interfaces
import "./interfaces/ISynthetix.sol";
import "./interfaces/IAddressResolver.sol";
import "./interfaces/IExchanger.sol";
import "./interfaces/IExchangeRates.sol";
import "./LiquidityPool.sol";
import "./interfaces/IDelegateApprovals.sol";

/**
 * @title SynthetixAdapter
 * @author Lyra
 * @dev Manages access to exchange functions on Synthetix.
 * The OptionMarket contract address is used as the key to access the relevant exchange parameters for the market.
 */
contract SynthetixAdapter is OwnedUpgradeable {
  using DecimalMath for uint;

  /**
   * @dev Structs to help reduce the number of calls between other contracts and this one
   * Grouped in usage for a particular contract/use case
   */
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
  mapping(address => bool) public isMarketPaused;
  bool public isGlobalPaused;

  IAddressResolver public addressResolver;

  bytes32 private constant CONTRACT_SYNTHETIX = "ProxySynthetix";
  bytes32 private constant CONTRACT_EXCHANGER = "Exchanger";
  bytes32 private constant CONTRACT_EXCHANGE_RATES = "ExchangeRates";
  bytes32 private constant CONTRACT_DELEGATE_APPROVALS = "DelegateApprovals";

  // Cached addresses that can be updated via a public function
  ISynthetix public synthetix;
  IExchanger public exchanger;
  IExchangeRates public exchangeRates;
  IDelegateApprovals public delegateApprovals;

  // Variables related to calculating premium/fees
  mapping(address => bytes32) public quoteKey;
  mapping(address => bytes32) public baseKey;
  mapping(address => address) public rewardAddress;
  mapping(address => bytes32) public trackingCode;

  function initialize() external initializer {
    __Ownable_init();
  }

  /////////////
  // Setters //
  /////////////

  /**
   * @dev Set the address of the Synthetix address resolver.
   *
   * @param _addressResolver The address of Synthetix's AddressResolver.
   */
  function setAddressResolver(IAddressResolver _addressResolver) external onlyOwner {
    addressResolver = _addressResolver;
    updateSynthetixAddresses();
    emit AddressResolverSet(addressResolver);
  }

  /**
   * @dev Set the synthetixAdapter for a specific OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _quoteKey The key of the quoteAsset.
   * @param _baseKey The key of the baseAsset.
   */
  function setGlobalsForContract(
    address _contractAddress,
    bytes32 _quoteKey,
    bytes32 _baseKey,
    address _rewardAddress,
    bytes32 _trackingCode
  ) external onlyOwner {
    if (_rewardAddress == address(0)) {
      revert InvalidRewardAddress(address(this), _rewardAddress);
    }
    quoteKey[_contractAddress] = _quoteKey;
    baseKey[_contractAddress] = _baseKey;
    rewardAddress[_contractAddress] = _rewardAddress;
    trackingCode[_contractAddress] = _trackingCode;
    emit GlobalsSetForContract(_contractAddress, _quoteKey, _baseKey, _rewardAddress, _trackingCode);
  }

  /**
   * @dev Pauses all market actions for a given market.
   *
   * @param _isPaused Whether getting synthetixAdapter will revert or not.
   */
  function setMarketPaused(address _contractAddress, bool _isPaused) external onlyOwner {
    isMarketPaused[_contractAddress] = _isPaused;
    emit MarketPausedSet(_contractAddress, _isPaused);
  }

  /**
   * @dev Pauses all market actions for all markets.
   *
   * @param _isPaused Whether getting synthetixAdapter will revert or not.
   */
  function setGlobalPaused(bool _isPaused) external onlyOwner {
    isGlobalPaused = _isPaused;
    emit GlobalPausedSet(_isPaused);
  }

  //////////////////////
  // Address Resolver //
  //////////////////////

  /**
   * @dev Public function to update synthetix addresses Lyra uses. The addresses are cached this way for gas efficiency.
   */
  function updateSynthetixAddresses() public {
    synthetix = ISynthetix(addressResolver.getAddress(CONTRACT_SYNTHETIX));
    exchanger = IExchanger(addressResolver.getAddress(CONTRACT_EXCHANGER));
    exchangeRates = IExchangeRates(addressResolver.getAddress(CONTRACT_EXCHANGE_RATES));
    delegateApprovals = IDelegateApprovals(addressResolver.getAddress(CONTRACT_DELEGATE_APPROVALS));

    emit SynthetixAddressesUpdated(synthetix, exchanger, exchangeRates, delegateApprovals);
  }

  /////////////
  // Getters //
  /////////////
  /**
   * @notice Returns the price of the baseAsset.
   *
   * @param _contractAddress The address of the OptionMarket.
   */
  function getSpotPriceForMarket(address _contractAddress)
    public
    view
    notPaused(_contractAddress)
    returns (uint spotPrice)
  {
    return getSpotPrice(baseKey[_contractAddress]);
  }

  /**
   * @notice Gets spot price of an asset.
   * @dev All rates are denominated in terms of sUSD,
   * so the price of sUSD is always $1.00, and is never stale.
   *
   * @param to The key of the synthetic asset.
   */
  function getSpotPrice(bytes32 to) public view returns (uint) {
    (uint spotPrice, bool invalid) = exchangeRates.rateAndInvalid(to);
    if (spotPrice == 0 || invalid) {
      revert RateIsInvalid(address(this), spotPrice, invalid);
    }
    return spotPrice;
  }

  /**
   * @notice Returns the ExchangeParams.
   *
   * @param optionMarket The address of the OptionMarket.
   */
  function getExchangeParams(address optionMarket)
    public
    view
    notPaused(optionMarket)
    returns (ExchangeParams memory exchangeParams)
  {
    exchangeParams = ExchangeParams({
      spotPrice: 0,
      quoteKey: quoteKey[optionMarket],
      baseKey: baseKey[optionMarket],
      quoteBaseFeeRate: 0,
      baseQuoteFeeRate: 0
    });

    exchangeParams.spotPrice = getSpotPrice(exchangeParams.baseKey);
    exchangeParams.quoteBaseFeeRate = exchanger.feeRateForExchange(exchangeParams.quoteKey, exchangeParams.baseKey);
    exchangeParams.baseQuoteFeeRate = exchanger.feeRateForExchange(exchangeParams.baseKey, exchangeParams.quoteKey);
  }

  /// @dev Revert if the global state is paused
  function requireNotGlobalPaused(address optionMarket) external view {
    if (isGlobalPaused) {
      revert AllMarketsPaused(address(this), optionMarket);
    }
  }

  /////////////////////////////////////////
  // Exchanging QuoteAsset for BaseAsset //
  /////////////////////////////////////////

  /**
   * @notice Swap an exact amount of quote for base.
   *
   * @param optionMarket The base asset of this option market to receive
   * @param amountQuote The exact amount of quote to be used for the swap
   * @return baseReceived The amount of base received from the swap
   */
  function exchangeFromExactQuote(address optionMarket, uint amountQuote) external returns (uint baseReceived) {
    return _exchangeQuoteForBase(optionMarket, amountQuote);
  }

  /**
   * @notice Swap quote for an exact amount of base.
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param optionMarket The base asset of this option market to receive
   * @param amountBase The exact amount of base to receive from the swap
   * @return quoteSpent The amount of quote spent on the swap
   * @return baseReceived The amount of base received
   */
  function exchangeToExactBase(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase
  ) external returns (uint quoteSpent, uint baseReceived) {
    return exchangeToExactBaseWithLimit(exchangeParams, optionMarket, amountBase, type(uint).max);
  }

  /**
   * @notice Swap quote for base with a limit on the amount of quote to be spent.
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param optionMarket The base asset of this option market to receive
   * @param amountBase The exact amount of base to receive from the swap
   * @param quoteLimit The maximum amount of quote to spend for base
   * @return quoteSpent The amount of quote spent on the swap
   * @return baseReceived The amount of baes received from the swap
   */
  function exchangeToExactBaseWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountBase,
    uint quoteLimit
  ) public returns (uint quoteSpent, uint baseReceived) {
    uint quoteToSpend = estimateExchangeToExactBase(exchangeParams, amountBase);
    if (quoteToSpend > quoteLimit) {
      revert QuoteBaseExchangeExceedsLimit(
        address(this),
        amountBase,
        quoteToSpend,
        quoteLimit,
        exchangeParams.spotPrice,
        exchangeParams.quoteKey,
        exchangeParams.baseKey
      );
    }

    return (quoteToSpend, _exchangeQuoteForBase(optionMarket, quoteToSpend));
  }

  function _exchangeQuoteForBase(address optionMarket, uint amountQuote) internal returns (uint baseReceived) {
    if (amountQuote == 0) {
      return 0;
    }
    baseReceived = synthetix.exchangeOnBehalfWithTracking(
      msg.sender,
      quoteKey[optionMarket],
      amountQuote,
      baseKey[optionMarket],
      rewardAddress[optionMarket],
      trackingCode[optionMarket]
    );
    if (amountQuote > 1e10 && baseReceived == 0) {
      revert ReceivedZeroFromExchange(
        address(this),
        quoteKey[optionMarket],
        baseKey[optionMarket],
        amountQuote,
        baseReceived
      );
    }
    emit QuoteSwappedForBase(optionMarket, msg.sender, amountQuote, baseReceived);
    return baseReceived;
  }

  /**
   * @notice Returns an estimated amount of quote required to swap for the specified amount of base.
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param amountBase The amount of base to receive
   * @return quoteNeeded The amount of quote required to received the amount of base requested
   */
  function estimateExchangeToExactBase(ExchangeParams memory exchangeParams, uint amountBase)
    public
    pure
    returns (uint quoteNeeded)
  {
    return
      amountBase.divideDecimalRound(DecimalMath.UNIT - exchangeParams.quoteBaseFeeRate).multiplyDecimalRound(
        exchangeParams.spotPrice
      );
  }

  /////////////////////////////////////////
  // Exchanging BaseAsset for QuoteAsset //
  /////////////////////////////////////////

  /**
   * @notice Swap an exact amount of base for quote.
   *
   * @param optionMarket The base asset of this optionMarket to be used
   * @param amountBase The exact amount of base to be used for the swap
   * @return quoteReceived The amount of quote received from the swap
   */
  function exchangeFromExactBase(address optionMarket, uint amountBase) external returns (uint quoteReceived) {
    return _exchangeBaseForQuote(optionMarket, amountBase);
  }

  /**
   * @notice Swap base for an exact amount of quote
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param optionMarket The base asset of this optionMarket to be used
   * @param amountQuote The exact amount of quote to receive
   * @return baseSpent The amount of baseSpent on the swap
   * @return quoteReceived The amount of quote received from the swap
   */
  function exchangeToExactQuote(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote
  ) external returns (uint baseSpent, uint quoteReceived) {
    return exchangeToExactQuoteWithLimit(exchangeParams, optionMarket, amountQuote, type(uint).max);
  }

  /**
   * @notice Swap base for an exact amount of quote with a limit on the amount of base to be used
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param optionMarket The base asset of this optionMarket to be used
   * @param amountQuote The exact amount of quote to receive
   * @param baseLimit The limit on the amount of base to be used
   * @return baseSpent The amount of base spent on the swap
   * @return quoteReceived The amount of quote received from the swap
   */
  function exchangeToExactQuoteWithLimit(
    ExchangeParams memory exchangeParams,
    address optionMarket,
    uint amountQuote,
    uint baseLimit
  ) public returns (uint baseSpent, uint quoteReceived) {
    uint baseToSpend = estimateExchangeToExactQuote(exchangeParams, amountQuote);
    if (baseToSpend > baseLimit) {
      revert BaseQuoteExchangeExceedsLimit(
        address(this),
        amountQuote,
        baseToSpend,
        baseLimit,
        exchangeParams.spotPrice,
        exchangeParams.baseKey,
        exchangeParams.quoteKey
      );
    }

    return (baseToSpend, _exchangeBaseForQuote(optionMarket, baseToSpend));
  }

  function _exchangeBaseForQuote(address optionMarket, uint amountBase) internal returns (uint quoteReceived) {
    if (amountBase == 0) {
      return 0;
    }
    // swap exactly `amountBase` baseAsset for quoteAsset
    quoteReceived = synthetix.exchangeOnBehalfWithTracking(
      msg.sender,
      baseKey[optionMarket],
      amountBase,
      quoteKey[optionMarket],
      rewardAddress[optionMarket],
      trackingCode[optionMarket]
    );
    if (amountBase > 1e10 && quoteReceived == 0) {
      revert ReceivedZeroFromExchange(
        address(this),
        baseKey[optionMarket],
        quoteKey[optionMarket],
        amountBase,
        quoteReceived
      );
    }
    emit BaseSwappedForQuote(optionMarket, msg.sender, amountBase, quoteReceived);
    return quoteReceived;
  }

  /**
   * @notice Returns an estimated amount of base required to swap for the amount of quote
   *
   * @param exchangeParams The current exchange rates for the swap
   * @param amountQuote The amount of quote to swap to
   * @return baseNeeded The amount of base required for the swap
   */
  function estimateExchangeToExactQuote(ExchangeParams memory exchangeParams, uint amountQuote)
    public
    pure
    returns (uint baseNeeded)
  {
    return
      amountQuote.divideDecimalRound(DecimalMath.UNIT - exchangeParams.baseQuoteFeeRate).divideDecimalRound(
        exchangeParams.spotPrice
      );
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier notPaused(address _contractAddress) {
    if (isGlobalPaused) {
      revert AllMarketsPaused(address(this), _contractAddress);
    }
    if (isMarketPaused[_contractAddress]) {
      revert MarketIsPaused(address(this), _contractAddress);
    }
    _;
  }

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
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";
import "./synthetix/SignedDecimalMath.sol";

// Inherited
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";

// Interfaces
import "openzeppelin-contracts-4.4.1/token/ERC20/ERC20.sol";
import "./libraries/BlackScholes.sol";
import "./SynthetixAdapter.sol";
import "./OptionMarket.sol";
import "./OptionMarketPricer.sol";
import "./libraries/GWAV.sol";

/**
 * @title OptionGreekCache
 * @author Lyra
 * @dev Aggregates the netDelta and netStdVega of the OptionMarket by iterating over current strikes, using gwav vols.
 * Needs to be called by an external actor as it's not feasible to do all the computation during the trade flow and
 * because delta/vega change over time and with movements in asset price and volatility.
 * All stored values in this contract are the aggregate of the trader's perspective. So values need to be inverted
 * to get the LP's perspective
 * Also handles logic for figuring out minimal collateral requirements for shorts.
 */
contract OptionGreekCache is Owned, SimpleInitializeable, ReentrancyGuard {
  using DecimalMath for uint;
  using SignedDecimalMath for int;
  using GWAV for GWAV.Params;
  using BlackScholes for BlackScholes.BlackScholesInputs;

  ////////////////
  // Parameters //
  ////////////////

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

  ///////////////
  // Variables //
  ///////////////
  SynthetixAdapter internal synthetixAdapter;
  OptionMarket internal optionMarket;
  address internal optionMarketPricer;

  GreekCacheParameters internal greekCacheParams;
  ForceCloseParameters internal forceCloseParams;
  MinCollateralParameters internal minCollatParams;

  // Cached values and GWAVs
  /// @dev Should be a clone of OptionMarket.liveBoards
  uint[] internal liveBoards;
  GlobalCache internal globalCache;

  mapping(uint => OptionBoardCache) internal boardCaches;
  mapping(uint => GWAV.Params) internal boardIVGWAV;

  mapping(uint => StrikeCache) internal strikeCaches;
  mapping(uint => GWAV.Params) internal strikeSkewGWAV;

  ///////////
  // Setup //
  ///////////

  constructor() Owned() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _synthetixAdapter SynthetixAdapter address
   * @param _optionMarket OptionMarket address
   * @param _optionMarketPricer OptionMarketPricer address
   */
  function init(
    SynthetixAdapter _synthetixAdapter,
    OptionMarket _optionMarket,
    address _optionMarketPricer
  ) external onlyOwner initializer {
    synthetixAdapter = _synthetixAdapter;
    optionMarket = _optionMarket;
    optionMarketPricer = _optionMarketPricer;
  }

  ///////////
  // Admin //
  ///////////

  function setGreekCacheParameters(GreekCacheParameters memory _greekCacheParams) external onlyOwner {
    if (
      !(_greekCacheParams.acceptableSpotPricePercentMove <= 10e18 && //
        _greekCacheParams.staleUpdateDuration <= 30 days && //
        _greekCacheParams.varianceIvGWAVPeriod > 0 && //
        _greekCacheParams.varianceIvGWAVPeriod <= 60 days && //
        _greekCacheParams.varianceSkewGWAVPeriod > 0 &&
        _greekCacheParams.varianceSkewGWAVPeriod <= 60 days &&
        _greekCacheParams.optionValueIvGWAVPeriod > 0 &&
        _greekCacheParams.optionValueIvGWAVPeriod <= 60 days &&
        _greekCacheParams.optionValueSkewGWAVPeriod > 0 &&
        _greekCacheParams.optionValueSkewGWAVPeriod <= 60 days &&
        _greekCacheParams.gwavSkewFloor <= 1e18 &&
        _greekCacheParams.gwavSkewFloor > 0 &&
        _greekCacheParams.gwavSkewCap >= 1e18 &&
        _greekCacheParams.rateAndCarry >= -50e18 &&
        _greekCacheParams.rateAndCarry <= 50e18)
    ) {
      revert InvalidGreekCacheParameters(address(this), _greekCacheParams);
    }

    greekCacheParams = _greekCacheParams;
    emit GreekCacheParametersSet(greekCacheParams);
  }

  function setForceCloseParameters(ForceCloseParameters memory _forceCloseParams) external onlyOwner {
    if (
      !(_forceCloseParams.ivGWAVPeriod > 0 &&
        _forceCloseParams.ivGWAVPeriod <= 60 days &&
        _forceCloseParams.skewGWAVPeriod > 0 &&
        _forceCloseParams.skewGWAVPeriod <= 60 days &&
        _forceCloseParams.shortVolShock >= 1e18 &&
        _forceCloseParams.shortPostCutoffVolShock >= 1e18 &&
        _forceCloseParams.longVolShock > 0 &&
        _forceCloseParams.longVolShock <= 1e18 &&
        _forceCloseParams.longPostCutoffVolShock > 0 &&
        _forceCloseParams.longPostCutoffVolShock <= 1e18 &&
        _forceCloseParams.liquidateVolShock >= 1e18 &&
        _forceCloseParams.liquidatePostCutoffVolShock >= 1e18 &&
        _forceCloseParams.shortSpotMin <= 1e18 &&
        _forceCloseParams.liquidateSpotMin <= 1e18)
    ) {
      revert InvalidForceCloseParameters(address(this), _forceCloseParams);
    }

    forceCloseParams = _forceCloseParams;
    emit ForceCloseParametersSet(forceCloseParams);
  }

  function setMinCollateralParameters(MinCollateralParameters memory _minCollatParams) external onlyOwner {
    if (
      !(_minCollatParams.minStaticQuoteCollateral > 0 &&
        _minCollatParams.minStaticBaseCollateral > 0 &&
        _minCollatParams.shockVolA > 0 &&
        _minCollatParams.shockVolA >= _minCollatParams.shockVolB &&
        _minCollatParams.shockVolPointA <= _minCollatParams.shockVolPointB &&
        _minCollatParams.callSpotPriceShock >= 1e18 &&
        _minCollatParams.putSpotPriceShock > 0 &&
        _minCollatParams.putSpotPriceShock <= 1e18)
    ) {
      revert InvalidMinCollatParams(address(this), _minCollatParams);
    }

    minCollatParams = _minCollatParams;
    emit MinCollateralParametersSet(minCollatParams);
  }

  //////////////////////////////////////////////////////
  // Sync Boards with OptionMarket (onlyOptionMarket) //
  //////////////////////////////////////////////////////

  /**
   * @notice Adds a new OptionBoardCache
   * @dev Called by the OptionMarket whenever a new OptionBoard is added
   *
   * @param board The new OptionBoard
   * @param strikes The new Strikes for the given board
   */
  function addBoard(OptionMarket.OptionBoard memory board, OptionMarket.Strike[] memory strikes)
    external
    onlyOptionMarket
  {
    uint strikesLength = strikes.length;
    if (strikesLength > greekCacheParams.maxStrikesPerBoard) {
      revert BoardStrikeLimitExceeded(address(this), board.id, strikesLength, greekCacheParams.maxStrikesPerBoard);
    }

    OptionBoardCache storage boardCache = boardCaches[board.id];
    boardCache.id = board.id;
    boardCache.expiry = board.expiry;
    boardCache.iv = board.iv;
    boardCache.updatedAt = block.timestamp;
    emit BoardCacheUpdated(boardCache);
    boardIVGWAV[board.id]._initialize(board.iv, block.timestamp);
    emit BoardIvUpdated(boardCache.id, board.iv, globalCache.maxIvVariance);

    liveBoards.push(board.id);

    for (uint i = 0; i < strikesLength; ++i) {
      _addNewStrikeToStrikeCache(boardCache, strikes[i].id, strikes[i].strikePrice, strikes[i].skew);
    }

    updateBoardCachedGreeks(board.id);
  }

  /// @dev After board settlement, remove an OptionBoardCache. Called by OptionMarket
  function removeBoard(uint boardId) external onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionBoardCache memory boardCache = boardCaches[boardId];
    globalCache.netGreeks.netDelta -= boardCache.netGreeks.netDelta;
    globalCache.netGreeks.netStdVega -= boardCache.netGreeks.netStdVega;
    globalCache.netGreeks.netOptionValue -= boardCache.netGreeks.netOptionValue;

    // Clean up, cache isn't necessary for settle logic
    uint boardStrikesLength = boardCache.strikes.length;
    for (uint i = 0; i < boardStrikesLength; ++i) {
      emit StrikeCacheRemoved(boardCache.strikes[i]);
      delete strikeCaches[boardCache.strikes[i]];
    }
    uint liveBoardsLength = liveBoards.length;
    for (uint i = 0; i < liveBoardsLength; ++i) {
      if (liveBoards[i] == boardId) {
        liveBoards[i] = liveBoards[liveBoardsLength - 1];
        liveBoards.pop();
        break;
      }
    }
    emit BoardCacheRemoved(boardId);
    emit GlobalCacheUpdated(globalCache);
    delete boardCaches[boardId];
  }

  /// @dev Add a new strike to a given boardCache. Only callable by OptionMarket.
  function addStrikeToBoard(
    uint boardId,
    uint strikeId,
    uint strikePrice,
    uint skew
  ) external onlyOptionMarket {
    OptionBoardCache storage boardCache = boardCaches[boardId];
    if (boardCache.strikes.length == greekCacheParams.maxStrikesPerBoard) {
      revert BoardStrikeLimitExceeded(
        address(this),
        boardId,
        boardCache.strikes.length + 1,
        greekCacheParams.maxStrikesPerBoard
      );
    }

    _addNewStrikeToStrikeCache(boardCache, strikeId, strikePrice, skew);
    updateBoardCachedGreeks(boardId);
  }

  /// @dev Updates an OptionBoard's baseIv. Only callable by OptionMarket.
  function setBoardIv(uint boardId, uint newBaseIv) external onlyOptionMarket {
    OptionBoardCache storage boardCache = boardCaches[boardId];
    _updateBoardIv(boardCache, newBaseIv);
    emit BoardIvUpdated(boardId, newBaseIv, globalCache.maxIvVariance);
  }

  /**
   * @dev Updates a Strike's skew. Only callable by OptionMarket.
   *
   * @param strikeId The id of the Strike
   * @param newSkew The new skew of the given Strike
   */
  function setStrikeSkew(uint strikeId, uint newSkew) external onlyOptionMarket {
    StrikeCache storage strikeCache = strikeCaches[strikeId];
    OptionBoardCache storage boardCache = boardCaches[strikeCache.boardId];
    _updateStrikeSkew(boardCache, strikeCache, newSkew);
  }

  /// @dev Adds a new strike to a given board, initialising the skew GWAV
  function _addNewStrikeToStrikeCache(
    OptionBoardCache storage boardCache,
    uint strikeId,
    uint strikePrice,
    uint skew
  ) internal {
    // This is only called when a new board or a new strike is added, so exposure values will be 0
    StrikeCache storage strikeCache = strikeCaches[strikeId];
    strikeCache.id = strikeId;
    strikeCache.strikePrice = strikePrice;
    strikeCache.skew = skew;
    strikeCache.boardId = boardCache.id;

    emit StrikeCacheUpdated(strikeCache);

    strikeSkewGWAV[strikeId]._initialize(
      _max(_min(skew, greekCacheParams.gwavSkewCap), greekCacheParams.gwavSkewFloor),
      block.timestamp
    );

    emit StrikeSkewUpdated(strikeCache.id, skew, globalCache.maxSkewVariance);

    boardCache.strikes.push(strikeId);
  }

  //////////////////////////////////////////////
  // Updating exposure/getting option pricing //
  //////////////////////////////////////////////

  /**
   * @notice During a trade, updates the exposure of the given strike, board and global state. Computes the cost of the
   * trade and returns it to the OptionMarketPricer.
   * @return pricing The final price of the option to be paid for by the user. This could use marketVol or shockVol,
   * depending on the trade executed.
   */
  function updateStrikeExposureAndGetPrice(
    OptionMarket.Strike memory strike,
    OptionMarket.TradeParameters memory trade,
    uint iv,
    uint skew,
    bool isPostCutoff
  ) external onlyOptionMarketPricer returns (TradePricing memory pricing) {
    StrikeCache storage strikeCache = strikeCaches[strike.id];
    OptionBoardCache storage boardCache = boardCaches[strikeCache.boardId];

    _updateBoardIv(boardCache, iv);
    _updateStrikeSkew(boardCache, strikeCache, skew);

    pricing = _updateStrikeExposureAndGetPrice(
      strikeCache,
      boardCache,
      trade,
      SafeCast.toInt256(strike.longCall) - SafeCast.toInt256(strike.shortCallBase + strike.shortCallQuote),
      SafeCast.toInt256(strike.longPut) - SafeCast.toInt256(strike.shortPut)
    );

    pricing.ivVariance = boardCache.ivVariance;

    // If this is a force close or liquidation, override the option price, delta and volTraded based on pricing for
    // force closes.
    if (trade.isForceClose) {
      (pricing.optionPrice, pricing.volTraded) = getPriceForForceClose(
        trade,
        strike,
        boardCache.expiry,
        iv.multiplyDecimal(skew),
        isPostCutoff
      );
    }

    return pricing;
  }

  /// @dev Updates the exposure of the strike and computes the market black scholes price
  function _updateStrikeExposureAndGetPrice(
    StrikeCache storage strikeCache,
    OptionBoardCache storage boardCache,
    OptionMarket.TradeParameters memory trade,
    int newCallExposure,
    int newPutExposure
  ) internal returns (TradePricing memory pricing) {
    BlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega = BlackScholes
      .BlackScholesInputs({
        timeToExpirySec: _timeToMaturitySeconds(boardCache.expiry),
        volatilityDecimal: boardCache.iv.multiplyDecimal(strikeCache.skew),
        spotDecimal: trade.exchangeParams.spotPrice,
        strikePriceDecimal: strikeCache.strikePrice,
        rateDecimal: greekCacheParams.rateAndCarry
      })
      .pricesDeltaStdVega();

    int strikeOptionValue = (newCallExposure - strikeCache.callExposure).multiplyDecimal(
      SafeCast.toInt256(strikeCache.greeks.callPrice)
    ) + (newPutExposure - strikeCache.putExposure).multiplyDecimal(SafeCast.toInt256(strikeCache.greeks.putPrice));

    int netDeltaDiff = (newCallExposure - strikeCache.callExposure).multiplyDecimal(strikeCache.greeks.callDelta) +
      (newPutExposure - strikeCache.putExposure).multiplyDecimal(strikeCache.greeks.putDelta);

    int netStdVegaDiff = (newCallExposure + newPutExposure - strikeCache.callExposure - strikeCache.putExposure)
      .multiplyDecimal(SafeCast.toInt256(strikeCache.greeks.stdVega));

    strikeCache.callExposure = newCallExposure;
    strikeCache.putExposure = newPutExposure;
    boardCache.netGreeks.netOptionValue += strikeOptionValue;
    boardCache.netGreeks.netDelta += netDeltaDiff;
    boardCache.netGreeks.netStdVega += netStdVegaDiff;

    // The AMM's net std vega is opposite to the global sum of user's std vega
    pricing.preTradeAmmNetStdVega = -globalCache.netGreeks.netStdVega;

    globalCache.netGreeks.netOptionValue += strikeOptionValue;
    globalCache.netGreeks.netDelta += netDeltaDiff;
    globalCache.netGreeks.netStdVega += netStdVegaDiff;

    pricing.optionPrice = (trade.optionType != OptionMarket.OptionType.LONG_PUT &&
      trade.optionType != OptionMarket.OptionType.SHORT_PUT_QUOTE)
      ? pricesDeltaStdVega.callPrice
      : pricesDeltaStdVega.putPrice;
    // AMM's net positions are the inverse of the user's net position
    pricing.postTradeAmmNetStdVega = -globalCache.netGreeks.netStdVega;
    pricing.callDelta = pricesDeltaStdVega.callDelta;
    pricing.volTraded = boardCache.iv.multiplyDecimal(strikeCache.skew);
    pricing.vega = pricesDeltaStdVega.vega;

    emit StrikeCacheUpdated(strikeCache);
    emit BoardCacheUpdated(boardCache);
    emit GlobalCacheUpdated(globalCache);

    return pricing;
  }

  /////////////////////////////////////
  // Liquidation/Force Close pricing //
  /////////////////////////////////////

  /**
   * @notice Calculate price paid by the user to forceClose an options position
   * 
   * @param trade TradeParameter as defined in OptionMarket
   * @param strike strikes details (including total exposure)
   * @param expiry expiry of option
   * @param newVol volatility post slippage as determined in `OptionTokOptionMarketPriceren.ivImpactForTrade()`
   * @param isPostCutoff flag for whether order is closer to expiry than postCutoff param.

   * @return optionPrice premium to charge for close order (excluding fees added in OptionMarketPricer)
   * @return forceCloseVol volatility used to calculate optionPrice
   */
  function getPriceForForceClose(
    OptionMarket.TradeParameters memory trade,
    OptionMarket.Strike memory strike,
    uint expiry,
    uint newVol,
    bool isPostCutoff
  ) public view returns (uint optionPrice, uint forceCloseVol) {
    forceCloseVol = _getGWAVVolWithOverride(
      strike.boardId,
      strike.id,
      forceCloseParams.ivGWAVPeriod,
      forceCloseParams.skewGWAVPeriod
    );

    if (trade.tradeDirection == OptionMarket.TradeDirection.CLOSE) {
      // If the tradeDirection is a close, we know the user force closed.
      if (trade.isBuy) {
        // closing a short - maximise vol
        forceCloseVol = _max(forceCloseVol, newVol);
        forceCloseVol = isPostCutoff
          ? forceCloseVol.multiplyDecimal(forceCloseParams.shortPostCutoffVolShock)
          : forceCloseVol.multiplyDecimal(forceCloseParams.shortVolShock);
      } else {
        // closing a long - minimise vol
        forceCloseVol = _min(forceCloseVol, newVol);
        forceCloseVol = isPostCutoff
          ? forceCloseVol.multiplyDecimal(forceCloseParams.longPostCutoffVolShock)
          : forceCloseVol.multiplyDecimal(forceCloseParams.longVolShock);
      }
    } else {
      // Otherwise it can only be a liquidation
      forceCloseVol = isPostCutoff
        ? forceCloseVol.multiplyDecimal(forceCloseParams.liquidatePostCutoffVolShock)
        : forceCloseVol.multiplyDecimal(forceCloseParams.liquidateVolShock);
    }

    (uint callPrice, uint putPrice) = BlackScholes
      .BlackScholesInputs({
        timeToExpirySec: _timeToMaturitySeconds(expiry),
        volatilityDecimal: forceCloseVol,
        spotDecimal: trade.exchangeParams.spotPrice,
        strikePriceDecimal: strike.strikePrice,
        rateDecimal: greekCacheParams.rateAndCarry
      })
      .optionPrices();

    uint price = (trade.optionType == OptionMarket.OptionType.LONG_PUT ||
      trade.optionType == OptionMarket.OptionType.SHORT_PUT_QUOTE)
      ? putPrice
      : callPrice;

    if (trade.isBuy) {
      // In the case a short is being closed, ensure the AMM doesn't overpay by charging parity + some excess
      uint parity = _getParity(strike.strikePrice, trade.exchangeParams.spotPrice, trade.optionType);
      uint minPrice = parity +
        trade.exchangeParams.spotPrice.multiplyDecimal(
          trade.tradeDirection == OptionMarket.TradeDirection.CLOSE
            ? forceCloseParams.shortSpotMin
            : forceCloseParams.liquidateSpotMin
        );
      price = _max(price, minPrice);
    }

    return (price, forceCloseVol);
  }

  function _getGWAVVolWithOverride(
    uint boardId,
    uint strikeId,
    uint overrideIvPeriod,
    uint overrideSkewPeriod
  ) internal view returns (uint gwavVol) {
    uint gwavIV = boardIVGWAV[boardId].getGWAVForPeriod(overrideIvPeriod, 0);
    uint strikeGWAVSkew = strikeSkewGWAV[strikeId].getGWAVForPeriod(overrideSkewPeriod, 0);
    return gwavIV.multiplyDecimal(strikeGWAVSkew);
  }

  /**
   * @notice Gets minimum collateral requirement for the specified option
   *
   * @param optionType The option type
   * @param strikePrice The strike price of the option
   * @param expiry The expiry of the option
   * @param spotPrice The price of the underlying asset
   * @param amount The size of the option
   */
  function getMinCollateral(
    OptionMarket.OptionType optionType,
    uint strikePrice,
    uint expiry,
    uint spotPrice,
    uint amount
  ) external view returns (uint minCollateral) {
    if (amount == 0) {
      return 0;
    }

    // If put, reduce spot by percentage. If call, increase.
    uint shockPrice = (optionType == OptionMarket.OptionType.SHORT_PUT_QUOTE)
      ? spotPrice.multiplyDecimal(minCollatParams.putSpotPriceShock)
      : spotPrice.multiplyDecimal(minCollatParams.callSpotPriceShock);

    uint timeToMaturity = _timeToMaturitySeconds(expiry);

    (uint callPrice, uint putPrice) = BlackScholes
      .BlackScholesInputs({
        timeToExpirySec: timeToMaturity,
        volatilityDecimal: getShockVol(timeToMaturity),
        spotDecimal: shockPrice,
        strikePriceDecimal: strikePrice,
        rateDecimal: greekCacheParams.rateAndCarry
      })
      .optionPrices();

    uint fullCollat;
    uint volCollat;
    uint staticCollat = minCollatParams.minStaticQuoteCollateral;
    if (optionType == OptionMarket.OptionType.SHORT_CALL_BASE) {
      // Can be more lenient to SHORT_CALL_BASE traders
      volCollat = callPrice.multiplyDecimal(amount).divideDecimal(shockPrice);
      fullCollat = amount;
      staticCollat = minCollatParams.minStaticBaseCollateral;
    } else if (optionType == OptionMarket.OptionType.SHORT_CALL_QUOTE) {
      volCollat = callPrice.multiplyDecimal(amount);
      fullCollat = type(uint).max;
    } else {
      // optionType == OptionMarket.OptionType.SHORT_PUT_QUOTE
      volCollat = putPrice.multiplyDecimal(amount);
      fullCollat = amount.multiplyDecimal(strikePrice);
    }

    return _min(_max(volCollat, staticCollat), fullCollat);
  }

  /// @notice Gets shock vol (Vol used to compute the minimum collateral requirements for short positions)
  function getShockVol(uint timeToMaturity) public view returns (uint) {
    if (timeToMaturity <= minCollatParams.shockVolPointA) {
      return minCollatParams.shockVolA;
    }
    if (timeToMaturity >= minCollatParams.shockVolPointB) {
      return minCollatParams.shockVolB;
    }

    // Flip a and b so we don't need to convert to int
    return
      minCollatParams.shockVolA -
      (((minCollatParams.shockVolA - minCollatParams.shockVolB) * (timeToMaturity - minCollatParams.shockVolPointA)) /
        (minCollatParams.shockVolPointB - minCollatParams.shockVolPointA));
  }

  //////////////////////////////////////////
  // Update GWAV vol greeks and net greeks //
  //////////////////////////////////////////

  /**
   * @notice Updates the cached greeks for an OptionBoardCache used to calculate:
   * - trading fees
   * - aggregate AMM option value
   * - net delta exposure for proper hedging
   *
   * @param boardId The id of the OptionBoardCache.
   */
  function updateBoardCachedGreeks(uint boardId) public nonReentrant {
    _updateBoardCachedGreeks(synthetixAdapter.getSpotPriceForMarket(address(optionMarket)), boardId);
  }

  function _updateBoardCachedGreeks(uint spotPrice, uint boardId) internal {
    OptionBoardCache storage boardCache = boardCaches[boardId];
    if (boardCache.id == 0) {
      revert InvalidBoardId(address(this), boardCache.id);
    }

    if (block.timestamp > boardCache.expiry) {
      revert CannotUpdateExpiredBoard(address(this), boardCache.id, boardCache.expiry, block.timestamp);
    }

    // Zero out the board net greeks and recompute all strikes, adding to the totals
    globalCache.netGreeks.netOptionValue -= boardCache.netGreeks.netOptionValue;
    globalCache.netGreeks.netDelta -= boardCache.netGreeks.netDelta;
    globalCache.netGreeks.netStdVega -= boardCache.netGreeks.netStdVega;

    boardCache.netGreeks.netOptionValue = 0;
    boardCache.netGreeks.netDelta = 0;
    boardCache.netGreeks.netStdVega = 0;

    _updateBoardIvVariance(boardCache);
    uint navGWAVbaseIv = boardIVGWAV[boardId].getGWAVForPeriod(greekCacheParams.optionValueIvGWAVPeriod, 0);

    uint strikesLen = boardCache.strikes.length;
    for (uint i = 0; i < strikesLen; ++i) {
      StrikeCache storage strikeCache = strikeCaches[boardCache.strikes[i]];
      _updateStrikeSkewVariance(strikeCache);

      // update variance for strike skew
      uint strikeNavGWAVSkew = strikeSkewGWAV[strikeCache.id].getGWAVForPeriod(
        greekCacheParams.optionValueSkewGWAVPeriod,
        0
      );
      uint navGWAVvol = navGWAVbaseIv.multiplyDecimal(strikeNavGWAVSkew);

      _updateStrikeCachedGreeks(strikeCache, boardCache, spotPrice, navGWAVvol);
    }

    _updateMaxSkewVariance(boardCache);
    _updateMaxIvVariance();

    boardCache.updatedAt = block.timestamp;
    boardCache.updatedAtPrice = spotPrice;

    _updateGlobalLastUpdatedAt();

    emit BoardIvUpdated(boardCache.id, boardCache.iv, globalCache.maxIvVariance);
    emit BoardCacheUpdated(boardCache);
    emit GlobalCacheUpdated(globalCache);
  }

  /**
   * @dev Updates an StrikeCache using TWAP.
   * Assumes board has been zeroed out before updating all strikes at once
   *
   * @param strikeCache The StrikeCache.
   * @param boardCache The OptionBoardCache.
   */
  function _updateStrikeCachedGreeks(
    StrikeCache storage strikeCache,
    OptionBoardCache storage boardCache,
    uint spotPrice,
    uint navGWAVvol
  ) internal {
    BlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega = BlackScholes
      .BlackScholesInputs({
        timeToExpirySec: _timeToMaturitySeconds(boardCache.expiry),
        volatilityDecimal: navGWAVvol,
        spotDecimal: spotPrice,
        strikePriceDecimal: strikeCache.strikePrice,
        rateDecimal: greekCacheParams.rateAndCarry
      })
      .pricesDeltaStdVega();

    strikeCache.greeks.callPrice = pricesDeltaStdVega.callPrice;
    strikeCache.greeks.putPrice = pricesDeltaStdVega.putPrice;
    strikeCache.greeks.callDelta = pricesDeltaStdVega.callDelta;
    strikeCache.greeks.putDelta = pricesDeltaStdVega.putDelta;
    strikeCache.greeks.stdVega = pricesDeltaStdVega.stdVega;

    // only update board/global if exposure present
    if (strikeCache.callExposure != 0 || strikeCache.putExposure != 0) {
      int strikeOptionValue = (strikeCache.callExposure).multiplyDecimal(
        SafeCast.toInt256(strikeCache.greeks.callPrice)
      ) + (strikeCache.putExposure).multiplyDecimal(SafeCast.toInt256(strikeCache.greeks.putPrice));

      int strikeNetDelta = strikeCache.callExposure.multiplyDecimal(strikeCache.greeks.callDelta) +
        strikeCache.putExposure.multiplyDecimal(strikeCache.greeks.putDelta);

      int strikeNetStdVega = (strikeCache.callExposure + strikeCache.putExposure).multiplyDecimal(
        SafeCast.toInt256(strikeCache.greeks.stdVega)
      );

      boardCache.netGreeks.netOptionValue += strikeOptionValue;
      boardCache.netGreeks.netDelta += strikeNetDelta;
      boardCache.netGreeks.netStdVega += strikeNetStdVega;

      globalCache.netGreeks.netOptionValue += strikeOptionValue;
      globalCache.netGreeks.netDelta += strikeNetDelta;
      globalCache.netGreeks.netStdVega += strikeNetStdVega;
    }

    emit StrikeCacheUpdated(strikeCache);
    emit StrikeSkewUpdated(strikeCache.id, strikeCache.skew, globalCache.maxSkewVariance);
  }

  /// @dev Updates global `lastUpdatedAt`.
  function _updateGlobalLastUpdatedAt() internal {
    OptionBoardCache storage boardCache = boardCaches[liveBoards[0]];
    uint minUpdatedAt = boardCache.updatedAt;
    uint minUpdatedAtPrice = boardCache.updatedAtPrice;
    uint maxUpdatedAtPrice = boardCache.updatedAtPrice;
    uint maxSkewVariance = boardCache.maxSkewVariance;
    uint maxIvVariance = boardCache.ivVariance;

    uint liveBoardsLen = liveBoards.length;
    for (uint i = 1; i < liveBoardsLen; ++i) {
      boardCache = boardCaches[liveBoards[i]];
      if (boardCache.updatedAt < minUpdatedAt) {
        minUpdatedAt = boardCache.updatedAt;
      }
      if (boardCache.updatedAtPrice < minUpdatedAtPrice) {
        minUpdatedAtPrice = boardCache.updatedAtPrice;
      }
      if (boardCache.updatedAtPrice > maxUpdatedAtPrice) {
        maxUpdatedAtPrice = boardCache.updatedAtPrice;
      }
      if (boardCache.maxSkewVariance > maxSkewVariance) {
        maxSkewVariance = boardCache.maxSkewVariance;
      }
      if (boardCache.ivVariance > maxIvVariance) {
        maxIvVariance = boardCache.ivVariance;
      }
    }

    globalCache.minUpdatedAt = minUpdatedAt;
    globalCache.minUpdatedAtPrice = minUpdatedAtPrice;
    globalCache.maxUpdatedAtPrice = maxUpdatedAtPrice;
    globalCache.maxSkewVariance = maxSkewVariance;
    globalCache.maxIvVariance = maxIvVariance;
  }

  /////////////////////////
  // Updating GWAV values //
  /////////////////////////

  /// @dev updates baseIv for a given board, updating the baseIv gwav
  function _updateBoardIv(OptionBoardCache storage boardCache, uint newIv) internal {
    boardCache.iv = newIv;
    boardIVGWAV[boardCache.id]._write(newIv, block.timestamp);
    _updateBoardIvVariance(boardCache);
    _updateMaxIvVariance();

    emit BoardIvUpdated(boardCache.id, newIv, globalCache.maxIvVariance);
  }

  /// @dev updates skew for a given strike, updating the skew gwav
  function _updateStrikeSkew(
    OptionBoardCache storage boardCache,
    StrikeCache storage strikeCache,
    uint newSkew
  ) internal {
    strikeCache.skew = newSkew;

    strikeSkewGWAV[strikeCache.id]._write(
      _max(_min(newSkew, greekCacheParams.gwavSkewCap), greekCacheParams.gwavSkewFloor),
      block.timestamp
    );
    // Update variance
    _updateStrikeSkewVariance(strikeCache);
    _updateMaxSkewVariance(boardCache);

    emit StrikeSkewUpdated(strikeCache.id, newSkew, globalCache.maxSkewVariance);
  }

  /// @dev updates maxIvVariance across all boards
  function _updateMaxIvVariance() internal {
    uint maxIvVariance = boardCaches[liveBoards[0]].ivVariance;
    uint liveBoardsLen = liveBoards.length;
    for (uint i = 1; i < liveBoardsLen; ++i) {
      if (boardCaches[liveBoards[i]].ivVariance > maxIvVariance) {
        maxIvVariance = boardCaches[liveBoards[i]].ivVariance;
      }
    }
    globalCache.maxIvVariance = maxIvVariance;
  }

  /// @dev updates skewVariance for strike, used to trigger CBs and charge varianceFees
  function _updateStrikeSkewVariance(StrikeCache storage strikeCache) internal {
    uint strikeVarianceGWAVSkew = strikeSkewGWAV[strikeCache.id].getGWAVForPeriod(
      greekCacheParams.varianceSkewGWAVPeriod,
      0
    );

    if (strikeVarianceGWAVSkew >= strikeCache.skew) {
      strikeCache.skewVariance = strikeVarianceGWAVSkew - strikeCache.skew;
    } else {
      strikeCache.skewVariance = strikeCache.skew - strikeVarianceGWAVSkew;
    }
  }

  /// @dev updates ivVariance for board, used to trigger CBs and charge varianceFees
  function _updateBoardIvVariance(OptionBoardCache storage boardCache) internal {
    uint boardVarianceGWAVIv = boardIVGWAV[boardCache.id].getGWAVForPeriod(greekCacheParams.varianceIvGWAVPeriod, 0);

    if (boardVarianceGWAVIv >= boardCache.iv) {
      boardCache.ivVariance = boardVarianceGWAVIv - boardCache.iv;
    } else {
      boardCache.ivVariance = boardCache.iv - boardVarianceGWAVIv;
    }
  }

  /// @dev updates maxSkewVariance for the board and across all strikes
  function _updateMaxSkewVariance(OptionBoardCache storage boardCache) internal {
    uint maxBoardSkewVariance = strikeCaches[boardCache.strikes[0]].skewVariance;
    uint strikesLen = boardCache.strikes.length;
    for (uint i = 1; i < strikesLen; ++i) {
      if (strikeCaches[boardCache.strikes[i]].skewVariance > maxBoardSkewVariance) {
        maxBoardSkewVariance = strikeCaches[boardCache.strikes[i]].skewVariance;
      }
    }
    boardCache.maxSkewVariance = maxBoardSkewVariance;

    uint maxSkewVariance = boardCaches[liveBoards[0]].maxSkewVariance;
    uint liveBoardsLen = liveBoards.length;

    for (uint i = 1; i < liveBoardsLen; ++i) {
      if (boardCaches[liveBoards[i]].maxSkewVariance > maxSkewVariance) {
        maxSkewVariance = boardCaches[liveBoards[i]].maxSkewVariance;
      }
    }
    globalCache.maxSkewVariance = maxSkewVariance;
  }

  //////////////////////////
  // Stale cache checking //
  //////////////////////////

  /**
   * @notice returns `true` if even one board not updated within `staleUpdateDuration` or
   *         if spot price moves up/down beyond `acceptablePriceMovement`
   */

  function isGlobalCacheStale(uint spotPrice) external view returns (bool) {
    if (liveBoards.length == 0) {
      return false;
    } else {
      return (_isUpdatedAtTimeStale(globalCache.minUpdatedAt) ||
        !_isPriceMoveAcceptable(globalCache.minUpdatedAtPrice, spotPrice) ||
        !_isPriceMoveAcceptable(globalCache.maxUpdatedAtPrice, spotPrice));
    }
  }

  /**
   * @notice returns `true` if board not updated within `staleUpdateDuration` or
   *         if spot price moves up/down beyond `acceptablePriceMovement`
   */
  function isBoardCacheStale(uint boardId) external view returns (bool) {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
    OptionBoardCache memory boardCache = boardCaches[boardId];
    if (boardCache.id == 0) {
      revert InvalidBoardId(address(this), boardCache.id);
    }
    return (_isUpdatedAtTimeStale(boardCache.updatedAt) ||
      !_isPriceMoveAcceptable(boardCache.updatedAtPrice, spotPrice));
  }

  /**
   * @notice Check if the price move of base asset renders the cache stale.
   *
   * @param pastPrice The previous price.
   * @param currentPrice The current price.
   */
  function _isPriceMoveAcceptable(uint pastPrice, uint currentPrice) internal view returns (bool) {
    uint acceptablePriceMovement = pastPrice.multiplyDecimal(greekCacheParams.acceptableSpotPricePercentMove);
    if (currentPrice > pastPrice) {
      return (currentPrice - pastPrice) < acceptablePriceMovement;
    } else {
      return (pastPrice - currentPrice) < acceptablePriceMovement;
    }
  }

  /**
   * @notice Checks if board updated within `staleUpdateDuration`.
   *
   * @param updatedAt The time of the last update.
   */
  function _isUpdatedAtTimeStale(uint updatedAt) internal view returns (bool) {
    // This can be more complex than just checking the item wasn't updated in the last two hours
    return _getSecondsTo(updatedAt, block.timestamp) > greekCacheParams.staleUpdateDuration;
  }

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  /// @notice Get the current cached global netDelta exposure.
  function getGlobalNetDelta() external view returns (int) {
    return globalCache.netGreeks.netDelta;
  }

  /// @notice Get the current global net option value
  function getGlobalOptionValue() external view returns (int) {
    return globalCache.netGreeks.netOptionValue;
  }

  /// @notice Returns the BoardGreeksView struct given a specific boardId
  function getBoardGreeksView(uint boardId) external view returns (BoardGreeksView memory) {
    uint strikesLen = boardCaches[boardId].strikes.length;

    StrikeGreeks[] memory strikeGreeks = new StrikeGreeks[](strikesLen);
    uint[] memory skewGWAVs = new uint[](strikesLen);
    for (uint i = 0; i < strikesLen; ++i) {
      strikeGreeks[i] = strikeCaches[boardCaches[boardId].strikes[i]].greeks;
      skewGWAVs[i] = strikeSkewGWAV[boardCaches[boardId].strikes[i]].getGWAVForPeriod(
        forceCloseParams.skewGWAVPeriod,
        0
      );
    }
    return
      BoardGreeksView({
        boardGreeks: boardCaches[boardId].netGreeks,
        ivGWAV: boardIVGWAV[boardId].getGWAVForPeriod(forceCloseParams.ivGWAVPeriod, 0),
        strikeGreeks: strikeGreeks,
        skewGWAVs: skewGWAVs
      });
  }

  /// @notice Get StrikeCache given a specific strikeId
  function getStrikeCache(uint strikeId) external view returns (StrikeCache memory) {
    return (strikeCaches[strikeId]);
  }

  /// @notice Get OptionBoardCache given a specific boardId
  function getOptionBoardCache(uint boardId) external view returns (OptionBoardCache memory) {
    return (boardCaches[boardId]);
  }

  /// @notice Get the global cache
  function getGlobalCache() external view returns (GlobalCache memory) {
    return globalCache;
  }

  /// @notice Returns ivGWAV for a given boardId and GWAV time interval
  function getIvGWAV(uint boardId, uint secondsAgo) external view returns (uint ivGWAV) {
    return boardIVGWAV[boardId].getGWAVForPeriod(secondsAgo, 0);
  }

  /// @notice Returns skewGWAV for a given strikeId and GWAV time interval
  function getSkewGWAV(uint strikeId, uint secondsAgo) external view returns (uint skewGWAV) {
    return strikeSkewGWAV[strikeId].getGWAVForPeriod(secondsAgo, 0);
  }

  /// @notice Get the GreekCacheParameters
  function getGreekCacheParams() external view returns (GreekCacheParameters memory) {
    return greekCacheParams;
  }

  /// @notice Get the ForceCloseParamters
  function getForceCloseParams() external view returns (ForceCloseParameters memory) {
    return forceCloseParams;
  }

  /// @notice Get the MinCollateralParamters
  function getMinCollatParams() external view returns (MinCollateralParameters memory) {
    return minCollatParams;
  }

  ////////////////////////////
  // Utility/Math functions //
  ////////////////////////////

  /// @dev Calculate option payout on expiry given a strikePrice, spot on expiry and optionType.
  function _getParity(
    uint strikePrice,
    uint spot,
    OptionMarket.OptionType optionType
  ) internal pure returns (uint parity) {
    int diff = (optionType == OptionMarket.OptionType.LONG_PUT || optionType == OptionMarket.OptionType.SHORT_PUT_QUOTE)
      ? SafeCast.toInt256(strikePrice) - SafeCast.toInt256(spot)
      : SafeCast.toInt256(spot) - SafeCast.toInt256(strikePrice);

    parity = diff > 0 ? uint(diff) : 0;
  }

  /// @dev Returns time to maturity for a given expiry.
  function _timeToMaturitySeconds(uint expiry) internal view returns (uint) {
    return _getSecondsTo(block.timestamp, expiry);
  }

  /// @dev Returns the difference in seconds between two dates.
  function _getSecondsTo(uint fromTime, uint toTime) internal pure returns (uint) {
    if (toTime > fromTime) {
      return toTime - fromTime;
    }
    return 0;
  }

  function _min(uint x, uint y) internal pure returns (uint) {
    return (x < y) ? x : y;
  }

  function _max(uint x, uint y) internal pure returns (uint) {
    return (x > y) ? x : y;
  }

  ///////////////
  // Modifiers //
  ///////////////
  modifier onlyOptionMarket() {
    if (msg.sender != address(optionMarket)) {
      revert OnlyOptionMarket(address(this), msg.sender, address(optionMarket));
    }
    _;
  }

  modifier onlyOptionMarketPricer() {
    if (msg.sender != address(optionMarketPricer)) {
      revert OnlyOptionMarketPricer(address(this), msg.sender, address(optionMarketPricer));
    }
    _;
  }

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
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
  error OnlyOptionMarketPricer(address thrower, address caller, address optionMarketPricer);
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

// Libraries
import "./synthetix/DecimalMath.sol";

// Inherited
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";

// Interfaces
import "openzeppelin-contracts-4.4.1/token/ERC20/ERC20.sol";
import "./LiquidityToken.sol";
import "./OptionGreekCache.sol";
import "./OptionMarket.sol";
import "./libraries/PoolHedger.sol";

/**
 * @title LiquidityPool
 * @author Lyra
 * @dev Holds funds from LPs, which are used for the following purposes:
 * 1. Collateralizing options sold by the OptionMarket.
 * 2. Buying options from users.
 * 3. Delta hedging the LPs.
 * 4. Storing funds for expired in the money options.
 */
contract LiquidityPool is Owned, SimpleInitializeable, ReentrancyGuard {
  using DecimalMath for uint;

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

  SynthetixAdapter internal synthetixAdapter;
  OptionMarket internal optionMarket;
  LiquidityToken internal liquidityToken;
  ShortCollateral internal shortCollateral;
  OptionGreekCache internal greekCache;
  PoolHedger public poolHedger;
  ERC20 internal quoteAsset;
  ERC20 internal baseAsset;

  mapping(uint => QueuedDeposit) public queuedDeposits;
  /// @dev The total amount of quoteAsset pending deposit (that hasn't entered the pool)
  uint public totalQueuedDeposits = 0;

  /// @dev The next queue item that needs to be processed
  uint public queuedDepositHead = 1;
  uint public nextQueuedDepositId = 1;

  mapping(uint => QueuedWithdrawal) public queuedWithdrawals;
  uint public totalQueuedWithdrawals = 0;

  /// @dev The next queue item that needs to be processed
  uint public queuedWithdrawalHead = 1;
  uint public nextQueuedWithdrawalId = 1;

  /// @dev Parameters relating to depositing and withdrawing from the Lyra LP
  LiquidityPoolParameters public lpParams;

  // timestamp for when deposits/withdrawals will be available to deposit/withdraw
  // This checks if liquidity is all used - adds 3 days to block.timestamp if it is
  // This also checks if vol variance is high - adds 12 hrs to block.timestamp if it is
  uint public CBTimestamp = 0;

  ////
  // Other Variables
  ////
  /// @dev Amount of collateral locked for outstanding calls and puts sold to users
  Collateral public lockedCollateral;
  /// @dev Total amount of quoteAsset reserved for all settled options that have yet to be paid out
  uint public totalOutstandingSettlements;

  /// @dev Total value not transferred to this contract for all shorts that didn't have enough collateral after expiry
  uint public insolventSettlementAmount;
  /// @dev Total value not transferred to this contract for all liquidations that didn't have enough collateral when liquidated
  uint public liquidationInsolventAmount;

  ///////////
  // Setup //
  ///////////

  constructor() Owned() {}

  /// @dev Initialise important addresses for the contract
  function init(
    SynthetixAdapter _synthetixAdapter,
    OptionMarket _optionMarket,
    LiquidityToken _liquidityToken,
    OptionGreekCache _greekCache,
    PoolHedger _poolHedger,
    ShortCollateral _shortCollateral,
    ERC20 _quoteAsset,
    ERC20 _baseAsset
  ) external onlyOwner initializer {
    synthetixAdapter = _synthetixAdapter;
    optionMarket = _optionMarket;
    liquidityToken = _liquidityToken;
    greekCache = _greekCache;
    shortCollateral = _shortCollateral;
    poolHedger = _poolHedger;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
    synthetixAdapter.delegateApprovals().approveExchangeOnBehalf(address(synthetixAdapter));
  }

  ///////////
  // Admin //
  ///////////

  /// @notice set `LiquidityPoolParameteres`
  function setLiquidityPoolParameters(LiquidityPoolParameters memory _lpParams) external onlyOwner {
    if (
      !(_lpParams.depositDelay < 365 days &&
        _lpParams.withdrawalDelay < 365 days &&
        _lpParams.withdrawalFee < 2e17 &&
        _lpParams.liquidityCBThreshold < 1e18 &&
        _lpParams.liquidityCBTimeout < 60 days &&
        _lpParams.ivVarianceCBTimeout < 60 days &&
        _lpParams.skewVarianceCBTimeout < 60 days &&
        _lpParams.guardianDelay < 365 days &&
        _lpParams.boardSettlementCBTimeout < 10 days)
    ) {
      revert InvalidLiquidityPoolParameters(address(this), _lpParams);
    }

    lpParams = _lpParams;

    emit LiquidityPoolParametersUpdated(lpParams);
  }

  /// @dev Swap out current PoolHedger with a new contract
  function setPoolHedger(PoolHedger newPoolHedger) external onlyOwner {
    poolHedger = newPoolHedger;
    emit PoolHedgerUpdated(poolHedger);
  }

  /// @dev In case of an update to the synthetix contract that revokes the approval
  function updateDelegateApproval() external onlyOwner {
    synthetixAdapter.delegateApprovals().approveExchangeOnBehalf(address(synthetixAdapter));
  }

  //////////////////////////////
  // Deposits and Withdrawals //
  //////////////////////////////

  /**
   * @notice LP will send sUSD into the contract in return for LiquidityToken (representative of their share of the entire pool)
   *         to be given either instantly (if no live boards) or after the delay period passes (including CBs).
   *         This action is not reversible.
   *
   * @param beneficiary will receive the LiquidityToken after the deposit is processed
   * @param amountQuote is the amount of sUSD the LP is depositing
   */
  function initiateDeposit(address beneficiary, uint amountQuote) external nonReentrant {
    if (beneficiary == address(0)) {
      revert InvalidBeneficiaryAddress(address(this), beneficiary);
    }
    if (amountQuote < lpParams.minDepositWithdraw) {
      revert MinimumDepositNotMet(address(this), amountQuote, lpParams.minDepositWithdraw);
    }
    if (optionMarket.getNumLiveBoards() == 0) {
      uint tokenPrice = getTokenPrice();
      uint amountTokens = amountQuote.divideDecimal(tokenPrice);
      liquidityToken.mint(beneficiary, amountTokens);
      emit DepositProcessed(msg.sender, beneficiary, 0, amountQuote, tokenPrice, amountTokens, block.timestamp);
    } else {
      QueuedDeposit storage newDeposit = queuedDeposits[nextQueuedDepositId];

      newDeposit.id = nextQueuedDepositId++;
      newDeposit.beneficiary = beneficiary;
      newDeposit.amountLiquidity = amountQuote;
      newDeposit.depositInitiatedTime = block.timestamp;

      totalQueuedDeposits += amountQuote;

      emit DepositQueued(msg.sender, beneficiary, newDeposit.id, amountQuote, totalQueuedDeposits, block.timestamp);
    }

    if (!quoteAsset.transferFrom(msg.sender, address(this), amountQuote)) {
      revert QuoteTransferFailed(address(this), msg.sender, address(this), amountQuote);
    }
  }

  /**
   * @notice LP instantly burns LiquidityToken, signalling they wish to withdraw
   *         their share of the pool in exchange for quote, to be processed instantly (if no live boards)
   *         or after the delay period passes (including CBs).
   *         This action is not reversible.
   *
   *
   * @param beneficiary will receive sUSD after the withdrawal is processed
   * @param amountLiquidityToken: is the amount of LiquidityToken the LP is withdrawing
   */
  function initiateWithdraw(address beneficiary, uint amountLiquidityToken) external nonReentrant {
    if (beneficiary == address(0)) {
      revert InvalidBeneficiaryAddress(address(this), beneficiary);
    }
    if (amountLiquidityToken < lpParams.minDepositWithdraw) {
      revert MinimumWithdrawNotMet(address(this), amountLiquidityToken, lpParams.minDepositWithdraw);
    }
    if (optionMarket.getNumLiveBoards() == 0) {
      uint tokenPrice = getTokenPrice();
      uint quoteReceived = amountLiquidityToken.multiplyDecimal(tokenPrice);
      _transferQuote(beneficiary, quoteReceived);
      emit WithdrawProcessed(
        msg.sender,
        beneficiary,
        0,
        amountLiquidityToken,
        tokenPrice,
        quoteReceived,
        totalQueuedWithdrawals,
        block.timestamp
      );
    } else {
      QueuedWithdrawal storage newWithdrawal = queuedWithdrawals[nextQueuedWithdrawalId];

      newWithdrawal.id = nextQueuedWithdrawalId++;
      newWithdrawal.beneficiary = beneficiary;
      newWithdrawal.amountTokens = amountLiquidityToken;
      newWithdrawal.withdrawInitiatedTime = block.timestamp;

      totalQueuedWithdrawals += amountLiquidityToken;

      emit WithdrawQueued(
        msg.sender,
        beneficiary,
        newWithdrawal.id,
        amountLiquidityToken,
        totalQueuedWithdrawals,
        block.timestamp
      );
    }
    liquidityToken.burn(msg.sender, amountLiquidityToken);
  }

  /// @param limit number of deposit tickets to process in a single transaction to avoid gas limit soft-locks
  function processDepositQueue(uint limit) external nonReentrant {
    (uint tokenPrice, bool stale, ) = _getTokenPriceAndStale();

    for (uint i = 0; i < limit; ++i) {
      QueuedDeposit storage current = queuedDeposits[queuedDepositHead];
      if (!_canProcess(current.depositInitiatedTime, lpParams.depositDelay, stale, queuedDepositHead)) {
        return;
      }

      uint amountTokens = current.amountLiquidity.divideDecimal(tokenPrice);
      liquidityToken.mint(current.beneficiary, amountTokens);
      current.mintedTokens = amountTokens;
      totalQueuedDeposits -= current.amountLiquidity;

      emit DepositProcessed(
        msg.sender,
        current.beneficiary,
        queuedDepositHead,
        current.amountLiquidity,
        tokenPrice,
        amountTokens,
        block.timestamp
      );
      current.amountLiquidity = 0;

      queuedDepositHead++;
    }
  }

  /// @param limit number of withdrawal tickets to process in a single transaction to avoid gas limit soft-locks
  function processWithdrawalQueue(uint limit) external nonReentrant {
    for (uint i = 0; i < limit; ++i) {
      (uint totalTokensBurnable, uint tokenPriceWithFee, bool stale) = _getTotalBurnableTokens();

      QueuedWithdrawal storage current = queuedWithdrawals[queuedWithdrawalHead];

      if (!_canProcess(current.withdrawInitiatedTime, lpParams.withdrawalDelay, stale, queuedWithdrawalHead)) {
        return;
      }

      if (totalTokensBurnable == 0) {
        return;
      }

      uint burnAmount = current.amountTokens;
      if (burnAmount > totalTokensBurnable) {
        burnAmount = totalTokensBurnable;
      }

      current.amountTokens -= burnAmount;
      totalQueuedWithdrawals -= burnAmount;

      uint quoteAmount = burnAmount.multiplyDecimal(tokenPriceWithFee);
      current.quoteSent += quoteAmount;
      _transferQuote(current.beneficiary, quoteAmount);
      if (current.amountTokens > 0) {
        emit WithdrawPartiallyProcessed(
          msg.sender,
          current.beneficiary,
          queuedWithdrawalHead,
          burnAmount,
          tokenPriceWithFee,
          quoteAmount,
          totalQueuedWithdrawals,
          block.timestamp
        );
        return;
      }
      emit WithdrawProcessed(
        msg.sender,
        current.beneficiary,
        queuedWithdrawalHead,
        burnAmount,
        tokenPriceWithFee,
        quoteAmount,
        totalQueuedWithdrawals,
        block.timestamp
      );
      queuedWithdrawalHead++;
    }
  }

  /// @dev Checks if deposit/withdrawal ticket can be processed
  function _canProcess(
    uint initiatedTime,
    uint minimumDelay,
    bool isStale,
    uint entryId
  ) internal returns (bool) {
    bool validEntry = initiatedTime != 0;
    // bypass circuit breaker and stale checks if the guardian is calling and their delay has passed
    bool guardianBypass = msg.sender == lpParams.guardianMultisig &&
      initiatedTime + lpParams.guardianDelay < block.timestamp;
    // if minimum delay or circuit breaker timeout hasn't passed, we can't process
    bool delaysExpired = initiatedTime + minimumDelay < block.timestamp && CBTimestamp < block.timestamp;

    emit CheckingCanProcess(entryId, !isStale, validEntry, guardianBypass, delaysExpired);

    return validEntry && ((!isStale && delaysExpired) || guardianBypass);
  }

  function _getTotalBurnableTokens()
    internal
    returns (
      uint tokensBurnable,
      uint tokenPriceWithFee,
      bool stale
    )
  {
    uint burnableLiquidity;
    uint tokenPrice;
    (tokenPrice, stale, burnableLiquidity) = _getTokenPriceAndStale();

    if (optionMarket.getNumLiveBoards() != 0) {
      tokenPriceWithFee = tokenPrice.multiplyDecimal(DecimalMath.UNIT - lpParams.withdrawalFee);
    } else {
      tokenPriceWithFee = tokenPrice;
    }

    return (burnableLiquidity.divideDecimal(tokenPriceWithFee), tokenPriceWithFee, stale);
  }

  function _getTokenPriceAndStale()
    internal
    returns (
      uint tokenPrice,
      bool,
      uint burnableLiquidity
    )
  {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));

    OptionGreekCache.GlobalCache memory globalCache = greekCache.getGlobalCache();
    bool stale = greekCache.isGlobalCacheStale(spotPrice);

    (uint pendingDelta, uint usedDelta) = _getPoolHedgerLiquidity(spotPrice);

    uint totalPoolValue = _getTotalPoolValueQuote(spotPrice, usedDelta, globalCache.netGreeks.netOptionValue);
    uint totalTokenSupply = getTotalTokenSupply();
    tokenPrice = _getTokenPrice(totalPoolValue, totalTokenSupply);

    uint queuedTokenValue = tokenPrice.multiplyDecimal(totalQueuedWithdrawals);

    Liquidity memory liquidity = _getLiquidity(spotPrice, totalPoolValue, queuedTokenValue, usedDelta, pendingDelta);

    _updateCBs(liquidity, globalCache.maxIvVariance, globalCache.maxSkewVariance, globalCache.netGreeks.netOptionValue);

    return (tokenPrice, stale, liquidity.burnableLiquidity);
  }

  //////////////////////
  // Circuit Breakers //
  //////////////////////

  /// @notice Checks the ivVariance, skewVariance, and liquidity circuit breakers and triggers if necessary
  function updateCBs() external nonReentrant {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
    OptionGreekCache.GlobalCache memory globalCache = greekCache.getGlobalCache();
    Liquidity memory liquidity = getLiquidity(spotPrice);
    _updateCBs(liquidity, globalCache.maxIvVariance, globalCache.maxSkewVariance, globalCache.netGreeks.netOptionValue);
  }

  function _updateCBs(
    Liquidity memory liquidity,
    uint maxIvVariance,
    uint maxSkewVariance,
    int optionValueDebt
  ) internal {
    // don't trigger CBs if pool has no open options
    if (liquidity.usedCollatLiquidity == 0 && optionValueDebt == 0) {
      return;
    }

    uint timeToAdd = 0;

    // if NAV == 0, openAmount will be zero too and _updateCB() won't be called.
    uint freeLiquidityPercent = liquidity.freeLiquidity.divideDecimal(liquidity.NAV);

    bool ivVarianceThresholdCrossed = maxIvVariance > lpParams.ivVarianceCBThreshold;
    bool skewVarianceThresholdCrossed = maxSkewVariance > lpParams.skewVarianceCBThreshold;
    bool liquidityThresholdCrossed = freeLiquidityPercent < lpParams.liquidityCBThreshold;

    if (ivVarianceThresholdCrossed) {
      timeToAdd = lpParams.ivVarianceCBTimeout;
    }

    if (skewVarianceThresholdCrossed && lpParams.skewVarianceCBTimeout > timeToAdd) {
      timeToAdd = lpParams.skewVarianceCBTimeout;
    }

    if (liquidityThresholdCrossed && lpParams.liquidityCBTimeout > timeToAdd) {
      timeToAdd = lpParams.liquidityCBTimeout;
    }

    if (timeToAdd > 0 && CBTimestamp < block.timestamp + timeToAdd) {
      CBTimestamp = block.timestamp + timeToAdd;
      emit CircuitBreakerUpdated(
        CBTimestamp,
        ivVarianceThresholdCrossed,
        skewVarianceThresholdCrossed,
        liquidityThresholdCrossed
      );
    }
  }

  ///////////////////////
  // Only OptionMarket //
  ///////////////////////

  /**
   * @notice Locks quote as collateral when the AMM sells a put option.
   *
   * @param amount The amount of quote to lock.
   * @param freeLiquidity The amount of free collateral that can be locked.
   */
  function lockQuote(uint amount, uint freeLiquidity) external onlyOptionMarket {
    if (amount > freeLiquidity) {
      revert LockingMoreQuoteThanIsFree(address(this), amount, freeLiquidity, lockedCollateral);
    }
    lockedCollateral.quote += amount;
    emit QuoteLocked(amount, lockedCollateral.quote);
  }

  /**
   * @notice Purchases and locks base as collateral when the AMM sells a call option.
   *
   * @param amount The amount of baseAsset to purchase and lock.
   * @param exchangeParams The exchangeParams.
   * @param freeLiquidity The amount of free collateral that can be locked.
   */
  function lockBase(
    uint amount,
    SynthetixAdapter.ExchangeParams memory exchangeParams,
    uint freeLiquidity
  ) external onlyOptionMarket {
    lockedCollateral.base += amount;
    _maybeExchangeBase(exchangeParams, freeLiquidity, true);
    emit BaseLocked(amount, lockedCollateral.base);
  }

  /**
   * @notice Frees quote collateral when user closes a long put
   *         and sends them the option premium
   *
   * @param amountQuoteFreed The amount of quote to free.
   */
  function freeQuoteCollateralAndSendPremium(
    uint amountQuoteFreed,
    address recipient,
    uint totalCost,
    uint reservedFee
  ) external onlyOptionMarket {
    _freeQuoteCollateral(amountQuoteFreed);
    _sendPremium(recipient, totalCost, reservedFee);
  }

  /**
   * @notice Frees/exchange base collateral when user closes a long call
   *         and sends the option premium to the user
   *
   * @param amountBase The amount of base to free and exchange.
   */
  function liquidateBaseAndSendPremium(
    uint amountBase,
    address recipient,
    uint totalCost,
    uint reservedFee
  ) external onlyOptionMarket {
    _freeBase(amountBase);
    exchangeBase();
    _sendPremium(recipient, totalCost, reservedFee);
  }

  /**
   * @notice Sends premium user selling an option to the pool.
   * @dev The caller must be the OptionMarket.
   *
   * @param recipient The address of the recipient.
   * @param premium The amount to transfer to the user.
   * @param freeLiquidity The amount of free collateral liquidity.
   * @param reservedFee The amount collected by the OptionMarket.
   */
  function sendShortPremium(
    address recipient,
    uint premium,
    uint freeLiquidity,
    uint reservedFee
  ) external onlyOptionMarket {
    if (premium + reservedFee > freeLiquidity) {
      revert SendPremiumNotEnoughCollateral(address(this), premium, reservedFee, freeLiquidity);
    }
    _sendPremium(recipient, premium, reservedFee);
  }

  /**
   * @notice Manages collateral at the time of board liquidation, also converting base received from shortCollateral.
   *
   * @param insolventSettlements amount of AMM profits not paid by shortCollateral due to user insolvencies.
   * @param amountQuoteFreed amount of AMM long put quote collateral that can be freed, including ITM profits.
   * @param amountQuoteReserved amount of AMM quote reserved for long call/put ITM profits.
   * @param amountBaseFreed amount of AMM long call base collateral that can be freed, including ITM profits.
   */
  function boardSettlement(
    uint insolventSettlements,
    uint amountQuoteFreed,
    uint amountQuoteReserved,
    uint amountBaseFreed
  ) external onlyOptionMarket {
    // Update circuit breaker whenever a board is settled, to pause deposits/withdrawals
    // This allows keepers some time to settle insolvent positions
    if (block.timestamp + lpParams.boardSettlementCBTimeout > CBTimestamp) {
      CBTimestamp = block.timestamp + lpParams.boardSettlementCBTimeout;
      emit BoardSettlementCircuitBreakerUpdated(CBTimestamp);
    }

    insolventSettlementAmount += insolventSettlements;

    _freeQuoteCollateral(amountQuoteFreed);
    _freeBase(amountBaseFreed);

    totalOutstandingSettlements += amountQuoteReserved;
    emit BoardSettlement(insolventSettlementAmount, amountQuoteReserved, totalOutstandingSettlements);

    if (address(poolHedger) != address(0)) {
      poolHedger.resetInteractionDelay();
    }
  }

  /**
   * @notice Frees quote when the AMM buys back/settles a put from the user.
   * @param amountQuote The amount of quote to free.
   */
  function _freeQuoteCollateral(uint amountQuote) internal {
    // In case of rounding errors
    amountQuote = amountQuote > lockedCollateral.quote ? lockedCollateral.quote : amountQuote;
    lockedCollateral.quote -= amountQuote;
    emit QuoteFreed(amountQuote, lockedCollateral.quote);
  }

  /**
   * @notice Frees base when the AMM buys back/settles a call from the user.
   * @param amountBase The amount of base to free.
   */

  function _freeBase(uint amountBase) internal {
    // In case of rounding errors
    amountBase = amountBase > lockedCollateral.base ? lockedCollateral.base : amountBase;
    lockedCollateral.base -= amountBase;
    emit BaseFreed(amountBase, lockedCollateral.base);
  }

  /**
   * @notice Sends the premium to a user who is closing a long or opening a short.
   * @dev The caller must be the OptionMarket.
   *
   * @param recipient The address of the recipient.
   * @param recipientAmount The amount to transfer to the recipient.
   * @param optionMarketPortion The fee to transfer to the optionMarket.
   */
  function _sendPremium(
    address recipient,
    uint recipientAmount,
    uint optionMarketPortion
  ) internal {
    _transferQuote(recipient, recipientAmount);
    _transferQuote(address(optionMarket), optionMarketPortion);

    emit PremiumTransferred(recipient, recipientAmount, optionMarketPortion);
  }

  //////////////////////////
  // Only ShortCollateral //
  //////////////////////////

  /**
   * @notice Transfers long option settlement profits to `user`.
   * @dev The caller must be the ShortCollateral.
   *
   * @param user The address of the user to send the quote.
   * @param amount The amount of quote to send.
   */
  function sendSettlementValue(address user, uint amount) external onlyShortCollateral {
    // To prevent any potential rounding errors
    if (amount > totalOutstandingSettlements) {
      amount = totalOutstandingSettlements;
    }
    totalOutstandingSettlements -= amount;
    _transferQuote(user, amount);

    emit OutstandingSettlementSent(user, amount, totalOutstandingSettlements);
  }

  /**
   * @notice Claims AMM profits that were not paid during boardSettlement() due to
   * total quote insolvencies > total solvent quote collateral.
   * @dev The caller must be ShortCollateral.
   *
   * @param spotPrice The current spot price of the base asset.
   * @param amountQuote The amount of quote to send to the LiquidityPool.
   */
  function reclaimInsolventQuote(uint spotPrice, uint amountQuote) external onlyShortCollateral {
    Liquidity memory liquidity = getLiquidity(spotPrice);
    if (amountQuote > liquidity.freeLiquidity) {
      revert NotEnoughFreeToReclaimInsolvency(address(this), amountQuote, liquidity);
    }
    _transferQuote(address(shortCollateral), amountQuote);

    insolventSettlementAmount += amountQuote;

    emit InsolventSettlementAmountUpdated(amountQuote, insolventSettlementAmount);
  }

  /**
   * @notice Claims AMM profits that were not paid during boardSettlement() due to
   * total base insolvencies > total solvent base collateral.
   * @dev The caller must be ShortCollateral.
   *
   * @param exchangeParams synthetix exchange parameters.
   * @param amountBase The amount of base to send to the LiquidityPool.
   */

  function reclaimInsolventBase(SynthetixAdapter.ExchangeParams memory exchangeParams, uint amountBase)
    external
    onlyShortCollateral
  {
    Liquidity memory liquidity = getLiquidity(exchangeParams.spotPrice);
    (uint quoteSpent, ) = synthetixAdapter.exchangeToExactBaseWithLimit(
      exchangeParams,
      address(optionMarket),
      amountBase,
      liquidity.freeLiquidity
    );
    insolventSettlementAmount += quoteSpent;
    // It is better for the contract to revert if there is not enough here (due to rounding) to keep accounting in
    // ShortCollateral correct. baseAsset can be donated (sent) to this contract to allow this to pass.
    if (!baseAsset.transfer(address(shortCollateral), amountBase)) {
      revert BaseTransferFailed(address(this), address(this), address(shortCollateral), amountBase);
    }

    emit InsolventSettlementAmountUpdated(quoteSpent, insolventSettlementAmount);
  }

  //////////////////////////////
  // Getting Pool Token Value //
  //////////////////////////////

  /// @dev Get total number of oustanding LiquidityToken
  function getTotalTokenSupply() public view returns (uint) {
    return liquidityToken.totalSupply() + totalQueuedWithdrawals;
  }

  /**
   * @notice Get current pool token price and check if market conditions warrant an accurate token price
   *
   * @return tokenPrice price of token
   * @return isStale has global cache not been updated in a long time (if stale, greeks may be inaccurate)
   * @return circuitBreakerExpiry expiry timestamp of the CircuitBreaker (if not expired, greeks may be inaccurate)
   */
  function getTokenPriceWithCheck()
    external
    view
    returns (
      uint tokenPrice,
      bool isStale,
      uint circuitBreakerExpiry
    )
  {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
    int optionValueDebt = greekCache.getGlobalOptionValue();
    (, uint usedDelta) = _getPoolHedgerLiquidity(spotPrice);
    uint totalPoolValue = _getTotalPoolValueQuote(spotPrice, usedDelta, optionValueDebt);
    uint totalTokenSupply = getTotalTokenSupply();

    tokenPrice = _getTokenPrice(totalPoolValue, totalTokenSupply);
    isStale = greekCache.isGlobalCacheStale(spotPrice);
    return (tokenPrice, isStale, CBTimestamp);
  }

  /// @dev Get current pool token price without market condition check
  function getTokenPrice() public view returns (uint) {
    return _getTokenPrice(getTotalPoolValueQuote(), getTotalTokenSupply());
  }

  function _getTokenPrice(uint totalPoolValue, uint totalTokenSupply) internal pure returns (uint) {
    if (totalTokenSupply == 0) {
      return 1e18;
    }

    return totalPoolValue.divideDecimal(totalTokenSupply);
  }

  ////////////////////////////
  // Getting Pool Liquidity //
  ////////////////////////////

  /// @notice Returns the breakdown of current liquidity usage
  function getCurrentLiquidity() external view returns (Liquidity memory) {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
    return getLiquidity(spotPrice);
  }

  /**
   * @notice Same return as `getCurrentLiquidity()` but with manual spot price
   */
  function getLiquidity(uint spotPrice) public view returns (Liquidity memory) {
    // if cache is stale, pendingDelta may be inaccurate
    (uint pendingDelta, uint usedDelta) = _getPoolHedgerLiquidity(spotPrice);
    int optionValueDebt = greekCache.getGlobalOptionValue();
    uint totalPoolValue = _getTotalPoolValueQuote(spotPrice, usedDelta, optionValueDebt);
    uint tokenPrice = _getTokenPrice(totalPoolValue, getTotalTokenSupply());

    return
      _getLiquidity(
        spotPrice,
        totalPoolValue,
        tokenPrice.multiplyDecimal(totalQueuedWithdrawals),
        usedDelta,
        pendingDelta
      );
  }

  /// @dev Gets the current NAV
  function getTotalPoolValueQuote() public view returns (uint) {
    uint spotPrice = synthetixAdapter.getSpotPriceForMarket(address(optionMarket));
    int optionValueDebt = greekCache.getGlobalOptionValue();
    (, uint usedDelta) = _getPoolHedgerLiquidity(spotPrice);

    return _getTotalPoolValueQuote(spotPrice, usedDelta, optionValueDebt);
  }

  function _getTotalPoolValueQuote(
    uint basePrice,
    uint usedDeltaLiquidity,
    int optionValueDebt
  ) internal view returns (uint) {
    int totalAssetValue = SafeCast.toInt256(
      quoteAsset.balanceOf(address(this)) +
        baseAsset.balanceOf(address(this)).multiplyDecimal(basePrice) +
        usedDeltaLiquidity -
        totalOutstandingSettlements -
        totalQueuedDeposits
    );

    // Should not be possible due to being fully collateralised
    if (optionValueDebt > totalAssetValue) {
      revert OptionValueDebtExceedsTotalAssets(address(this), totalAssetValue, optionValueDebt);
    }

    return uint(totalAssetValue - optionValueDebt);
  }

  /**
   * @dev Calculates breakdown of LP liquidity usage.
   *      Accounts for quote needed to buy/lock base in cases where pool is not fully collateralized.
   *      PendingLiquidity never exceeds freeLiquidity (before pendingLiquidity is considered).
   */
  function _getLiquidity(
    uint basePrice,
    uint totalPoolValue,
    uint reservedTokenValue,
    uint usedDelta,
    uint pendingDelta
  ) internal view returns (Liquidity memory) {
    Liquidity memory liquidity;
    liquidity.NAV = totalPoolValue;
    liquidity.usedDeltaLiquidity = usedDelta;
    uint baseBalance = baseAsset.balanceOf(address(this));

    liquidity.usedCollatLiquidity = lockedCollateral.quote;
    uint pendingBaseValue;
    if (baseBalance > lockedCollateral.base) {
      liquidity.usedCollatLiquidity += baseBalance.multiplyDecimal(basePrice);
    } else {
      liquidity.usedCollatLiquidity += lockedCollateral.base.multiplyDecimal(basePrice);
      pendingBaseValue = (lockedCollateral.base - baseBalance).multiplyDecimal(basePrice);
    }

    uint usedQuote = totalOutstandingSettlements + totalQueuedDeposits + lockedCollateral.quote + pendingBaseValue;
    uint totalQuote = quoteAsset.balanceOf(address(this));

    uint availableQuote = totalQuote > usedQuote ? totalQuote - usedQuote : 0;

    liquidity.pendingDeltaLiquidity = availableQuote > pendingDelta ? pendingDelta : availableQuote;

    liquidity.freeLiquidity = availableQuote > (pendingDelta + reservedTokenValue)
      ? availableQuote - (pendingDelta + reservedTokenValue)
      : 0;

    liquidity.burnableLiquidity = availableQuote - liquidity.pendingDeltaLiquidity;

    return liquidity;
  }

  /////////////////////
  // Exchanging Base //
  /////////////////////

  /// @notice Will buy/sell and lock/free base if pool is under or over collateralized
  function exchangeBase() public nonReentrant {
    SynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));
    Liquidity memory liquidity = getLiquidity(exchangeParams.spotPrice);
    _maybeExchangeBase(exchangeParams, liquidity.freeLiquidity, false);
  }

  /// @dev Will skip base purchase/locking if snx spot fees exceed `lpParams.maxFeePaid`.
  function _maybeExchangeBase(
    SynthetixAdapter.ExchangeParams memory exchangeParams,
    uint freeLiquidity,
    bool revertBuyOnInsufficientFunds
  ) internal {
    uint currentBaseBalance = baseAsset.balanceOf(address(this));
    if (currentBaseBalance > lockedCollateral.base) {
      // Sell base for quote
      if (exchangeParams.baseQuoteFeeRate > lpParams.maxFeePaid) {
        return;
      }
      uint amountBase = currentBaseBalance - lockedCollateral.base;
      uint quoteReceived = synthetixAdapter.exchangeFromExactBase(address(optionMarket), amountBase);
      emit BaseSold(amountBase, quoteReceived);
    } else if (currentBaseBalance < lockedCollateral.base) {
      // Buy base for quote
      uint amountBase = lockedCollateral.base - currentBaseBalance;
      if (exchangeParams.quoteBaseFeeRate > lpParams.maxFeePaid) {
        uint estimatedExchangeCost = synthetixAdapter.estimateExchangeToExactBase(exchangeParams, amountBase);
        if (revertBuyOnInsufficientFunds && estimatedExchangeCost > freeLiquidity) {
          revert InsufficientFreeLiquidityForBaseExchange(
            address(this),
            amountBase,
            estimatedExchangeCost,
            freeLiquidity
          );
        }
        return;
      }
      (uint quoteSpent, uint baseReceived) = synthetixAdapter.exchangeToExactBaseWithLimit(
        exchangeParams,
        address(optionMarket),
        amountBase,
        revertBuyOnInsufficientFunds ? freeLiquidity : type(uint).max
      );
      emit BasePurchased(quoteSpent, baseReceived);
    }
  }

  //////////
  // Misc //
  //////////

  /// @notice returns the LiquidityPoolParameters struct
  function getLpParams() external view returns (LiquidityPoolParameters memory) {
    return lpParams;
  }

  /// @notice updates `liquidationInsolventAmount` if liquidated position is insolveny
  function updateLiquidationInsolvency(uint insolvencyAmountInQuote) external onlyOptionMarket {
    liquidationInsolventAmount += insolvencyAmountInQuote;
  }

  /**
   * @dev get the total amount of quote used and pending for delta hedging
   *
   * @return pendingDeltaLiquidity The amount of liquidity reserved for delta hedging that hasn't occured yet
   * @return usedDeltaLiquidity The value of the current hedge position (long value OR collateral - short debt)
   */
  function _getPoolHedgerLiquidity(uint basePrice)
    internal
    view
    returns (uint pendingDeltaLiquidity, uint usedDeltaLiquidity)
  {
    if (address(poolHedger) != address(0)) {
      return poolHedger.getHedgingLiquidity(basePrice);
    }
    return (0, 0);
  }

  /**
   * @notice Sends quote to the PoolHedger.
   * @dev Transfer amount up to `pendingLiquidity + freeLiquidity`.
   * The hedger must determine what to do with the amount received.
   *
   * @param spotPrice The spot price of the base asset.
   * @param amount The amount requested by the PoolHedger.
   */
  function transferQuoteToHedge(uint spotPrice, uint amount) external onlyPoolHedger returns (uint) {
    Liquidity memory liquidity = getLiquidity(spotPrice);

    uint available = liquidity.pendingDeltaLiquidity + liquidity.freeLiquidity;

    amount = amount > available ? available : amount;

    _transferQuote(address(poolHedger), amount);

    emit QuoteTransferredToPoolHedger(amount);

    return amount;
  }

  function _transferQuote(address to, uint amount) internal {
    if (amount > 0) {
      if (!quoteAsset.transfer(to, amount)) {
        revert QuoteTransferFailed(address(this), address(this), to, amount);
      }
    }
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyPoolHedger() {
    if (msg.sender != address(poolHedger)) {
      revert OnlyPoolHedger(address(this), msg.sender, address(poolHedger));
    }
    _;
  }

  modifier onlyOptionMarket() {
    if (msg.sender != address(optionMarket)) {
      revert OnlyOptionMarket(address(this), msg.sender, address(optionMarket));
    }
    _;
  }

  modifier onlyShortCollateral() {
    if (msg.sender != address(shortCollateral)) {
      revert OnlyShortCollateral(address(this), msg.sender, address(shortCollateral));
    }
    _;
  }

  ////////////
  // Events //
  ////////////

  /// @dev Emitted whenever the pool paramters are updated
  event LiquidityPoolParametersUpdated(LiquidityPoolParameters lpParams);

  /// @dev Emitted whenever the poolHedger address is modified
  event PoolHedgerUpdated(PoolHedger poolHedger);

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

// SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

/**
 * @title SimpleInitializeable
 * @author Lyra
 * @dev Contract to enable a function to be marked as the initializer
 */
abstract contract SimpleInitializeable {
  bool internal initialized = false;

  modifier initializer() {
    if (initialized) {
      revert AlreadyInitialised(address(this));
    }
    initialized = true;
    _;
  }

  ////////////
  // Errors //
  ////////////
  error AlreadyInitialised(address thrower);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";
// Inherited
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";
import "openzeppelin-contracts-4.4.1/security/ReentrancyGuard.sol";
// Interfaces
import "openzeppelin-contracts-4.4.1/token/ERC20/ERC20.sol";
import "./libraries/PoolHedger.sol";
import "./SynthetixAdapter.sol";
import "./LiquidityPool.sol";
import "./OptionMarket.sol";
import "./OptionToken.sol";

/**
 * @title ShortCollateral
 * @author Lyra
 * @dev Holds collateral from users who are selling (shorting) options to the OptionMarket.
 */
contract ShortCollateral is Owned, SimpleInitializeable, ReentrancyGuard {
  using DecimalMath for uint;

  OptionMarket internal optionMarket;
  LiquidityPool internal liquidityPool;
  OptionToken internal optionToken;
  SynthetixAdapter internal synthetixAdapter;
  ERC20 internal quoteAsset;
  ERC20 internal baseAsset;

  // The amount the SC underpaid the LP due to insolvency.
  // The SC will take this much less from the LP when settling insolvent positions.
  uint public LPBaseExcess;
  uint public LPQuoteExcess;

  ///////////
  // Setup //
  ///////////

  constructor() Owned() {}

  /**
   * @dev Initialize the contract.
   */
  function init(
    OptionMarket _optionMarket,
    LiquidityPool _liquidityPool,
    OptionToken _optionToken,
    SynthetixAdapter _synthetixAdapter,
    ERC20 _quoteAsset,
    ERC20 _baseAsset
  ) external onlyOwner initializer {
    optionMarket = _optionMarket;
    liquidityPool = _liquidityPool;
    optionToken = _optionToken;
    synthetixAdapter = _synthetixAdapter;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;

    synthetixAdapter.delegateApprovals().approveExchangeOnBehalf(address(synthetixAdapter));
  }

  ///////////
  // Admin //
  ///////////

  /// @dev In case of an update to the synthetix contract that revokes the approval
  function updateDelegateApproval() external onlyOwner {
    synthetixAdapter.delegateApprovals().approveExchangeOnBehalf(address(synthetixAdapter));
  }

  ////////////////////////////////
  // Collateral/premium sending //
  ////////////////////////////////

  /**
   * @notice Transfers quoteAsset to the recipient. This should only be called by OptionMarket in the following cases:
   * - A short is closed, in which case the premium for the option is sent to the LP
   * - A user reduces their collateral position on a quote collateralized option
   *
   * @param recipient The recipient of the transfer.
   * @param amount The amount to send.
   */
  function sendQuoteCollateral(address recipient, uint amount) external onlyOptionMarket {
    _sendQuoteCollateral(recipient, amount);
  }

  /**
   * @notice Transfers baseAsset to the recipient. This should only be called by OptionMarket when a user is reducing
   * their collateral on a base collateralized option.
   *
   * @param recipient The recipient of the transfer.
   * @param amount The amount to send.
   */
  function sendBaseCollateral(address recipient, uint amount) external onlyOptionMarket {
    _sendBaseCollateral(recipient, amount);
  }

  /**
   * @notice Transfers quote/base fees and remaining collateral when `OptionMarket.liquidatePosition()` called
   * - liquidator: liquidator portion of liquidation fees
   * - LiquidityPool: premium to close position + LP portion of liquidation fees
   * - OptionMarket: SM portion of the liquidation fees
   * - position owner: remaining collateral after all above fees deducted
   *
   * @param trader address of position owner
   * @param liquidator address of liquidator
   * @param optionType OptionType
   * @param liquidationFees fee/collateral distribution as determined by OptionToken
   */
  function routeLiquidationFunds(
    address trader,
    address liquidator,
    OptionMarket.OptionType optionType,
    OptionToken.LiquidationFees memory liquidationFees
  ) external onlyOptionMarket {
    if (optionType == OptionMarket.OptionType.SHORT_CALL_BASE) {
      _sendBaseCollateral(trader, liquidationFees.returnCollateral);
      _sendBaseCollateral(liquidator, liquidationFees.liquidatorFee);
      _exchangeAndSendBaseCollateral(address(optionMarket), liquidationFees.smFee);
      _exchangeAndSendBaseCollateral(address(liquidityPool), liquidationFees.lpFee + liquidationFees.lpPremiums);
    } else {
      // quote collateral
      _sendQuoteCollateral(trader, liquidationFees.returnCollateral);
      _sendQuoteCollateral(liquidator, liquidationFees.liquidatorFee);
      _sendQuoteCollateral(address(optionMarket), liquidationFees.smFee);
      _sendQuoteCollateral(address(liquidityPool), liquidationFees.lpFee + liquidationFees.lpPremiums);
    }
  }

  //////////////////////
  // Board settlement //
  //////////////////////

  /**
   * @notice Transfers quoteAsset and baseAsset to the LiquidityPool on board settlement.
   *
   * @param amountBase The amount of baseAsset to transfer.
   * @param amountQuote The amount of quoteAsset to transfer.
   * @return lpBaseInsolvency total base amount owed to LP but not sent due to large amount of user insolvencies
   * @return lpQuoteInsolvency total quote amount owed to LP but not sent due to large amount of user insolvencies
   */
  function boardSettlement(uint amountBase, uint amountQuote)
    external
    onlyOptionMarket
    returns (uint lpBaseInsolvency, uint lpQuoteInsolvency)
  {
    uint currentBaseBalance = baseAsset.balanceOf(address(this));
    if (amountBase > currentBaseBalance) {
      lpBaseInsolvency = amountBase - currentBaseBalance;
      amountBase = currentBaseBalance;
      LPBaseExcess += lpBaseInsolvency;
    }

    uint currentQuoteBalance = quoteAsset.balanceOf(address(this));
    if (amountQuote > currentQuoteBalance) {
      lpQuoteInsolvency = amountQuote - currentQuoteBalance;
      amountQuote = currentQuoteBalance;
      LPQuoteExcess += lpQuoteInsolvency;
    }

    _sendBaseCollateral(address(liquidityPool), amountBase);
    _sendQuoteCollateral(address(liquidityPool), amountQuote);

    emit BoardSettlementCollateralSent(
      amountBase,
      amountQuote,
      lpBaseInsolvency,
      lpQuoteInsolvency,
      LPBaseExcess,
      LPQuoteExcess
    );

    return (lpBaseInsolvency, lpQuoteInsolvency);
  }

  /////////////////////////
  // Position Settlement //
  /////////////////////////

  /**
   * @notice Routes profits or remaining collateral for settled long and short options.
   *
   * @param positionIds The ids of the relevant OptionTokens.
   */
  function settleOptions(uint[] memory positionIds) external nonReentrant notGlobalPaused {
    // This is how much is missing from the ShortCollateral contract that was claimed by LPs at board expiry
    // We want to take it back when we know how much was missing.
    uint baseInsolventAmount;
    uint quoteInsolventAmount;

    OptionToken.PositionWithOwner[] memory optionPositions = optionToken.getPositionsWithOwner(positionIds);
    optionToken.settlePositions(positionIds);

    uint positionsLength = optionPositions.length;
    for (uint i = 0; i < positionsLength; ++i) {
      OptionToken.PositionWithOwner memory position = optionPositions[i];
      uint settlementAmount;
      uint insolventAmount;
      (uint strikePrice, uint priceAtExpiry, uint ammShortCallBaseProfitRatio) = optionMarket.getSettlementParameters(
        position.strikeId
      );

      if (priceAtExpiry == 0) {
        revert BoardMustBeSettled(address(this), position);
      }

      if (position.optionType == OptionMarket.OptionType.LONG_CALL) {
        settlementAmount = _sendLongCallProceeds(position.owner, position.amount, strikePrice, priceAtExpiry);
      } else if (position.optionType == OptionMarket.OptionType.LONG_PUT) {
        settlementAmount = _sendLongPutProceeds(position.owner, position.amount, strikePrice, priceAtExpiry);
      } else if (position.optionType == OptionMarket.OptionType.SHORT_CALL_BASE) {
        (settlementAmount, insolventAmount) = _sendShortCallBaseProceeds(
          position.owner,
          position.collateral,
          position.amount,
          ammShortCallBaseProfitRatio
        );
        baseInsolventAmount += insolventAmount;
      } else if (position.optionType == OptionMarket.OptionType.SHORT_CALL_QUOTE) {
        (settlementAmount, insolventAmount) = _sendShortCallQuoteProceeds(
          position.owner,
          position.collateral,
          position.amount,
          strikePrice,
          priceAtExpiry
        );
        quoteInsolventAmount += insolventAmount;
      } else {
        // OptionMarket.OptionType.SHORT_PUT_QUOTE
        (settlementAmount, insolventAmount) = _sendShortPutQuoteProceeds(
          position.owner,
          position.collateral,
          position.amount,
          strikePrice,
          priceAtExpiry
        );
        quoteInsolventAmount += insolventAmount;
      }

      emit PositionSettled(
        position.positionId,
        msg.sender,
        position.owner,
        strikePrice,
        priceAtExpiry,
        position.optionType,
        position.amount,
        settlementAmount,
        insolventAmount
      );
    }

    _reclaimInsolvency(baseInsolventAmount, quoteInsolventAmount);
  }

  /// @dev Send quote or base owed to LiquidityPool due to large number of insolvencies
  function _reclaimInsolvency(uint baseInsolventAmount, uint quoteInsolventAmount) internal {
    SynthetixAdapter.ExchangeParams memory exchangeParams = synthetixAdapter.getExchangeParams(address(optionMarket));

    if (LPBaseExcess > baseInsolventAmount) {
      LPBaseExcess -= baseInsolventAmount;
    } else if (baseInsolventAmount > 0) {
      baseInsolventAmount -= LPBaseExcess;
      LPBaseExcess = 0;
      liquidityPool.reclaimInsolventBase(exchangeParams, baseInsolventAmount);
    }

    if (LPQuoteExcess > quoteInsolventAmount) {
      LPQuoteExcess -= quoteInsolventAmount;
    } else if (quoteInsolventAmount > 0) {
      quoteInsolventAmount -= LPQuoteExcess;
      LPQuoteExcess = 0;
      liquidityPool.reclaimInsolventQuote(exchangeParams.spotPrice, quoteInsolventAmount);
    }
  }

  function _sendLongCallProceeds(
    address account,
    uint amount,
    uint strikePrice,
    uint priceAtExpiry
  ) internal returns (uint settlementAmount) {
    settlementAmount = (priceAtExpiry > strikePrice) ? (priceAtExpiry - strikePrice).multiplyDecimal(amount) : 0;
    liquidityPool.sendSettlementValue(account, settlementAmount);
    return settlementAmount;
  }

  function _sendLongPutProceeds(
    address account,
    uint amount,
    uint strikePrice,
    uint priceAtExpiry
  ) internal returns (uint settlementAmount) {
    settlementAmount = (strikePrice > priceAtExpiry) ? (strikePrice - priceAtExpiry).multiplyDecimal(amount) : 0;
    liquidityPool.sendSettlementValue(account, settlementAmount);
    return settlementAmount;
  }

  function _sendShortCallBaseProceeds(
    address account,
    uint userCollateral,
    uint amount,
    uint strikeToBaseReturnedRatio
  ) internal returns (uint settlementAmount, uint insolvency) {
    uint ammProfit = strikeToBaseReturnedRatio.multiplyDecimal(amount);
    (settlementAmount, insolvency) = _getInsolvency(userCollateral, ammProfit);
    _sendBaseCollateral(account, settlementAmount);
    return (settlementAmount, insolvency);
  }

  function _sendShortCallQuoteProceeds(
    address account,
    uint userCollateral,
    uint amount,
    uint strikePrice,
    uint priceAtExpiry
  ) internal returns (uint settlementAmount, uint insolvency) {
    uint ammProfit = (priceAtExpiry > strikePrice) ? (priceAtExpiry - strikePrice).multiplyDecimal(amount) : 0;
    (settlementAmount, insolvency) = _getInsolvency(userCollateral, ammProfit);
    _sendQuoteCollateral(account, settlementAmount);
    return (settlementAmount, insolvency);
  }

  function _sendShortPutQuoteProceeds(
    address account,
    uint userCollateral,
    uint amount,
    uint strikePrice,
    uint priceAtExpiry
  ) internal returns (uint settlementAmount, uint insolvency) {
    uint ammProfit = (priceAtExpiry < strikePrice) ? (strikePrice - priceAtExpiry).multiplyDecimal(amount) : 0;
    (settlementAmount, insolvency) = _getInsolvency(userCollateral, ammProfit);
    _sendQuoteCollateral(account, settlementAmount);
    return (settlementAmount, insolvency);
  }

  function _getInsolvency(uint userCollateral, uint ammProfit)
    internal
    pure
    returns (uint returnCollateral, uint insolvency)
  {
    if (userCollateral >= ammProfit) {
      returnCollateral = userCollateral - ammProfit;
    } else {
      insolvency = ammProfit - userCollateral;
    }
    return (returnCollateral, insolvency);
  }

  ///////////////
  // Transfers //
  ///////////////
  function _sendQuoteCollateral(address recipient, uint amount) internal {
    if (amount == 0) {
      return;
    }

    uint currentBalance = quoteAsset.balanceOf(address(this));

    if (amount > currentBalance) {
      revert OutOfQuoteCollateralForTransfer(address(this), currentBalance, amount);
    }

    if (!quoteAsset.transfer(recipient, amount)) {
      revert QuoteTransferFailed(address(this), address(this), recipient, amount);
    }
    emit QuoteSent(recipient, amount);
  }

  function _sendBaseCollateral(address recipient, uint amount) internal {
    if (amount == 0) {
      return;
    }

    uint currentBalance = baseAsset.balanceOf(address(this));

    if (amount > currentBalance) {
      revert OutOfBaseCollateralForTransfer(address(this), currentBalance, amount);
    }

    if (!baseAsset.transfer(recipient, amount)) {
      revert BaseTransferFailed(address(this), address(this), recipient, amount);
    }
    emit BaseSent(recipient, amount);
  }

  function _exchangeAndSendBaseCollateral(address recipient, uint amountBase) internal {
    if (amountBase == 0) {
      return;
    }

    uint currentBalance = baseAsset.balanceOf(address(this));
    if (amountBase > currentBalance) {
      revert OutOfBaseCollateralForExchangeAndTransfer(address(this), currentBalance, amountBase);
    }

    uint quoteReceived = synthetixAdapter.exchangeFromExactBase(address(optionMarket), amountBase);

    if (!quoteAsset.transfer(recipient, quoteReceived)) {
      revert QuoteTransferFailed(address(this), address(this), recipient, quoteReceived);
    }

    emit BaseExchangedAndQuoteSent(recipient, amountBase, quoteReceived);
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyOptionMarket() {
    if (msg.sender != address(optionMarket)) {
      revert OnlyOptionMarket(address(this), msg.sender, address(optionMarket));
    }
    _;
  }

  modifier notGlobalPaused() {
    synthetixAdapter.requireNotGlobalPaused(address(optionMarket));
    _;
  }

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
    OptionMarket.OptionType optionType,
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
  error BoardMustBeSettled(address thrower, OptionToken.PositionWithOwner position);
  error OnlyOptionMarket(address thrower, address caller, address optionMarket);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/SignedDecimalMath.sol";
import "./synthetix/DecimalMath.sol";
import "openzeppelin-contracts-4.4.1/utils/math/SafeCast.sol";

// Inherited
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";

// Interfaces
import "./SynthetixAdapter.sol";
import "./LiquidityPool.sol";
import "./OptionMarket.sol";
import "./OptionGreekCache.sol";

/**
 * @title OptionMarketPricer
 * @author Lyra
 * @dev Logic for working out the price of an option. Includes the IV impact of the trade, the fee components and
 * premium.
 */
contract OptionMarketPricer is Owned, SimpleInitializeable {
  using DecimalMath for uint;

  ////////////////
  // Parameters //
  ////////////////
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
  address internal optionMarket;
  OptionGreekCache internal greekCache;

  PricingParameters public pricingParams;
  TradeLimitParameters public tradeLimitParams;
  VarianceFeeParameters public varianceFeeParams;

  ///////////
  // Setup //
  ///////////

  constructor() Owned() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _optionMarket OptionMarket address
   * @param _greekCache OptionGreekCache address
   */
  function init(address _optionMarket, OptionGreekCache _greekCache) external onlyOwner initializer {
    optionMarket = _optionMarket;
    greekCache = _greekCache;
  }

  ///////////
  // Admin //
  ///////////

  /**
   * @dev
   *
   * @param params new parameters
   */
  function setPricingParams(PricingParameters memory _pricingParams) public onlyOwner {
    if (
      !(_pricingParams.optionPriceFeeCoefficient <= 200e18 &&
        _pricingParams.spotPriceFeeCoefficient <= 2e18 &&
        _pricingParams.optionPriceFee1xPoint >= 1 weeks &&
        _pricingParams.optionPriceFee2xPoint >= (_pricingParams.optionPriceFee1xPoint + 1 weeks) &&
        _pricingParams.spotPriceFee1xPoint >= 1 weeks &&
        _pricingParams.spotPriceFee2xPoint >= (_pricingParams.spotPriceFee1xPoint + 1 weeks) &&
        _pricingParams.standardSize > 0 &&
        _pricingParams.skewAdjustmentFactor <= 1000e18)
    ) {
      revert InvalidPricingParameters(address(this), _pricingParams);
    }

    pricingParams = _pricingParams;

    emit PricingParametersSet(pricingParams);
  }

  /**
   * @dev
   *
   * @param params new parameters
   */
  function setTradeLimitParams(TradeLimitParameters memory _tradeLimitParams) public onlyOwner {
    if (
      !(_tradeLimitParams.minDelta <= 1e18 &&
        _tradeLimitParams.minForceCloseDelta <= 1e18 &&
        _tradeLimitParams.tradingCutoff > 0 &&
        _tradeLimitParams.tradingCutoff <= 10 days &&
        _tradeLimitParams.minBaseIV < 10e18 &&
        _tradeLimitParams.maxBaseIV > 0 &&
        _tradeLimitParams.maxBaseIV < 100e18 &&
        _tradeLimitParams.minSkew < 10e18 &&
        _tradeLimitParams.maxSkew > 0 &&
        _tradeLimitParams.maxSkew < 10e18 &&
        _tradeLimitParams.maxVol > 0 &&
        _tradeLimitParams.absMaxSkew >= _tradeLimitParams.maxSkew &&
        _tradeLimitParams.absMinSkew <= _tradeLimitParams.minSkew)
    ) {
      revert InvalidTradeLimitParameters(address(this), _tradeLimitParams);
    }

    tradeLimitParams = _tradeLimitParams;

    emit TradeLimitParametersSet(tradeLimitParams);
  }

  /**
   * @dev
   *
   * @param params new parameters
   */
  function setVarianceFeeParams(VarianceFeeParameters memory _varianceFeeParams) public onlyOwner {
    varianceFeeParams = _varianceFeeParams;

    emit VarianceFeeParametersSet(varianceFeeParams);
  }

  ////////////////////////
  // Only Option Market //
  ////////////////////////

  /**
   * @dev The entry point for the OptionMarket into the pricing logic when a trade is performed.
   *
   * @param strike The strike being traded.
   * @param trade The trade struct, containing fields related to the ongoing trade.
   * @param boardBaseIv The base IV of the OptionBoard.
   */
  function updateCacheAndGetTradeResult(
    OptionMarket.Strike memory strike,
    OptionMarket.TradeParameters memory trade,
    uint boardBaseIv,
    uint boardExpiry
  ) external onlyOptionMarket returns (TradeResult memory tradeResult) {
    (uint newBaseIv, uint newSkew) = ivImpactForTrade(trade, boardBaseIv, strike.skew);

    bool isPostCutoff = block.timestamp + tradeLimitParams.tradingCutoff > boardExpiry;

    if (trade.isForceClose) {
      // don't actually update baseIV for forceCloses
      newBaseIv = boardBaseIv;

      // If it is a force close and skew ends up outside the "abs min/max" thresholds
      if (
        trade.tradeDirection != OptionMarket.TradeDirection.LIQUIDATE &&
        (newSkew <= tradeLimitParams.absMinSkew || newSkew >= tradeLimitParams.absMaxSkew)
      ) {
        revert ForceCloseSkewOutOfRange(
          address(this),
          trade.isBuy,
          newSkew,
          tradeLimitParams.absMinSkew,
          tradeLimitParams.absMaxSkew
        );
      }
    } else {
      if (isPostCutoff) {
        revert TradingCutoffReached(address(this), tradeLimitParams.tradingCutoff, boardExpiry, block.timestamp);
      }

      uint newVol = newBaseIv.multiplyDecimal(newSkew);

      if (trade.isBuy) {
        if (
          newVol > tradeLimitParams.maxVol ||
          newBaseIv > tradeLimitParams.maxBaseIV ||
          newSkew > tradeLimitParams.maxSkew
        ) {
          revert VolSkewOrBaseIvOutsideOfTradingBounds(
            address(this),
            trade.isBuy,
            VolComponents(boardBaseIv.multiplyDecimal(strike.skew), boardBaseIv, strike.skew),
            VolComponents(newVol, newBaseIv, newSkew),
            VolComponents(tradeLimitParams.maxVol, tradeLimitParams.maxBaseIV, tradeLimitParams.maxSkew)
          );
        }
      } else {
        if (
          newVol < tradeLimitParams.minVol ||
          newBaseIv < tradeLimitParams.minBaseIV ||
          newSkew < tradeLimitParams.minSkew
        ) {
          revert VolSkewOrBaseIvOutsideOfTradingBounds(
            address(this),
            trade.isBuy,
            VolComponents(boardBaseIv.multiplyDecimal(strike.skew), boardBaseIv, strike.skew),
            VolComponents(newVol, newBaseIv, newSkew),
            VolComponents(tradeLimitParams.minVol, tradeLimitParams.minBaseIV, tradeLimitParams.minSkew)
          );
        }
      }
    }

    if (tradeLimitParams.capSkewsToAbs) {
      // Only relevant to liquidations. Technically only needs to be capped on the max side (as closing shorts)
      newSkew = _max(_min(newSkew, tradeLimitParams.absMaxSkew), tradeLimitParams.absMinSkew);
    }

    OptionGreekCache.TradePricing memory pricing = greekCache.updateStrikeExposureAndGetPrice(
      strike,
      trade,
      newBaseIv,
      newSkew,
      isPostCutoff
    );

    if (trade.isForceClose) {
      // ignore delta cutoffs post trading cutoff, and for liquidations
      if (trade.tradeDirection != OptionMarket.TradeDirection.LIQUIDATE && !isPostCutoff) {
        // delta must fall BELOW the min or ABOVE the max to allow for force closes
        if (
          pricing.callDelta > tradeLimitParams.minForceCloseDelta &&
          pricing.callDelta < (int(DecimalMath.UNIT) - tradeLimitParams.minForceCloseDelta)
        ) {
          revert ForceCloseDeltaOutOfRange(
            address(this),
            pricing.callDelta,
            tradeLimitParams.minForceCloseDelta,
            (int(DecimalMath.UNIT) - tradeLimitParams.minForceCloseDelta)
          );
        }
      }
    } else {
      if (
        pricing.callDelta < tradeLimitParams.minDelta ||
        pricing.callDelta > int(DecimalMath.UNIT) - tradeLimitParams.minDelta
      ) {
        revert TradeDeltaOutOfRange(
          address(this),
          pricing.callDelta,
          tradeLimitParams.minDelta,
          int(DecimalMath.UNIT) - tradeLimitParams.minDelta
        );
      }
    }

    return getTradeResult(trade, pricing, newBaseIv, newSkew);
  }

  /**
   * @dev Calculates the impact a trade has on the base IV of the OptionBoard and the skew of the Strike.
   *
   * @param trade The trade struct, containing fields related to the ongoing trade.
   * @param boardBaseIv The base IV of the OptionBoard.
   * @param strikeSkew The skew of the option being traded.
   */
  function ivImpactForTrade(
    OptionMarket.TradeParameters memory trade,
    uint boardBaseIv,
    uint strikeSkew
  ) public view returns (uint newBaseIv, uint newSkew) {
    uint orderSize = trade.amount.divideDecimal(pricingParams.standardSize);
    uint orderMoveBaseIv = orderSize / 100;
    uint orderMoveSkew = orderMoveBaseIv.multiplyDecimal(pricingParams.skewAdjustmentFactor);
    if (trade.isBuy) {
      return (boardBaseIv + orderMoveBaseIv, strikeSkew + orderMoveSkew);
    } else {
      return (boardBaseIv - orderMoveBaseIv, strikeSkew - orderMoveSkew);
    }
  }

  /////////////////////
  // Fee Computation //
  /////////////////////

  /**
   * @dev Calculates the final premium for a trade.
   *
   * @param trade The trade struct, containing fields related to the ongoing trade.
   * @param pricing Fields related to option pricing and required for fees.
   */
  function getTradeResult(
    OptionMarket.TradeParameters memory trade,
    OptionGreekCache.TradePricing memory pricing,
    uint newBaseIv,
    uint newSkew
  ) public view returns (TradeResult memory tradeResult) {
    uint premium = pricing.optionPrice.multiplyDecimal(trade.amount);

    // time weight fees
    uint timeWeightedOptionPriceFee = getTimeWeightedFee(
      trade.expiry,
      pricingParams.optionPriceFee1xPoint,
      pricingParams.optionPriceFee2xPoint,
      pricingParams.optionPriceFeeCoefficient
    );

    uint timeWeightedSpotPriceFee = getTimeWeightedFee(
      trade.expiry,
      pricingParams.spotPriceFee1xPoint,
      pricingParams.spotPriceFee2xPoint,
      pricingParams.spotPriceFeeCoefficient
    );

    // scale by premium/amount/spot
    uint optionPriceFee = timeWeightedOptionPriceFee.multiplyDecimal(premium);
    uint spotPriceFee = timeWeightedSpotPriceFee.multiplyDecimal(trade.exchangeParams.spotPrice).multiplyDecimal(
      trade.amount
    );
    VegaUtilFeeComponents memory vegaUtilFeeComponents = getVegaUtilFee(trade, pricing);
    VarianceFeeComponents memory varianceFeeComponents = getVarianceFee(trade, pricing, newSkew);

    uint totalFee = optionPriceFee +
      spotPriceFee +
      vegaUtilFeeComponents.vegaUtilFee +
      varianceFeeComponents.varianceFee;

    uint totalCost;
    if (trade.isBuy) {
      // If we are selling, increase the amount the user pays
      totalCost = premium + totalFee;
    } else {
      // If we are buying, reduce the amount we pay
      if (totalFee > premium) {
        totalFee = premium;
        totalCost = 0;
      } else {
        totalCost = premium - totalFee;
      }
    }

    return
      TradeResult({
        amount: trade.amount,
        premium: premium,
        optionPriceFee: optionPriceFee,
        spotPriceFee: spotPriceFee,
        vegaUtilFee: vegaUtilFeeComponents,
        varianceFee: varianceFeeComponents,
        totalCost: totalCost,
        totalFee: totalFee,
        newBaseIv: newBaseIv,
        newSkew: newSkew,
        volTraded: pricing.volTraded
      });
  }

  /**
   * @dev Calculates a time weighted fee depending on the time to expiry. The fee graph has value = 1 and slope = 0
   * until pointA is reached; at which it increasing linearly to 2x at pointB. This only assumes pointA < pointB, so
   * fees can only get larger for longer dated options.
   *    |
   *    |       /
   *    |      /
   * 2x |     /|
   *    |    / |
   * 1x |___/  |
   *    |__________
   *        A  B
   * @param expiry the timestamp at which the listing/board expires
   * @param pointA the point (time to expiry) at which the fees start to increase beyond 1x
   * @param pointB the point (time to expiry) at which the fee are 2x
   * @param coefficient the fee coefficent as a result of the time to expiry.
   */
  function getTimeWeightedFee(
    uint expiry,
    uint pointA,
    uint pointB,
    uint coefficient
  ) public view returns (uint timeWeightedFee) {
    uint timeToExpiry = expiry - block.timestamp;
    if (timeToExpiry <= pointA) {
      return coefficient;
    }
    return
      coefficient.multiplyDecimal(DecimalMath.UNIT + ((timeToExpiry - pointA) * DecimalMath.UNIT) / (pointB - pointA));
  }

  /**
   * @dev Calculates vega utilisation to be used as part of the trade fee. If the trade reduces net standard vega, this
   * component is omitted from the fee.
   *
   * @param trade The trade struct, containing fields related to the ongoing trade.
   * @param pricing Fields related to option pricing and required for fees.
   */
  function getVegaUtilFee(OptionMarket.TradeParameters memory trade, OptionGreekCache.TradePricing memory pricing)
    public
    view
    returns (VegaUtilFeeComponents memory vegaUtilFeeComponents)
  {
    if (_abs(pricing.preTradeAmmNetStdVega) >= _abs(pricing.postTradeAmmNetStdVega)) {
      return
        VegaUtilFeeComponents({
          preTradeAmmNetStdVega: pricing.preTradeAmmNetStdVega,
          postTradeAmmNetStdVega: pricing.postTradeAmmNetStdVega,
          vegaUtil: 0,
          volTraded: pricing.volTraded,
          NAV: trade.liquidity.NAV,
          vegaUtilFee: 0
        });
    }
    // As we use nav here and the value doesn't change between iterations, opening 5x 1 options will be different to
    // opening 5 options with 5 iterations as nav won't update each iteration

    // This would be the whitepaper vegaUtil divided by 100 due to vol being stored as a percentage
    uint vegaUtil = pricing.volTraded.multiplyDecimal(_abs(pricing.postTradeAmmNetStdVega)).divideDecimal(
      trade.liquidity.NAV
    );

    uint vegaUtilFee = pricingParams.vegaFeeCoefficient.multiplyDecimal(vegaUtil).multiplyDecimal(trade.amount);
    return
      VegaUtilFeeComponents({
        preTradeAmmNetStdVega: pricing.preTradeAmmNetStdVega,
        postTradeAmmNetStdVega: pricing.postTradeAmmNetStdVega,
        vegaUtil: vegaUtil,
        volTraded: pricing.volTraded,
        NAV: trade.liquidity.NAV,
        vegaUtilFee: vegaUtilFee
      });
  }

  /**
   * @dev Calculates the variance fee to be used as part of the trade fee.
   *
   * @param trade The trade struct, containing fields related to the ongoing trade.
   * @param pricing Fields related to option pricing and required for fees.
   */
  function getVarianceFee(
    OptionMarket.TradeParameters memory trade,
    OptionGreekCache.TradePricing memory pricing,
    uint skew
  ) public view returns (VarianceFeeComponents memory varianceFeeComponents) {
    uint coefficient = trade.isForceClose
      ? varianceFeeParams.forceCloseVarianceFeeCoefficient
      : varianceFeeParams.defaultVarianceFeeCoefficient;
    if (coefficient == 0) {
      return
        VarianceFeeComponents({
          varianceFeeCoefficient: 0,
          vega: pricing.vega,
          vegaCoefficient: 0,
          skew: skew,
          skewCoefficient: 0,
          ivVariance: pricing.ivVariance,
          ivVarianceCoefficient: 0,
          varianceFee: 0
        });
    }

    uint vegaCoefficient = varianceFeeParams.minimumStaticVega +
      pricing.vega.multiplyDecimal(varianceFeeParams.vegaCoefficient);
    uint skewCoefficient = varianceFeeParams.minimumStaticSkewAdjustment +
      _abs(SafeCast.toInt256(skew) - SafeCast.toInt256(varianceFeeParams.referenceSkew)).multiplyDecimal(
        varianceFeeParams.skewAdjustmentCoefficient
      );
    uint ivVarianceCoefficient = varianceFeeParams.minimumStaticIvVariance +
      pricing.ivVariance.multiplyDecimal(varianceFeeParams.ivVarianceCoefficient);

    uint varianceFee = coefficient
      .multiplyDecimal(vegaCoefficient)
      .multiplyDecimal(skewCoefficient)
      .multiplyDecimal(ivVarianceCoefficient)
      .multiplyDecimal(trade.amount);
    return
      VarianceFeeComponents({
        varianceFeeCoefficient: coefficient,
        vega: pricing.vega,
        vegaCoefficient: vegaCoefficient,
        skew: skew,
        skewCoefficient: skewCoefficient,
        ivVariance: pricing.ivVariance,
        ivVarianceCoefficient: ivVarianceCoefficient,
        varianceFee: varianceFee
      });
  }

  /////////////////////////////
  // External View functions //
  /////////////////////////////

  /// @notice returns current pricing paramters
  function getPricingParams() external view returns (PricingParameters memory pricingParameters) {
    return pricingParams;
  }

  /// @notice returns current trade limit parameters
  function getTradeLimitParams() external view returns (TradeLimitParameters memory tradeLimitParameters) {
    return tradeLimitParams;
  }

  /// @notice returns current variance fee parameters
  function getVarianceFeeParams() external view returns (VarianceFeeParameters memory varianceFeeParameters) {
    return varianceFeeParams;
  }

  ///////////
  // Utils //
  ///////////

  function _min(uint x, uint y) internal pure returns (uint) {
    return (x < y) ? x : y;
  }

  function _max(uint x, uint y) internal pure returns (uint) {
    return (x > y) ? x : y;
  }

  /**
   * @dev Compute the absolute value of `val`.
   *
   * @param val The number to absolute value.
   */
  function _abs(int val) internal pure returns (uint) {
    return uint(val < 0 ? -val : val);
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyOptionMarket() {
    if (msg.sender != optionMarket) {
      revert OnlyOptionMarket(address(this), msg.sender, optionMarket);
    }
    _;
  }

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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
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

//SPDX-License-Identifier: MIT

import "openzeppelin-contracts-upgradeable-4.5.1/proxy/utils/Initializable.sol";
import "./AbstractOwned.sol";

pragma solidity ^0.8.9;

/**
 * @title OwnedUpgradeable
 * @author Lyra
 * @dev Modified owned contract to allow for the owner to be initialised by the calling proxy
 * @dev https://docs.synthetix.io/contracts/source/contracts/owned
 */
contract OwnedUpgradeable is AbstractOwned, Initializable {
  /**
   * @dev Initializes the contract setting the deployer as the initial owner.
   */
  function __Ownable_init() internal onlyInitializing {
    owner = msg.sender;
  }
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
  function getAddress(bytes32 name) external view returns (address);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

interface IDelegateApprovals {
  function approveExchangeOnBehalf(address delegate) external;

  function canExchangeOnBehalf(address exchanger, address beneficiary) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
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
contract ERC20 is Context, IERC20, IERC20Metadata {
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
    constructor(string memory name_, string memory symbol_) {
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
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
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
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

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
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
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
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
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
        _balances[account] += amount;
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
        }
        _totalSupply -= amount;

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
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Libraries
import "./synthetix/DecimalMath.sol";
// Inherited
import "openzeppelin-contracts-4.4.1/token/ERC20/ERC20.sol";
import "./synthetix/Owned.sol";
import "./libraries/SimpleInitializeable.sol";

// Interfaces
import "./interfaces/ILiquidityTracker.sol";

/**
 * @title LiquidityToken
 * @author Lyra
 * @dev An ERC20 token which represents a share of the LiquidityPool.
 * It is minted when users deposit, and burned when users withdraw.
 */
contract LiquidityToken is ERC20, Owned, SimpleInitializeable {
  using DecimalMath for uint;

  /// @dev The liquidityPool for which these tokens represent a share of
  address public liquidityPool;
  /// @dev Contract to call when liquidity gets updated. Basically a hook for future contracts to use.
  ILiquidityTracker public liquidityTracker;

  ///////////
  // Setup //
  ///////////

  /**
   * @param name_ Token collection name
   * @param symbol_ Token collection symbol
   */
  constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) Owned() {}

  /**
   * @dev Initialize the contract.
   * @param _liquidityPool LiquidityPool address
   */
  function init(address _liquidityPool) external onlyOwner initializer {
    liquidityPool = _liquidityPool;
  }

  ///////////
  // Admin //
  ///////////

  function setLiquidityTracker(ILiquidityTracker _liquidityTracker) external onlyOwner {
    liquidityTracker = _liquidityTracker;
    emit LiquidityTrackerSet(liquidityTracker);
  }

  ////////////////////////
  // Only LiquidityPool //
  ////////////////////////

  /**
   * @dev Mints new tokens and transfers them to `owner`.
   */
  function mint(address account, uint tokenAmount) external onlyLiquidityPool {
    _mint(account, tokenAmount);
  }

  /**
   * @dev Burn new tokens and transfers them to `owner`.
   */
  function burn(address account, uint tokenAmount) external onlyLiquidityPool {
    _burn(account, tokenAmount);
  }

  //////////
  // Misc //
  //////////
  /**
   * @dev Override to track the liquidty of the token. Mint, address(0), burn - to, address(0)
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint amount
  ) internal override {
    if (address(liquidityTracker) != address(0)) {
      if (from != address(0)) {
        liquidityTracker.removeTokens(from, amount);
      }
      if (to != address(0)) {
        liquidityTracker.addTokens(to, amount);
      }
    }
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyLiquidityPool() {
    if (msg.sender != liquidityPool) {
      revert OnlyLiquidityPool(address(this), msg.sender, liquidityPool);
    }
    _;
  }

  ////////////
  // Events //
  ////////////
  event LiquidityTrackerSet(ILiquidityTracker liquidityTracker);

  ////////////
  // Errors //
  ////////////
  // Access
  error OnlyLiquidityPool(address thrower, address caller, address liquidityPool);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.8.9;

// Interfaces
import "../LiquidityPool.sol";

/**
 * @title PoolHedger
 * @author Lyra
 * @dev Uses the delta hedging funds from the LiquidityPool to hedge option deltas, so LPs are minimally exposed to
 * movements in the underlying asset price.
 */
abstract contract PoolHedger {
  struct PoolHedgerParameters {
    uint interactionDelay;
    uint hedgeCap;
  }

  LiquidityPool internal liquidityPool;
  PoolHedgerParameters internal poolHedgerParams;
  uint public lastInteraction;

  /////////////
  // Only LP //
  /////////////
  function resetInteractionDelay() external onlyLiquidityPool {
    lastInteraction = 0;
  }

  /////////////
  // Getters //
  /////////////

  /**
   * @dev Returns the current hedged netDelta position.
   */
  function getCurrentHedgedNetDelta() external view virtual returns (int);

  /// @notice Returns pending delta hedge liquidity and used delta hedge liquidity
  /// @dev include funds that would need to be transferred to the contract to hedge optimally
  function getHedgingLiquidity(uint spotPrice)
    external
    view
    virtual
    returns (uint pendingDeltaLiquidity, uint usedDeltaLiquidity);

  /**
   * @dev Calculates the expected delta hedge that hedger must perform and
   * adjusts the result down to the hedgeCap param if needed.
   */
  function getCappedExpectedHedge() public view virtual returns (int cappedExpectedHedge);

  //////////////
  // External //
  //////////////

  /**
   * @dev Retrieves the netDelta for the system and hedges appropriately.
   */
  function hedgeDelta() external virtual;

  function updateCollateral() external virtual;

  function getPoolHedgerParams() external view virtual returns (PoolHedgerParameters memory) {
    return poolHedgerParams;
  }

  //////////////
  // Internal //
  //////////////

  function _setPoolHedgerParams(PoolHedgerParameters memory _poolHedgerParams) internal {
    poolHedgerParams = _poolHedgerParams;
    emit PoolHedgerParametersSet(poolHedgerParams);
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyLiquidityPool() {
    if (msg.sender != address(liquidityPool)) {
      revert OnlyLiquidityPool(address(this), msg.sender, address(liquidityPool));
    }
    _;
  }

  ////////////
  // Events //
  ////////////
  /**
   * @dev Emitted when pool hedger parameters are updated.
   */
  event PoolHedgerParametersSet(PoolHedgerParameters poolHedgerParams);

  ////////////
  // Errors //
  ////////////

  // Access
  error OnlyLiquidityPool(address thrower, address caller, address liquidityPool);
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

//SPDX-License-Identifier: ISC
pragma solidity ^0.8.9;

// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface ILiquidityTracker {
  function addTokens(address trader, uint amount) external;

  function removeTokens(address trader, uint amount) external;
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        require(_exists(tokenId), "ERC721: approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `_data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory _data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, _data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits a {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits a {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param _data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256 tokenId);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Address.sol)

pragma solidity ^0.8.0;

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
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
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

//SPDX-License-Identifier:ISC
pragma solidity 0.8.9;

// Libraries
import "../libraries/GWAV.sol";
import "../libraries/BlackScholes.sol";
import "../synthetix/DecimalMath.sol";

// Inherited
import "openzeppelin-contracts-4.4.1/access/Ownable.sol";
import "openzeppelin-contracts-4.4.1/token/ERC20/IERC20.sol";

// Interfaces
import "../interfaces/IOptionToken.sol";
import "../interfaces/IOptionMarket.sol";
import "../interfaces/ILiquidityPool.sol";
import "../interfaces/IShortCollateral.sol";
import "../interfaces/IOptionGreekCache.sol";
import "../interfaces/ISynthetixAdapter.sol";
import "../interfaces/IDelegateApprovals.sol";
import "../interfaces/ICurve.sol";
import "../interfaces/IGWAVOracle.sol";
import "../interfaces/ILyraRegistry.sol";
import "./BasicFeeCounter.sol";

/**
 * @title LyraAdapter
 * @author Lyra
 * @dev Provides helpful functions for any Lyra trading/market data/vault related actions in one contract
 *      To earn trading rewards, integrators must request to be whitelisted by Lyra
 */

contract LyraAdapter is Ownable {
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

  constructor() Ownable() {}

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
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

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
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
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

  function getSpotPriceForMarket(address _contractAddress) external view returns (uint spotPrice);

  function getSpotPrice(bytes32 to) external view returns (uint);

  function getExchangeParams(address optionMarket) external view returns (ExchangeParams memory exchangeParams);

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

interface IFeeCounter {
  function trackFee(
    address market,
    address trader,
    uint amount,
    uint totalCost,
    uint totalFee
  ) external;
}