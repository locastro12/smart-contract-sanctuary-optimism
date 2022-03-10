//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LyraGlobals.sol";
import "./LiquidityPool.sol";
import "./OptionToken.sol";
import "./OptionGreekCache.sol";
import "./LyraGlobals.sol";
import "./ShortCollateral.sol";
import "./interfaces/IOptionToken.sol";

/**
 * @title OptionMarket
 * @author Lyra
 * @dev An AMM which allows users to trade options. Supports both buying and selling options, which determine the value
 * for the listing's IV. Also allows for auto cash settling options as at expiry.
 */
contract OptionMarket is IOptionMarket {
  using SafeMath for uint;
  using SafeDecimalMath for uint;

  ILyraGlobals internal globals;
  ILiquidityPool internal liquidityPool;
  IOptionMarketPricer internal optionPricer;
  IOptionGreekCache internal greekCache;
  IShortCollateral internal shortCollateral;
  IOptionToken internal optionToken;
  IERC20 internal quoteAsset;
  IERC20 internal baseAsset;

  mapping(uint => string) internal errorMessages;
  address internal owner;
  bool internal initialized = false;
  uint internal nextListingId = 1;
  uint internal nextBoardId = 1;
  uint[] internal liveBoards;

  uint public override maxExpiryTimestamp;
  mapping(uint => OptionBoard) public override optionBoards;
  mapping(uint => OptionListing) public override optionListings;
  mapping(uint => uint) public override boardToPriceAtExpiry;
  mapping(uint => uint) public override listingToBaseReturnedRatio;

  constructor() {
    owner = msg.sender;
  }

  /**
   * @dev Initialize the contract.
   *
   * @param _globals LyraGlobals address
   * @param _liquidityPool LiquidityPool address
   * @param _optionPricer OptionMarketPricer address
   * @param _greekCache OptionGreekCache address
   * @param _quoteAsset Quote asset address
   * @param _baseAsset Base asset address
   */
  function init(
    ILyraGlobals _globals,
    ILiquidityPool _liquidityPool,
    IOptionMarketPricer _optionPricer,
    IOptionGreekCache _greekCache,
    IShortCollateral _shortCollateral,
    IOptionToken _optionToken,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    string[] memory _errorMessages
  ) external {
    require(!initialized, "already initialized");
    globals = _globals;
    liquidityPool = _liquidityPool;
    optionPricer = _optionPricer;
    greekCache = _greekCache;
    shortCollateral = _shortCollateral;
    optionToken = _optionToken;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
    require(_errorMessages.length == uint(Error.Last), "error msg count");
    for (uint i = 0; i < _errorMessages.length; i++) {
      errorMessages[i] = _errorMessages[i];
    }
    initialized = true;
  }

  /////////////////////
  // Admin functions //
  /////////////////////

  /**
   * @dev Transfer this contract ownership to `newOwner`.
   * @param newOwner The address of the new contract owner.
   */
  function transferOwnership(address newOwner) external override onlyOwner {
    _require(newOwner != address(0), Error.TransferOwnerToZero);
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

  /**
   * @dev Sets the frozen state of an OptionBoard.
   * @param boardId The id of the OptionBoard.
   * @param frozen Whether the board will be frozen or not.
   */
  function setBoardFrozen(uint boardId, bool frozen) external override onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    _require(board.id == boardId, Error.InvalidBoardId);
    optionBoards[boardId].frozen = frozen;
    emit BoardFrozen(boardId, frozen);
  }

  /**
   * @dev Sets the baseIv of a frozen OptionBoard.
   * @param boardId The id of the OptionBoard.
   * @param baseIv The new baseIv value.
   */
  function setBoardBaseIv(uint boardId, uint baseIv) external override onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    _require(board.id == boardId && board.frozen, Error.InvalidBoardIdOrNotFrozen);
    board.iv = baseIv;
    greekCache.setBoardIv(boardId, baseIv);
    emit BoardBaseIvSet(boardId, baseIv);
  }

  /**
   * @dev Sets the skew of an OptionListing of a frozen OptionBoard.
   * @param listingId The id of the listing being modified.
   * @param skew The new skew value.
   */
  function setListingSkew(uint listingId, uint skew) external override onlyOwner {
    OptionListing storage listing = optionListings[listingId];
    OptionBoard memory board = optionBoards[listing.boardId];
    _require(listing.id == listingId && board.frozen, Error.InvalidListingIdOrNotFrozen);
    listing.skew = skew;
    greekCache.setListingSkew(listingId, skew);
    emit ListingSkewSet(listingId, skew);
  }

  /**
   * @dev Creates a new OptionBoard which contains OptionListings.
   * This only allows a new maxExpiryTimestamp to be added if the previous one has been passed. This is done to create a
   * system of "rounds" where PnL for LPs can be computed easily across all boards.
   *
   * @param expiry The timestamp when the board expires.
   * @param baseIV The initial value for implied volatility.
   * @param strikes The array of strikes offered for this expiry.
   * @param skews The array of skews for each strike.
   */
  function createOptionBoard(
    uint expiry,
    uint baseIV,
    uint[] memory strikes,
    uint[] memory skews
  ) external override onlyOwner returns (uint) {
    // strike and skew length must match and must have at least 1
    _require(strikes.length == skews.length && strikes.length > 0, Error.StrikeSkewLengthMismatch);
    // We do not support expiry more than 10 weeks out, as it locks collateral for the entire duration
    _require(expiry.sub(block.timestamp) < 10 weeks, Error.BoardMaxExpiryReached);

    if (expiry > maxExpiryTimestamp) {
      _require(liveBoards.length == 0, Error.CannotStartNewRoundWhenBoardsExist);
      liquidityPool.startRound(maxExpiryTimestamp, expiry);
      maxExpiryTimestamp = expiry;
    }

    uint boardId = nextBoardId++;
    optionBoards[boardId].id = boardId;
    optionBoards[boardId].expiry = expiry;
    optionBoards[boardId].iv = baseIV;

    liveBoards.push(boardId);

    emit BoardCreated(boardId, expiry, baseIV);

    for (uint i = 0; i < strikes.length; i++) {
      _addListingToBoard(boardId, strikes[i], skews[i]);
    }

    greekCache.addBoard(boardId);

    return boardId;
  }

  /**
   * @dev Add a listing to an existing board in the OptionMarket.
   *
   * @param boardId The id of the board which the listing will be added
   * @param strike Strike of the Listing
   * @param skew Skew of the Listing
   */
  function addListingToBoard(
    uint boardId,
    uint strike,
    uint skew
  ) external override onlyOwner {
    OptionBoard storage board = optionBoards[boardId];
    _require(board.id == boardId, Error.InvalidBoardId);

    uint listingId = _addListingToBoard(boardId, strike, skew);
    greekCache.addListingToBoard(boardId, listingId);
  }

  /**
   * @dev Add a listing to an existing board.
   */
  function _addListingToBoard(
    uint boardId,
    uint strike,
    uint skew
  ) internal returns (uint listingId) {
    listingId = nextListingId;
    nextListingId += 4;
    optionListings[listingId] = OptionListing(listingId, strike, skew, 0, 0, 0, 0, boardId);
    optionBoards[boardId].listingIds.push(listingId);
    emit ListingAdded(boardId, listingId, strike, skew);
  }

  ///////////
  // Views //
  ///////////

  /**
   * @dev Returns the list of live board ids.
   */
  function getLiveBoards() external view override returns (uint[] memory _liveBoards) {
    _liveBoards = new uint[](liveBoards.length);
    for (uint i = 0; i < liveBoards.length; i++) {
      _liveBoards[i] = liveBoards[i];
    }
  }

  /**
   * @dev Returns the listing ids for a given `boardId`.
   *
   * @param boardId The id of the relevant OptionBoard.
   */
  function getBoardListings(uint boardId) external view override returns (uint[] memory) {
    uint[] memory listingIds = new uint[](optionBoards[boardId].listingIds.length);
    for (uint i = 0; i < optionBoards[boardId].listingIds.length; i++) {
      listingIds[i] = optionBoards[boardId].listingIds[i];
    }
    return listingIds;
  }

  ////////////////////
  // User functions //
  ////////////////////

  /**
   * @dev Opens a position, which may be long call, long put, short call or short put.
   *
   * @param _listingId The id of the relevant OptionListing.
   * @param tradeType Is the trade long or short?
   * @param amount The amount the user has requested to trade.
   */
  function openPosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external override returns (uint totalCost) {
    _require(int(amount) > 0 && uint(TradeType.SHORT_PUT) >= uint(tradeType), Error.ZeroAmountOrInvalidTradeType);

    bool isLong = tradeType == TradeType.LONG_CALL || tradeType == TradeType.LONG_PUT;

    OptionListing storage listing = optionListings[_listingId];
    OptionBoard storage board = optionBoards[listing.boardId];

    (
      LyraGlobals.PricingGlobals memory pricingGlobals,
      LyraGlobals.ExchangeGlobals memory exchangeGlobals,
      uint tradingCutoff
    ) = globals.getGlobalsForOptionTrade(address(this), isLong);

    // Note: call will fail here if it is an invalid boardId (expiry will be 0)
    _require(!board.frozen && block.timestamp + tradingCutoff < board.expiry, Error.BoardFrozenOrTradingCutoffReached);

    Trade memory trade =
      Trade({
        isBuy: isLong,
        amount: amount,
        vol: board.iv.multiplyDecimalRound(listing.skew),
        expiry: board.expiry,
        liquidity: liquidityPool.getLiquidity(exchangeGlobals.spotPrice, exchangeGlobals.short)
      });

    optionToken.mint(msg.sender, _listingId + uint(tradeType), amount);

    if (tradeType == TradeType.LONG_CALL) {
      listing.longCall = listing.longCall.add(amount);
    } else if (tradeType == TradeType.SHORT_CALL) {
      listing.shortCall = listing.shortCall.add(amount);
    } else if (tradeType == TradeType.LONG_PUT) {
      listing.longPut = listing.longPut.add(amount);
    } else {
      listing.shortPut = listing.shortPut.add(amount);
    }

    totalCost = _doTrade(listing, board, trade, pricingGlobals);

    if (tradeType == TradeType.LONG_CALL) {
      liquidityPool.lockBase(amount, exchangeGlobals, trade.liquidity);
      _require(quoteAsset.transferFrom(msg.sender, address(liquidityPool), totalCost), Error.QuoteTransferFailed);
    } else if (tradeType == TradeType.LONG_PUT) {
      liquidityPool.lockQuote(amount.multiplyDecimal(listing.strike), trade.liquidity.freeCollatLiquidity);
      _require(quoteAsset.transferFrom(msg.sender, address(liquidityPool), totalCost), Error.QuoteTransferFailed);
    } else if (tradeType == TradeType.SHORT_CALL) {
      _require(baseAsset.transferFrom(msg.sender, address(shortCollateral), amount), Error.BaseTransferFailed);
      liquidityPool.sendPremium(msg.sender, totalCost, trade.liquidity.freeCollatLiquidity);
    } else {
      _require(
        quoteAsset.transferFrom(msg.sender, address(shortCollateral), amount.multiplyDecimal(listing.strike)),
        Error.QuoteTransferFailed
      );
      liquidityPool.sendPremium(msg.sender, totalCost, trade.liquidity.freeCollatLiquidity);
    }

    emit PositionOpened(msg.sender, _listingId, tradeType, amount, totalCost);
  }

  /**
   * @dev Closes some amount of an open position. The user does not have to close the whole position.
   *
   * @param _listingId The id of the relevant OptionListing.
   * @param tradeType Is the trade long or short?
   * @param amount The amount the user has requested to trade.
   */
  function closePosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external override returns (uint totalCost) {
    _require(int(amount) > 0 && uint(TradeType.SHORT_PUT) >= uint(tradeType), Error.ZeroAmountOrInvalidTradeType);

    bool isLong = tradeType == TradeType.LONG_CALL || tradeType == TradeType.LONG_PUT;

    OptionListing storage listing = optionListings[_listingId];
    OptionBoard storage board = optionBoards[listing.boardId];

    (
      LyraGlobals.PricingGlobals memory pricingGlobals,
      LyraGlobals.ExchangeGlobals memory exchangeGlobals,
      uint tradingCutoff
    ) = globals.getGlobalsForOptionTrade(address(this), !isLong);

    _require(!board.frozen && block.timestamp + tradingCutoff < board.expiry, Error.BoardFrozenOrTradingCutoffReached);

    Trade memory trade =
      Trade({
        isBuy: !isLong,
        amount: amount,
        vol: board.iv.multiplyDecimalRound(listing.skew),
        expiry: board.expiry,
        liquidity: liquidityPool.getLiquidity(exchangeGlobals.spotPrice, exchangeGlobals.short)
      });

    optionToken.burn(msg.sender, _listingId + uint(tradeType), amount);

    if (tradeType == TradeType.LONG_CALL) {
      listing.longCall = listing.longCall.sub(amount);
    } else if (tradeType == TradeType.SHORT_CALL) {
      listing.shortCall = listing.shortCall.sub(amount);
    } else if (tradeType == TradeType.LONG_PUT) {
      listing.longPut = listing.longPut.sub(amount);
    } else {
      listing.shortPut = listing.shortPut.sub(amount);
    }
    totalCost = _doTrade(listing, board, trade, pricingGlobals);

    if (tradeType == TradeType.LONG_CALL) {
      liquidityPool.freeBase(amount);
      liquidityPool.sendPremium(msg.sender, totalCost, trade.liquidity.freeCollatLiquidity);
    } else if (tradeType == TradeType.LONG_PUT) {
      liquidityPool.freeQuoteCollateral(amount.multiplyDecimal(listing.strike));
      liquidityPool.sendPremium(msg.sender, totalCost, trade.liquidity.freeCollatLiquidity);
    } else if (tradeType == TradeType.SHORT_CALL) {
      shortCollateral.sendBaseCollateral(msg.sender, amount);
      _require(quoteAsset.transferFrom(msg.sender, address(liquidityPool), totalCost), Error.QuoteTransferFailed);
    } else {
      shortCollateral.sendQuoteCollateral(msg.sender, amount.multiplyDecimal(listing.strike).sub(totalCost));
      shortCollateral.sendQuoteCollateral(address(liquidityPool), totalCost);
    }

    emit PositionClosed(msg.sender, _listingId, tradeType, amount, totalCost);
  }

  /**
   * @dev Determine the cost of the trade and update the system's iv/skew parameters.
   *
   * @param listing The relevant OptionListing.
   * @param board The relevant OptionBoard.
   * @param trade The trade parameters.
   * @param pricingGlobals The pricing globals.
   */
  function _doTrade(
    OptionListing storage listing,
    OptionBoard storage board,
    Trade memory trade,
    LyraGlobals.PricingGlobals memory pricingGlobals
  ) internal returns (uint) {
    (uint totalCost, uint newIv, uint newSkew) =
      optionPricer.updateCacheAndGetTotalCost(listing, trade, pricingGlobals, board.iv);
    listing.skew = newSkew;
    board.iv = newIv;

    emit BoardBaseIvSet(board.id, newIv);
    emit ListingSkewSet(listing.id, newSkew);
    return totalCost;
  }

  /**
   * @dev Liquidates a board that has passed expiry. This function will not preserve the ordering of liveBoards.
   *
   * @param boardId The id of the relevant OptionBoard.
   */
  function liquidateExpiredBoard(uint boardId) external override {
    OptionBoard memory board = optionBoards[boardId];
    _require(board.expiry <= block.timestamp, Error.BoardNotExpired);
    bool popped = false;
    // Find and remove the board from the list of live boards
    for (uint i = 0; i < liveBoards.length; i++) {
      if (liveBoards[i] == boardId) {
        liveBoards[i] = liveBoards[liveBoards.length - 1];
        liveBoards.pop();
        popped = true;
        break;
      }
    }
    // prevent old boards being liquidated
    _require(popped, Error.BoardAlreadyLiquidated);

    _liquidateExpiredBoard(board);
    greekCache.removeBoard(boardId);
  }

  /**
   * @dev Liquidates an expired board.
   * It will transfer all short collateral for ITM options that the market owns.
   * It will reserve collateral for users to settle their ITM long options.
   *
   * @param board The relevant OptionBoard.
   */
  function _liquidateExpiredBoard(OptionBoard memory board) internal {
    LyraGlobals.ExchangeGlobals memory exchangeGlobals =
      globals.getExchangeGlobals(address(this), ILyraGlobals.ExchangeType.ALL);

    uint totalUserLongProfitQuote;
    uint totalBoardLongCallCollateral;
    uint totalBoardLongPutCollateral;
    uint totalAMMShortCallProfitBase;
    uint totalAMMShortPutProfitQuote;

    // Store the price now for when users come to settle their options
    boardToPriceAtExpiry[board.id] = exchangeGlobals.spotPrice;

    for (uint i = 0; i < board.listingIds.length; i++) {
      OptionListing memory listing = optionListings[board.listingIds[i]];

      totalBoardLongCallCollateral = totalBoardLongCallCollateral.add(listing.longCall);
      totalBoardLongPutCollateral = totalBoardLongPutCollateral.add(listing.longPut.multiplyDecimal(listing.strike));

      if (exchangeGlobals.spotPrice > listing.strike) {
        // For long calls
        totalUserLongProfitQuote = totalUserLongProfitQuote.add(
          listing.longCall.multiplyDecimal(exchangeGlobals.spotPrice - listing.strike)
        );

        // Per unit of shortCalls
        uint amountReservedBase =
          (exchangeGlobals.spotPrice - listing.strike)
            .divideDecimal(SafeDecimalMath.UNIT.sub(exchangeGlobals.baseQuoteFeeRate))
            .divideDecimal(exchangeGlobals.spotPrice);
        // This is impossible unless the baseAsset price has gone up ~900%+
        if (amountReservedBase > SafeDecimalMath.UNIT) {
          amountReservedBase = SafeDecimalMath.UNIT;
        }

        totalAMMShortCallProfitBase = totalAMMShortCallProfitBase.add(
          amountReservedBase.multiplyDecimal(listing.shortCall)
        );
        listingToBaseReturnedRatio[listing.id] = SafeDecimalMath.UNIT.sub(amountReservedBase);
      } else {
        listingToBaseReturnedRatio[listing.id] = SafeDecimalMath.UNIT;
      }

      if (exchangeGlobals.spotPrice < listing.strike) {
        // if amount > 0 can be skipped as it will be multiplied by 0
        totalUserLongProfitQuote = totalUserLongProfitQuote.add(
          listing.longPut.multiplyDecimal(listing.strike - exchangeGlobals.spotPrice)
        );
        totalAMMShortPutProfitQuote = totalAMMShortPutProfitQuote.add(
          (listing.strike - exchangeGlobals.spotPrice).multiplyDecimal(listing.shortPut)
        );
      }
    }

    shortCollateral.sendToLP(totalAMMShortCallProfitBase, totalAMMShortPutProfitQuote);

    // This will batch all base we want to convert to quote and sell it in one transaction
    liquidityPool.boardLiquidation(totalBoardLongPutCollateral, totalUserLongProfitQuote, totalBoardLongCallCollateral);

    emit BoardLiquidated(
      board.id,
      totalUserLongProfitQuote,
      totalBoardLongCallCollateral,
      totalBoardLongPutCollateral,
      totalAMMShortCallProfitBase,
      totalAMMShortPutProfitQuote
    );
  }

  /**
   * @dev Settles options for expired and liquidated listings. Also functions as the way to reclaim capital for options
   * sold to the market.
   *
   * @param listingId The id of the relevant OptionListing.
   */
  function settleOptions(uint listingId, TradeType tradeType) external override {
    uint amount = optionToken.balanceOf(msg.sender, listingId + uint(tradeType));

    shortCollateral.processSettle(
      listingId,
      msg.sender,
      tradeType,
      amount,
      optionListings[listingId].strike,
      boardToPriceAtExpiry[optionListings[listingId].boardId],
      listingToBaseReturnedRatio[listingId]
    );

    optionToken.burn(msg.sender, listingId + uint(tradeType), amount);
  }

  ////
  // Misc
  ////

  function _require(bool pass, Error error) internal view {
    require(pass, errorMessages[uint(error)]);
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner virtual {
    _require(owner == msg.sender, Error.OnlyOwner);
    _;
  }

  // Events
  /**
   * @dev Emitted when a Board is created.
   */
  event BoardCreated(uint indexed boardId, uint expiry, uint baseIv);

  /**
   * @dev Emitted when a Board frozen is updated.
   */
  event BoardFrozen(uint indexed boardId, bool frozen);

  /**
   * @dev Emitted when a Board new baseIv is set.
   */
  event BoardBaseIvSet(uint indexed boardId, uint baseIv);

  /**
   * @dev Emitted when a Listing new skew is set.
   */
  event ListingSkewSet(uint indexed listingId, uint skew);

  /**
   * @dev Emitted when a Listing is added to a board
   */
  event ListingAdded(uint indexed boardId, uint indexed listingId, uint strike, uint skew);

  /**
   * @dev Emitted when a Position is opened.
   */
  event PositionOpened(
    address indexed trader,
    uint indexed listingId,
    TradeType indexed tradeType,
    uint amount,
    uint totalCost
  );

  /**
   * @dev Emitted when a Position is closed.
   */
  event PositionClosed(
    address indexed trader,
    uint indexed listingId,
    TradeType indexed tradeType,
    uint amount,
    uint totalCost
  );

  /**
   * @dev Emitted when a Board is liquidated.
   */
  event BoardLiquidated(
    uint indexed boardId,
    uint totalUserLongProfitQuote,
    uint totalBoardLongCallCollateral,
    uint totalBoardLongPutCollateral,
    uint totalAMMShortCallProfitBase,
    uint totalAMMShortPutProfitQuote
  );

  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
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

pragma solidity ^0.7.6;

// Libraries
import "@openzeppelin/contracts/math/SafeMath.sol";

// https://docs.synthetix.io/contracts/source/libraries/SafeDecimalMath/
library SafeDecimalMath {
  using SafeMath for uint;

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
    return x.mul(y) / UNIT;
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
    uint quotientTimesTen = x.mul(y) / (precisionUnit / 10);

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
    return x.mul(UNIT).div(y);
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
    uint resultTimesTen = x.mul(precisionUnit * 10).div(y);

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
    return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
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

pragma solidity >=0.6.0 <0.8.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";

// Inherited
import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "./interfaces/IExchanger.sol";
import "./interfaces/ICollateralShort.sol";
import "./interfaces/ISynthetix.sol";
import "./interfaces/IExchangeRates.sol";
import "./interfaces/ILiquidityPool.sol";

/**
 * @title LyraGlobals
 * @author Lyra
 * @dev Manages variables across all OptionMarkets, along with managing access to Synthetix.
 * Groups access to variables needed during a trade to reduce the gas costs associated with repetitive
 * inter-contract calls.
 * The OptionMarket contract address is used as the key to access the variables for the market.
 */
contract LyraGlobals is ILyraGlobals, Ownable {
  using SafeDecimalMath for uint;

  ISynthetix public override synthetix;
  IExchanger public override exchanger;
  IExchangeRates public override exchangeRates;
  ICollateralShort public override collateralShort;

  /// @dev Pause the whole system. Note; this will not pause settling previously expired options.
  bool public override isPaused = false;

  /// @dev Don't sell options this close to expiry
  mapping(address => uint) public override tradingCutoff;

  // Variables related to calculating premium/fees
  mapping(address => uint) public override optionPriceFeeCoefficient;
  mapping(address => uint) public override spotPriceFeeCoefficient;
  mapping(address => uint) public override vegaFeeCoefficient;
  mapping(address => uint) public override vegaNormFactor;
  mapping(address => uint) public override standardSize;
  mapping(address => uint) public override skewAdjustmentFactor;
  mapping(address => int) public override rateAndCarry;
  mapping(address => int) public override minDelta;
  mapping(address => uint) public override volatilityCutoff;
  mapping(address => bytes32) public override quoteKey;
  mapping(address => bytes32) public override baseKey;

  constructor() Ownable() {}

  /**
   * @dev Set the globals that apply to all OptionMarkets.
   *
   * @param _synthetix The address of Synthetix.
   * @param _exchanger The address of Synthetix's Exchanger.
   * @param _exchangeRates The address of Synthetix's ExchangeRates.
   * @param _collateralShort The address of Synthetix's CollateralShort.
   */
  function setGlobals(
    ISynthetix _synthetix,
    IExchanger _exchanger,
    IExchangeRates _exchangeRates,
    ICollateralShort _collateralShort
  ) external override onlyOwner {
    synthetix = _synthetix;
    exchanger = _exchanger;
    exchangeRates = _exchangeRates;
    collateralShort = _collateralShort;

    emit GlobalsSet(_synthetix, _exchanger, _exchangeRates, _collateralShort);
  }

  /**
   * @dev Set the globals for a specific OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _tradingCutoff The time to stop trading.
   * @param pricingGlobals The PricingGlobals.
   * @param _quoteKey The key of the quoteAsset.
   * @param _baseKey The key of the baseAsset.
   */
  function setGlobalsForContract(
    address _contractAddress,
    uint _tradingCutoff,
    PricingGlobals memory pricingGlobals,
    bytes32 _quoteKey,
    bytes32 _baseKey
  ) external override onlyOwner {
    setTradingCutoff(_contractAddress, _tradingCutoff);
    setOptionPriceFeeCoefficient(_contractAddress, pricingGlobals.optionPriceFeeCoefficient);
    setSpotPriceFeeCoefficient(_contractAddress, pricingGlobals.spotPriceFeeCoefficient);
    setVegaFeeCoefficient(_contractAddress, pricingGlobals.vegaFeeCoefficient);
    setVegaNormFactor(_contractAddress, pricingGlobals.vegaNormFactor);
    setStandardSize(_contractAddress, pricingGlobals.standardSize);
    setSkewAdjustmentFactor(_contractAddress, pricingGlobals.skewAdjustmentFactor);
    setRateAndCarry(_contractAddress, pricingGlobals.rateAndCarry);
    setMinDelta(_contractAddress, pricingGlobals.minDelta);
    setVolatilityCutoff(_contractAddress, pricingGlobals.volatilityCutoff);
    setQuoteKey(_contractAddress, _quoteKey);
    setBaseKey(_contractAddress, _baseKey);
  }

  /**
   * @dev Pauses the contract.
   *
   * @param _isPaused Whether getting globals will revert or not.
   */
  function setPaused(bool _isPaused) external override onlyOwner {
    isPaused = _isPaused;

    emit Paused(isPaused);
  }

  /**
   * @dev Set the time when the OptionMarket will cease trading before expiry.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _tradingCutoff The time to stop trading.
   */
  function setTradingCutoff(address _contractAddress, uint _tradingCutoff) public override onlyOwner {
    require(_tradingCutoff >= 6 hours && _tradingCutoff <= 14 days, "tradingCutoff value out of range");
    tradingCutoff[_contractAddress] = _tradingCutoff;
    emit TradingCutoffSet(_contractAddress, _tradingCutoff);
  }

  /**
   * @notice Set the option price fee coefficient for the OptionMarket.

   * @param _contractAddress The address of the OptionMarket.
   * @param _optionPriceFeeCoefficient The option price fee coefficient.
   */
  function setOptionPriceFeeCoefficient(address _contractAddress, uint _optionPriceFeeCoefficient)
    public
    override
    onlyOwner
  {
    require(_optionPriceFeeCoefficient <= 5e17, "optionPriceFeeCoefficient value out of range");
    optionPriceFeeCoefficient[_contractAddress] = _optionPriceFeeCoefficient;
    emit OptionPriceFeeCoefficientSet(_contractAddress, _optionPriceFeeCoefficient);
  }

  /**
   * @notice Set the spot price fee coefficient for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _spotPriceFeeCoefficient The spot price fee coefficient.
   */
  function setSpotPriceFeeCoefficient(address _contractAddress, uint _spotPriceFeeCoefficient)
    public
    override
    onlyOwner
  {
    require(_spotPriceFeeCoefficient <= 1e17, "optionPriceFeeCoefficient value out of range");
    spotPriceFeeCoefficient[_contractAddress] = _spotPriceFeeCoefficient;
    emit SpotPriceFeeCoefficientSet(_contractAddress, _spotPriceFeeCoefficient);
  }

  /**
   * @notice Set the vega fee coefficient for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _vegaFeeCoefficient The vega fee coefficient.
   */
  function setVegaFeeCoefficient(address _contractAddress, uint _vegaFeeCoefficient) public override onlyOwner {
    require(_vegaFeeCoefficient <= 100000e18, "optionPriceFeeCoefficient value out of range");
    vegaFeeCoefficient[_contractAddress] = _vegaFeeCoefficient;
    emit VegaFeeCoefficientSet(_contractAddress, _vegaFeeCoefficient);
  }

  /**
   * @notice Set the vega normalisation factor for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _vegaNormFactor The vega normalisation factor.
   */
  function setVegaNormFactor(address _contractAddress, uint _vegaNormFactor) public override onlyOwner {
    require(_vegaNormFactor <= 10e18, "optionPriceFeeCoefficient value out of range");
    vegaNormFactor[_contractAddress] = _vegaNormFactor;
    emit VegaNormFactorSet(_contractAddress, _vegaNormFactor);
  }

  /**
   * @notice Set the standard size for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _standardSize The size of an average trade.
   */
  function setStandardSize(address _contractAddress, uint _standardSize) public override onlyOwner {
    require(_standardSize >= 1e15 && _standardSize <= 100000e18, "standardSize value out of range");
    standardSize[_contractAddress] = _standardSize;
    emit StandardSizeSet(_contractAddress, _standardSize);
  }

  /**
   * @notice Set the skew adjustment factor for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _skewAdjustmentFactor The skew adjustment factor.
   */
  function setSkewAdjustmentFactor(address _contractAddress, uint _skewAdjustmentFactor) public override onlyOwner {
    require(_skewAdjustmentFactor <= 10e18, "skewAdjustmentFactor value out of range");
    skewAdjustmentFactor[_contractAddress] = _skewAdjustmentFactor;
    emit SkewAdjustmentFactorSet(_contractAddress, _skewAdjustmentFactor);
  }

  /**
   * @notice Set the rate for the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _rateAndCarry The rate.
   */
  function setRateAndCarry(address _contractAddress, int _rateAndCarry) public override onlyOwner {
    require(_rateAndCarry <= 3e18 && _rateAndCarry >= -3e18, "rateAndCarry value out of range");
    rateAndCarry[_contractAddress] = _rateAndCarry;
    emit RateAndCarrySet(_contractAddress, _rateAndCarry);
  }

  /**
   * @notice Set the minimum Delta that the OptionMarket will trade.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _minDelta The minimum delta value.
   */
  function setMinDelta(address _contractAddress, int _minDelta) public override onlyOwner {
    require(_minDelta >= 0 && _minDelta <= 2e17, "minDelta value out of range");
    minDelta[_contractAddress] = _minDelta;
    emit MinDeltaSet(_contractAddress, _minDelta);
  }

  /**
   * @notice Set the minimum volatility option that the OptionMarket will trade.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _volatilityCutoff The minimum volatility value.
   */
  function setVolatilityCutoff(address _contractAddress, uint _volatilityCutoff) public override onlyOwner {
    require(_volatilityCutoff <= 2e18, "volatilityCutoff value out of range");
    volatilityCutoff[_contractAddress] = _volatilityCutoff;
    emit VolatilityCutoffSet(_contractAddress, _volatilityCutoff);
  }

  /**
   * @notice Set the quoteKey of the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _quoteKey The key of the quoteAsset.
   */
  function setQuoteKey(address _contractAddress, bytes32 _quoteKey) public override onlyOwner {
    quoteKey[_contractAddress] = _quoteKey;
    emit QuoteKeySet(_contractAddress, _quoteKey);
  }

  /**
   * @notice Set the baseKey of the OptionMarket.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param _baseKey The key of the baseAsset.
   */
  function setBaseKey(address _contractAddress, bytes32 _baseKey) public override onlyOwner {
    baseKey[_contractAddress] = _baseKey;
    emit BaseKeySet(_contractAddress, _baseKey);
  }

  // Getters

  /**
   * @notice Returns the price of the baseAsset.
   *
   * @param _contractAddress The address of the OptionMarket.
   */
  function getSpotPriceForMarket(address _contractAddress) external view override returns (uint) {
    return getSpotPrice(baseKey[_contractAddress]);
  }

  /**
   * @notice Gets spot price of an asset.
   * @dev All rates are denominated in terms of sUSD,
   * so the price of sUSD is always $1.00, and is never stale.
   *
   * @param to The key of the synthetic asset.
   */
  function getSpotPrice(bytes32 to) public view override returns (uint) {
    (uint rate, bool invalid) = exchangeRates.rateAndInvalid(to);
    require(!invalid && rate != 0, "rate is invalid");
    return rate;
  }

  /**
   * @notice Returns a PricingGlobals struct for a given market address.
   *
   * @param _contractAddress The address of the OptionMarket.
   */
  function getPricingGlobals(address _contractAddress)
    external
    view
    override
    notPaused
    returns (PricingGlobals memory)
  {
    return
      PricingGlobals({
        optionPriceFeeCoefficient: optionPriceFeeCoefficient[_contractAddress],
        spotPriceFeeCoefficient: spotPriceFeeCoefficient[_contractAddress],
        vegaFeeCoefficient: vegaFeeCoefficient[_contractAddress],
        vegaNormFactor: vegaNormFactor[_contractAddress],
        standardSize: standardSize[_contractAddress],
        skewAdjustmentFactor: skewAdjustmentFactor[_contractAddress],
        rateAndCarry: rateAndCarry[_contractAddress],
        minDelta: minDelta[_contractAddress],
        volatilityCutoff: volatilityCutoff[_contractAddress],
        spotPrice: getSpotPrice(baseKey[_contractAddress])
      });
  }

  /**
   * @notice Returns the GreekCacheGlobals.
   *
   * @param _contractAddress The address of the OptionMarket.
   */
  function getGreekCacheGlobals(address _contractAddress)
    external
    view
    override
    notPaused
    returns (GreekCacheGlobals memory)
  {
    return
      GreekCacheGlobals({
        rateAndCarry: rateAndCarry[_contractAddress],
        spotPrice: getSpotPrice(baseKey[_contractAddress])
      });
  }

  /**
   * @notice Returns the ExchangeGlobals.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param exchangeType The ExchangeType.
   */
  function getExchangeGlobals(address _contractAddress, ExchangeType exchangeType)
    public
    view
    override
    notPaused
    returns (ExchangeGlobals memory exchangeGlobals)
  {
    exchangeGlobals = ExchangeGlobals({
      spotPrice: 0,
      quoteKey: quoteKey[_contractAddress],
      baseKey: baseKey[_contractAddress],
      synthetix: synthetix,
      short: collateralShort,
      quoteBaseFeeRate: 0,
      baseQuoteFeeRate: 0
    });

    exchangeGlobals.spotPrice = getSpotPrice(exchangeGlobals.baseKey);

    if (exchangeType == ExchangeType.BASE_QUOTE || exchangeType == ExchangeType.ALL) {
      exchangeGlobals.baseQuoteFeeRate = exchanger.feeRateForExchange(
        exchangeGlobals.baseKey,
        exchangeGlobals.quoteKey
      );
    }

    if (exchangeType == ExchangeType.QUOTE_BASE || exchangeType == ExchangeType.ALL) {
      exchangeGlobals.quoteBaseFeeRate = exchanger.feeRateForExchange(
        exchangeGlobals.quoteKey,
        exchangeGlobals.baseKey
      );
    }
  }

  /**
   * @dev Returns the globals needed to perform a trade.
   * The purpose of this function is to provide all the necessary variables in 1 call. Note that GreekCacheGlobals are a
   * subset of PricingGlobals, so we generate that struct when OptionMarketPricer calls OptionGreekCache.
   *
   * @param _contractAddress The address of the OptionMarket.
   * @param isBuy  Is the trade buying or selling options to the OptionMarket.
   */
  function getGlobalsForOptionTrade(address _contractAddress, bool isBuy)
    external
    view
    override
    notPaused
    returns (
      PricingGlobals memory pricingGlobals,
      ExchangeGlobals memory exchangeGlobals,
      uint tradeCutoff
    )
  {
    // exchangeGlobals aren't necessary apart from long calls, but since they are the most expensive transaction
    // we add this overhead to other types of calls, to save gas on long calls.
    exchangeGlobals = getExchangeGlobals(_contractAddress, isBuy ? ExchangeType.QUOTE_BASE : ExchangeType.BASE_QUOTE);
    pricingGlobals = PricingGlobals({
      optionPriceFeeCoefficient: optionPriceFeeCoefficient[_contractAddress],
      spotPriceFeeCoefficient: spotPriceFeeCoefficient[_contractAddress],
      vegaFeeCoefficient: vegaFeeCoefficient[_contractAddress],
      vegaNormFactor: vegaNormFactor[_contractAddress],
      standardSize: standardSize[_contractAddress],
      skewAdjustmentFactor: skewAdjustmentFactor[_contractAddress],
      rateAndCarry: rateAndCarry[_contractAddress],
      minDelta: minDelta[_contractAddress],
      volatilityCutoff: volatilityCutoff[_contractAddress],
      spotPrice: exchangeGlobals.spotPrice
    });
    tradeCutoff = tradingCutoff[_contractAddress];
  }

  modifier notPaused {
    require(!isPaused, "contracts are paused");
    _;
  }

  /** Emitted when globals are set.
   */
  event GlobalsSet(
    ISynthetix _synthetix,
    IExchanger _exchanger,
    IExchangeRates _exchangeRates,
    ICollateralShort _collateralShort
  );
  /**
   * @dev Emitted when paused.
   */
  event Paused(bool isPaused);
  /**
   * @dev Emitted when trading cut-off is set.
   */
  event TradingCutoffSet(address indexed _contractAddress, uint _tradingCutoff);
  /**
   * @dev Emitted when option price fee coefficient is set.
   */
  event OptionPriceFeeCoefficientSet(address indexed _contractAddress, uint _optionPriceFeeCoefficient);
  /**
   * @dev Emitted when spot price fee coefficient is set.
   */
  event SpotPriceFeeCoefficientSet(address indexed _contractAddress, uint _spotPriceFeeCoefficient);
  /**
   * @dev Emitted when vega fee coefficient is set.
   */
  event VegaFeeCoefficientSet(address indexed _contractAddress, uint _vegaFeeCoefficient);
  /**
   * @dev Emitted when standard size is set.
   */
  event StandardSizeSet(address indexed _contractAddress, uint _standardSize);
  /**
   * @dev Emitted when skew ddjustment factor is set.
   */
  event SkewAdjustmentFactorSet(address indexed _contractAddress, uint _skewAdjustmentFactor);
  /**
   * @dev Emitted when vegaNorm factor is set.
   */
  event VegaNormFactorSet(address indexed _contractAddress, uint _vegaNormFactor);
  /**
   * @dev Emitted when rate and carry is set.
   */
  event RateAndCarrySet(address indexed _contractAddress, int _rateAndCarry);
  /**
   * @dev Emitted when min delta is set.
   */
  event MinDeltaSet(address indexed _contractAddress, int _minDelta);
  /**
   * @dev Emitted when volatility cutoff is set.
   */
  event VolatilityCutoffSet(address indexed _contractAddress, uint _volatilityCutoff);
  /**
   * @dev Emitted when quote key is set.
   */
  event QuoteKeySet(address indexed _contractAddress, bytes32 _quoteKey);
  /**
   * @dev Emitted when base key is set.
   */
  event BaseKeySet(address indexed _contractAddress, bytes32 _baseKey);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOptionMarket.sol";
import "./interfaces/ILiquidityCertificate.sol";
import "./interfaces/IPoolHedger.sol";
import "./interfaces/IShortCollateral.sol";

/**
 * @title LiquidityPool
 * @author Lyra
 * @dev Holds funds from LPs, which are used for the following purposes:
 * 1. Collateralizing options sold by the OptionMarket.
 * 2. Buying options from users.
 * 3. Delta hedging the LPs.
 * 4. Storing funds for expired in the money options.
 */
contract LiquidityPool is ILiquidityPool {
  using SafeMath for uint;
  using SafeDecimalMath for uint;

  ////
  // Constants
  ////
  ILyraGlobals internal globals;
  IOptionMarket internal optionMarket;
  ILiquidityCertificate internal liquidityCertificate;
  IShortCollateral internal shortCollateral;
  IPoolHedger internal poolHedger;
  IERC20 internal quoteAsset;
  IERC20 internal baseAsset;
  uint internal constant INITIAL_RATE = 1e18;

  ////
  // Variables
  ////
  mapping(uint => string) internal errorMessages;

  bool internal initialized = false;

  /// @dev Amount of collateral locked for outstanding calls and puts sold to users
  Collateral public override lockedCollateral;
  /**
   * @dev Total amount of quoteAsset held to pay out users who have locked/waited for their tokens to be burnable. As
   * well as keeping track of all settled option's usd value.
   */
  uint internal totalQuoteAmountReserved;
  /// @dev Total number of tokens that will be removed from the totalTokenSupply at the end of the round.
  uint internal tokensBurnableForRound;
  /// @dev Funds entering the pool in the next round.
  uint public override queuedQuoteFunds;
  /// @dev Total amount of tokens that represents the total amount of pool shares
  uint internal totalTokenSupply;
  /// @dev Counter for reentrancy guard.
  uint internal counter = 1;

  /**
   * @dev Mapping of timestamps to conversion rates of liquidity to tokens. To get the token value of a certificate;
   * `certificate.liquidity / expiryToTokenValue[certificate.enteredAt]`
   */
  mapping(uint => uint) public override expiryToTokenValue;

  constructor() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _optionMarket OptionMarket address
   * @param _liquidityCertificate LiquidityCertificate address
   * @param _quoteAsset Quote Asset address
   * @param _poolHedger PoolHedger address
   */
  function init(
    ILyraGlobals _globals,
    IOptionMarket _optionMarket,
    ILiquidityCertificate _liquidityCertificate,
    IPoolHedger _poolHedger,
    IShortCollateral _shortCollateral,
    IERC20 _quoteAsset,
    IERC20 _baseAsset,
    string[] memory _errorMessages
  ) external {
    require(!initialized, "already initialized");
    globals = _globals;
    optionMarket = _optionMarket;
    liquidityCertificate = _liquidityCertificate;
    shortCollateral = _shortCollateral;
    poolHedger = _poolHedger;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
    require(_errorMessages.length == uint(Error.Last), "error msg count");
    for (uint i = 0; i < _errorMessages.length; i++) {
      errorMessages[i] = _errorMessages[i];
    }
    initialized = true;
  }

  ////////////////////////////////////////////////////////////////
  // Dealing with providing liquidity and withdrawing liquidity //
  ////////////////////////////////////////////////////////////////

  /**
   * @dev Deposits liquidity to the pool. This assumes users have authorised access to the quote ERC20 token. Will add
   * any deposited amount to the queuedQuoteFunds until the next round begins.
   *
   * @param beneficiary The account that will receive the liquidity certificate.
   * @param amount The amount of quoteAsset to deposit.
   */
  function deposit(address beneficiary, uint amount) external override returns (uint) {
    // Assume we have the allowance to take the amount they are depositing
    queuedQuoteFunds = queuedQuoteFunds.add(amount);
    uint certificateId = liquidityCertificate.mint(beneficiary, amount, optionMarket.maxExpiryTimestamp());
    emit Deposit(beneficiary, certificateId, amount);
    _require(quoteAsset.transferFrom(msg.sender, address(this), amount), Error.QuoteTransferFailed);
    return certificateId;
  }

  /**
   * @notice Signals withdraw of liquidity from the pool.
   * @dev It is not possible to withdraw during a round, thus a user can signal to withdraw at the time the round ends.
   *
   * @param certificateId The id of the LiquidityCertificate.
   */
  function signalWithdrawal(uint certificateId) external override {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();

    _require(certificateData.burnableAt == 0, Error.AlreadySignalledWithdrawal);
    _require(
      certificateData.enteredAt != maxExpiryTimestamp && expiryToTokenValue[maxExpiryTimestamp] == 0,
      Error.SignallingBetweenRounds
    );

    if (certificateData.enteredAt == 0) {
      // Dividing by INITIAL_RATE is redundant as initial rate is 1 unit
      tokensBurnableForRound = tokensBurnableForRound.add(certificateData.liquidity);
    } else {
      tokensBurnableForRound = tokensBurnableForRound.add(
        certificateData.liquidity.divideDecimal(expiryToTokenValue[certificateData.enteredAt])
      );
    }

    liquidityCertificate.setBurnableAt(msg.sender, certificateId, maxExpiryTimestamp);

    emit WithdrawSignaled(certificateId, tokensBurnableForRound);
  }

  /**
   * @dev Undo a previously signalled withdraw. Certificate owner must have signalled withdraw to call this function,
   * and cannot unsignal if the token is already burnable or burnt.
   *
   * @param certificateId The id of the LiquidityCertificate.
   */
  function unSignalWithdrawal(uint certificateId) external override {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);

    // Cannot unsignal withdrawal if the token is burnable/hasn't signalled exit
    _require(certificateData.burnableAt != 0, Error.UnSignalMustSignalFirst);
    _require(expiryToTokenValue[certificateData.burnableAt] == 0, Error.UnSignalAlreadyBurnable);

    liquidityCertificate.setBurnableAt(msg.sender, certificateId, 0);

    if (certificateData.enteredAt == 0) {
      // Dividing by INITIAL_RATE is redundant as initial rate is 1 unit
      tokensBurnableForRound = tokensBurnableForRound.sub(certificateData.liquidity);
    } else {
      tokensBurnableForRound = tokensBurnableForRound.sub(
        certificateData.liquidity.divideDecimal(expiryToTokenValue[certificateData.enteredAt])
      );
    }

    emit WithdrawUnSignaled(certificateId, tokensBurnableForRound);
  }

  /**
   * @dev Withdraws liquidity from the pool.
   *
   * This requires tokens to have been locked until the round ending at the burnableAt timestamp has been ended.
   * This will burn the liquidityCertificates and have the quote asset equivalent at the time be reserved for the users.
   *
   * @param beneficiary The account that will receive the withdrawn funds.
   * @param certificateId The id of the LiquidityCertificate.
   */
  function withdraw(address beneficiary, uint certificateId) external override returns (uint value) {
    ILiquidityCertificate.CertificateData memory certificateData = liquidityCertificate.certificateData(certificateId);
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();

    // We allow people to withdraw if their funds haven't entered the system
    if (certificateData.enteredAt == maxExpiryTimestamp) {
      queuedQuoteFunds = queuedQuoteFunds.sub(certificateData.liquidity);
      liquidityCertificate.burn(msg.sender, certificateId);
      emit Withdraw(beneficiary, certificateId, certificateData.liquidity, totalQuoteAmountReserved);
      _require(quoteAsset.transfer(beneficiary, certificateData.liquidity), Error.QuoteTransferFailed);
      return certificateData.liquidity;
    }

    uint enterValue = certificateData.enteredAt == 0 ? INITIAL_RATE : expiryToTokenValue[certificateData.enteredAt];

    // expiryToTokenValue will only be set if the previous round has ended, and the next has not started
    uint currentRoundValue = expiryToTokenValue[maxExpiryTimestamp];

    // If they haven't signaled withdrawal, and it is between rounds
    if (certificateData.burnableAt == 0 && currentRoundValue != 0) {
      uint tokenAmt = certificateData.liquidity.divideDecimal(enterValue);
      totalTokenSupply = totalTokenSupply.sub(tokenAmt);
      value = tokenAmt.multiplyDecimal(currentRoundValue);
      liquidityCertificate.burn(msg.sender, certificateId);
      emit Withdraw(beneficiary, certificateId, value, totalQuoteAmountReserved);
      _require(quoteAsset.transfer(beneficiary, value), Error.QuoteTransferFailed);
      return value;
    }

    uint exitValue = expiryToTokenValue[certificateData.burnableAt];

    _require(certificateData.burnableAt != 0 && exitValue != 0, Error.WithdrawNotBurnable);

    value = certificateData.liquidity.multiplyDecimal(exitValue).divideDecimal(enterValue);

    // We can allow a 0 expiry for options created before any boards exist
    liquidityCertificate.burn(msg.sender, certificateId);

    totalQuoteAmountReserved = totalQuoteAmountReserved.sub(value);
    emit Withdraw(beneficiary, certificateId, value, totalQuoteAmountReserved);
    _require(quoteAsset.transfer(beneficiary, value), Error.QuoteTransferFailed);
    return value;
  }

  //////////////////////////////////////////////
  // Dealing with locking and expiry rollover //
  //////////////////////////////////////////////

  /**
   * @dev Return Token value.
   *
   * This token price is only accurate within the period between rounds.
   */
  function tokenPriceQuote() public view override returns (uint) {
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
      globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.ALL);

    if (totalTokenSupply == 0) {
      return INITIAL_RATE;
    }

    uint poolValue =
      getTotalPoolValueQuote(
        exchangeGlobals.spotPrice,
        poolHedger.getValueQuote(exchangeGlobals.short, exchangeGlobals.spotPrice)
      );
    return poolValue.divideDecimal(totalTokenSupply);
  }

  /**
   * @notice Ends a round.
   * @dev Should only be called after all boards have been liquidated.
   */
  function endRound() external override {
    // Round can only be ended if all boards have been liquidated, and can only be called once.
    uint maxExpiryTimestamp = optionMarket.maxExpiryTimestamp();
    // We must ensure all boards have been expired
    _require(optionMarket.getLiveBoards().length == 0, Error.EndRoundWithLiveBoards);
    // We can only end the round once
    _require(expiryToTokenValue[maxExpiryTimestamp] == 0, Error.EndRoundAlreadyEnded);
    // We want to make sure all base collateral has been exchanged
    _require(baseAsset.balanceOf(address(this)) == 0, Error.EndRoundMustExchangeBase);
    // We want to make sure there is no outstanding poolHedger balance. If there is collateral left in the poolHedger
    // it will not affect calculations.
    _require(poolHedger.getCurrentHedgedNetDelta() == 0, Error.EndRoundMustHedgeDelta);

    uint pricePerToken = tokenPriceQuote();

    // Store the value for the tokens that are burnable for this round
    expiryToTokenValue[maxExpiryTimestamp] = pricePerToken;

    // Reserve the amount of quote we need for the tokens that are burnable
    totalQuoteAmountReserved = totalQuoteAmountReserved.add(tokensBurnableForRound.multiplyDecimal(pricePerToken));
    emit QuoteReserved(tokensBurnableForRound.multiplyDecimal(pricePerToken), totalQuoteAmountReserved);

    totalTokenSupply = totalTokenSupply.sub(tokensBurnableForRound);
    emit RoundEnded(maxExpiryTimestamp, pricePerToken, totalQuoteAmountReserved, tokensBurnableForRound);
    tokensBurnableForRound = 0;
  }

  /**
   * @dev Starts a round. Can only be called by optionMarket contract when adding a board.
   *
   * @param lastMaxExpiryTimestamp The time at which the previous round ended.
   * @param newMaxExpiryTimestamp The time which funds will be locked until.
   */
  function startRound(uint lastMaxExpiryTimestamp, uint newMaxExpiryTimestamp) external override onlyOptionMarket {
    // As the value is never reset, this is when the first board is added
    if (lastMaxExpiryTimestamp == 0) {
      totalTokenSupply = queuedQuoteFunds;
    } else {
      _require(expiryToTokenValue[lastMaxExpiryTimestamp] != 0, Error.StartRoundMustEndRound);
      totalTokenSupply = totalTokenSupply.add(
        queuedQuoteFunds.divideDecimal(expiryToTokenValue[lastMaxExpiryTimestamp])
      );
    }
    queuedQuoteFunds = 0;

    emit RoundStarted(
      lastMaxExpiryTimestamp,
      newMaxExpiryTimestamp,
      totalTokenSupply,
      lastMaxExpiryTimestamp == 0 ? SafeDecimalMath.UNIT : expiryToTokenValue[lastMaxExpiryTimestamp]
    );
  }

  /////////////////////////////////////////
  // Dealing with collateral for options //
  /////////////////////////////////////////

  /**
   * @dev external override function that will bring the base balance of this contract to match locked.base. This cannot be done
   * in the same transaction as locking the base, as exchanging on synthetix is too costly gas-wise.
   */
  function exchangeBase() external override reentrancyGuard {
    uint currentBaseBalance = baseAsset.balanceOf(address(this));

    // Add this additional check to prevent any soft locks at round end, as the base balance must be 0 to end the round.
    if (optionMarket.getLiveBoards().length == 0) {
      lockedCollateral.base = 0;
    }

    if (currentBaseBalance > lockedCollateral.base) {
      // Sell excess baseAsset
      ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
        globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.BASE_QUOTE);
      uint amount = currentBaseBalance - lockedCollateral.base;
      uint quoteReceived =
        exchangeGlobals.synthetix.exchange(exchangeGlobals.baseKey, amount, exchangeGlobals.quoteKey);
      _require(quoteReceived > 0, Error.ReceivedZeroFromBaseQuoteExchange);
      emit BaseSold(msg.sender, amount, quoteReceived);
    } else if (lockedCollateral.base > currentBaseBalance) {
      // Buy required amount of baseAsset
      ILyraGlobals.ExchangeGlobals memory exchangeGlobals =
        globals.getExchangeGlobals(address(optionMarket), ILyraGlobals.ExchangeType.QUOTE_BASE);
      uint quoteToSpend =
        (lockedCollateral.base - currentBaseBalance)
          .divideDecimalRound(SafeDecimalMath.UNIT.sub(exchangeGlobals.quoteBaseFeeRate))
          .multiplyDecimalRound(exchangeGlobals.spotPrice);
      uint totalQuoteAvailable =
        quoteAsset.balanceOf(address(this)).sub(totalQuoteAmountReserved).sub(lockedCollateral.quote).sub(
          queuedQuoteFunds
        );
      // We want to always buy as much collateral as we can, even if it dips into the delta hedging portion.
      // But we cannot compromise funds that aren't useable by the pool.
      quoteToSpend = quoteToSpend > totalQuoteAvailable ? totalQuoteAvailable : quoteToSpend;
      uint amtReceived =
        exchangeGlobals.synthetix.exchange(exchangeGlobals.quoteKey, quoteToSpend, exchangeGlobals.baseKey);
      _require(amtReceived > 0, Error.ReceivedZeroFromQuoteBaseExchange);
      emit BasePurchased(msg.sender, quoteToSpend, amtReceived);
    }
  }

  /**
   * @notice Locks quote when the system sells a put option.
   *
   * @param amount The amount of quote to lock.
   * @param freeCollatLiq The amount of free collateral that can be locked.
   */
  function lockQuote(uint amount, uint freeCollatLiq) external override onlyOptionMarket {
    _require(amount <= freeCollatLiq, Error.LockingMoreQuoteThanIsFree);
    lockedCollateral.quote = lockedCollateral.quote.add(amount);
    emit QuoteLocked(amount, lockedCollateral.quote);
  }

  /**
   * @notice Purchases and locks base when the system sells a call option.
   *
   * @param amount The amount of baseAsset to purchase and lock.
   * @param exchangeGlobals The exchangeGlobals.
   * @param liquidity Free and used liquidity amounts.
   */
  function lockBase(
    uint amount,
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals,
    Liquidity memory liquidity
  ) external override onlyOptionMarket {
    uint currentBaseBal = baseAsset.balanceOf(address(this));

    uint desiredBase;
    uint availableQuote = liquidity.freeCollatLiquidity;

    if (lockedCollateral.base >= currentBaseBal) {
      uint outstanding = lockedCollateral.base - currentBaseBal;
      // We need to ignore any base we haven't purchased yet from our availableQuote
      availableQuote = availableQuote.add(outstanding.multiplyDecimal(exchangeGlobals.spotPrice));
      // But we want to make sure we will have enough quote to cover the debt owed on top of new base we want to lock
      desiredBase = amount.add(outstanding);
    } else {
      // We actually need to buy less, or none, if we already have excess balance
      uint excess = currentBaseBal - lockedCollateral.base;
      if (excess >= amount) {
        desiredBase = 0;
      } else {
        desiredBase = amount.sub(excess);
      }
    }
    uint quoteToSpend =
      desiredBase.divideDecimalRound(SafeDecimalMath.UNIT.sub(exchangeGlobals.quoteBaseFeeRate)).multiplyDecimalRound(
        exchangeGlobals.spotPrice
      );

    _require(availableQuote >= quoteToSpend, Error.LockingMoreBaseThanCanBeExchanged);

    lockedCollateral.base = lockedCollateral.base.add(amount);
    emit BaseLocked(amount, lockedCollateral.base);
  }

  /**
   * @notice Frees quote when the system buys back a put from the user.
   *
   * @param amount The amount of quote to free.
   */
  function freeQuoteCollateral(uint amount) external override onlyOptionMarket {
    _freeQuoteCollateral(amount);
  }

  /**
   * @notice Frees quote when the system buys back a put from the user.
   *
   * @param amount The amount of quote to free.
   */
  function _freeQuoteCollateral(uint amount) internal {
    // Handle rounding errors by returning the full amount when the requested amount is greater
    if (amount > lockedCollateral.quote) {
      amount = lockedCollateral.quote;
    }
    lockedCollateral.quote = lockedCollateral.quote.sub(amount);
    emit QuoteFreed(amount, lockedCollateral.quote);
  }

  /**
   * @notice Sells base and frees the proceeds of the sale.
   *
   * @param amountBase The amount of base to sell.
   */
  function freeBase(uint amountBase) external override onlyOptionMarket {
    _require(amountBase <= lockedCollateral.base, Error.FreeingMoreBaseThanLocked);
    lockedCollateral.base = lockedCollateral.base.sub(amountBase);
    emit BaseFreed(amountBase, lockedCollateral.base);
  }

  /**
   * @notice Sends the premium to a user who is selling an option to the pool.
   * @dev The caller must be the OptionMarket.
   *
   * @param recipient The address of the recipient.
   * @param amount The amount to transfer.
   * @param freeCollatLiq The amount of free collateral liquidity.
   */
  function sendPremium(
    address recipient,
    uint amount,
    uint freeCollatLiq
  ) external override onlyOptionMarket reentrancyGuard {
    _require(freeCollatLiq >= amount, Error.SendPremiumNotEnoughCollateral);
    _require(quoteAsset.transfer(recipient, amount), Error.QuoteTransferFailed);

    emit CollateralQuoteTransferred(recipient, amount);
  }

  //////////////////////////////////////////
  // Dealing with expired option premiums //
  //////////////////////////////////////////

  /**
   * @notice Manages collateral at the time of board liquidation, also converting base sent here from the OptionMarket.
   *
   * @param amountQuoteFreed Total amount of base to convert to quote, including profits from short calls.
   * @param amountQuoteReserved Total amount of base to convert to quote, including profits from short calls.
   * @param amountBaseFreed Total amount of collateral to liquidate.
   */
  function boardLiquidation(
    uint amountQuoteFreed,
    uint amountQuoteReserved,
    uint amountBaseFreed
  ) external override onlyOptionMarket {
    _freeQuoteCollateral(amountQuoteFreed);

    totalQuoteAmountReserved = totalQuoteAmountReserved.add(amountQuoteReserved);
    emit QuoteReserved(amountQuoteReserved, totalQuoteAmountReserved);

    lockedCollateral.base = lockedCollateral.base.sub(amountBaseFreed);
    emit BaseFreed(amountBaseFreed, lockedCollateral.base);
  }

  /**
   * @dev Transfers reserved quote. Sends `amount` of reserved quoteAsset to `user`.
   *
   * Requirements:
   *
   * - the caller must be `OptionMarket`.
   *
   * @param user The address of the user to send the quote.
   * @param amount The amount of quote to send.
   */
  function sendReservedQuote(address user, uint amount) external override onlyShortCollateral reentrancyGuard {
    // Should never happen, but added to prevent any potential rounding errors
    if (amount > totalQuoteAmountReserved) {
      amount = totalQuoteAmountReserved;
    }
    totalQuoteAmountReserved = totalQuoteAmountReserved.sub(amount);
    _require(quoteAsset.transfer(user, amount), Error.QuoteTransferFailed);

    emit ReservedQuoteSent(user, amount, totalQuoteAmountReserved);
  }

  ////////////////////////////
  // Getting Pool Liquidity //
  ////////////////////////////

  /**
   * @notice Returns the total pool value in quoteAsset.
   *
   * @param basePrice The price of the baseAsset.
   * @param usedDeltaLiquidity The amout of delta liquidity that has been used for hedging.
   */
  function getTotalPoolValueQuote(uint basePrice, uint usedDeltaLiquidity) public view override returns (uint) {
    return
      quoteAsset
        .balanceOf(address(this))
        .add(baseAsset.balanceOf(address(this)).multiplyDecimal(basePrice))
        .add(usedDeltaLiquidity)
        .sub(totalQuoteAmountReserved)
        .sub(queuedQuoteFunds);
  }

  /**
   * @notice Returns the used and free amounts for collateral and delta liquidity.
   *
   * @param basePrice The price of the base asset.
   * @param short The address of the short contract.
   */
  function getLiquidity(uint basePrice, ICollateralShort short) public view override returns (Liquidity memory) {
    Liquidity memory liquidity;

    liquidity.usedDeltaLiquidity = poolHedger.getValueQuote(short, basePrice);
    liquidity.usedCollatLiquidity = lockedCollateral.quote.add(lockedCollateral.base.multiplyDecimal(basePrice));

    uint totalLiquidity = getTotalPoolValueQuote(basePrice, liquidity.usedDeltaLiquidity);

    uint collatPortion = (totalLiquidity * 2) / 3;
    uint deltaPortion = totalLiquidity.sub(collatPortion);

    if (liquidity.usedCollatLiquidity > collatPortion) {
      collatPortion = liquidity.usedCollatLiquidity;
      deltaPortion = totalLiquidity.sub(collatPortion);
    } else if (liquidity.usedDeltaLiquidity > deltaPortion) {
      deltaPortion = liquidity.usedDeltaLiquidity;
      collatPortion = totalLiquidity.sub(deltaPortion);
    }

    liquidity.freeDeltaLiquidity = deltaPortion.sub(liquidity.usedDeltaLiquidity);
    liquidity.freeCollatLiquidity = collatPortion.sub(liquidity.usedCollatLiquidity);

    return liquidity;
  }

  //////////
  // Misc //
  //////////

  /**
   * @notice Sends quoteAsset to the PoolHedger.
   * @dev This function will transfer whatever free delta liquidity is available.
   * The hedger must determine what to do with the amount received.
   *
   * @param exchangeGlobals The exchangeGlobals.
   * @param amount The amount requested by the PoolHedger.
   */
  function transferQuoteToHedge(ILyraGlobals.ExchangeGlobals memory exchangeGlobals, uint amount)
    external
    override
    onlyPoolHedger
    reentrancyGuard
    returns (uint)
  {
    Liquidity memory liquidity = getLiquidity(exchangeGlobals.spotPrice, exchangeGlobals.short);

    uint available = liquidity.freeDeltaLiquidity;
    if (available < amount) {
      amount = available;
    }
    _require(quoteAsset.transfer(address(poolHedger), amount), Error.QuoteTransferFailed);

    emit DeltaQuoteTransferredToPoolHedger(amount);

    return amount;
  }

  function _require(bool pass, Error error) internal view {
    require(pass, errorMessages[uint(error)]);
  }

  ///////////////
  // Modifiers //
  ///////////////

  modifier onlyPoolHedger virtual {
    _require(msg.sender == address(poolHedger), Error.OnlyPoolHedger);
    _;
  }

  modifier onlyOptionMarket virtual {
    _require(msg.sender == address(optionMarket), Error.OnlyOptionMarket);
    _;
  }

  modifier onlyShortCollateral virtual {
    _require(msg.sender == address(shortCollateral), Error.OnlyShortCollateral);
    _;
  }

  modifier reentrancyGuard virtual {
    counter = counter.add(1); // counter adds 1 to the existing 1 so becomes 2
    uint guard = counter; // assigns 2 to the "guard" variable
    _;
    _require(guard == counter, Error.ReentrancyDetected);
  }

  /**
   * @dev Emitted when liquidity is deposited.
   */
  event Deposit(address indexed beneficiary, uint indexed certificateId, uint amount);
  /**
   * @dev Emitted when withdrawal is signaled.
   */
  event WithdrawSignaled(uint indexed certificateId, uint tokensBurnableForRound);
  /**
   * @dev Emitted when a withdrawal is unsignaled.
   */
  event WithdrawUnSignaled(uint indexed certificateId, uint tokensBurnableForRound);
  /**
   * @dev Emitted when liquidity is withdrawn.
   */
  event Withdraw(address indexed beneficiary, uint indexed certificateId, uint value, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when a round ends.
   */
  event RoundEnded(
    uint indexed maxExpiryTimestamp,
    uint pricePerToken,
    uint totalQuoteAmountReserved,
    uint tokensBurnableForRound
  );
  /**
   * @dev Emitted when a round starts.
   */
  event RoundStarted(
    uint indexed lastMaxExpiryTimestamp,
    uint indexed newMaxExpiryTimestamp,
    uint totalTokenSupply,
    uint tokenValue
  );
  /**
   * @dev Emitted when quote is locked.
   */
  event QuoteLocked(uint quoteLocked, uint lockedCollateralQuote);
  /**
   * @dev Emitted when base is locked.
   */
  event BaseLocked(uint baseLocked, uint lockedCollateralBase);
  /**
   * @dev Emitted when quote is freed.
   */
  event QuoteFreed(uint quoteFreed, uint lockedCollateralQuote);
  /**
   * @dev Emitted when base is freed.
   */
  event BaseFreed(uint baseFreed, uint lockedCollateralBase);
  /**
   * @dev Emitted when base is purchased.
   */
  event BasePurchased(address indexed caller, uint quoteSpent, uint amountPurchased);
  /**
   * @dev Emitted when base is sold.
   */
  event BaseSold(address indexed caller, uint amountSold, uint quoteReceived);
  /**
   * @dev Emitted when collateral is liquidated. This combines LP profit from short calls and freeing base collateral
   */
  event CollateralLiquidated(
    uint totalAmountToLiquidate,
    uint baseFreed,
    uint quoteReceived,
    uint lockedCollateralBase
  );
  /**
   * @dev Emitted when quote is reserved.
   */
  event QuoteReserved(uint amountQuoteReserved, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when reserved quote is sent.
   */
  event ReservedQuoteSent(address indexed user, uint amount, uint totalQuoteAmountReserved);
  /**
   * @dev Emitted when collatQuote is transferred.
   */
  event CollateralQuoteTransferred(address indexed recipient, uint amount);
  /**
   * @dev Emitted when quote is transferred to hedge.
   */
  event DeltaQuoteTransferredToPoolHedger(uint amount);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Inherited
import "./openzeppelin-l2/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOptionToken.sol";

/**
 * @title OptionToken
 * @author Lyra
 * @dev Provides a tokenised representation of each OptionListing offered
 * by the OptionMarket.
 */
contract OptionToken is IOptionToken, ERC1155, Ownable {
  bool internal initialized = false;
  address internal optionMarket;

  constructor(string memory uri_) ERC1155(uri_) Ownable() {}

  /**
   * @dev Initialise the contract.
   * @param _optionMarket The OptionMarket contract address.
   */
  function init(address _optionMarket) external {
    require(!initialized, "contract already initialized");
    optionMarket = _optionMarket;
    initialized = true;
  }

  /**
   * @dev Initialise the contract.
   * @param newURI The new uri definition for the contract.
   */
  function setURI(string memory newURI) external override onlyOwner {
    _setURI(newURI);
  }

  /**
   * @dev Initialise the contract.
   *
   * @param account The owner of the tokens.
   * @param id The listingId + tradeType of the option.
   * @param amount The amount of options.
   */
  function mint(
    address account,
    uint id,
    uint amount
  ) external override onlyOptionMarket {
    bytes memory data;
    _mint(account, id, amount, data);
  }

  /**
   * @dev Burn the specified amount of token for the account.
   *
   * @param account The owner of the tokens.
   * @param id The listingId + tradeType of the option.
   * @param amount The amount of options.
   */
  function burn(
    address account,
    uint id,
    uint amount
  ) external override onlyOptionMarket {
    _burn(account, id, amount);
  }

  modifier onlyOptionMarket virtual {
    require(msg.sender == address(optionMarket), "only OptionMarket");
    _;
  }
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";
import "./synthetix/SignedSafeDecimalMath.sol";

// Inherited
import "@openzeppelin/contracts/access/Ownable.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IBlackScholes.sol";
import "./interfaces/ILyraGlobals.sol";
import "./interfaces/IOptionMarket.sol";
import "./interfaces/IOptionMarketPricer.sol";
import "./interfaces/IOptionGreekCache.sol";

/**
 * @title OptionGreekCache
 * @author Lyra
 * @dev Aggregates the netDelta and netStdVega of the OptionMarket by iterating over current listings.
 * Needs to be called by an external override actor as it's not feasible to do all the computation during the trade flow and
 * because delta/vega change over time and with movements in asset price and volatility.
 */
contract OptionGreekCache is IOptionGreekCache, Ownable {
  using SafeMath for uint;
  using SafeDecimalMath for uint;
  using SignedSafeMath for int;
  using SignedSafeDecimalMath for int;

  ILyraGlobals internal globals;
  IOptionMarket internal optionMarket;
  IOptionMarketPricer internal optionPricer;
  IBlackScholes internal blackScholes;

  // Limit due to gas constraints when updating
  uint public constant override MAX_LISTINGS_PER_BOARD = 10;

  // For calculating if the cache is stale based on spot price
  // These values can be quite wide as per listing updates occur whenever a trade does.
  uint public override staleUpdateDuration = 2 days;
  uint public override priceScalingPeriod = 7 days;
  uint public override maxAcceptablePercent = (1e18 / 100) * 20; // 20%
  uint public override minAcceptablePercent = (1e18 / 100) * 10; // 10%

  bool internal initialized;

  uint[] public override liveBoards; // Should be a clone of OptionMarket.liveBoards
  mapping(uint => OptionListingCache) public override listingCaches;
  mapping(uint => OptionBoardCache) public override boardCaches;
  GlobalCache public override globalCache;

  constructor() Ownable() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _globals LyraGlobals address
   * @param _optionMarket OptionMarket address
   * @param _optionPricer OptionMarketPricer address
   */
  function init(
    ILyraGlobals _globals,
    IOptionMarket _optionMarket,
    IOptionMarketPricer _optionPricer,
    IBlackScholes _blackScholes
  ) external {
    require(!initialized, "Contract already initialized");
    globals = _globals;
    optionMarket = _optionMarket;
    optionPricer = _optionPricer;
    blackScholes = _blackScholes;
    initialized = true;
  }

  function setStaleCacheParameters(
    uint _staleUpdateDuration,
    uint _priceScalingPeriod,
    uint _maxAcceptablePercent,
    uint _minAcceptablePercent
  ) external override onlyOwner {
    require(_staleUpdateDuration >= 2 hours, "staleUpdateDuration too low");
    require(_maxAcceptablePercent >= _minAcceptablePercent, "maxAcceptablePercent must be >= min");
    require(_minAcceptablePercent >= (1e18 / 100) * 1, "minAcceptablePercent too low");
    // Note: this value can be zero even though it is in the divisor as timeToExpiry must be < priceScalingPeriod for it
    // to be used.
    priceScalingPeriod = _priceScalingPeriod;
    minAcceptablePercent = _minAcceptablePercent;
    maxAcceptablePercent = _maxAcceptablePercent;
    staleUpdateDuration = _staleUpdateDuration;

    emit StaleCacheParametersUpdated(
      priceScalingPeriod,
      minAcceptablePercent,
      maxAcceptablePercent,
      staleUpdateDuration
    );
  }

  ////
  // Add/Remove boards
  ////

  /**
   * @notice Adds a new OptionBoardCache.
   * @dev Called by the OptionMarket when an OptionBoard is added.
   *
   * @param boardId The id of the OptionBoard.
   */
  function addBoard(uint boardId) external override onlyOptionMarket {
    // Load in board from OptionMarket, adding net positions to global count
    (, uint expiry, uint iv, ) = optionMarket.optionBoards(boardId);
    uint[] memory listings = optionMarket.getBoardListings(boardId);

    require(listings.length <= MAX_LISTINGS_PER_BOARD, "too many listings for board");

    OptionBoardCache storage boardCache = boardCaches[boardId];
    boardCache.id = boardId;
    boardCache.expiry = expiry;
    boardCache.iv = iv;
    liveBoards.push(boardId);

    for (uint i = 0; i < listings.length; i++) {
      _addNewListingToListingCache(boardCache, listings[i]);
    }

    _updateBoardLastUpdatedAt(boardCache);
  }

  /**
   * @notice Removes an OptionBoardCache.
   * @dev Called by the OptionMarket when an OptionBoard is liquidated.
   *
   * @param boardId The id of the OptionBoard.
   */
  function removeBoard(uint boardId) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionBoardCache memory boardCache = boardCaches[boardId];
    globalCache.netDelta = globalCache.netDelta.sub(boardCache.netDelta);
    globalCache.netStdVega = globalCache.netStdVega.sub(boardCache.netStdVega);
    // Clean up, cache isn't necessary for settle logic
    for (uint i = 0; i < boardCache.listings.length; i++) {
      delete listingCaches[boardCache.listings[i]];
    }
    for (uint i = 0; i < liveBoards.length; i++) {
      if (liveBoards[i] == boardId) {
        liveBoards[i] = liveBoards[liveBoards.length - 1];
        liveBoards.pop();
        break;
      }
    }
    delete boardCaches[boardId];
    emit GlobalCacheUpdated(globalCache.netDelta, globalCache.netStdVega);
  }

  /**
   * @dev modifies an OptionBoard's baseIv
   *
   * @param boardId The id of the OptionBoard.
   * @param newIv The baseIv of the OptionBoard.
   */
  function setBoardIv(uint boardId, uint newIv) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionBoardCache storage boardCache = boardCaches[boardId];
    boardCache.iv = newIv;
  }

  /**
   * @dev modifies an OptionListing's skew
   *
   * @param listingId The id of the OptionListing.
   * @param newSkew The skew of the OptionListing.
   */
  function setListingSkew(uint listingId, uint newSkew) external override onlyOptionMarket {
    // Remove board from cache, removing net positions from global count
    OptionListingCache storage listingCache = listingCaches[listingId];
    listingCache.skew = newSkew;
  }

  /**
   * @notice Add a new listing to the listingCaches and the listingId to the boardCache
   *
   * @param boardId The id of the Board
   * @param listingId The id of the OptionListing.
   */
  function addListingToBoard(uint boardId, uint listingId) external override onlyOptionMarket {
    OptionBoardCache storage boardCache = boardCaches[boardId];
    require(boardCache.listings.length + 1 <= MAX_LISTINGS_PER_BOARD, "too many listings for board");
    _addNewListingToListingCache(boardCache, listingId);
  }

  /**
   * @notice Add a new listing to the listingCaches
   *
   * @param boardCache The OptionBoardCache object the listing is being added to
   * @param listingId The id of the OptionListing.
   */
  function _addNewListingToListingCache(OptionBoardCache storage boardCache, uint listingId) internal {
    IOptionMarket.OptionListing memory listing = getOptionMarketListing(listingId);

    // This is only called when a new board or a new listing is added, so exposure values will be 0
    OptionListingCache storage listingCache = listingCaches[listing.id];
    listingCache.id = listing.id;
    listingCache.strike = listing.strike;
    listingCache.boardId = listing.boardId;
    listingCache.skew = listing.skew;

    boardCache.listings.push(listingId);
  }

  /**
   * @notice Retrieves an OptionListing from the OptionMarket.
   *
   * @param listingId The id of the OptionListing.
   */
  function getOptionMarketListing(uint listingId) internal view returns (IOptionMarket.OptionListing memory) {
    (uint id, uint strike, uint skew, uint longCall, uint shortCall, uint longPut, uint shortPut, uint boardId) =
      optionMarket.optionListings(listingId);
    return IOptionMarket.OptionListing(id, strike, skew, longCall, shortCall, longPut, shortPut, boardId);
  }

  ////
  // Updating greeks/caches
  ////

  /**
   * @notice Updates all stale boards.
   */
  function updateAllStaleBoards() external override returns (int) {
    // Check all boards to see if they are stale
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals = globals.getGreekCacheGlobals(address(optionMarket));
    _updateAllStaleBoards(greekCacheGlobals);
    return globalCache.netDelta;
  }

  /**
   * @dev Updates all stale boards.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   */
  function _updateAllStaleBoards(ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals) internal {
    for (uint i = 0; i < liveBoards.length; i++) {
      uint boardId = liveBoards[i];
      if (_isBoardCacheStale(boardId, greekCacheGlobals.spotPrice)) {
        // This updates all listings in the board, even though it is not strictly necessary
        _updateBoardCachedGreeks(greekCacheGlobals, boardId);
      }
    }
  }

  /**
   * @notice Updates the cached greeks for an OptionBoardCache.
   *
   * @param boardCacheId The id of the OptionBoardCache.
   */
  function updateBoardCachedGreeks(uint boardCacheId) external override {
    _updateBoardCachedGreeks(globals.getGreekCacheGlobals(address(optionMarket)), boardCacheId);
  }

  /**
   * @dev Updates the cached greeks for an OptionBoardCache.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param boardCacheId The id of the OptionBoardCache.
   */
  function _updateBoardCachedGreeks(ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals, uint boardCacheId)
    internal
  {
    OptionBoardCache storage boardCache = boardCaches[boardCacheId];
    // In the case the board doesnt exist, listings.length is 0, so nothing happens
    for (uint i = 0; i < boardCache.listings.length; i++) {
      OptionListingCache storage listingCache = listingCaches[boardCache.listings[i]];
      _updateListingCachedGreeks(
        greekCacheGlobals,
        listingCache,
        boardCache,
        true,
        listingCache.callExposure,
        listingCache.putExposure
      );
    }

    boardCache.minUpdatedAt = block.timestamp;
    boardCache.minUpdatedAtPrice = greekCacheGlobals.spotPrice;
    boardCache.maxUpdatedAtPrice = greekCacheGlobals.spotPrice;
    _updateGlobalLastUpdatedAt();
  }

  /**
   * @notice Updates the OptionListingCache to reflect the new exposure.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param listingCacheId The id of the OptionListingCache.
   * @param newCallExposure The new call exposure of the OptionListing.
   * @param newPutExposure The new put exposure of the OptionListing.
   * @param iv The new iv of the OptionBoardCache.
   * @param skew The new skew of the OptionListingCache.
   */
  function updateListingCacheAndGetPrice(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    uint listingCacheId,
    int newCallExposure,
    int newPutExposure,
    uint iv,
    uint skew
  ) external override onlyOptionMarketPricer returns (IOptionMarketPricer.Pricing memory) {
    require(!_isGlobalCacheStale(greekCacheGlobals.spotPrice), "Global cache is stale");
    OptionListingCache storage listingCache = listingCaches[listingCacheId];
    OptionBoardCache storage boardCache = boardCaches[listingCache.boardId];

    int callExposureDiff = newCallExposure.sub(listingCache.callExposure);
    int putExposureDiff = newPutExposure.sub(listingCache.putExposure);

    require(callExposureDiff == 0 || putExposureDiff == 0, "both call and put exposure updated");

    boardCache.iv = iv;
    listingCache.skew = skew;

    // The AMM's net std vega is opposite to the global sum of user's std vega
    int preTradeAmmNetStdVega = -globalCache.netStdVega;

    IOptionMarketPricer.Pricing memory pricing =
      _updateListingCachedGreeks(
        greekCacheGlobals,
        listingCache,
        boardCache,
        callExposureDiff != 0,
        newCallExposure,
        newPutExposure
      );
    pricing.preTradeAmmNetStdVega = preTradeAmmNetStdVega;

    _updateBoardLastUpdatedAt(boardCache);

    return pricing;
  }

  /**
   * @dev Updates an OptionListingCache.
   *
   * @param greekCacheGlobals The GreekCacheGlobals.
   * @param listingCache The OptionListingCache.
   * @param boardCache The OptionBoardCache.
   * @param returnCallPrice If true, return the call price, otherwise return the put price.
   */
  function _updateListingCachedGreeks(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    OptionListingCache storage listingCache,
    OptionBoardCache storage boardCache,
    bool returnCallPrice,
    int newCallExposure,
    int newPutExposure
  ) internal returns (IOptionMarketPricer.Pricing memory pricing) {
    IBlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega =
      blackScholes.pricesDeltaStdVega(
        timeToMaturitySeconds(boardCache.expiry),
        boardCache.iv.multiplyDecimal(listingCache.skew),
        greekCacheGlobals.spotPrice,
        listingCache.strike,
        greekCacheGlobals.rateAndCarry
      );

    // (newCallExposure * newCallDelta - oldCallExposure * oldCallDelta)
    // + (newPutExposure * newPutDelta - oldPutExposure * oldPutDelta)
    int netDeltaDiff =
      (
        (newCallExposure.multiplyDecimal(pricesDeltaStdVega.callDelta)) // newCall
          .sub(listingCache.callExposure.multiplyDecimal(listingCache.callDelta))
          .add(
          (newPutExposure.multiplyDecimal(pricesDeltaStdVega.putDelta)).sub(
            listingCache.putExposure.multiplyDecimal(listingCache.putDelta)
          )
        )
      );

    int netStdVegaDiff =
      newCallExposure.add(newPutExposure).multiplyDecimal(int(pricesDeltaStdVega.stdVega)).sub(
        listingCache.callExposure.add(listingCache.putExposure).multiplyDecimal(int(listingCache.stdVega))
      );

    if (listingCache.callExposure != newCallExposure || listingCache.putExposure != newPutExposure) {
      emit ListingExposureUpdated(listingCache.id, newCallExposure, newPutExposure);
    }

    listingCache.callExposure = newCallExposure;
    listingCache.putExposure = newPutExposure;
    listingCache.callDelta = pricesDeltaStdVega.callDelta;
    listingCache.putDelta = pricesDeltaStdVega.putDelta;
    listingCache.stdVega = pricesDeltaStdVega.stdVega;

    listingCache.updatedAt = block.timestamp;
    listingCache.updatedAtPrice = greekCacheGlobals.spotPrice;

    boardCache.netDelta = boardCache.netDelta.add(netDeltaDiff);
    boardCache.netStdVega = boardCache.netStdVega.add(netStdVegaDiff);

    globalCache.netDelta = globalCache.netDelta.add(netDeltaDiff);
    globalCache.netStdVega = globalCache.netStdVega.add(netStdVegaDiff);

    pricing.optionPrice = returnCallPrice ? pricesDeltaStdVega.callPrice : pricesDeltaStdVega.putPrice;
    // AMM's net positions are the inverse of the user's net position
    pricing.postTradeAmmNetStdVega = -globalCache.netStdVega;
    pricing.callDelta = pricesDeltaStdVega.callDelta;

    emit ListingGreeksUpdated(
      listingCache.id,
      pricesDeltaStdVega.callDelta,
      pricesDeltaStdVega.putDelta,
      pricesDeltaStdVega.stdVega,
      greekCacheGlobals.spotPrice,
      boardCache.iv,
      listingCache.skew
    );
    emit GlobalCacheUpdated(globalCache.netDelta, globalCache.netStdVega);

    return pricing;
  }

  /**
   * @notice Checks if the GlobalCache is stale.
   */
  function isGlobalCacheStale() external view override returns (bool) {
    // Check all boards to see if they are stale
    uint currentPrice = getCurrentPrice();
    return _isGlobalCacheStale(currentPrice);
  }

  /**
   * @dev Checks if the GlobalCache is stale.
   *
   * @param spotPrice The price of the baseAsset.
   */
  function _isGlobalCacheStale(uint spotPrice) internal view returns (bool) {
    // Check all boards to see if they are stale
    return (isUpdatedAtTimeStale(globalCache.minUpdatedAt) ||
      !isPriceMoveAcceptable(
        globalCache.minUpdatedAtPrice,
        spotPrice,
        timeToMaturitySeconds(globalCache.minExpiryTimestamp)
      ) ||
      !isPriceMoveAcceptable(
        globalCache.maxUpdatedAtPrice,
        spotPrice,
        timeToMaturitySeconds(globalCache.minExpiryTimestamp)
      ));
  }

  /**
   * @notice Checks if the OptionBoardCache is stale.
   *
   * @param boardCacheId The OptionBoardCache id.
   */
  function isBoardCacheStale(uint boardCacheId) external view override returns (bool) {
    uint spotPrice = getCurrentPrice();
    return _isBoardCacheStale(boardCacheId, spotPrice);
  }

  /**
   * @dev Checks if the OptionBoardCache is stale.
   *
   * @param boardCacheId The OptionBoardCache id.
   * @param spotPrice The price of the baseAsset.
   */
  function _isBoardCacheStale(uint boardCacheId, uint spotPrice) internal view returns (bool) {
    // We do not have to check every individual listing, as the OptionBoardCache
    // should always keep the minimum values.
    OptionBoardCache memory boardCache = boardCaches[boardCacheId];
    require(boardCache.id != 0, "Board does not exist");

    return
      isUpdatedAtTimeStale(boardCache.minUpdatedAt) ||
      !isPriceMoveAcceptable(boardCache.minUpdatedAtPrice, spotPrice, timeToMaturitySeconds(boardCache.expiry)) ||
      !isPriceMoveAcceptable(boardCache.maxUpdatedAtPrice, spotPrice, timeToMaturitySeconds(boardCache.expiry));
  }

  /**
   * @dev Checks if `updatedAt` is stale.
   *
   * @param updatedAt The time of the last update.
   */
  function isUpdatedAtTimeStale(uint updatedAt) internal view returns (bool) {
    // This can be more complex than just checking the item wasn't updated in the last two hours
    return getSecondsTo(updatedAt, block.timestamp) > staleUpdateDuration;
  }

  /**
   * @dev Check if the price move of an asset is acceptable given the time to expiry.
   *
   * @param pastPrice The previous price.
   * @param currentPrice The current price.
   * @param timeToExpirySec The time to expiry in seconds.
   */
  function isPriceMoveAcceptable(
    uint pastPrice,
    uint currentPrice,
    uint timeToExpirySec
  ) internal view returns (bool) {
    uint acceptablePriceMovementPercent = maxAcceptablePercent;

    if (timeToExpirySec < priceScalingPeriod) {
      acceptablePriceMovementPercent = ((maxAcceptablePercent.sub(minAcceptablePercent)).mul(timeToExpirySec))
        .div(priceScalingPeriod)
        .add(minAcceptablePercent);
    }

    uint acceptablePriceMovement = pastPrice.multiplyDecimal(acceptablePriceMovementPercent);

    if (currentPrice > pastPrice) {
      return currentPrice.sub(pastPrice) < acceptablePriceMovement;
    } else {
      return pastPrice.sub(currentPrice) < acceptablePriceMovement;
    }
  }

  /**
   * @dev Updates `lastUpdatedAt` for an OptionBoardCache.
   *
   * @param boardCache The OptionBoardCache.
   */
  function _updateBoardLastUpdatedAt(OptionBoardCache storage boardCache) internal {
    OptionListingCache memory listingCache = listingCaches[boardCache.listings[0]];
    uint minUpdate = listingCache.updatedAt;
    uint minPrice = listingCache.updatedAtPrice;
    uint maxPrice = listingCache.updatedAtPrice;

    for (uint i = 1; i < boardCache.listings.length; i++) {
      listingCache = listingCaches[boardCache.listings[i]];
      if (listingCache.updatedAt < minUpdate) {
        minUpdate = listingCache.updatedAt;
      }
      if (listingCache.updatedAtPrice < minPrice) {
        minPrice = listingCache.updatedAtPrice;
      } else if (listingCache.updatedAtPrice > maxPrice) {
        maxPrice = listingCache.updatedAtPrice;
      }
    }
    boardCache.minUpdatedAt = minUpdate;
    boardCache.minUpdatedAtPrice = minPrice;
    boardCache.maxUpdatedAtPrice = maxPrice;

    _updateGlobalLastUpdatedAt();
  }

  /**
   * @dev Updates global `lastUpdatedAt`.
   */
  function _updateGlobalLastUpdatedAt() internal {
    OptionBoardCache memory boardCache = boardCaches[liveBoards[0]];
    uint minUpdate = boardCache.minUpdatedAt;
    uint minPrice = boardCache.minUpdatedAtPrice;
    uint minExpiry = boardCache.expiry;
    uint maxPrice = boardCache.maxUpdatedAtPrice;

    for (uint i = 1; i < liveBoards.length; i++) {
      boardCache = boardCaches[liveBoards[i]];
      if (boardCache.minUpdatedAt < minUpdate) {
        minUpdate = boardCache.minUpdatedAt;
      }
      if (boardCache.minUpdatedAtPrice < minPrice) {
        minPrice = boardCache.minUpdatedAtPrice;
      }
      if (boardCache.maxUpdatedAtPrice > maxPrice) {
        maxPrice = boardCache.maxUpdatedAtPrice;
      }
      if (boardCache.expiry < minExpiry) {
        minExpiry = boardCache.expiry;
      }
    }

    globalCache.minUpdatedAt = minUpdate;
    globalCache.minUpdatedAtPrice = minPrice;
    globalCache.maxUpdatedAtPrice = maxPrice;
    globalCache.minExpiryTimestamp = minExpiry;
  }

  /**
   * @dev Returns time to maturity for a given expiry.
   */
  function timeToMaturitySeconds(uint expiry) internal view returns (uint) {
    return getSecondsTo(block.timestamp, expiry);
  }

  /**
   * @dev Returns the difference in seconds between two dates.
   */
  function getSecondsTo(uint fromTime, uint toTime) internal pure returns (uint) {
    if (toTime > fromTime) {
      return toTime - fromTime;
    }
    return 0;
  }

  /**
   * @dev Get the price of the baseAsset for the OptionMarket.
   */
  function getCurrentPrice() internal view returns (uint) {
    return globals.getSpotPriceForMarket(address(optionMarket));
  }

  /**
   * @dev Get the current cached global netDelta value.
   */
  function getGlobalNetDelta() external view override returns (int) {
    return globalCache.netDelta;
  }

  modifier onlyOptionMarket virtual {
    require(msg.sender == address(optionMarket), "Only optionMarket permitted");
    _;
  }

  modifier onlyOptionMarketPricer virtual {
    require(msg.sender == address(optionPricer), "Only optionPricer permitted");
    _;
  }

  /**
   * @dev Emitted when stale cache parameters are updated.
   */
  event StaleCacheParametersUpdated(
    uint priceScalingPeriod,
    uint minAcceptablePercent,
    uint maxAcceptablePercent,
    uint staleUpdateDuration
  );

  /**
   * @dev Emitted when the cache of an OptionListing is updated.
   */
  event ListingGreeksUpdated(
    uint indexed listingId,
    int callDelta,
    int putDelta,
    uint vega,
    uint price,
    uint baseIv,
    uint skew
  );

  /**
   * @dev Emitted when the exposure of an OptionListing is updated.
   */
  event ListingExposureUpdated(uint indexed listingId, int newCallExposure, int newPutExposure);

  /**
   * @dev Emitted when the GlobalCache is updated.
   */
  event GlobalCacheUpdated(int netDelta, int netStdVega);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

// Libraries
import "./synthetix/SafeDecimalMath.sol";
// Inherited
// Interfaces
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IPoolHedger.sol";
import "./interfaces/ILyraGlobals.sol";
import "./interfaces/ILiquidityPool.sol";
import "./interfaces/IOptionMarket.sol";
import "./interfaces/IShortCollateral.sol";

/**
 * @title ShortCollateral
 * @author Lyra
 * @dev Holds collateral from users who are selling (shorting) options to the OptionMarket.
 */
contract ShortCollateral is IShortCollateral {
  using SafeMath for uint;
  using SafeDecimalMath for uint;

  bool internal initialized = false;

  IOptionMarket internal optionMarket;
  ILiquidityPool internal liquidityPool;
  IERC20 internal quoteAsset;
  IERC20 internal baseAsset;

  constructor() {}

  /**
   * @dev Initialize the contract.
   *
   * @param _optionMarket OptionMarket address
   * @param _liquidityPool LiquidityPool address
   * @param _quoteAsset Quote asset address
   * @param _baseAsset Base asset address
   */
  function init(
    IOptionMarket _optionMarket,
    ILiquidityPool _liquidityPool,
    IERC20 _quoteAsset,
    IERC20 _baseAsset
  ) external {
    require(!initialized, "contract already initialized");
    optionMarket = _optionMarket;
    liquidityPool = _liquidityPool;
    quoteAsset = _quoteAsset;
    baseAsset = _baseAsset;
    initialized = true;
  }

  /**
   * @dev Transfers quoteAsset to the recipient.
   *
   * @param recipient The recipient of the transfer.
   * @param amount The amount to send.
   */
  function sendQuoteCollateral(address recipient, uint amount) external override onlyOptionMarket {
    uint currentBalance = quoteAsset.balanceOf(address(this));
    if (amount > currentBalance) {
      amount = currentBalance;
    }
    require(quoteAsset.transfer(recipient, amount), "transfer failed");
    emit QuoteSent(recipient, amount);
  }

  /**
   * @dev Transfers baseAsset to the recipient.
   *
   * @param recipient The recipient of the transfer.
   * @param amount The amount to send.
   */
  function sendBaseCollateral(address recipient, uint amount) external override onlyOptionMarket {
    uint currentBalance = baseAsset.balanceOf(address(this));
    if (amount > currentBalance) {
      amount = currentBalance;
    }
    require(baseAsset.transfer(recipient, amount), "transfer failed");
    emit BaseSent(recipient, amount);
  }

  /**
   * @dev Transfers quoteAsset and baseAsset to the LiquidityPool.
   *
   * @param amountBase The amount of baseAsset to transfer.
   * @param amountQuote The amount of quoteAsset to transfer.
   */
  function sendToLP(uint amountBase, uint amountQuote) external override onlyOptionMarket {
    uint currentBaseBalance = baseAsset.balanceOf(address(this));
    if (amountBase > currentBaseBalance) {
      amountBase = currentBaseBalance;
    }
    if (amountBase > 0) {
      require(baseAsset.transfer(address(liquidityPool), amountBase), "base transfer failed");
      emit BaseSent(address(liquidityPool), amountBase);
    }

    uint currentQuoteBalance = quoteAsset.balanceOf(address(this));
    if (amountQuote > currentQuoteBalance) {
      amountQuote = currentQuoteBalance;
    }
    if (amountQuote > 0) {
      require(quoteAsset.transfer(address(liquidityPool), amountQuote), "quote transfer failed");
      emit QuoteSent(address(liquidityPool), amountQuote);
    }
  }

  /**
   * @dev Called by the OptionMarket when the owner of an option settles.
   *
   * @param listingId The OptionListing.
   * @param receiver The address of the receiver.
   * @param tradeType The TradeType.
   * @param amount The amount to settle.
   * @param strike The strike price of the OptionListing.
   * @param priceAtExpiry The price of baseAsset at expiry.
   * @param listingToShortCallBaseReturned The amount of baseAsset to be returned.
   */
  function processSettle(
    uint listingId,
    address receiver,
    IOptionMarket.TradeType tradeType,
    uint amount,
    uint strike,
    uint priceAtExpiry,
    uint listingToShortCallBaseReturned
  ) external override onlyOptionMarket {
    // Check board has been liquidated
    require(priceAtExpiry != 0, "board must be liquidated");
    require(amount > 0, "option position is 0");

    if (tradeType == IOptionMarket.TradeType.SHORT_CALL) {
      require(
        baseAsset.transfer(receiver, listingToShortCallBaseReturned.multiplyDecimal(amount)),
        "base transfer failed"
      );
    } else if (tradeType == IOptionMarket.TradeType.LONG_CALL && strike < priceAtExpiry) {
      // long call finished in the money
      liquidityPool.sendReservedQuote(receiver, (priceAtExpiry - strike).multiplyDecimal(amount));
    } else if (tradeType == IOptionMarket.TradeType.SHORT_PUT) {
      // If the listing finished in the money;
      // = we pay out the priceAtExpiry (strike - (strike - priceAtExpiry) == priceAtExpiry)
      // Otherwise pay back the strike...
      uint balance = quoteAsset.balanceOf(address(this));
      uint owed = amount.multiplyDecimal((strike > priceAtExpiry) ? priceAtExpiry : strike);
      require(
        quoteAsset.transfer(
          receiver,
          // Return the full balance if owed > balance due to rounding errors
          owed > balance ? balance : owed
        ),
        "quote transfer failed"
      );
    } else if (tradeType == IOptionMarket.TradeType.LONG_PUT && strike > priceAtExpiry) {
      // user was long put and it finished in the money
      liquidityPool.sendReservedQuote(receiver, (strike - priceAtExpiry).multiplyDecimal(amount));
    }

    emit OptionsSettled(listingId, receiver, strike, priceAtExpiry, tradeType, amount);
  }

  // Modifiers

  modifier onlyOptionMarket virtual {
    require(msg.sender == address(optionMarket), "only OptionMarket");
    _;
  }

  // Events

  /**
   * @dev Emitted when an Option is settled.
   */
  event OptionsSettled(
    uint indexed listingId,
    address indexed optionOwner,
    uint strike,
    uint priceAtExpiry,
    IOptionMarket.TradeType tradeType,
    uint amount
  );

  /**
   * @dev Emitted when quote is sent to either a user or the LiquidityPool
   */
  event QuoteSent(address indexed receiver, uint amount);
  /**
   * @dev Emitted when base is sent to either a user or the LiquidityPool
   */
  event BaseSent(address indexed receiver, uint amount);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";

interface IOptionToken is IERC1155, IERC1155MetadataURI {
  function setURI(string memory newURI) external;

  function mint(
    address account,
    uint id,
    uint amount
  ) external;

  function burn(
    address account,
    uint id,
    uint amount
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        uint256 c = a + b;
        if (c < a) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b > a) return (false, 0);
        return (true, a - b);
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) return (true, 0);
        uint256 c = a * b;
        if (c / a != b) return (false, 0);
        return (true, c);
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a / b);
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        if (b == 0) return (false, 0);
        return (true, a % b);
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
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
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
        require(b <= a, "SafeMath: subtraction overflow");
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
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
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
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
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
        require(b > 0, "SafeMath: modulo by zero");
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
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        return a - b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryDiv}.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a / b;
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
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        return a % b;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
  function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
    external
    view
    returns (uint exchangeFeeRate);
}

//SPDX-License-Identifier: ISC
pragma solidity >=0.7.6;
pragma experimental ABIEncoderV2;

interface ICollateralShort {
  struct Loan {
    // ID for the loan
    uint id;
    //  Account that created the loan
    address account;
    //  Amount of collateral deposited
    uint collateral;
    // The synth that was borrowed
    bytes32 currency;
    //  Amount of synths borrowed
    uint amount;
    // Indicates if the position was short sold
    bool short;
    // interest amounts accrued
    uint accruedInterest;
    // last interest index
    uint interestIndex;
    // time of last interaction.
    uint lastInteraction;
  }

  function loans(uint id)
    external
    returns (
      uint,
      address,
      uint,
      bytes32,
      uint,
      bool,
      uint,
      uint,
      uint
    );

  function minCratio() external returns (uint);

  function minCollateral() external returns (uint);

  function issueFeeRate() external returns (uint);

  function open(
    uint collateral,
    uint amount,
    bytes32 currency
  ) external returns (uint id);

  function repay(
    address borrower,
    uint id,
    uint amount
  ) external returns (uint short, uint collateral);

  function repayWithCollateral(uint id, uint repayAmount) external returns (uint short, uint collateral);

  function draw(uint id, uint amount) external returns (uint short, uint collateral);

  // Same as before
  function deposit(
    address borrower,
    uint id,
    uint amount
  ) external returns (uint short, uint collateral);

  // Same as before
  function withdraw(uint id, uint amount) external returns (uint short, uint collateral);

  // function to return the loan details in one call, without needing to know about the collateralstate
  function getShortAndCollateral(address account, uint id) external view returns (uint short, uint collateral);
}

//SPDX-License-Identifier: ISC
pragma solidity >=0.7.6;

interface ISynthetix {
  function exchange(
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);

  function exchangeOnBehalf(
    address exchangeForAddress,
    bytes32 sourceCurrencyKey,
    uint sourceAmount,
    bytes32 destinationCurrencyKey
  ) external returns (uint amountReceived);
}

//SPDX-License-Identifier:MIT
pragma solidity ^0.7.6;

// https://docs.synthetix.io/contracts/source/interfaces/iexchangerates
interface IExchangeRates {
  function rateAndInvalid(bytes32 currencyKey) external view returns (uint rate, bool isInvalid);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";

interface ILiquidityPool {
  struct Collateral {
    uint quote;
    uint base;
  }

  /// @dev These are all in quoteAsset amounts.
  struct Liquidity {
    uint freeCollatLiquidity;
    uint usedCollatLiquidity;
    uint freeDeltaLiquidity;
    uint usedDeltaLiquidity;
  }

  enum Error {
    QuoteTransferFailed,
    AlreadySignalledWithdrawal,
    SignallingBetweenRounds,
    UnSignalMustSignalFirst,
    UnSignalAlreadyBurnable,
    WithdrawNotBurnable,
    EndRoundWithLiveBoards,
    EndRoundAlreadyEnded,
    EndRoundMustExchangeBase,
    EndRoundMustHedgeDelta,
    StartRoundMustEndRound,
    ReceivedZeroFromBaseQuoteExchange,
    ReceivedZeroFromQuoteBaseExchange,
    LockingMoreQuoteThanIsFree,
    LockingMoreBaseThanCanBeExchanged,
    FreeingMoreBaseThanLocked,
    SendPremiumNotEnoughCollateral,
    OnlyPoolHedger,
    OnlyOptionMarket,
    OnlyShortCollateral,
    ReentrancyDetected,
    Last
  }

  function lockedCollateral() external view returns (uint, uint);

  function queuedQuoteFunds() external view returns (uint);

  function expiryToTokenValue(uint) external view returns (uint);

  function deposit(address beneficiary, uint amount) external returns (uint);

  function signalWithdrawal(uint certificateId) external;

  function unSignalWithdrawal(uint certificateId) external;

  function withdraw(address beneficiary, uint certificateId) external returns (uint value);

  function tokenPriceQuote() external view returns (uint);

  function endRound() external;

  function startRound(uint lastMaxExpiryTimestamp, uint newMaxExpiryTimestamp) external;

  function exchangeBase() external;

  function lockQuote(uint amount, uint freeCollatLiq) external;

  function lockBase(
    uint amount,
    ILyraGlobals.ExchangeGlobals memory exchangeGlobals,
    Liquidity memory liquidity
  ) external;

  function freeQuoteCollateral(uint amount) external;

  function freeBase(uint amountBase) external;

  function sendPremium(
    address recipient,
    uint amount,
    uint freeCollatLiq
  ) external;

  function boardLiquidation(
    uint amountQuoteFreed,
    uint amountQuoteReserved,
    uint amountBaseFreed
  ) external;

  function sendReservedQuote(address user, uint amount) external;

  function getTotalPoolValueQuote(uint basePrice, uint usedDeltaLiquidity) external view returns (uint);

  function getLiquidity(uint basePrice, ICollateralShort short) external view returns (Liquidity memory);

  function transferQuoteToHedge(ILyraGlobals.ExchangeGlobals memory exchangeGlobals, uint amount)
    external
    returns (uint);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/*
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with GSN meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ICollateralShort.sol";
import "./IExchangeRates.sol";
import "./IExchanger.sol";
import "./ISynthetix.sol";

interface ILyraGlobals {
  enum ExchangeType {BASE_QUOTE, QUOTE_BASE, ALL}

  /**
   * @dev Structs to help reduce the number of calls between other contracts and this one
   * Grouped in usage for a particular contract/use case
   */
  struct ExchangeGlobals {
    uint spotPrice;
    bytes32 quoteKey;
    bytes32 baseKey;
    ISynthetix synthetix;
    ICollateralShort short;
    uint quoteBaseFeeRate;
    uint baseQuoteFeeRate;
  }

  struct GreekCacheGlobals {
    int rateAndCarry;
    uint spotPrice;
  }

  struct PricingGlobals {
    uint optionPriceFeeCoefficient;
    uint spotPriceFeeCoefficient;
    uint vegaFeeCoefficient;
    uint vegaNormFactor;
    uint standardSize;
    uint skewAdjustmentFactor;
    int rateAndCarry;
    int minDelta;
    uint volatilityCutoff;
    uint spotPrice;
  }

  function synthetix() external view returns (ISynthetix);

  function exchanger() external view returns (IExchanger);

  function exchangeRates() external view returns (IExchangeRates);

  function collateralShort() external view returns (ICollateralShort);

  function isPaused() external view returns (bool);

  function tradingCutoff(address) external view returns (uint);

  function optionPriceFeeCoefficient(address) external view returns (uint);

  function spotPriceFeeCoefficient(address) external view returns (uint);

  function vegaFeeCoefficient(address) external view returns (uint);

  function vegaNormFactor(address) external view returns (uint);

  function standardSize(address) external view returns (uint);

  function skewAdjustmentFactor(address) external view returns (uint);

  function rateAndCarry(address) external view returns (int);

  function minDelta(address) external view returns (int);

  function volatilityCutoff(address) external view returns (uint);

  function quoteKey(address) external view returns (bytes32);

  function baseKey(address) external view returns (bytes32);

  function setGlobals(
    ISynthetix _synthetix,
    IExchanger _exchanger,
    IExchangeRates _exchangeRates,
    ICollateralShort _collateralShort
  ) external;

  function setGlobalsForContract(
    address _contractAddress,
    uint _tradingCutoff,
    PricingGlobals memory pricingGlobals,
    bytes32 _quoteKey,
    bytes32 _baseKey
  ) external;

  function setPaused(bool _isPaused) external;

  function setTradingCutoff(address _contractAddress, uint _tradingCutoff) external;

  function setOptionPriceFeeCoefficient(address _contractAddress, uint _optionPriceFeeCoefficient) external;

  function setSpotPriceFeeCoefficient(address _contractAddress, uint _spotPriceFeeCoefficient) external;

  function setVegaFeeCoefficient(address _contractAddress, uint _vegaFeeCoefficient) external;

  function setVegaNormFactor(address _contractAddress, uint _vegaNormFactor) external;

  function setStandardSize(address _contractAddress, uint _standardSize) external;

  function setSkewAdjustmentFactor(address _contractAddress, uint _skewAdjustmentFactor) external;

  function setRateAndCarry(address _contractAddress, int _rateAndCarry) external;

  function setMinDelta(address _contractAddress, int _minDelta) external;

  function setVolatilityCutoff(address _contractAddress, uint _volatilityCutoff) external;

  function setQuoteKey(address _contractAddress, bytes32 _quoteKey) external;

  function setBaseKey(address _contractAddress, bytes32 _baseKey) external;

  function getSpotPriceForMarket(address _contractAddress) external view returns (uint);

  function getSpotPrice(bytes32 to) external view returns (uint);

  function getPricingGlobals(address _contractAddress) external view returns (PricingGlobals memory);

  function getGreekCacheGlobals(address _contractAddress) external view returns (GreekCacheGlobals memory);

  function getExchangeGlobals(address _contractAddress, ExchangeType exchangeType)
    external
    view
    returns (ExchangeGlobals memory exchangeGlobals);

  function getGlobalsForOptionTrade(address _contractAddress, bool isBuy)
    external
    view
    returns (
      PricingGlobals memory pricingGlobals,
      ExchangeGlobals memory exchangeGlobals,
      uint tradeCutoff
    );
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./ILiquidityPool.sol";

interface IOptionMarket {
  struct OptionListing {
    uint id;
    uint strike;
    uint skew;
    uint longCall;
    uint shortCall;
    uint longPut;
    uint shortPut;
    uint boardId;
  }

  struct OptionBoard {
    uint id;
    uint expiry;
    uint iv;
    bool frozen;
    uint[] listingIds;
  }

  struct Trade {
    bool isBuy;
    uint amount;
    uint vol;
    uint expiry;
    ILiquidityPool.Liquidity liquidity;
  }

  enum TradeType {LONG_CALL, SHORT_CALL, LONG_PUT, SHORT_PUT}

  enum Error {
    TransferOwnerToZero,
    InvalidBoardId,
    InvalidBoardIdOrNotFrozen,
    InvalidListingIdOrNotFrozen,
    StrikeSkewLengthMismatch,
    BoardMaxExpiryReached,
    CannotStartNewRoundWhenBoardsExist,
    ZeroAmountOrInvalidTradeType,
    BoardFrozenOrTradingCutoffReached,
    QuoteTransferFailed,
    BaseTransferFailed,
    BoardNotExpired,
    BoardAlreadyLiquidated,
    OnlyOwner,
    Last
  }

  function maxExpiryTimestamp() external view returns (uint);

  function optionBoards(uint)
    external
    view
    returns (
      uint id,
      uint expiry,
      uint iv,
      bool frozen
    );

  function optionListings(uint)
    external
    view
    returns (
      uint id,
      uint strike,
      uint skew,
      uint longCall,
      uint shortCall,
      uint longPut,
      uint shortPut,
      uint boardId
    );

  function boardToPriceAtExpiry(uint) external view returns (uint);

  function listingToBaseReturnedRatio(uint) external view returns (uint);

  function transferOwnership(address newOwner) external;

  function setBoardFrozen(uint boardId, bool frozen) external;

  function setBoardBaseIv(uint boardId, uint baseIv) external;

  function setListingSkew(uint listingId, uint skew) external;

  function createOptionBoard(
    uint expiry,
    uint baseIV,
    uint[] memory strikes,
    uint[] memory skews
  ) external returns (uint);

  function addListingToBoard(
    uint boardId,
    uint strike,
    uint skew
  ) external;

  function getLiveBoards() external view returns (uint[] memory _liveBoards);

  function getBoardListings(uint boardId) external view returns (uint[] memory);

  function openPosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external returns (uint totalCost);

  function closePosition(
    uint _listingId,
    TradeType tradeType,
    uint amount
  ) external returns (uint totalCost);

  function liquidateExpiredBoard(uint boardId) external;

  function settleOptions(uint listingId, TradeType tradeType) external;
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface ILiquidityCertificate {
  struct CertificateData {
    uint liquidity;
    uint enteredAt;
    uint burnableAt;
  }

  function MIN_LIQUIDITY() external view returns (uint);

  function liquidityPool() external view returns (address);

  function certificates(address owner) external view returns (uint[] memory);

  function liquidity(uint certificateId) external view returns (uint);

  function enteredAt(uint certificateId) external view returns (uint);

  function burnableAt(uint certificateId) external view returns (uint);

  function certificateData(uint certificateId) external view returns (CertificateData memory);

  function mint(
    address owner,
    uint liquidityAmount,
    uint expiryAtCreation
  ) external returns (uint);

  function setBurnableAt(
    address spender,
    uint certificateId,
    uint timestamp
  ) external;

  function burn(address spender, uint certificateId) external;

  function split(uint certificateId, uint percentageSplit) external returns (uint);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ICollateralShort.sol";

interface IPoolHedger {
  function shortingInitialized() external view returns (bool);

  function shortId() external view returns (uint);

  function shortBuffer() external view returns (uint);

  function lastInteraction() external view returns (uint);

  function interactionDelay() external view returns (uint);

  function setShortBuffer(uint newShortBuffer) external;

  function setInteractionDelay(uint newInteractionDelay) external;

  function initShort() external;

  function reopenShort() external;

  function hedgeDelta() external;

  function getShortPosition(ICollateralShort short) external view returns (uint shortBalance, uint collateral);

  function getCurrentHedgedNetDelta() external view returns (int);

  function getValueQuote(ICollateralShort short, uint spotPrice) external view returns (uint value);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./IOptionMarket.sol";

interface IShortCollateral {
  function sendQuoteCollateral(address recipient, uint amount) external;

  function sendBaseCollateral(address recipient, uint amount) external;

  function sendToLP(uint amountBase, uint amountQuote) external;

  function processSettle(
    uint listingId,
    address receiver,
    IOptionMarket.TradeType tradeType,
    uint amount,
    uint strike,
    uint priceAtExpiry,
    uint listingToShortCallEthReturned
  ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/introspection/ERC165.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./Address.sol";

/**
 *
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
  using SafeMath for uint;
  using Address for address;

  // Mapping from token ID to account balances
  mapping(uint => mapping(address => uint)) private _balances;

  // Mapping from account to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
  string private _uri;

  /*
   *     bytes4(keccak256('balanceOf(address,uint256)')) == 0x00fdd58e
   *     bytes4(keccak256('balanceOfBatch(address[],uint256[])')) == 0x4e1273f4
   *     bytes4(keccak256('setApprovalForAll(address,bool)')) == 0xa22cb465
   *     bytes4(keccak256('isApprovedForAll(address,address)')) == 0xe985e9c5
   *     bytes4(keccak256('safeTransferFrom(address,address,uint256,uint256,bytes)')) == 0xf242432a
   *     bytes4(keccak256('safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)')) == 0x2eb2c2d6
   *
   *     => 0x00fdd58e ^ 0x4e1273f4 ^ 0xa22cb465 ^
   *        0xe985e9c5 ^ 0xf242432a ^ 0x2eb2c2d6 == 0xd9b67a26
   */
  bytes4 private constant _INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /*
   *     bytes4(keccak256('uri(uint256)')) == 0x0e89341c
   */
  bytes4 private constant _INTERFACE_ID_ERC1155_METADATA_URI = 0x0e89341c;

  /**
   * @dev See {_setURI}.
   */
  constructor(string memory uri_) {
    _setURI(uri_);

    // register the supported interfaces to conform to ERC1155 via ERC165
    _registerInterface(_INTERFACE_ID_ERC1155);

    // register the supported interfaces to conform to ERC1155MetadataURI via ERC165
    _registerInterface(_INTERFACE_ID_ERC1155_METADATA_URI);
  }

  /**
   * @dev See {IERC1155MetadataURI-uri}.
   *
   * This implementation returns the same URI for *all* token types. It relies
   * on the token type ID substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * Clients calling this function must replace the `\{id\}` substring with the
   * actual token type ID.
   */
  function uri(uint) external view virtual override returns (string memory) {
    return _uri;
  }

  /**
   * @dev See {IERC1155-balanceOf}.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function balanceOf(address account, uint id) public view virtual override returns (uint) {
    require(account != address(0), "ERC1155: balance query for the zero address");
    return _balances[id][account];
  }

  /**
   * @dev See {IERC1155-balanceOfBatch}.
   *
   * Requirements:
   *
   * - `accounts` and `ids` must have the same length.
   */
  function balanceOfBatch(address[] memory accounts, uint[] memory ids)
    public
    view
    virtual
    override
    returns (uint[] memory)
  {
    require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

    uint[] memory batchBalances = new uint[](accounts.length);

    for (uint i = 0; i < accounts.length; ++i) {
      batchBalances[i] = balanceOf(accounts[i], ids[i]);
    }

    return batchBalances;
  }

  /**
   * @dev See {IERC1155-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    require(_msgSender() != operator, "ERC1155: setting approval status for self");

    _operatorApprovals[_msgSender()][operator] = approved;
    emit ApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC1155-isApprovedForAll}.
   */
  function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
    return _operatorApprovals[account][operator];
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint id,
    uint amount,
    bytes memory data
  ) public virtual override {
    require(to != address(0), "ERC1155: transfer to the zero address");
    require(from == _msgSender() || isApprovedForAll(from, _msgSender()), "ERC1155: caller is not owner nor approved");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, to, _asSingletonArray(id), _asSingletonArray(amount), data);

    _balances[id][from] = _balances[id][from].sub(amount, "ERC1155: insufficient balance for transfer");
    _balances[id][to] = _balances[id][to].add(amount);

    emit TransferSingle(operator, from, to, id, amount);
  }

  /**
   * @dev See {IERC1155-safeBatchTransferFrom}.
   */
  function safeBatchTransferFrom(
    address from,
    address to,
    uint[] memory ids,
    uint[] memory amounts,
    bytes memory data
  ) public virtual override {
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
    require(to != address(0), "ERC1155: transfer to the zero address");
    require(
      from == _msgSender() || isApprovedForAll(from, _msgSender()),
      "ERC1155: transfer caller is not owner nor approved"
    );

    address operator = _msgSender();

    _beforeTokenTransfer(operator, from, to, ids, amounts, data);

    for (uint i = 0; i < ids.length; ++i) {
      uint id = ids[i];
      uint amount = amounts[i];

      _balances[id][from] = _balances[id][from].sub(amount, "ERC1155: insufficient balance for transfer");
      _balances[id][to] = _balances[id][to].add(amount);
    }

    emit TransferBatch(operator, from, to, ids, amounts);
  }

  /**
   * @dev Sets a new URI for all token types, by relying on the token type ID
   * substitution mechanism
   * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
   *
   * By this mechanism, any occurrence of the `\{id\}` substring in either the
   * URI or any of the amounts in the JSON file at said URI will be replaced by
   * clients with the token type ID.
   *
   * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
   * interpreted by clients as
   * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
   * for token type ID 0x4cce0.
   *
   * See {uri}.
   *
   * Because these URIs cannot be meaningfully represented by the {URI} event,
   * this function emits no events.
   */
  function _setURI(string memory newuri) internal virtual {
    _uri = newuri;
  }

  /**
   * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
   *
   * Emits a {TransferSingle} event.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
   * acceptance magic value.
   */
  function _mint(
    address account,
    uint id,
    uint amount,
    bytes memory data
  ) internal virtual {
    require(account != address(0), "ERC1155: mint to the zero address");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, address(0), account, _asSingletonArray(id), _asSingletonArray(amount), data);

    _balances[id][account] = _balances[id][account].add(amount);
    emit TransferSingle(operator, address(0), account, id, amount);
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
   *
   * Requirements:
   *
   * - `ids` and `amounts` must have the same length.
   * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
   * acceptance magic value.
   */
  function _mintBatch(
    address to,
    uint[] memory ids,
    uint[] memory amounts,
    bytes memory data
  ) internal virtual {
    require(to != address(0), "ERC1155: mint to the zero address");
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

    for (uint i = 0; i < ids.length; i++) {
      _balances[ids[i]][to] = amounts[i].add(_balances[ids[i]][to]);
    }

    emit TransferBatch(operator, address(0), to, ids, amounts);
  }

  /**
   * @dev Destroys `amount` tokens of token type `id` from `account`
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens of token type `id`.
   */
  function _burn(
    address account,
    uint id,
    uint amount
  ) internal virtual {
    require(account != address(0), "ERC1155: burn from the zero address");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, account, address(0), _asSingletonArray(id), _asSingletonArray(amount), "");

    _balances[id][account] = _balances[id][account].sub(amount, "ERC1155: burn amount exceeds balance");

    emit TransferSingle(operator, account, address(0), id, amount);
  }

  /**
   * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
   *
   * Requirements:
   *
   * - `ids` and `amounts` must have the same length.
   */
  function _burnBatch(
    address account,
    uint[] memory ids,
    uint[] memory amounts
  ) internal virtual {
    require(account != address(0), "ERC1155: burn from the zero address");
    require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

    address operator = _msgSender();

    _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

    for (uint i = 0; i < ids.length; i++) {
      _balances[ids[i]][account] = _balances[ids[i]][account].sub(amounts[i], "ERC1155: burn amount exceeds balance");
    }

    emit TransferBatch(operator, account, address(0), ids, amounts);
  }

  /**
   * @dev Hook that is called before any token transfer. This includes minting
   * and burning, as well as batched variants.
   *
   * The same hook is called on both single and batched variants. For single
   * transfers, the length of the `id` and `amount` arrays will be 1.
   *
   * Calling conditions (for each `id` and `amount` pair):
   *
   * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
   * of token type `id` will be  transferred to `to`.
   * - When `from` is zero, `amount` tokens of token type `id` will be minted
   * for `to`.
   * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
   * will be burned.
   * - `from` and `to` are never both zero.
   * - `ids` and `amounts` have the same, non-zero length.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint[] memory ids,
    uint[] memory amounts,
    bytes memory data
  ) internal virtual {}

  function _asSingletonArray(uint element) private pure returns (uint[] memory) {
    uint[] memory array = new uint[](1);
    array[0] = element;

    return array;
  }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "../../introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.2 <0.8.0;

import "./IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../../introspection/IERC165.sol";

/**
 * _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {

    /**
        @dev Handles the receipt of a single ERC1155 token type. This function is
        called at the end of a `safeTransferFrom` after the balance has been updated.
        To accept the transfer, this must return
        `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
        (i.e. 0xf23a6e61, or its own function selector).
        @param operator The address which initiated the transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param id The ID of the token being transferred
        @param value The amount of tokens being transferred
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
    */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    )
        external
        returns(bytes4);

    /**
        @dev Handles the receipt of a multiple ERC1155 token types. This function
        is called at the end of a `safeBatchTransferFrom` after the balances have
        been updated. To accept the transfer(s), this must return
        `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
        (i.e. 0xbc197c81, or its own function selector).
        @param operator The address which initiated the batch transfer (i.e. msg.sender)
        @param from The address which previously owned the token
        @param ids An array containing ids of each token being transferred (order and length must match values array)
        @param values An array containing amounts of each token being transferred (order and length must match ids array)
        @param data Additional data with no specified format
        @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
    */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    )
        external
        returns(bytes4);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165 is IERC165 {
    /*
     * bytes4(keccak256('supportsInterface(bytes4)')) == 0x01ffc9a7
     */
    bytes4 private constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;

    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    constructor () internal {
        // Derived contracts need only register support for their own interfaces,
        // we register support for ERC165 itself here
        _registerInterface(_INTERFACE_ID_ERC165);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     *
     * Time complexity O(1), guaranteed to always use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

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

    uint size;
    // solhint-disable-next-line no-inline-assembly
    assembly {
      size := extcodesize(account)
    }
    return size > 0;
  }

  /**
   * @dev Performs a Solidity function call using a low level `call`. A
   * plain`call` is an unsafe replacement for a function call: use this
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
    return functionCallWithoutValue(target, data, errorMessage);
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
  function functionCallWithoutValue(address target, bytes memory data) internal returns (bytes memory) {
    return functionCallWithoutValue(target, data, "Address: low-level call with value failed");
  }

  /**
   * @dev Same as {xref-Address-functionCallWithoutValue-address-bytes-uint256-}[`functionCallWithoutValue`], but
   * with `errorMessage` as a fallback revert reason when `target` reverts.
   *
   * _Available since v3.1._
   */
  function functionCallWithoutValue(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    require(isContract(target), "Address: call to non-contract");

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.call(data);
    return _verifyCallResult(success, returndata, errorMessage);
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

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.staticcall(data);
    return _verifyCallResult(success, returndata, errorMessage);
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

    // solhint-disable-next-line avoid-low-level-calls
    (bool success, bytes memory returndata) = target.delegatecall(data);
    return _verifyCallResult(success, returndata, errorMessage);
  }

  function _verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) private pure returns (bytes memory) {
    if (success) {
      return returndata;
    } else {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
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

pragma solidity >=0.6.0 <0.8.0;

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
//MIT License
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

pragma solidity ^0.7.6;

// Libraries
import "@openzeppelin/contracts/math/SignedSafeMath.sol";

// https://docs.synthetix.io/contracts/source/libraries/safedecimalmath
library SignedSafeDecimalMath {
  using SignedSafeMath for int;

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
    return x.mul(y) / UNIT;
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
    int quotientTimesTen = x.mul(y) / (precisionUnit / 10);

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
    return x.mul(UNIT).div(y);
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
    int resultTimesTen = x.mul(precisionUnit * 10).div(y);

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
    return i.mul(UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR);
  }

  /**
   * @dev Convert a high precision decimal to a standard decimal representation.
   */
  function preciseDecimalToDecimal(int i) internal pure returns (int) {
    int quotientTimesTen = i / (UNIT_TO_HIGH_PRECISION_CONVERSION_FACTOR / 10);

    if (quotientTimesTen % 10 >= 5) {
      quotientTimesTen += 10;
    }

    return quotientTimesTen / 10;
  }
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

interface IBlackScholes {
  struct PricesDeltaStdVega {
    uint callPrice;
    uint putPrice;
    int callDelta;
    int putDelta;
    uint stdVega;
  }

  function abs(int x) external pure returns (uint);

  function exp(uint x) external pure returns (uint);

  function exp(int x) external pure returns (uint);

  function sqrt(uint x) external pure returns (uint y);

  function optionPrices(
    uint timeToExpirySec,
    uint volatilityDecimal,
    uint spotDecimal,
    uint strikeDecimal,
    int rateDecimal
  ) external pure returns (uint call, uint put);

  function pricesDeltaStdVega(
    uint timeToExpirySec,
    uint volatilityDecimal,
    uint spotDecimal,
    uint strikeDecimal,
    int rateDecimal
  ) external pure returns (PricesDeltaStdVega memory);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./IOptionMarket.sol";

interface IOptionMarketPricer {
  struct Pricing {
    uint optionPrice;
    int preTradeAmmNetStdVega;
    int postTradeAmmNetStdVega;
    int callDelta;
  }

  function ivImpactForTrade(
    IOptionMarket.OptionListing memory listing,
    IOptionMarket.Trade memory trade,
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint boardBaseIv
  ) external pure returns (uint, uint);

  function updateCacheAndGetTotalCost(
    IOptionMarket.OptionListing memory listing,
    IOptionMarket.Trade memory trade,
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint boardBaseIv
  )
    external
    returns (
      uint totalCost,
      uint newBaseIv,
      uint newSkew
    );

  function getPremium(
    IOptionMarket.Trade memory trade,
    Pricing memory pricing,
    ILyraGlobals.PricingGlobals memory pricingGlobals
  ) external pure returns (uint premium);

  function getVegaUtil(
    IOptionMarket.Trade memory trade,
    Pricing memory pricing,
    ILyraGlobals.PricingGlobals memory pricingGlobals
  ) external pure returns (uint vegaUtil);

  function getFee(
    ILyraGlobals.PricingGlobals memory pricingGlobals,
    uint amount,
    uint optionPrice,
    uint vegaUtil
  ) external pure returns (uint fee);
}

//SPDX-License-Identifier: ISC
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "./ILyraGlobals.sol";
import "./IOptionMarketPricer.sol";

interface IOptionGreekCache {
  struct OptionListingCache {
    uint id;
    uint strike;
    uint skew;
    uint boardId;
    int callDelta;
    int putDelta;
    uint stdVega;
    int callExposure; // long - short
    int putExposure; // long - short
    uint updatedAt;
    uint updatedAtPrice;
  }

  struct OptionBoardCache {
    uint id;
    uint expiry;
    uint iv;
    uint[] listings;
    uint minUpdatedAt; // This should be the minimum value of all the listings
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    int netDelta;
    int netStdVega;
  }

  struct GlobalCache {
    int netDelta;
    int netStdVega;
    uint minUpdatedAt; // This should be the minimum value of all the listings
    uint minUpdatedAtPrice;
    uint maxUpdatedAtPrice;
    uint minExpiryTimestamp;
  }

  function MAX_LISTINGS_PER_BOARD() external view returns (uint);

  function staleUpdateDuration() external view returns (uint);

  function priceScalingPeriod() external view returns (uint);

  function maxAcceptablePercent() external view returns (uint);

  function minAcceptablePercent() external view returns (uint);

  function liveBoards(uint) external view returns (uint);

  function listingCaches(uint)
    external
    view
    returns (
      uint id,
      uint strike,
      uint skew,
      uint boardId,
      int callDelta,
      int putDelta,
      uint stdVega,
      int callExposure,
      int putExposure,
      uint updatedAt,
      uint updatedAtPrice
    );

  function boardCaches(uint)
    external
    view
    returns (
      uint id,
      uint expiry,
      uint iv,
      uint minUpdatedAt,
      uint minUpdatedAtPrice,
      uint maxUpdatedAtPrice,
      int netDelta,
      int netStdVega
    );

  function globalCache()
    external
    view
    returns (
      int netDelta,
      int netStdVega,
      uint minUpdatedAt,
      uint minUpdatedAtPrice,
      uint maxUpdatedAtPrice,
      uint minExpiryTimestamp
    );

  function setStaleCacheParameters(
    uint _staleUpdateDuration,
    uint _priceScalingPeriod,
    uint _maxAcceptablePercent,
    uint _minAcceptablePercent
  ) external;

  function addBoard(uint boardId) external;

  function removeBoard(uint boardId) external;

  function setBoardIv(uint boardId, uint newIv) external;

  function setListingSkew(uint listingId, uint newSkew) external;

  function addListingToBoard(uint boardId, uint listingId) external;

  function updateAllStaleBoards() external returns (int);

  function updateBoardCachedGreeks(uint boardCacheId) external;

  function updateListingCacheAndGetPrice(
    ILyraGlobals.GreekCacheGlobals memory greekCacheGlobals,
    uint listingCacheId,
    int newCallExposure,
    int newPutExposure,
    uint iv,
    uint skew
  ) external returns (IOptionMarketPricer.Pricing memory);

  function isGlobalCacheStale() external view returns (bool);

  function isBoardCacheStale(uint boardCacheId) external view returns (bool);

  function getGlobalNetDelta() external view returns (int);
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

/**
 * @title SignedSafeMath
 * @dev Signed math operations with safety checks that revert on error.
 */
library SignedSafeMath {
    int256 constant private _INT256_MIN = -2**255;

    /**
     * @dev Returns the multiplication of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(int256 a, int256 b) internal pure returns (int256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        require(!(a == -1 && b == _INT256_MIN), "SignedSafeMath: multiplication overflow");

        int256 c = a * b;
        require(c / a == b, "SignedSafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two signed integers. Reverts on
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
    function div(int256 a, int256 b) internal pure returns (int256) {
        require(b != 0, "SignedSafeMath: division by zero");
        require(!(b == -1 && a == _INT256_MIN), "SignedSafeMath: division overflow");

        int256 c = a / b;

        return c;
    }

    /**
     * @dev Returns the subtraction of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a - b;
        require((b >= 0 && c <= a) || (b < 0 && c > a), "SignedSafeMath: subtraction overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two signed integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(int256 a, int256 b) internal pure returns (int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a), "SignedSafeMath: addition overflow");

        return c;
    }
}