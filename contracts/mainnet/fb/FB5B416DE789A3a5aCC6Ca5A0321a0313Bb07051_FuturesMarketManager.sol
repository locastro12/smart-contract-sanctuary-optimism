/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-12-20
*/

/*
   ____            __   __        __   _
  / __/__ __ ___  / /_ / /  ___  / /_ (_)__ __
 _\ \ / // // _ \/ __// _ \/ -_)/ __// / \ \ /
/___/ \_, //_//_/\__//_//_/\__/ \__//_/ /_\_\
     /___/

* Synthetix: FuturesMarketManager.sol
*
* Latest source (may be newer): https://github.com/Synthetixio/synthetix/blob/master/contracts/FuturesMarketManager.sol
* Docs: https://docs.synthetix.io/contracts/FuturesMarketManager
*
* Contract Dependencies: 
*	- IAddressResolver
*	- IFuturesMarketManager
*	- MixinResolver
*	- Owned
* Libraries: 
*	- AddressSetLib
*	- SafeMath
*
* MIT License
* ===========
*
* Copyright (c) 2022 Synthetix
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/



pragma solidity ^0.5.16;

// https://docs.synthetix.io/contracts/source/contracts/owned
contract Owned {
    address public owner;
    address public nominatedOwner;

    constructor(address _owner) public {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

    function nominateNewOwner(address _owner) external onlyOwner {
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}


// https://docs.synthetix.io/contracts/source/interfaces/iaddressresolver
interface IAddressResolver {
    function getAddress(bytes32 name) external view returns (address);

    function getSynth(bytes32 key) external view returns (address);

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}


// https://docs.synthetix.io/contracts/source/interfaces/isynth
interface ISynth {
    // Views
    function currencyKey() external view returns (bytes32);

    function transferableSynths(address account) external view returns (uint);

    // Mutative functions
    function transferAndSettle(address to, uint value) external returns (bool);

    function transferFromAndSettle(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Restricted: used internally to Synthetix
    function burn(address account, uint amount) external;

    function issue(address account, uint amount) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/iissuer
interface IIssuer {
    // Views

    function allNetworksDebtInfo()
        external
        view
        returns (
            uint256 debt,
            uint256 sharesSupply,
            bool isStale
        );

    function anySynthOrSNXRateIsInvalid() external view returns (bool anyRateInvalid);

    function availableCurrencyKeys() external view returns (bytes32[] memory);

    function availableSynthCount() external view returns (uint);

    function availableSynths(uint index) external view returns (ISynth);

    function canBurnSynths(address account) external view returns (bool);

    function collateral(address account) external view returns (uint);

    function collateralisationRatio(address issuer) external view returns (uint);

    function collateralisationRatioAndAnyRatesInvalid(address _issuer)
        external
        view
        returns (uint cratio, bool anyRateIsInvalid);

    function debtBalanceOf(address issuer, bytes32 currencyKey) external view returns (uint debtBalance);

    function issuanceRatio() external view returns (uint);

    function lastIssueEvent(address account) external view returns (uint);

    function maxIssuableSynths(address issuer) external view returns (uint maxIssuable);

    function minimumStakeTime() external view returns (uint);

    function remainingIssuableSynths(address issuer)
        external
        view
        returns (
            uint maxIssuable,
            uint alreadyIssued,
            uint totalSystemDebt
        );

    function synths(bytes32 currencyKey) external view returns (ISynth);

    function getSynths(bytes32[] calldata currencyKeys) external view returns (ISynth[] memory);

    function synthsByAddress(address synthAddress) external view returns (bytes32);

    function totalIssuedSynths(bytes32 currencyKey, bool excludeOtherCollateral) external view returns (uint);

    function transferableSynthetixAndAnyRateIsInvalid(address account, uint balance)
        external
        view
        returns (uint transferable, bool anyRateIsInvalid);

    function liquidationAmounts(address account, bool isSelfLiquidation)
        external
        view
        returns (
            uint totalRedeemed,
            uint debtToRemove,
            uint escrowToLiquidate,
            uint initialDebtBalance
        );

    // Restricted: used internally to Synthetix
    function addSynths(ISynth[] calldata synthsToAdd) external;

    function issueSynths(address from, uint amount) external;

    function issueSynthsOnBehalf(
        address issueFor,
        address from,
        uint amount
    ) external;

    function issueMaxSynths(address from) external;

    function issueMaxSynthsOnBehalf(address issueFor, address from) external;

    function burnSynths(address from, uint amount) external;

    function burnSynthsOnBehalf(
        address burnForAddress,
        address from,
        uint amount
    ) external;

    function burnSynthsToTarget(address from) external;

    function burnSynthsToTargetOnBehalf(address burnForAddress, address from) external;

    function burnForRedemption(
        address deprecatedSynthProxy,
        address account,
        uint balance
    ) external;

    function setCurrentPeriodId(uint128 periodId) external;

    function liquidateAccount(address account, bool isSelfLiquidation)
        external
        returns (
            uint totalRedeemed,
            uint debtRemoved,
            uint escrowToLiquidate
        );

    function issueSynthsWithoutDebt(
        bytes32 currencyKey,
        address to,
        uint amount
    ) external returns (bool rateInvalid);

    function burnSynthsWithoutDebt(
        bytes32 currencyKey,
        address to,
        uint amount
    ) external returns (bool rateInvalid);
}


// Inheritance


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/addressresolver
contract AddressResolver is Owned, IAddressResolver {
    mapping(bytes32 => address) public repository;

    constructor(address _owner) public Owned(_owner) {}

    /* ========== RESTRICTED FUNCTIONS ========== */

    function importAddresses(bytes32[] calldata names, address[] calldata destinations) external onlyOwner {
        require(names.length == destinations.length, "Input lengths must match");

        for (uint i = 0; i < names.length; i++) {
            bytes32 name = names[i];
            address destination = destinations[i];
            repository[name] = destination;
            emit AddressImported(name, destination);
        }
    }

    /* ========= PUBLIC FUNCTIONS ========== */

    function rebuildCaches(MixinResolver[] calldata destinations) external {
        for (uint i = 0; i < destinations.length; i++) {
            destinations[i].rebuildCache();
        }
    }

    /* ========== VIEWS ========== */

    function areAddressesImported(bytes32[] calldata names, address[] calldata destinations) external view returns (bool) {
        for (uint i = 0; i < names.length; i++) {
            if (repository[names[i]] != destinations[i]) {
                return false;
            }
        }
        return true;
    }

    function getAddress(bytes32 name) external view returns (address) {
        return repository[name];
    }

    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address) {
        address _foundAddress = repository[name];
        require(_foundAddress != address(0), reason);
        return _foundAddress;
    }

    function getSynth(bytes32 key) external view returns (address) {
        IIssuer issuer = IIssuer(repository["Issuer"]);
        require(address(issuer) != address(0), "Cannot find Issuer address");
        return address(issuer.synths(key));
    }

    /* ========== EVENTS ========== */

    event AddressImported(bytes32 name, address destination);
}


// Internal references


// https://docs.synthetix.io/contracts/source/contracts/mixinresolver
contract MixinResolver {
    AddressResolver public resolver;

    mapping(bytes32 => address) private addressCache;

    constructor(address _resolver) internal {
        resolver = AddressResolver(_resolver);
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function combineArrays(bytes32[] memory first, bytes32[] memory second)
        internal
        pure
        returns (bytes32[] memory combination)
    {
        combination = new bytes32[](first.length + second.length);

        for (uint i = 0; i < first.length; i++) {
            combination[i] = first[i];
        }

        for (uint j = 0; j < second.length; j++) {
            combination[first.length + j] = second[j];
        }
    }

    /* ========== PUBLIC FUNCTIONS ========== */

    // Note: this function is public not external in order for it to be overridden and invoked via super in subclasses
    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {}

    function rebuildCache() public {
        bytes32[] memory requiredAddresses = resolverAddressesRequired();
        // The resolver must call this function whenver it updates its state
        for (uint i = 0; i < requiredAddresses.length; i++) {
            bytes32 name = requiredAddresses[i];
            // Note: can only be invoked once the resolver has all the targets needed added
            address destination =
                resolver.requireAndGetAddress(name, string(abi.encodePacked("Resolver missing target: ", name)));
            addressCache[name] = destination;
            emit CacheUpdated(name, destination);
        }
    }

    /* ========== VIEWS ========== */

    function isResolverCached() external view returns (bool) {
        bytes32[] memory requiredAddresses = resolverAddressesRequired();
        for (uint i = 0; i < requiredAddresses.length; i++) {
            bytes32 name = requiredAddresses[i];
            // false if our cache is invalid or if the resolver doesn't have the required address
            if (resolver.getAddress(name) != addressCache[name] || addressCache[name] == address(0)) {
                return false;
            }
        }

        return true;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function requireAndGetAddress(bytes32 name) internal view returns (address) {
        address _foundAddress = addressCache[name];
        require(_foundAddress != address(0), string(abi.encodePacked("Missing address: ", name)));
        return _foundAddress;
    }

    /* ========== EVENTS ========== */

    event CacheUpdated(bytes32 name, address destination);
}


interface IFuturesMarketManager {
    function markets(uint index, uint pageSize) external view returns (address[] memory);

    function markets(
        uint index,
        uint pageSize,
        bool proxiedMarkets
    ) external view returns (address[] memory);

    function numMarkets() external view returns (uint);

    function numMarkets(bool proxiedMarkets) external view returns (uint);

    function allMarkets() external view returns (address[] memory);

    function allMarkets(bool proxiedMarkets) external view returns (address[] memory);

    function marketForKey(bytes32 marketKey) external view returns (address);

    function marketsForKeys(bytes32[] calldata marketKeys) external view returns (address[] memory);

    function totalDebt() external view returns (uint debt, bool isInvalid);
}


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
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
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
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0, "SafeMath: modulo by zero");
        return a % b;
    }
}


// https://docs.synthetix.io/contracts/source/libraries/addresssetlib/
library AddressSetLib {
    struct AddressSet {
        address[] elements;
        mapping(address => uint) indices;
    }

    function contains(AddressSet storage set, address candidate) internal view returns (bool) {
        if (set.elements.length == 0) {
            return false;
        }
        uint index = set.indices[candidate];
        return index != 0 || set.elements[0] == candidate;
    }

    function getPage(
        AddressSet storage set,
        uint index,
        uint pageSize
    ) internal view returns (address[] memory) {
        // NOTE: This implementation should be converted to slice operators if the compiler is updated to v0.6.0+
        uint endIndex = index + pageSize; // The check below that endIndex <= index handles overflow.

        // If the page extends past the end of the list, truncate it.
        if (endIndex > set.elements.length) {
            endIndex = set.elements.length;
        }
        if (endIndex <= index) {
            return new address[](0);
        }

        uint n = endIndex - index; // We already checked for negative overflow.
        address[] memory page = new address[](n);
        for (uint i; i < n; i++) {
            page[i] = set.elements[i + index];
        }
        return page;
    }

    function add(AddressSet storage set, address element) internal {
        // Adding to a set is an idempotent operation.
        if (!contains(set, element)) {
            set.indices[element] = set.elements.length;
            set.elements.push(element);
        }
    }

    function remove(AddressSet storage set, address element) internal {
        require(contains(set, element), "Element not in set.");
        // Replace the removed element with the last element of the list.
        uint index = set.indices[element];
        uint lastIndex = set.elements.length - 1; // We required that element is in the list, so it is not empty.
        if (index != lastIndex) {
            // No need to shift the last element if it is the one we want to delete.
            address shiftedElement = set.elements[lastIndex];
            set.elements[index] = shiftedElement;
            set.indices[shiftedElement] = index;
        }
        set.elements.pop();
        delete set.indices[element];
    }
}


// https://docs.synthetix.io/contracts/source/interfaces/ifeepool
interface IFeePool {
    // Views

    // solhint-disable-next-line func-name-mixedcase
    function FEE_ADDRESS() external view returns (address);

    function feesAvailable(address account) external view returns (uint, uint);

    function feePeriodDuration() external view returns (uint);

    function isFeesClaimable(address account) external view returns (bool);

    function targetThreshold() external view returns (uint);

    function totalFeesAvailable() external view returns (uint);

    function totalRewardsAvailable() external view returns (uint);

    // Mutative Functions
    function claimFees() external returns (bool);

    function claimOnBehalf(address claimingForAddress) external returns (bool);

    function closeCurrentFeePeriod() external;

    function closeSecondary(uint snxBackedDebt, uint debtShareSupply) external;

    function recordFeePaid(uint sUSDAmount) external;

    function setRewardsToDistribute(uint amount) external;
}


interface IVirtualSynth {
    // Views
    function balanceOfUnderlying(address account) external view returns (uint);

    function rate() external view returns (uint);

    function readyToSettle() external view returns (bool);

    function secsLeftInWaitingPeriod() external view returns (uint);

    function settled() external view returns (bool);

    function synth() external view returns (ISynth);

    // Mutative functions
    function settle(address account) external;
}


pragma experimental ABIEncoderV2;


// https://docs.synthetix.io/contracts/source/interfaces/iexchanger
interface IExchanger {
    struct ExchangeEntrySettlement {
        bytes32 src;
        uint amount;
        bytes32 dest;
        uint reclaim;
        uint rebate;
        uint srcRoundIdAtPeriodEnd;
        uint destRoundIdAtPeriodEnd;
        uint timestamp;
    }

    struct ExchangeEntry {
        uint sourceRate;
        uint destinationRate;
        uint destinationAmount;
        uint exchangeFeeRate;
        uint exchangeDynamicFeeRate;
        uint roundIdForSrc;
        uint roundIdForDest;
        uint sourceAmountAfterSettlement;
    }

    // Views
    function calculateAmountAfterSettlement(
        address from,
        bytes32 currencyKey,
        uint amount,
        uint refunded
    ) external view returns (uint amountAfterSettlement);

    function isSynthRateInvalid(bytes32 currencyKey) external view returns (bool);

    function maxSecsLeftInWaitingPeriod(address account, bytes32 currencyKey) external view returns (uint);

    function settlementOwing(address account, bytes32 currencyKey)
        external
        view
        returns (
            uint reclaimAmount,
            uint rebateAmount,
            uint numEntries
        );

    function hasWaitingPeriodOrSettlementOwing(address account, bytes32 currencyKey) external view returns (bool);

    function feeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey) external view returns (uint);

    function dynamicFeeRateForExchange(bytes32 sourceCurrencyKey, bytes32 destinationCurrencyKey)
        external
        view
        returns (uint feeRate, bool tooVolatile);

    function getAmountsForExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
        external
        view
        returns (
            uint amountReceived,
            uint fee,
            uint exchangeFeeRate
        );

    function priceDeviationThresholdFactor() external view returns (uint);

    function waitingPeriodSecs() external view returns (uint);

    function lastExchangeRate(bytes32 currencyKey) external view returns (uint);

    // Mutative functions
    function exchange(
        address exchangeForAddress,
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bool virtualSynth,
        address rewardAddress,
        bytes32 trackingCode
    ) external returns (uint amountReceived, IVirtualSynth vSynth);

    function exchangeAtomically(
        address from,
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        address destinationAddress,
        bytes32 trackingCode,
        uint minAmount
    ) external returns (uint amountReceived);

    function settle(address from, bytes32 currencyKey)
        external
        returns (
            uint reclaimed,
            uint refunded,
            uint numEntries
        );
}

// Used to have strongly-typed access to internal mutative functions in Synthetix
interface ISynthetixInternal {
    function emitExchangeTracking(
        bytes32 trackingCode,
        bytes32 toCurrencyKey,
        uint256 toAmount,
        uint256 fee
    ) external;

    function emitSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint fromAmount,
        bytes32 toCurrencyKey,
        uint toAmount,
        address toAddress
    ) external;

    function emitAtomicSynthExchange(
        address account,
        bytes32 fromCurrencyKey,
        uint fromAmount,
        bytes32 toCurrencyKey,
        uint toAmount,
        address toAddress
    ) external;

    function emitExchangeReclaim(
        address account,
        bytes32 currencyKey,
        uint amount
    ) external;

    function emitExchangeRebate(
        address account,
        bytes32 currencyKey,
        uint amount
    ) external;
}

interface IExchangerInternalDebtCache {
    function updateCachedSynthDebtsWithRates(bytes32[] calldata currencyKeys, uint[] calldata currencyRates) external;

    function updateCachedSynthDebts(bytes32[] calldata currencyKeys) external;
}


// https://docs.synthetix.io/contracts/source/interfaces/ierc20
interface IERC20 {
    // ERC20 Optional Views
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    // Views
    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(address owner, address spender) external view returns (uint);

    // Mutative functions
    function transfer(address to, uint value) external returns (bool);

    function approve(address spender, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    // Events
    event Transfer(address indexed from, address indexed to, uint value);

    event Approval(address indexed owner, address indexed spender, uint value);
}


// Inheritance


// Libraries


// Internal references


// basic views that are expected to be supported by v1 (IFuturesMarket) and v2 (via ProxyPerpsV2)
interface IMarketViews {
    function marketKey() external view returns (bytes32);

    function baseAsset() external view returns (bytes32);

    function marketSize() external view returns (uint128);

    function marketSkew() external view returns (int128);

    function assetPrice() external view returns (uint price, bool invalid);

    function marketDebt() external view returns (uint debt, bool isInvalid);

    function currentFundingRate() external view returns (int fundingRate);

    // v1 does not have a this so we never call it but this is here for v2.
    function currentFundingVelocity() external view returns (int fundingVelocity);

    // only supported by PerpsV2 Markets (and implemented in ProxyPerpsV2)
    function getAllTargets() external view returns (address[] memory);
}

// https://docs.synthetix.io/contracts/source/contracts/FuturesMarketManager
contract FuturesMarketManager is Owned, MixinResolver, IFuturesMarketManager {
    using SafeMath for uint;
    using AddressSetLib for AddressSetLib.AddressSet;

    /* ========== STATE VARIABLES ========== */

    AddressSetLib.AddressSet internal _allMarkets;
    AddressSetLib.AddressSet internal _legacyMarkets;
    AddressSetLib.AddressSet internal _proxiedMarkets;
    mapping(bytes32 => address) public marketForKey;

    // PerpsV2 implementations
    AddressSetLib.AddressSet internal _implementations;
    mapping(address => address[]) internal _marketImplementation;

    /* ========== ADDRESS RESOLVER CONFIGURATION ========== */

    bytes32 public constant CONTRACT_NAME = "FuturesMarketManager";

    bytes32 internal constant SUSD = "sUSD";
    bytes32 internal constant CONTRACT_SYNTHSUSD = "SynthsUSD";
    bytes32 internal constant CONTRACT_FEEPOOL = "FeePool";
    bytes32 internal constant CONTRACT_EXCHANGER = "Exchanger";

    /* ========== CONSTRUCTOR ========== */

    constructor(address _owner, address _resolver) public Owned(_owner) MixinResolver(_resolver) {}

    /* ========== VIEWS ========== */

    function resolverAddressesRequired() public view returns (bytes32[] memory addresses) {
        addresses = new bytes32[](3);
        addresses[0] = CONTRACT_SYNTHSUSD;
        addresses[1] = CONTRACT_FEEPOOL;
        addresses[2] = CONTRACT_EXCHANGER;
    }

    function _sUSD() internal view returns (ISynth) {
        return ISynth(requireAndGetAddress(CONTRACT_SYNTHSUSD));
    }

    function _feePool() internal view returns (IFeePool) {
        return IFeePool(requireAndGetAddress(CONTRACT_FEEPOOL));
    }

    function _exchanger() internal view returns (IExchanger) {
        return IExchanger(requireAndGetAddress(CONTRACT_EXCHANGER));
    }

    /*
     * Returns slices of the list of all markets.
     */
    function markets(uint index, uint pageSize) external view returns (address[] memory) {
        return _allMarkets.getPage(index, pageSize);
    }

    /*
     * Returns slices of the list of all v1 or v2 (proxied) markets.
     */
    function markets(
        uint index,
        uint pageSize,
        bool proxiedMarkets
    ) external view returns (address[] memory) {
        if (proxiedMarkets) {
            return _proxiedMarkets.getPage(index, pageSize);
        } else {
            return _legacyMarkets.getPage(index, pageSize);
        }
    }

    /*
     * The number of proxied + legacy markets known to the manager.
     */
    function numMarkets() external view returns (uint) {
        return _allMarkets.elements.length;
    }

    /*
     * The number of proxied or legacy markets known to the manager.
     */
    function numMarkets(bool proxiedMarkets) external view returns (uint) {
        if (proxiedMarkets) {
            return _proxiedMarkets.elements.length;
        } else {
            return _legacyMarkets.elements.length;
        }
    }

    /*
     * The list of all proxied AND legacy markets.
     */
    function allMarkets() public view returns (address[] memory) {
        return _allMarkets.getPage(0, _allMarkets.elements.length);
    }

    /*
     * The list of all proxied OR legacy markets.
     */
    function allMarkets(bool proxiedMarkets) public view returns (address[] memory) {
        if (proxiedMarkets) {
            return _proxiedMarkets.getPage(0, _proxiedMarkets.elements.length);
        } else {
            return _legacyMarkets.getPage(0, _legacyMarkets.elements.length);
        }
    }

    function _marketsForKeys(bytes32[] memory marketKeys) internal view returns (address[] memory) {
        uint mMarkets = marketKeys.length;
        address[] memory results = new address[](mMarkets);
        for (uint i; i < mMarkets; i++) {
            results[i] = marketForKey[marketKeys[i]];
        }
        return results;
    }

    /*
     * The market addresses for a given set of market key strings.
     */
    function marketsForKeys(bytes32[] calldata marketKeys) external view returns (address[] memory) {
        return _marketsForKeys(marketKeys);
    }

    /*
     * The accumulated debt contribution of all futures markets.
     */
    function totalDebt() external view returns (uint debt, bool isInvalid) {
        uint total;
        bool anyIsInvalid;
        uint numOfMarkets = _allMarkets.elements.length;
        for (uint i = 0; i < numOfMarkets; i++) {
            (uint marketDebt, bool invalid) = IMarketViews(_allMarkets.elements[i]).marketDebt();
            total = total.add(marketDebt);
            anyIsInvalid = anyIsInvalid || invalid;
        }
        return (total, anyIsInvalid);
    }

    struct MarketSummary {
        address market;
        bytes32 asset;
        bytes32 marketKey;
        uint price;
        uint marketSize;
        int marketSkew;
        uint marketDebt;
        int currentFundingRate;
        int currentFundingVelocity;
        bool priceInvalid;
        bool proxied;
    }

    function _marketSummaries(address[] memory addresses) internal view returns (MarketSummary[] memory) {
        uint nMarkets = addresses.length;
        MarketSummary[] memory summaries = new MarketSummary[](nMarkets);
        for (uint i; i < nMarkets; i++) {
            IMarketViews market = IMarketViews(addresses[i]);
            bytes32 marketKey = market.marketKey();
            bytes32 baseAsset = market.baseAsset();

            (uint price, bool invalid) = market.assetPrice();
            (uint debt, ) = market.marketDebt();

            bool proxied = _proxiedMarkets.contains(addresses[i]);
            summaries[i] = MarketSummary({
                market: address(market),
                asset: baseAsset,
                marketKey: marketKey,
                price: price,
                marketSize: market.marketSize(),
                marketSkew: market.marketSkew(),
                marketDebt: debt,
                currentFundingRate: market.currentFundingRate(),
                currentFundingVelocity: proxied ? market.currentFundingVelocity() : 0, // v1 does not have velocity.
                priceInvalid: invalid,
                proxied: proxied
            });
        }

        return summaries;
    }

    function marketSummaries(address[] calldata addresses) external view returns (MarketSummary[] memory) {
        return _marketSummaries(addresses);
    }

    function marketSummariesForKeys(bytes32[] calldata marketKeys) external view returns (MarketSummary[] memory) {
        return _marketSummaries(_marketsForKeys(marketKeys));
    }

    function allMarketSummaries() external view returns (MarketSummary[] memory) {
        return _marketSummaries(allMarkets());
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function _addImplementations(address market) internal {
        address[] memory implementations = IMarketViews(market).getAllTargets();
        for (uint i = 0; i < implementations.length; i++) {
            _implementations.add(implementations[i]);
        }
        _marketImplementation[market] = implementations;
    }

    function _removeImplementations(address market) internal {
        address[] memory implementations = _marketImplementation[market];
        for (uint i = 0; i < implementations.length; i++) {
            if (_implementations.contains(implementations[i])) {
                _implementations.remove(implementations[i]);
            }
        }
        delete _marketImplementation[market];
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function addMarkets(address[] calldata marketsToAdd) external onlyOwner {
        uint numOfMarkets = marketsToAdd.length;
        for (uint i; i < numOfMarkets; i++) {
            _addMarket(marketsToAdd[i], false);
        }
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function addProxiedMarkets(address[] calldata marketsToAdd) external onlyOwner {
        uint numOfMarkets = marketsToAdd.length;
        for (uint i; i < numOfMarkets; i++) {
            _addMarket(marketsToAdd[i], true);
        }
    }

    /*
     * Add a set of new markets. Reverts if some market key already has a market.
     */
    function _addMarket(address market, bool isProxied) internal onlyOwner {
        require(!_allMarkets.contains(market), "Market already exists");

        bytes32 key = IMarketViews(market).marketKey();
        bytes32 baseAsset = IMarketViews(market).baseAsset();

        require(marketForKey[key] == address(0), "Market already exists for key");
        marketForKey[key] = market;
        _allMarkets.add(market);

        if (isProxied) {
            _proxiedMarkets.add(market);
            // if PerpsV2 market => add implementations
            _addImplementations(market);
        } else {
            _legacyMarkets.add(market);
        }

        // Emit the event
        emit MarketAdded(market, baseAsset, key);
    }

    function _removeMarkets(address[] memory marketsToRemove) internal {
        uint numOfMarkets = marketsToRemove.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToRemove[i];
            require(market != address(0), "Unknown market");

            bytes32 key = IMarketViews(market).marketKey();
            bytes32 baseAsset = IMarketViews(market).baseAsset();

            require(marketForKey[key] != address(0), "Unknown market");

            // if PerpsV2 market => remove implementations
            if (_proxiedMarkets.contains(market)) {
                _removeImplementations(market);
                _proxiedMarkets.remove(market);
            } else {
                _legacyMarkets.remove(market);
            }

            delete marketForKey[key];
            _allMarkets.remove(market);
            emit MarketRemoved(market, baseAsset, key);
        }
    }

    /*
     * Remove a set of markets. Reverts if any market is not known to the manager.
     */
    function removeMarkets(address[] calldata marketsToRemove) external onlyOwner {
        return _removeMarkets(marketsToRemove);
    }

    /*
     * Remove the markets for a given set of market keys. Reverts if any key has no associated market.
     */
    function removeMarketsByKey(bytes32[] calldata marketKeysToRemove) external onlyOwner {
        _removeMarkets(_marketsForKeys(marketKeysToRemove));
    }

    function updateMarketsImplementations(address[] calldata marketsToUpdate) external onlyOwner {
        uint numOfMarkets = marketsToUpdate.length;
        for (uint i; i < numOfMarkets; i++) {
            address market = marketsToUpdate[i];
            require(market != address(0), "Invalid market");
            require(_allMarkets.contains(market), "Unknown market");

            // Remove old implementations
            _removeImplementations(market);

            // Pull new implementations
            _addImplementations(market);
        }
    }

    /*
     * Allows a market to issue sUSD to an account when it withdraws margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function issueSUSD(address account, uint amount) external onlyMarketImplementations {
        // No settlement is required to issue synths into the target account.
        _sUSD().issue(account, amount);
    }

    /*
     * Allows a market to burn sUSD from an account when it deposits margin.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function burnSUSD(address account, uint amount) external onlyMarketImplementations returns (uint postReclamationAmount) {
        // We'll settle first, in order to ensure the user has sufficient balance.
        // If the settlement reduces the user's balance below the requested amount,
        // the settled remainder will be the resulting deposit.

        // Exchanger.settle ensures synth is active
        ISynth sUSD = _sUSD();
        (uint reclaimed, , ) = _exchanger().settle(account, SUSD);

        uint balanceAfter = amount;
        if (0 < reclaimed) {
            balanceAfter = IERC20(address(sUSD)).balanceOf(account);
        }

        // Reduce the value to burn if balance is insufficient after reclamation
        amount = balanceAfter < amount ? balanceAfter : amount;

        sUSD.burn(account, amount);

        return amount;
    }

    /**
     * Allows markets to issue exchange fees into the fee pool and notify it that this occurred.
     * This function is not callable through the proxy, only underlying contracts interact;
     * it reverts if not called by a known market.
     */
    function payFee(uint amount, bytes32 trackingCode) external onlyMarketImplementations {
        _payFee(amount, trackingCode);
    }

    // backwards compatibility with futures v1
    function payFee(uint amount) external onlyMarketImplementations {
        _payFee(amount, bytes32(0));
    }

    function _payFee(uint amount, bytes32 trackingCode) internal {
        delete trackingCode; // unused for now, will be used SIP 203
        IFeePool pool = _feePool();
        _sUSD().issue(pool.FEE_ADDRESS(), amount);
        pool.recordFeePaid(amount);
    }

    /* ========== MODIFIERS ========== */

    function _requireIsMarketOrImplementation() internal view {
        require(
            _legacyMarkets.contains(msg.sender) || _implementations.contains(msg.sender),
            "Permitted only for market implementations"
        );
    }

    modifier onlyMarketImplementations() {
        _requireIsMarketOrImplementation();
        _;
    }

    /* ========== EVENTS ========== */

    event MarketAdded(address market, bytes32 indexed asset, bytes32 indexed marketKey);

    event MarketRemoved(address market, bytes32 indexed asset, bytes32 indexed marketKey);
}