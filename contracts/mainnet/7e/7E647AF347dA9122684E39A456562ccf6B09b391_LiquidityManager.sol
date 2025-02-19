// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "../interfaces/ILiquidityPool.sol";
import "../libraries/LibUtils.sol";

import "./Types.sol";
import "./Storage.sol";
import "./AssetManager.sol";
import "./Admin.sol";
import "./ExtensionProxy.sol";

/**
 * @title LiquidityManager provides funds management and bridging services.
 */
contract LiquidityManager is Storage, AssetManager, DexWrapper, Admin, ExtensionProxy {
    receive() external payable {}

    /**
     * @notice Initialize the LiquidityManager.
     */
    function initialize(address vault_, address pool_) external initializer {
        __SafeOwnable_init();
        _vault = vault_;
        _pool = pool_;
        // 0 for placeHolder
        _dexSpotConfigs.push();
    }

    /**
     * @notice Return the address of LiquidityPool.
     */
    function getPool() public view returns (address) {
        return _pool;
    }

    /**
     * @notice Return the address of vault to which the profits of dex farming is transferred.
     */
    function getVault() public view returns (address) {
        return _vault;
    }

    function getMaintainer() public view returns (address) {
        return _maintainer;
    }

    /**
     * @notice Return true if an external contract is allowed to access authed methods.
     */
    function isHandler(address handler) public view returns (bool) {
        return _handlers[handler];
    }

    /**
     * @notice Return all the configs of current dexes.
     */
    function getAllDexSpotConfiguration() external returns (DexSpotConfiguration[] memory configs) {
        uint256 n = _dexSpotConfigs.length - 1;
        if (n == 0) {
            return configs;
        }
        configs = new DexSpotConfiguration[](n);
        for (uint8 dexId = 1; dexId <= n; dexId++) {
            configs[dexId - 1] = _getDexSpotConfiguration(dexId);
        }
        return configs;
    }

    /**
     * @notice Return the config of a given dex.
     */
    function getDexSpotConfiguration(uint8 dexId) external returns (DexSpotConfiguration memory config) {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        config = _getDexSpotConfiguration(dexId);
    }

    /**
     * @notice Return the lp balance and calculated spot amounts of a given dex.
     */
    function getDexLiquidity(uint8 dexId) external returns (uint256[] memory liquidities, uint256 lpBalance) {
        lpBalance = getDexLpBalance(dexId);
        liquidities = getDexSpotAmounts(dexId, lpBalance);
    }

    /**
     * @notice Return adapter config of a given dex.
     */
    function getDexAdapterConfig(uint8 dexId) external view returns (bytes memory config) {
        config = _dexData[dexId].config;
    }

    /**
     * @notice Query the adapter state of a given dex by key. A state key can be obtain by `keccak(KEY_NAME)`
     */
    function getDexAdapterState(uint8 dexId, bytes32 key) external view returns (bytes32 state) {
        state = _dexData[dexId].states[key];
    }

    /**
     * @notice Return the address of adapter of a given dex.
     */
    function getDexAdapter(uint8 dexId) external view returns (DexRegistration memory registration) {
        registration = _dexAdapters[dexId];
    }

    function _getDexSpotConfiguration(uint8 dexId) internal returns (DexSpotConfiguration memory config) {
        config = _dexSpotConfigs[dexId];
        if (config.dexType == DEX_CURVE) {
            uint256[] memory amounts = getDexTotalSpotAmounts(dexId);
            config.totalSpotInDex = amounts;
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "../core/Types.sol";

interface ILiquidityPool {
    /////////////////////////////////////////////////////////////////////////////////
    //                                 getters

    function getAssetInfo(uint8 assetId) external view returns (Asset memory);

    function getAllAssetInfo() external view returns (Asset[] memory);

    function getAssetAddress(uint8 assetId) external view returns (address);

    function getLiquidityPoolStorage()
        external
        view
        returns (
            // [0] shortFundingBaseRate8H
            // [1] shortFundingLimitRate8H
            // [2] lastFundingTime
            // [3] fundingInterval
            // [4] liquidityBaseFeeRate
            // [5] liquidityDynamicFeeRate
            // [6] sequence. note: will be 0 after 0xffffffff
            // [7] strictStableDeviation
            uint32[8] memory u32s,
            // [0] mlpPriceLowerBound
            // [1] mlpPriceUpperBound
            uint96[2] memory u96s
        );

    function getSubAccount(bytes32 subAccountId)
        external
        view
        returns (
            uint96 collateral,
            uint96 size,
            uint32 lastIncreasedTime,
            uint96 entryPrice,
            uint128 entryFunding
        );

    /////////////////////////////////////////////////////////////////////////////////
    //                             for Trader / Broker

    function withdrawAllCollateral(bytes32 subAccountId) external;

    /////////////////////////////////////////////////////////////////////////////////
    //                                 only Broker

    function depositCollateral(
        bytes32 subAccountId,
        uint256 rawAmount // NOTE: OrderBook SHOULD transfer rawAmount collateral to LiquidityPool
    ) external;

    function withdrawCollateral(
        bytes32 subAccountId,
        uint256 rawAmount,
        uint96 collateralPrice,
        uint96 assetPrice
    ) external;

    function withdrawProfit(
        bytes32 subAccountId,
        uint256 rawAmount,
        uint8 profitAssetId, // only used when !isLong
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external;

    /**
     * @dev   Add liquidity.
     *
     * @param trader            liquidity provider address.
     * @param tokenId           asset.id that added.
     * @param rawAmount         asset token amount. decimals = erc20.decimals.
     * @param tokenPrice        token price. decimals = 18.
     * @param mlpPrice          mlp price.  decimals = 18.
     * @param currentAssetValue liquidity USD value of a single asset in all chains (even if tokenId is a stable asset).
     * @param targetAssetValue  weight / Σ weight * total liquidity USD value in all chains.
     */
    function addLiquidity(
        address trader,
        uint8 tokenId,
        uint256 rawAmount, // NOTE: OrderBook SHOULD transfer rawAmount collateral to LiquidityPool
        uint96 tokenPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external;

    /**
     * @dev   Remove liquidity.
     *
     * @param trader            liquidity provider address.
     * @param mlpAmount         mlp amount. decimals = 18.
     * @param tokenId           asset.id that removed to.
     * @param tokenPrice        token price. decimals = 18.
     * @param mlpPrice          mlp price. decimals = 18.
     * @param currentAssetValue liquidity USD value of a single asset in all chains (even if tokenId is a stable asset). decimals = 18.
     * @param targetAssetValue  weight / Σ weight * total liquidity USD value in all chains. decimals = 18.
     */
    function removeLiquidity(
        address trader,
        uint96 mlpAmount, // NOTE: OrderBook SHOULD transfer mlpAmount mlp to LiquidityPool
        uint8 tokenId,
        uint96 tokenPrice,
        uint96 mlpPrice,
        uint96 currentAssetValue,
        uint96 targetAssetValue
    ) external;

    /**
     * @notice Open a position.
     *
     * @param  subAccountId     check LibSubAccount.decodeSubAccountId for detail.
     * @param  amount           position size. decimals = 18.
     * @param  collateralPrice  price of subAccount.collateral.
     * @param  assetPrice       price of subAccount.asset.
     */
    function openPosition(
        bytes32 subAccountId,
        uint96 amount,
        uint96 collateralPrice,
        uint96 assetPrice
    ) external returns (uint96);

    /**
     * @notice Close a position.
     *
     * @param  subAccountId     check LibSubAccount.decodeSubAccountId for detail.
     * @param  amount           position size. decimals = 18.
     * @param  profitAssetId    for long position (unless asset.useStable is true), ignore this argument;
     *                          for short position, the profit asset should be one of the stable coin.
     * @param  collateralPrice  price of subAccount.collateral. decimals = 18.
     * @param  assetPrice       price of subAccount.asset. decimals = 18.
     * @param  profitAssetPrice price of profitAssetId. ignore this argument if profitAssetId is ignored. decimals = 18.
     */
    function closePosition(
        bytes32 subAccountId,
        uint96 amount,
        uint8 profitAssetId, // only used when !isLong
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external returns (uint96);

    /**
     * @notice Broker can update funding each [fundingInterval] seconds by specifying utilizations.
     *
     *         Check _getFundingRate in Liquidity.sol on how to calculate funding rate.
     * @param  stableUtilization    Stable coin utilization in all chains. decimals = 5.
     * @param  unstableTokenIds     All unstable Asset id(s) MUST be passed in order. ex: 1, 2, 5, 6, ...
     * @param  unstableUtilizations Unstable Asset utilizations in all chains. decimals = 5.
     * @param  unstablePrices       Unstable Asset prices.
     */
    function updateFundingState(
        uint32 stableUtilization, // 1e5
        uint8[] calldata unstableTokenIds,
        uint32[] calldata unstableUtilizations, // 1e5
        uint96[] calldata unstablePrices
    ) external;

    function liquidate(
        bytes32 subAccountId,
        uint8 profitAssetId, // only used when !isLong
        uint96 collateralPrice,
        uint96 assetPrice,
        uint96 profitAssetPrice // only used when !isLong
    ) external returns (uint96);

    /**
     * @notice Redeem mux token into original tokens.
     *
     *         Only strict stable coins and un-stable coins are supported.
     */
    function redeemMuxToken(
        address trader,
        uint8 tokenId,
        uint96 muxTokenAmount // NOTE: OrderBook SHOULD transfer muxTokenAmount to LiquidityPool
    ) external;

    /**
     * @dev  Rebalance pool liquidity. Swap token 0 for token 1.
     *
     *       rebalancer must implement IMuxRebalancerCallback.
     */
    function rebalance(
        address rebalancer,
        uint8 tokenId0,
        uint8 tokenId1,
        uint96 rawAmount0,
        uint96 maxRawAmount1,
        bytes32 userData,
        uint96 price0,
        uint96 price1
    ) external;

    /**
     * @dev Broker can withdraw brokerGasRebate.
     */
    function claimBrokerGasRebate(address receiver) external returns (uint256 rawAmount);

    /////////////////////////////////////////////////////////////////////////////////
    //                            only LiquidityManager

    function transferLiquidityOut(uint8[] memory assetIds, uint256[] memory amounts) external;

    function transferLiquidityIn(uint8[] memory assetIds, uint256[] memory amounts) external;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

interface IDecimals {
    function decimals() external view returns (uint8);
}

library LibUtils {
    bytes4 constant SELECTOR_DECIMALS = 0x313ce567;

    function toBytes32(string memory source) internal pure returns (bytes32 result) {
        uint256 size = bytes(source).length;
        require(size > 0 && size <= 32, "RNG"); // out of range
        assembly {
            result := mload(add(source, 32))
        }
    }

    function norm(address[] memory tokens_, uint256[] memory amounts_)
        internal
        view
        returns (uint256[] memory normAmounts_)
    {
        require(tokens_.length == amounts_.length, "L!L");
        uint256 n = tokens_.length;
        normAmounts_ = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            uint256 decimals;
            try IDecimals(tokens_[i]).decimals() returns (uint8 decimals_) {
                decimals = decimals_;
            } catch {
                decimals = 18;
            }
            normAmounts_[i] = amounts_[i] / (10**decimals);
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

uint256 constant DEX_UNISWAP = 0;
uint256 constant DEX_CURVE = 1;

struct DexSpotConfiguration {
    uint8 dexId;
    uint8 dexType;
    uint32 dexWeight;
    uint8[] assetIds;
    uint32[] assetWeightInDex;
    uint256[] totalSpotInDex;
}

struct DexRegistration {
    address adapter;
    bool disabled;
    uint32 slippage;
}

struct DexData {
    bytes config;
    mapping(bytes32 => bytes32) states;
}

struct PluginData {
    mapping(bytes32 => bytes32) states;
}

struct CallContext {
    uint8 dexId;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./Types.sol";
import "../components/SafeOwnableUpgradeable.sol";

contract PlaceHolder {
    bytes32[200] private __deprecated;
}

contract Storage is PlaceHolder, Initializable, SafeOwnableUpgradeable {
    // base properties
    address internal _vault;
    address internal _pool;

    DexSpotConfiguration[] internal _dexSpotConfigs;
    // address => isAllowed
    mapping(address => bool) internal _handlers;
    CallContext internal _dexContext;
    // dexId => Context
    mapping(uint8 => DexData) internal _dexData;
    // assetId => address
    mapping(uint8 => address) internal _tokenCache;
    // dexId => dexRegistration
    mapping(uint8 => DexRegistration) internal _dexAdapters;
    // sig => callee
    mapping(bytes4 => address) internal _plugins;
    mapping(string => PluginData) internal _pluginData;

    address internal _maintainer;
    // reserves
    bytes32[49] private __gaps;
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interfaces/ILiquidityPool.sol";
import "./Types.sol";
import "./Storage.sol";

contract AssetManager is Storage {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event FetchAssets(uint8[] assetIds, uint256[] amounts);
    event PushAssets(uint8[] assetIds, uint256[] amounts);
    event WithdrawToken(address token, address recipient, uint256 amount);

    modifier auth() {
        require(_handlers[msg.sender], "NHL"); // not handler
        _;
    }

    modifier onlyMaintainer() {
        require(msg.sender == _maintainer || msg.sender == owner(), "SND"); // invalid sender
        _;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            AddressUpgradeable.sendValue(payable(msg.sender), amount);
        } else {
            IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
        }
        emit WithdrawToken(token, msg.sender, amount);
    }

    function _fetchAssets(uint8[] memory assetIds, uint256[] memory amounts) internal {
        require(assetIds.length == amounts.length, "LEN"); // LENgth of 2 arguments does not match
        ILiquidityPool(_pool).transferLiquidityOut(assetIds, amounts);
        emit FetchAssets(assetIds, amounts);
    }

    function _pushAssets(uint8[] memory assetIds, uint256[] memory amounts) internal {
        if (_transferTo(_pool, assetIds, amounts)) {
            ILiquidityPool(_pool).transferLiquidityIn(assetIds, amounts);
            emit PushAssets(assetIds, amounts);
        }
    }

    function _getDexTokens(uint8 dexId) internal view returns (address[] memory tokens) {
        uint8[] memory assetIds = _dexSpotConfigs[dexId].assetIds;
        tokens = new address[](assetIds.length);
        for (uint256 i = 0; i < assetIds.length; i++) {
            tokens[i] = _getTokenAddress(assetIds[i]);
        }
    }

    function _repayAssets(
        uint8 dexId,
        uint256[] memory maxAmounts,
        uint256[] memory usedAmounts
    ) internal returns (uint256[] memory remainAmounts) {
        require(maxAmounts.length == usedAmounts.length, "LEN"); // LENgth of 2 arguments does not match
        uint256 n = maxAmounts.length;
        remainAmounts = new uint256[](n);
        bool hasRemain = false;
        for (uint256 i = 0; i < n; i++) {
            if (maxAmounts[i] > usedAmounts[i]) {
                remainAmounts[i] = maxAmounts[i] - usedAmounts[i];
                hasRemain = true;
            }
        }
        _pushAssets(_dexSpotConfigs[dexId].assetIds, remainAmounts);
    }

    function _getTokenAddress(uint8 assetId) internal view returns (address token) {
        token = _tokenCache[assetId];
        require(token != address(0), "NAD");
    }

    function _tryGetTokenAddress(uint8 assetId) internal returns (address token) {
        token = _tokenCache[assetId];
        if (token == address(0)) {
            token = ILiquidityPool(_pool).getAssetAddress(assetId);
            _tokenCache[assetId] = token;
        }
    }

    function _transferTo(
        address recipient,
        uint8[] memory assetIds,
        uint256[] memory amounts
    ) internal returns (bool transferred) {
        require(assetIds.length == amounts.length, "LEN"); // LENgth of 2 arguments does not match
        for (uint256 i = 0; i < assetIds.length; i++) {
            if (amounts[i] != 0) {
                IERC20Upgradeable(_tryGetTokenAddress(assetIds[i])).safeTransfer(recipient, amounts[i]);
                transferred = true;
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interfaces/IPlugin.sol";
import "./AssetManager.sol";
import "./DexWrapper.sol";

contract Admin is AssetManager, DexWrapper {
    using AddressUpgradeable for address;

    uint32 constant DEFAULT_SLIPPAGE = 1000; // 1%

    event SetHandler(address handler, bool enable);
    event AddDex(uint8 dexId, uint8 dexType, uint32 dexWeight, uint8[] assetIds, uint32[] assetWeightInDex);
    event SetDexWeight(uint8 dexId, uint32 dexWeight, uint32[] assetWeightInDex);
    event SetAssetIds(uint8 dexId, uint8[] assetIds);
    event SetDexAdapter(uint8 dexId, address entrypoint, bytes initialData);
    event SetDexWrapperEnable(uint8 dexId, bool enable);
    event SetDexSlippage(uint8 dexId, uint32 slippage);
    event SetPlugin(address plugin, bool enable, bytes4[] selectors);
    event SetVault(address previousVault, address newVault);
    event SetPool(address previousVault, address newPool);
    event SetMaintainer(address previousMaintainer, address newMaintainer);

    function setVault(address newVault) external onlyOwner {
        require(newVault != address(0), "ZAD"); // zero address
        require(newVault != _vault, "DUP"); // duplicated
        emit SetVault(_vault, newVault);
        _vault = newVault;
    }

    function setPool(address newPool) external onlyOwner {
        require(newPool != address(0), "ZAD"); // zero address
        require(newPool != _pool, "DUP"); // duplicated
        emit SetPool(_pool, newPool);
        _pool = newPool;
    }

    function setMaintainer(address newMaintainer) external onlyOwner {
        require(newMaintainer != _maintainer, "DUP"); // duplicated
        emit SetMaintainer(_maintainer, newMaintainer);
        _maintainer = newMaintainer;
    }

    function setHandler(address handler, bool enable) external onlyOwner {
        require(_handlers[handler] != enable, "DUP");
        _handlers[handler] = enable;
        emit SetHandler(handler, enable);
    }

    /**
     * @notice Add a configuration for dex.
     *         Each configuration [dex, assets0, asset1, ...] represents a combination of dex pool address and assets categories.
     * @param dexId The name of dex for user to distinguish between the configurations.
     * @param dexType The name of dex for user to distinguish between the configurations.
     * @param dexWeight The name of dex for user to distinguish between the configurations.
     * @param assetIds The array represents the category of assets to add to the dex.
     * @param assetWeightInDex The array represents the weight of each asset added to the dex as liquidity.
     *
     */
    function addDexSpotConfiguration(
        uint8 dexId,
        uint8 dexType,
        uint32 dexWeight,
        uint8[] calldata assetIds,
        uint32[] calldata assetWeightInDex
    ) external onlyOwner {
        require(_dexSpotConfigs.length <= 256, "FLL"); // the array is FuLL
        require(assetIds.length > 0, "MTY"); // argument array is eMpTY
        require(assetIds.length == assetWeightInDex.length, "LEN"); // LENgth of 2 arguments does not match
        require(dexId == _dexSpotConfigs.length, "IDI"); // invalid dex id

        _dexSpotConfigs.push(
            DexSpotConfiguration({
                dexId: dexId,
                dexType: dexType,
                dexWeight: dexWeight,
                assetIds: assetIds,
                assetWeightInDex: assetWeightInDex,
                totalSpotInDex: _makeEmpty(assetIds.length)
            })
        );
        for (uint256 i = 0; i < assetIds.length; i++) {
            _tryGetTokenAddress(assetIds[i]);
        }
        emit AddDex(dexId, dexType, dexWeight, assetIds, assetWeightInDex);
    }

    /**
     * @notice Modify the weight of a dex configuration.
     * @param dexId The id of the dex.
     * @param dexWeight The new weight of the dex.
     */
    function setDexWeight(
        uint8 dexId,
        uint32 dexWeight,
        uint32[] memory assetWeightInDex
    ) external onlyOwner {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        _dexSpotConfigs[dexId].dexWeight = dexWeight;
        _dexSpotConfigs[dexId].assetWeightInDex = assetWeightInDex;
        emit SetDexWeight(dexId, dexWeight, assetWeightInDex);
    }

    function refreshTokenCache(uint8[] memory assetIds) external {
        for (uint256 i = 0; i < assetIds.length; i++) {
            _tokenCache[assetIds[i]] = ILiquidityPool(_pool).getAssetAddress(assetIds[i]);
        }
    }

    /**
     * @notice Modify the weight of a dex configuration. Only can be modified when lp balance is zero or no module.
     * @param dexId The id of the dex.
     * @param assetIds The new ids of the dex.
     */
    function setAssetIds(uint8 dexId, uint8[] memory assetIds) external onlyOwner {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        require(getDexLpBalance(dexId) == 0, "FBD"); // forbidden
        _dexSpotConfigs[dexId].assetIds = assetIds;
        emit SetAssetIds(dexId, assetIds);
    }

    function setDexWrapper(
        uint8 dexId,
        address adapter,
        bytes memory initialData
    ) external onlyOwner {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        _dexAdapters[dexId].adapter = adapter;
        _dexAdapters[dexId].slippage = DEFAULT_SLIPPAGE;
        _initializeAdapter(dexId, initialData);
        emit SetDexAdapter(dexId, adapter, initialData);
    }

    function setDexSlippage(uint8 dexId, uint32 slippage) external onlyOwner {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        require(slippage <= BASE_RATE, "OOR"); // out of range
        _dexAdapters[dexId].slippage = slippage;
        emit SetDexSlippage(dexId, slippage);
    }

    function freezeDexWrapper(uint8 dexId, bool enable) external onlyOwner {
        require(dexId != 0 && dexId < _dexSpotConfigs.length, "LST"); // the asset is not LiSTed
        _dexAdapters[dexId].disabled = !enable;
        emit SetDexWrapperEnable(dexId, enable);
    }

    function setPlugin(address plugin, bool enable) external onlyOwner {
        require(plugin != address(0), "ZPA"); // zero plugin address
        bytes4[] memory selectors;
        try IPlugin(plugin).exports() returns (bytes4[] memory _selectors) {
            selectors = _selectors;
        } catch Error(string memory reason) {
            revert(reason);
        } catch {
            revert("SushiFarm::CallUnStakeFail");
        }
        if (enable) {
            for (uint256 i = 0; i < selectors.length; i++) {
                require(_plugins[selectors[i]] == address(0), "PAE"); // plugin already exists
                _plugins[selectors[i]] = plugin;
            }
        } else {
            for (uint256 i = 0; i < selectors.length; i++) {
                require(_plugins[selectors[i]] != address(0), "PNE"); // plugin not exists
                delete _plugins[selectors[i]];
            }
        }
        emit SetPlugin(plugin, enable, selectors);
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "./Storage.sol";

interface IExports {
    function exports() external pure returns (bytes4[] memory selectors);
}

// functionCall chain:
// upgradeableProxy(admin) => liquidityManager => module => plugin
contract ExtensionProxy is Storage {
    event PluginCall(address sender, address target, bytes4 sig, bytes payload);

    fallback() external {
        _delegate();
    }

    function _delegate() internal {
        address target = _plugins[msg.sig];
        require(target != address(0), "NPG"); // no plugin
        emit PluginCall(msg.sender, target, msg.sig, msg.data);
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())
            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), target, 0, calldatasize(), 0, 0)
            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())
            switch result
            // delegatecall returns 0 on error.
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

struct LiquidityPoolStorage {
    // slot
    address orderBook;
    // slot
    address mlp;
    // slot
    address _reserved6; // was liquidityManager
    // slot
    address weth;
    // slot
    uint128 _reserved1;
    uint32 shortFundingBaseRate8H; // 1e5
    uint32 shortFundingLimitRate8H; // 1e5
    uint32 fundingInterval; // 1e0
    uint32 lastFundingTime; // 1e0
    // slot
    uint32 _reserved2;
    // slot
    Asset[] assets;
    // slot
    mapping(bytes32 => SubAccount) accounts;
    // slot
    mapping(address => bytes32) _reserved3;
    // slot
    address _reserved4;
    uint96 _reserved5;
    // slot
    uint96 mlpPriceLowerBound; // safeguard against mlp price attacks
    uint96 mlpPriceUpperBound; // safeguard against mlp price attacks
    uint32 liquidityBaseFeeRate; // 1e5
    uint32 liquidityDynamicFeeRate; // 1e5
    // slot
    address nativeUnwrapper;
    // a sequence number that changes when LiquidityPoolStorage updated. this helps to keep track the state of LiquidityPool.
    uint32 sequence; // 1e0. note: will be 0 after 0xffffffff
    uint32 strictStableDeviation; // 1e5. strictStable price is 1.0 if in this damping range
    uint32 brokerTransactions; // transaction count for broker gas rebates
    // slot
    address vault;
    uint96 brokerGasRebate; // the number of native tokens for broker gas rebates per transaction
    // slot
    address maintainer;
    // slot
    mapping(address => bool) liquidityManager;
    bytes32[50] _gap;
}

struct Asset {
    // slot
    // assets with the same symbol in different chains are the same asset. they shares the same muxToken. so debts of the same symbol
    // can be accumulated across chains (see Reader.AssetState.deduct). ex: ERC20(fBNB).symbol should be "BNB", so that BNBs of
    // different chains are the same.
    // since muxToken of all stable coins is the same and is calculated separately (see Reader.ChainState.stableDeduct), stable coin
    // symbol can be different (ex: "USDT", "USDT.e" and "fUSDT").
    bytes32 symbol;
    // slot
    address tokenAddress; // erc20.address
    uint8 id;
    uint8 decimals; // erc20.decimals
    uint56 flags; // a bitset of ASSET_*
    uint24 _flagsPadding;
    // slot
    uint32 initialMarginRate; // 1e5
    uint32 maintenanceMarginRate; // 1e5
    uint32 minProfitRate; // 1e5
    uint32 minProfitTime; // 1e0
    uint32 positionFeeRate; // 1e5
    // note: 96 bits remaining
    // slot
    address referenceOracle;
    uint32 referenceDeviation; // 1e5
    uint8 referenceOracleType;
    uint32 halfSpread; // 1e5
    // note: 24 bits remaining
    // slot
    uint96 credit;
    uint128 _reserved2;
    // slot
    uint96 collectedFee;
    uint32 liquidationFeeRate; // 1e5
    uint96 spotLiquidity;
    // note: 32 bits remaining
    // slot
    uint96 maxLongPositionSize;
    uint96 totalLongPosition;
    // note: 64 bits remaining
    // slot
    uint96 averageLongPrice;
    uint96 maxShortPositionSize;
    // note: 64 bits remaining
    // slot
    uint96 totalShortPosition;
    uint96 averageShortPrice;
    // note: 64 bits remaining
    // slot, less used
    address muxTokenAddress; // muxToken.address. all stable coins share the same muxTokenAddress
    uint32 spotWeight; // 1e0
    uint32 longFundingBaseRate8H; // 1e5
    uint32 longFundingLimitRate8H; // 1e5
    // slot
    uint128 longCumulativeFundingRate; // Σ_t fundingRate_t
    uint128 shortCumulativeFunding; // Σ_t fundingRate_t * indexPrice_t
}

uint32 constant FUNDING_PERIOD = 3600 * 8;

uint56 constant ASSET_IS_STABLE = 0x00000000000001; // is a usdt, usdc, ...
uint56 constant ASSET_CAN_ADD_REMOVE_LIQUIDITY = 0x00000000000002; // can call addLiquidity and removeLiquidity with this token
uint56 constant ASSET_IS_TRADABLE = 0x00000000000100; // allowed to be assetId
uint56 constant ASSET_IS_OPENABLE = 0x00000000010000; // can open position
uint56 constant ASSET_IS_SHORTABLE = 0x00000001000000; // allow shorting this asset
uint56 constant ASSET_USE_STABLE_TOKEN_FOR_PROFIT = 0x00000100000000; // take profit will get stable coin
uint56 constant ASSET_IS_ENABLED = 0x00010000000000; // allowed to be assetId and collateralId
uint56 constant ASSET_IS_STRICT_STABLE = 0x01000000000000; // assetPrice is always 1 unless volatility exceeds strictStableDeviation

struct SubAccount {
    // slot
    uint96 collateral;
    uint96 size;
    uint32 lastIncreasedTime;
    // slot
    uint96 entryPrice;
    uint128 entryFunding; // entry longCumulativeFundingRate for long position. entry shortCumulativeFunding for short position
}

enum ReferenceOracleType {
    None,
    Chainlink
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract SafeOwnableUpgradeable is OwnableUpgradeable {
    address internal _pendingOwner;

    event PrepareToTransferOwnership(address indexed pendingOwner);

    function __SafeOwnable_init() internal onlyInitializing {
        __Ownable_init();
    }

    function transferOwnership(address newOwner) public virtual override onlyOwner {
        require(newOwner != address(0), "O=0"); // Owner Is Zero
        require(newOwner != owner(), "O=O"); // Owner is the same as the old Owner
        _pendingOwner = newOwner;
        emit PrepareToTransferOwnership(_pendingOwner);
    }

    function takeOwnership() public virtual {
        require(_msgSender() == _pendingOwner, "SND"); // SeNDer is not authorized
        _transferOwnership(_pendingOwner);
        _pendingOwner = address(0);
    }

    function renounceOwnership() public virtual override onlyOwner {
        _pendingOwner = address(0);
        _transferOwnership(address(0));
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
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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
     * This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
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
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20Upgradeable {
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20Upgradeable.sol";
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

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20Upgradeable token, bytes memory data) private {
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

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.10;

interface IPlugin {
    function name() external view returns (string memory);

    function exports() external view returns (bytes4[] memory);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "../interfaces/IDexAdapter.sol";
import "./AssetManager.sol";

contract DexWrapper is AssetManager {
    using AddressUpgradeable for address;

    uint256 constant BASE_RATE = 100000;

    event AddDexLiquidity(uint8 dexId, uint256[] maxAmounts, uint256[] addedAmounts, uint256 lpAmount, bytes extraData);
    event RemoveDexLiquidity(uint8 dexId, uint256 shareAmount, uint256[] minAmounts, uint256 deadline);
    event ClaimDexFees(uint8 dexId);

    /**
     * @notice Set dex id before dex method access.
     */
    modifier dexCall(uint8 dexId) {
        require(dexId != 0, "ZDI"); // zero dex id
        uint8 lastDexId = _dexContext.dexId;
        if (lastDexId == 0) {
            _dexContext.dexId = dexId;
        } else {
            require(lastDexId == dexId, "NDR"); // no dex-call reentrant
        }
        _;
        _dexContext.dexId = lastDexId;
    }

    // read methods
    function getDexLpBalance(uint8 dexId) public dexCall(dexId) returns (uint256 lpBalance) {
        DexRegistration storage registration = _dexAdapters[dexId];
        if (_dexAdapters[dexId].adapter != address(0)) {
            bytes memory returnData = _delegateCall(
                registration.adapter,
                abi.encodeWithSelector(IDexAdapter.getLpBalance.selector)
            );
            lpBalance = abi.decode(returnData, (uint256));
        } else {
            lpBalance = 0;
        }
    }

    function getDexFees(uint8 dexId)
        external
        dexCall(dexId)
        returns (
            address[] memory tokens,
            uint256[] memory claimedAmounts,
            uint256[] memory pendingAmounts
        )
    {
        DexRegistration storage registration = _dexAdapters[dexId];
        if (_dexAdapters[dexId].adapter != address(0)) {
            bytes memory returnData = _delegateCall(
                registration.adapter,
                abi.encodeWithSelector(IDexAdapter.getFees.selector)
            );
            (tokens, claimedAmounts, pendingAmounts) = abi.decode(returnData, (address[], uint256[], uint256[]));
        } else {
            uint256 n = _dexSpotConfigs[dexId].assetIds.length;
            tokens = new address[](n);
            claimedAmounts = _makeEmpty(n);
            pendingAmounts = _makeEmpty(n);
        }
    }

    function getDexSpotAmounts(uint8 dexId, uint256 shareAmount)
        public
        dexCall(dexId)
        returns (uint256[] memory amounts)
    {
        DexRegistration storage registration = _dexAdapters[dexId];
        if (_dexAdapters[dexId].adapter != address(0)) {
            bytes memory returnData = _delegateCall(
                registration.adapter,
                abi.encodeWithSelector(IDexAdapter.getSpotAmounts.selector, shareAmount)
            );
            amounts = abi.decode(returnData, (uint256[]));
        } else {
            uint256 n = _dexSpotConfigs[dexId].assetIds.length;
            amounts = _makeEmpty(n);
        }
    }

    function getDexTotalSpotAmounts(uint8 dexId) public dexCall(dexId) returns (uint256[] memory amounts) {
        DexRegistration storage registration = _dexAdapters[dexId];
        if (_dexAdapters[dexId].adapter != address(0)) {
            bytes memory returnData = _delegateCall(
                registration.adapter,
                abi.encodeWithSelector(IDexAdapter.getTotalSpotAmounts.selector)
            );
            amounts = abi.decode(returnData, (uint256[]));
        }
    }

    function getDexLiquidityData(uint8 dexId, uint256[] memory amounts)
        external
        dexCall(dexId)
        returns (bytes memory data)
    {
        DexRegistration storage registration = _dexAdapters[dexId];
        if (_dexAdapters[dexId].adapter != address(0)) {
            data = _delegateCall(registration.adapter, abi.encodeWithSignature("getLiquidityData(uint256[])", amounts));
        }
    }

    // write methods
    function addDexLiquidityUniSwapV2(
        uint8 dexId,
        uint256[] calldata amounts,
        uint256 deadline
    ) external dexCall(dexId) auth returns (uint256[] memory addedAmounts, uint256 liquidityAmount) {
        DexRegistration storage registration = _dexAdapters[dexId];
        require(!registration.disabled, "FRZ");
        require(registration.adapter != address(0), "ANS"); // adapter not set
        _fetchAssets(_dexSpotConfigs[dexId].assetIds, amounts);
        uint256[] memory minAmounts = new uint256[](amounts.length);
        uint256 rate = BASE_RATE - registration.slippage;
        minAmounts[0] = (amounts[0] * rate) / BASE_RATE;
        minAmounts[1] = (amounts[1] * rate) / BASE_RATE;
        bytes memory returnData = _delegateCall(
            registration.adapter,
            abi.encodeWithSelector(IDexAdapter.addLiquidityUniSwapV2.selector, amounts, minAmounts, deadline)
        );
        (addedAmounts, liquidityAmount) = abi.decode(returnData, (uint256[], uint256));
        _repayAssets(dexId, amounts, addedAmounts);

        emit AddDexLiquidity(dexId, amounts, addedAmounts, liquidityAmount, abi.encode(minAmounts, deadline));
    }

    // write methods
    function addDexLiquidityCurve(
        uint8 dexId,
        uint256[] calldata maxAmounts,
        uint256 desiredAmount
    ) external dexCall(dexId) auth returns (uint256[] memory addedAmounts, uint256 liquidityAmount) {
        DexRegistration storage registration = _dexAdapters[dexId];
        require(!registration.disabled, "FRZ");
        require(registration.adapter != address(0), "ANS"); // adapter not set
        _fetchAssets(_dexSpotConfigs[dexId].assetIds, maxAmounts);
        uint256 minLpAmount = (desiredAmount * (BASE_RATE - registration.slippage)) / BASE_RATE;
        bytes memory returnData = _delegateCall(
            registration.adapter,
            abi.encodeWithSelector(IDexAdapter.addLiquidityCurve.selector, maxAmounts, minLpAmount)
        );
        (addedAmounts, liquidityAmount) = abi.decode(returnData, (uint256[], uint256));

        emit AddDexLiquidity(dexId, maxAmounts, addedAmounts, liquidityAmount, abi.encode(desiredAmount, minLpAmount));
    }

    function removeDexLiquidity(
        uint8 dexId,
        uint256 shareAmount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external dexCall(dexId) auth returns (uint256[] memory removedAmounts) {
        DexRegistration storage registration = _dexAdapters[dexId];
        require(!registration.disabled, "FRZ");
        require(registration.adapter != address(0), "ANS"); // adapter not set

        bytes memory returnData = _delegateCall(
            registration.adapter,
            abi.encodeWithSelector(IDexAdapter.removeLiquidity.selector, shareAmount, minAmounts, deadline)
        );
        removedAmounts = abi.decode(returnData, (uint256[]));
        if (removedAmounts.length != 0) {
            _pushAssets(_dexSpotConfigs[dexId].assetIds, removedAmounts);
        }
        emit RemoveDexLiquidity(dexId, shareAmount, minAmounts, deadline);
    }

    function claimDexFees(uint8 dexId) external dexCall(dexId) {
        DexRegistration storage registration = _dexAdapters[dexId];
        require(registration.adapter != address(0), "ANS"); // adapter not set
        _delegateCall(registration.adapter, abi.encodeWithSelector(IDexAdapter.claimFees.selector, dexId));
    }

    function _initializeAdapter(uint8 dexId, bytes memory initialData) internal dexCall(dexId) {
        DexRegistration storage registration = _dexAdapters[dexId];
        require(registration.adapter != address(0), "ANS"); // adapter not set
        _delegateCall(
            registration.adapter,
            abi.encodeWithSelector(IDexAdapter.initializeAdapter.selector, initialData)
        );
        emit ClaimDexFees(dexId);
    }

    // helpers
    function _makeEmpty(uint256 length) internal pure returns (uint256[] memory empty) {
        empty = new uint256[](length);
    }

    function _delegateCall(address target, bytes memory callData) internal returns (bytes memory) {
        (bool success, bytes memory returnData) = target.delegatecall(callData);
        return AddressUpgradeable.verifyCallResult(success, returnData, "!DC");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

interface IDexAdapter {
    function initializeAdapter(bytes memory initialData) external;

    function getLpBalance() external view returns (uint256);

    function getFees()
        external
        returns (
            address[] memory rewardTokens,
            uint256[] memory collectedFeeAmounts,
            uint256[] memory pendingFeeAmounts
        );

    function getTotalSpotAmounts() external view returns (uint256[] memory amounts);

    function getSpotAmounts(uint256 shareAmount) external view returns (uint256[] memory amounts);

    function addLiquidityUniSwapV2(
        uint256[] calldata maxAmounts,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory addedAmounts, uint256 liquidityAmount);

    function addLiquidityCurve(uint256[] calldata maxAmounts, uint256 minLpAmount)
        external
        returns (uint256[] memory addedAmounts, uint256 liquidityAmount);

    function removeLiquidity(
        uint256 shareAmount,
        uint256[] calldata minAmounts,
        uint256 deadline
    ) external returns (uint256[] memory removedAmounts);

    function claimFees() external;
}