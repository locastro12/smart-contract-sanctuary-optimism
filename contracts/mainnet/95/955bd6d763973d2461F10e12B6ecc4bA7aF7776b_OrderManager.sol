// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {ReentrancyGuardUpgradeable} from "../../../openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "../../../openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "../../../openzeppelin-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "../../../openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "../../../openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IPool, Side} from "../interfaces/IPool.sol";
import {SwapOrder, Order} from "../interfaces/IOrderManager.sol";
import {IOracle} from "../interfaces/IOracle.sol";
import {IWETH} from "../interfaces/IWETH.sol";
import {IETHUnwrapper} from "../interfaces/IETHUnwrapper.sol";
import {IOrderHook} from "../interfaces/IOrderHook.sol";
import {IPermit} from "../interfaces/IPermit.sol";

// since we defined this function via a state variable of PoolStorage, it cannot be re-declared the interface IPool
interface IWhitelistedPool is IPool {
    function isListed(address) external returns (bool);
    function allTranches(uint256 index) external returns (address);
}

enum UpdatePositionType {
    INCREASE,
    DECREASE
}

enum OrderType {
    MARKET,
    LIMIT
}

struct UpdatePositionRequest {
    Side side;
    uint256 sizeChange;
    uint256 collateral;
    UpdatePositionType updateType;
}

interface IFarm {
  function depositFor(uint256, uint256, address) external;
  function withdrawFrom(uint256, uint256, address) external;
}

interface ILPToken {
  function minter() external returns (address);
}

contract OrderManager is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using SafeERC20 for IWETH;

    uint256 constant MARKET_ORDER_TIMEOUT = 5 minutes;
    uint256 constant MAX_MIN_EXECUTION_FEE = 1e17; // 0.1 ETH
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    IWETH public weth;

    uint256 public nextOrderId;
    mapping(uint256 => Order) public orders;
    mapping(uint256 => UpdatePositionRequest) public requests;

    uint256 public nextSwapOrderId;
    mapping(uint256 => SwapOrder) public swapOrders;

    IWhitelistedPool public mainPool;
    IOracle public oracle;
    uint256 public minExecutionFee;

    IOrderHook public orderHook;

    mapping(address => uint256[]) public userOrders;
    mapping(address => uint256[]) public userSwapOrders;

    IETHUnwrapper public ethUnwrapper;

    address public executor;

    IFarm public farm;
    mapping(address => IWhitelistedPool) public tranchePools;
    mapping(address => bool) public poolStatus;
    mapping(address => uint256 ) public trancheFarmPid;

    modifier onlyExecutor() {
        _validateExecutor(msg.sender);
        _;
    }

    receive() external payable {
        // prevent send ETH directly to contract
        require(msg.sender == address(weth), "OrderManager:rejected");
    }

    function initialize(address _weth, address _oracle, uint256 _minExecutionFee, address _ethUnwrapper)
        external
        initializer
    {
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        require(_oracle != address(0), "OrderManager:invalidOracle");
        require(_weth != address(0), "OrderManager:invalidWeth");
        require(_minExecutionFee <= MAX_MIN_EXECUTION_FEE, "OrderManager:minExecutionFeeTooHigh");
        require(_ethUnwrapper != address(0), "OrderManager:invalidEthUnwrapper");
        minExecutionFee = _minExecutionFee;
        oracle = IOracle(_oracle);
        nextOrderId = 1;
        nextSwapOrderId = 1;
        weth = IWETH(_weth);
        ethUnwrapper = IETHUnwrapper(_ethUnwrapper);
    }

    // ============= VIEW FUNCTIONS ==============
    function getOrders(address user, uint256 skip, uint256 take)
        external
        view
        returns (uint256[] memory orderIds, uint256 total)
    {
        total = userOrders[user].length;
        uint256 toIdx = skip + take;
        toIdx = toIdx > total ? total : toIdx;
        uint256 nOrders = toIdx > skip ? toIdx - skip : 0;
        orderIds = new uint[](nOrders);
        for (uint256 i = 0; i < nOrders; i++) {
            orderIds[i] = userOrders[user][i];
        }
    }

    function getSwapOrders(address user, uint256 skip, uint256 take)
        external
        view
        returns (uint256[] memory orderIds, uint256 total)
    {
        total = userSwapOrders[user].length;
        uint256 toIdx = skip + take;
        toIdx = toIdx > total ? total : toIdx;
        uint256 nOrders = toIdx > skip ? toIdx - skip : 0;
        orderIds = new uint[](nOrders);
        for (uint256 i = 0; i < nOrders; i++) {
            orderIds[i] = userSwapOrders[user][i];
        }
    }

    // =========== MUTATIVE FUNCTIONS ==========
    function placeOrder(
        IERC20 _tranche,
        UpdatePositionType _updateType,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes calldata data
    ) public payable nonReentrant {
        IWhitelistedPool pool = getPool(_tranche);
        bool isIncrease = _updateType == UpdatePositionType.INCREASE;
        require(pool.validateToken(_indexToken, _collateralToken, _side, isIncrease), "OrderManager:invalidTokens");
        uint256 orderId;
        if (isIncrease) {
            orderId = _createIncreasePositionOrder2(pool, _tranche, _side, _indexToken, _collateralToken, _orderType, data);
        } else {
            orderId = _createDecreasePositionOrder(pool, _side, _indexToken, _collateralToken, _orderType, data);
        }
        userOrders[msg.sender].push(orderId);
    }

    function placeOrderWithPermit(
        IERC20 _tranche,
        UpdatePositionType _updateType,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes calldata data,
        address _token, uint256[] memory _rvs, bytes32 r, bytes32 s
    ) external payable {
        // uint256 deadline, uint256 value, uint8 v
        IPermit(_token).permit(msg.sender, address(this), _rvs[1], _rvs[0], uint8(_rvs[2]), r, s);
        placeOrder(_tranche, _updateType, _side, _indexToken, _collateralToken, _orderType, data);
    }

    function placeSwapOrder(IERC20 _tranche, address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _minOut, uint256 _price)
        external
        payable
        nonReentrant
    {
        IWhitelistedPool pool = getPool(_tranche);
        address payToken;
        (payToken, _tokenIn) = _tokenIn == ETH ? (ETH, address(weth)) : (_tokenIn, _tokenIn);
        // if token out is ETH, check wether pool support WETH
        require(
            pool.isListed(_tokenIn) && pool.isListed(_tokenOut == ETH ? address(weth) : _tokenOut),
            "OrderManager:invalidTokens"
        );

        uint256 executionFee;
        if (payToken == ETH) {
            executionFee = msg.value - _amountIn;
            weth.deposit{value: _amountIn}();
        } else {
            executionFee = msg.value;
            IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);
        }

        require(executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");

        SwapOrder memory order = SwapOrder({
            pool: pool,
            owner: msg.sender,
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            amountIn: _amountIn,
            minAmountOut: _minOut,
            price: _price,
            executionFee: executionFee
        });
        swapOrders[nextSwapOrderId] = order;
        userSwapOrders[msg.sender].push(nextSwapOrderId);
        emit SwapOrderPlaced(nextSwapOrderId);
        nextSwapOrderId += 1;
    }

	function swap(uint256 _amountIn, uint256 _minAmountOut, address[] memory _path) public payable {
        require(_path.length >= 3, "invalide path length");
        uint256 amountOut = _poolSwap2(_path, _amountIn, _minAmountOut, msg.sender, msg.sender);
        emit Swap(msg.sender, _path[0], _path[_path.length - 1], address(0), _amountIn, amountOut);
	}

	function swapWithPermit(uint256 _amountIn, uint256 _minAmountOut, address[] memory _path,
         uint256 deadline, uint256 value, uint8 v, bytes32 r, bytes32 s)
         external payable {
        IPermit(address(_path[0])).permit(msg.sender, address(this), value, deadline, v, r, s);
        swap(_amountIn, _minAmountOut, _path);
	}

    function executeOrder(uint256 _orderId, address payable _feeTo) external nonReentrant onlyExecutor {
        Order memory order = orders[_orderId];
        require(order.owner != address(0), "OrderManager:orderNotExists");
        require(block.number > order.submissionBlock, "OrderManager:blockNotPass");
        _validatePool(order.pool);

        if (order.expiresAt != 0 && order.expiresAt < block.timestamp) {
            _expiresOrder(_orderId, order);
            return;
        }

        UpdatePositionRequest memory request = requests[_orderId];
        uint256 indexPrice = _getMarkPrice(order, request);
        bool isValid = order.triggerAboveThreshold ? indexPrice >= order.price : indexPrice <= order.price;
        if (!isValid) {
            require(order.expiresAt != 0, "OrderManager:invalidLimitOrderPrice");
            return;
        }

        _executeRequest(order, request);
        delete orders[_orderId];
        delete requests[_orderId];
        _safeTransferETH(_feeTo, order.executionFee);
        emit OrderExecuted(_orderId, order, request, indexPrice);
    }

    function _getMarkPrice(Order memory order, UpdatePositionRequest memory request) internal view returns (uint256) {
        bool max = (request.updateType == UpdatePositionType.INCREASE) == (request.side == Side.LONG);
        return oracle.getPrice(order.indexToken, max);
    }

    function cancelOrder(uint256 _orderId) external nonReentrant {
        Order memory order = orders[_orderId];
        require(order.owner == msg.sender, "OrderManager:unauthorizedCancellation");
        UpdatePositionRequest memory request = requests[_orderId];

        delete orders[_orderId];
        delete requests[_orderId];

        _safeTransferETH(order.owner, order.executionFee);
        if (request.updateType == UpdatePositionType.INCREASE) {
            _refundCollateral(order.collateralToken, request.collateral, order.owner);
        }

        emit OrderCancelled(_orderId);
    }

    function cancelSwapOrder(uint256 _orderId) external nonReentrant {
        SwapOrder memory order = swapOrders[_orderId];
        require(order.owner == msg.sender, "OrderManager:unauthorizedCancellation");
        delete swapOrders[_orderId];
        _safeTransferETH(order.owner, order.executionFee);
        IERC20(order.tokenIn).safeTransfer(order.owner, order.amountIn);
        emit SwapOrderCancelled(_orderId);
    }

    function executeSwapOrder(uint256 _orderId, address payable _feeTo) external nonReentrant onlyExecutor {
        SwapOrder memory order = swapOrders[_orderId];
        IPool pool = order.pool;
        _validatePool(pool);
        require(order.owner != address(0), "OrderManager:notFound");
        delete swapOrders[_orderId];
        IERC20(order.tokenIn).safeTransfer(address(pool), order.amountIn);
        uint256 amountOut;
        if (order.tokenOut != ETH) {
            amountOut = _doSwap(pool, order.tokenIn, order.tokenOut, order.minAmountOut, order.owner, order.owner);
        } else {
            amountOut = _doSwap(pool, order.tokenIn, address(weth), order.minAmountOut, address(this), order.owner);
            _safeUnwrapETH(amountOut, order.owner);
        }
        _safeTransferETH(_feeTo, order.executionFee);
        require(amountOut >= order.minAmountOut, "OrderManager:slippageReached");
        emit SwapOrderExecuted(_orderId, order.amountIn, amountOut);
    }

    function _executeRequest(Order memory _order, UpdatePositionRequest memory _request) internal {
        if (_request.updateType == UpdatePositionType.INCREASE) {
            IERC20(_order.collateralToken).safeTransfer(address(_order.pool), _request.collateral);
            _order.pool.increasePosition(
                _order.owner, _order.indexToken, _order.collateralToken, _request.sizeChange, _request.side
            );
        } else {
            IERC20 collateralToken = IERC20(_order.collateralToken);
            uint256 priorBalance = collateralToken.balanceOf(address(this));
            _order.pool.decreasePosition(
                _order.owner,
                _order.indexToken,
                _order.collateralToken,
                _request.collateral,
                _request.sizeChange,
                _request.side,
                address(this)
            );
            uint256 payoutAmount = collateralToken.balanceOf(address(this)) - priorBalance;

            address _tranche = IWhitelistedPool(address(_order.pool)).allTranches(0);
            address[] memory payPath = new address[](3);
            payPath[0] = _order.collateralToken;
            payPath[1] = _tranche;
            payPath[2] = _order.payToken;
            // min amount out
            uint256 amountOut = __poolSwap(payPath, payoutAmount, 0, _order.owner);

            if (_order.payToken == ETH) {
                _safeUnwrapETH(amountOut, _order.owner);
            } else {
                IERC20(_order.payToken).safeTransfer(_order.owner, amountOut);
            }
        }
    }

    function _createDecreasePositionOrder(
        IWhitelistedPool _pool,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes memory _data
    ) internal returns (uint256 orderId) {
        Order memory order;
        UpdatePositionRequest memory request;
        bytes memory extradata;

        if (_orderType == OrderType.MARKET) {
            (order.price, order.payToken, request.sizeChange, request.collateral, extradata) =
                abi.decode(_data, (uint256, address, uint256, uint256, bytes));
            order.triggerAboveThreshold = _side == Side.LONG;
        } else {
            (
                order.price,
                order.triggerAboveThreshold,
                order.payToken,
                request.sizeChange,
                request.collateral,
                extradata
            ) = abi.decode(_data, (uint256, bool, address, uint256, uint256, bytes));
        }
        order.pool = _pool;
        order.owner = msg.sender;
        order.indexToken = _indexToken;
        order.collateralToken = _collateralToken;
        order.expiresAt = _orderType == OrderType.MARKET ? block.timestamp + MARKET_ORDER_TIMEOUT : 0;
        order.submissionBlock = block.number;
        order.executionFee = msg.value;
        require(order.executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");

        request.updateType = UpdatePositionType.DECREASE;
        request.side = _side;
        orderId = nextOrderId;
        nextOrderId = orderId + 1;
        orders[orderId] = order;
        requests[orderId] = request;

        if (address(orderHook) != address(0)) {
            orderHook.postPlaceOrder(orderId, extradata);
        }

        emit OrderPlaced(orderId, order, request);
    }

    function _createIncreasePositionOrder2(
        IWhitelistedPool _pool,
        IERC20 _tranche,
        Side _side,
        address _indexToken,
        address _collateralToken,
        OrderType _orderType,
        bytes memory _data
    ) internal returns (uint256 orderId) {
        Order memory order;
        UpdatePositionRequest memory request;
        order.triggerAboveThreshold = _side == Side.SHORT;
        address purchaseToken;
        uint256 purchaseAmount;
        bytes memory extradata;
        address[] memory purchasePath;
        (order.price, purchaseToken, purchaseAmount, purchasePath, request.sizeChange, request.collateral, extradata) =
            abi.decode(_data, (uint256, address, uint256, address[], uint256, uint256, bytes));

        //require(purchaseAmount != 0, "OrderManager:invalidPurchaseAmount");
        require(purchaseToken != address(0), "OrderManager:invalidPurchaseToken");

        order.pool = _pool;
        order.owner = msg.sender;
        order.indexToken = _indexToken;
        order.collateralToken = _collateralToken;
        order.expiresAt = _orderType == OrderType.MARKET ? block.timestamp + MARKET_ORDER_TIMEOUT : 0;
        order.submissionBlock = block.number;
        //order.executionFee = purchaseToken == ETH ? msg.value - purchaseAmount : msg.value;
        //require(order.executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");
        request.updateType = UpdatePositionType.INCREASE;
        request.side = _side;
        orderId = nextOrderId;
        nextOrderId = orderId + 1;
        requests[orderId] = request;

        if (purchasePath.length == 0) {
            purchasePath = new address[](3);
            purchasePath[0] = purchaseToken;
            purchasePath[1] = address(_tranche);
            purchasePath[2] = _collateralToken;
        } else {
            if (purchaseToken == ETH) {
                require(purchasePath[0] == purchaseToken || purchasePath[0] == address(weth), "purchase token invalid");
            } else {
                require(purchasePath[0] == purchaseToken, "purchase token invalid");
            }
            require(purchasePath[purchasePath.length - 1] == _collateralToken, "collateral token invalid");
        }

        if (purchaseToken == ETH) {
            if (purchaseAmount > 0) {
                weth.safeTransferFrom(msg.sender, address(this), purchaseAmount);
            }
            require(msg.value >= minExecutionFee, "OrderManager:executionFeeTooLow ether");
            order.executionFee = minExecutionFee;
            if (msg.value > minExecutionFee) {
                weth.deposit{value: msg.value - minExecutionFee}();
                purchaseAmount += (msg.value - minExecutionFee);
            }
            purchaseToken = address(weth);
        } else {
            order.executionFee = msg.value;
            IERC20(purchaseToken).safeTransferFrom(msg.sender, address(this), purchaseAmount);
        }
        require(purchaseAmount != 0, "OrderManager:invalidPurchaseAmount");
        require(order.executionFee >= minExecutionFee, "OrderManager:executionFeeTooLow");

        if (purchaseToken != _collateralToken) {
            // update request collateral value to the actual swap output
            requests[orderId].collateral = __poolSwap(purchasePath, purchaseAmount, request.collateral, order.owner);
        } else {
            require(purchaseAmount == request.collateral, "OrderManager:invalidPurchaseAmount");
        }

        if (address(orderHook) != address(0)) {
            orderHook.postPlaceOrder(orderId, extradata);
        }

        orders[orderId] = order;

        emit OrderPlaced(orderId, order, request);
    }


    function _poolSwap(
        IWhitelistedPool _pool,
        address _fromToken,
        address _toToken,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address _beneficier
    ) internal returns (uint256 amountOut) {
        address payToken;
        (payToken, _fromToken) = _fromToken == ETH ? (ETH, address(weth)) : (_fromToken, _fromToken);
        if (payToken == ETH) {
            weth.deposit{value: _amountIn}();
            weth.safeTransfer(address(_pool), _amountIn);
        } else {
            IERC20(_fromToken).safeTransferFrom(msg.sender, address(_pool), _amountIn);
        }
        return _doSwap(_pool, _fromToken, _toToken, _minAmountOut, _receiver, _beneficier);
    }

    function _doSwap(
        IPool _pool,
        address _fromToken,
        address _toToken,
        uint256 _minAmountOut,
        address _receiver,
        address _beneficier
    ) internal returns (uint256 amountOut) {
        IERC20 tokenOut = IERC20(_toToken);
        uint256 priorBalance = tokenOut.balanceOf(_receiver);
        _pool.swap(_fromToken, _toToken, _minAmountOut, _receiver, abi.encode(_beneficier));
        amountOut = tokenOut.balanceOf(_receiver) - priorBalance;
    }

    function _expiresOrder(uint256 _orderId, Order memory _order) internal {
        UpdatePositionRequest memory request = requests[_orderId];
        delete orders[_orderId];
        delete requests[_orderId];
        emit OrderExpired(_orderId);

        _safeTransferETH(_order.owner, _order.executionFee);
        if (request.updateType == UpdatePositionType.INCREASE) {
            _refundCollateral(_order.collateralToken, request.collateral, _order.owner);
        }
    }

    function _refundCollateral(address _collateralToken, uint256 _amount, address _orderOwner) internal {
        if (_collateralToken == address(weth)) {
            _safeUnwrapETH(_amount, _orderOwner);
        } else {
            IERC20(_collateralToken).safeTransfer(_orderOwner, _amount);
        }
    }

    function _safeTransferETH(address _to, uint256 _amount) internal {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = _to.call{value: _amount}(new bytes(0));
        require(success, "TransferHelper: ETH_TRANSFER_FAILED");
    }

    function _safeUnwrapETH(uint256 _amount, address _to) internal {
        weth.safeIncreaseAllowance(address(ethUnwrapper), _amount);
        ethUnwrapper.unwrap(_amount, _to);
    }

    function _validateExecutor(address _sender) internal view {
        require(_sender == executor, "OrderManager:onlyExecutor");
    }
    function _validateTranche(IERC20 _tranche) internal view {
        require(address(tranchePools[address(_tranche)]) != address(0), "OrderManager:validateTranche");
    }
    function _validatePool(IPool _pool) internal view {
        require(poolStatus[address(_pool)], "OrderManager:validatePool");
    }
    function getPool(IERC20 _tranche) public view returns (IWhitelistedPool pool) {
        pool = tranchePools[address(_tranche)];
        _validateTranche(_tranche);
        _validatePool(pool);
    }

    // ============ New API ===========

	// token0,tranche0,token1
	// token0,tranche0,token1,tranche1,token2
    function _poolSwap2(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _receiver,
        address _beneficier
    ) internal returns (uint256 amountOut) {
        require(_path.length >= 3, "invalide path length");

        address fromToken = _path[0];
        address toToken = _path[_path.length - 1];
        if (fromToken == ETH) {
            if (_amountIn > 0) {
                weth.safeTransferFrom(msg.sender, address(this), _amountIn);
            }
            if (msg.value > 0) {
                weth.deposit{value: msg.value}();
                _amountIn += msg.value;
            }
        } else {
            IERC20(fromToken).safeTransferFrom(msg.sender, address(this), _amountIn);
        }

        amountOut = __poolSwap(_path, _amountIn, _minAmountOut, _beneficier);

        if (toToken == ETH) {
            _safeUnwrapETH(amountOut, _receiver);
        } else {
            IERC20(toToken).safeTransfer(_receiver, amountOut);
        }
    }

    function __poolSwap(
        address[] memory _path,
        uint256 _amountIn,
        uint256 _minAmountOut,
        address _beneficier
    ) internal returns (uint256) {
        uint len = (_path.length - 1) / 2;
        for(uint i = 0; i < len; ) {
            address fromToken = _path[2 * i];
            address tranche = _path[2 * i + 1];
            address toToken = _path[2 * i + 2];
            if (fromToken == ETH) fromToken = address(weth);
            if (toToken == ETH) toToken = address(weth);
            if (fromToken != toToken) {
                IPool pool = getPool(IERC20(tranche));
                IERC20(fromToken).safeTransfer(address(pool), _amountIn);
                _amountIn = _doSwap(pool, fromToken, toToken, 0, address(this), _beneficier);
            }
            unchecked {
                i = i + 1;
            }
        }

        require(_amountIn >= _minAmountOut, "!min amount out");
        return _amountIn;
    }

    // ============ Stake & Unstake ============

    function addLiquidity(IERC20 _tranche, IERC20 _token, uint256 _amountIn, uint256 _minLpAmount, bool _stake)
        public payable
    {
        _token.safeTransferFrom(msg.sender, address(this), _amountIn);
        if (address(_token) == address(weth) && msg.value > 0) {
            weth.deposit{value: msg.value}();
            _amountIn += msg.value;
        }

        _addLiquidity(_tranche, _token, _amountIn, _minLpAmount, _stake);
    }
    function addLiquidityWithPermit(IERC20 _tranche, IERC20 _token, uint256 _amountIn, uint256 _minLpAmount, bool _stake,
        uint256 deadline, uint256 value, uint8 v, bytes32 r, bytes32 s)
        external payable
    {
        IPermit(address(_token)).permit(msg.sender, address(this), value, deadline, v, r, s);
        addLiquidity(_tranche, _token, _amountIn, _minLpAmount, _stake);
    }

    function _addLiquidity(IERC20 _tranche, IERC20 _token, uint256 _amountIn, uint256 _minLpAmount, bool _stake) internal {
        IWhitelistedPool pool = getPool(_tranche);
        require(pool.isListed(address(_token)), "OrderManager:invalidStakeTokens");
        _token.safeApprove(address(pool), _amountIn);
        if (_stake) {
            uint256 lpAmount = _tranche.balanceOf(address(this));
            pool.addLiquidity(address(_tranche), address(_token), _amountIn, _minLpAmount, address(this));
            lpAmount = _tranche.balanceOf(address(this)) - lpAmount;

            // stake to farm
            _tranche.safeApprove(address(farm), lpAmount);
            farm.depositFor(trancheFarmPid[address(_tranche)], lpAmount, msg.sender);
        } else {
            pool.addLiquidity(address(_tranche), address(_token), _amountIn, _minLpAmount, msg.sender);
        }

        emit AddLiquidity(msg.sender, address(_tranche), address(_token), _amountIn, _minLpAmount, _stake);
    }

    function removeLiquidity(IERC20 _tranche, uint256 _lpAmount, address _tokenOut, uint256 _minOut, bool _unstake, bool _native)
        external
    {
        IWhitelistedPool pool = getPool(_tranche);
        if (_unstake) {
            farm.withdrawFrom(trancheFarmPid[address(_tranche)], _lpAmount, msg.sender);
        } else {
            _tranche.safeTransferFrom(msg.sender, address(this), _lpAmount);
        }

        _tranche.safeApprove(address(pool), _lpAmount);
        if (_native) {
            uint256 amountOut = weth.balanceOf(address(this));
            pool.removeLiquidity(address(_tranche), address(weth), _lpAmount, _minOut, address(this));
            amountOut = weth.balanceOf(address(this)) - amountOut;
            _safeUnwrapETH(amountOut, msg.sender);
        } else {
            pool.removeLiquidity(address(_tranche), _tokenOut, _lpAmount, _minOut, msg.sender);
        }

        emit RemoveLiquidity(msg.sender, address(_tranche), address(_tokenOut), _lpAmount, _minOut, _unstake);
    }

    // ============ Administrative =============

    function setOracle(address _oracle) external onlyOwner {
        require(_oracle != address(0), "OrderManager:invalidOracleAddress");
        oracle = IOracle(_oracle);
        emit OracleChanged(_oracle);
    }

    function setFarm(address _farm) external onlyOwner {
        require(_farm != address(0), "OrderManager:invalidFarmAddress");
        require(address(farm) != _farm, "OrderManager:faramAlreadyAdded");
        farm = IFarm(_farm);
        emit FarmSet(_farm);
    }
    function setTrancheFarmPid(address _tranche, uint256 _pid) external onlyOwner {
        trancheFarmPid[_tranche] = _pid;
    }
    function setTranchePool(address _tranche, IWhitelistedPool _pool) external onlyOwner {
        tranchePools[_tranche] = _pool;
        poolStatus[address(_pool)] = true;
    }
    function addTranche(address _tranche) external onlyOwner {
        IWhitelistedPool pool = IWhitelistedPool(ILPToken(_tranche).minter());
        tranchePools[_tranche] = pool;
        poolStatus[address(pool)] = true;
    }

    function setMinExecutionFee(uint256 _fee) external onlyOwner {
        require(_fee != 0, "OrderManager:invalidFeeValue");
        require(_fee <= MAX_MIN_EXECUTION_FEE, "OrderManager:minExecutionFeeTooHigh");
        minExecutionFee = _fee;
        emit MinExecutionFeeSet(_fee);
    }

    function setOrderHook(address _hook) external onlyOwner {
        orderHook = IOrderHook(_hook);
        emit OrderHookSet(_hook);
    }

    function setExecutor(address _executor) external onlyOwner {
        require(_executor != address(0), "OrderManager:invalidAddress");
        executor = _executor;
        emit ExecutorSet(_executor);
    }

    // ========== EVENTS =========

    event OrderPlaced(uint256 indexed key, Order order, UpdatePositionRequest request);
    event OrderCancelled(uint256 indexed key);
    event OrderExecuted(uint256 indexed key, Order order, UpdatePositionRequest request, uint256 fillPrice);
    event OrderExpired(uint256 indexed key);
    event OracleChanged(address);
    event SwapOrderPlaced(uint256 indexed key);
    event SwapOrderCancelled(uint256 indexed key);
    event SwapOrderExecuted(uint256 indexed key, uint256 amountIn, uint256 amountOut);
    event Swap(
        address indexed account,
        address indexed tokenIn,
        address indexed tokenOut,
        address pool,
        uint256 amountIn,
        uint256 amountOut
    );
    event PoolSet(address indexed pool);
    event FarmSet(address indexed farm);
    event MinExecutionFeeSet(uint256 fee);
    event OrderHookSet(address indexed hook);
    event ExecutorSet(address indexed executor);
    event AddLiquidity(address indexed sender, address indexed pool, address indexed token, uint256 amountIn, uint256 minLpAmount, bool stake);
    event RemoveLiquidity(address indexed sender, address indexed pool, address indexed token, uint256 lpAmount, uint256 minAmount, bool unstake);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
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
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Permit.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (proxy/utils/Initializable.sol)

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
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
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
        if (_initialized != type(uint8).max) {
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
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

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
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

uint256 constant POS = 1;
uint256 constant NEG = 0;

/// SignedInt is integer number with sign. It value range is -(2 ^ 256 - 1) to (2 ^ 256 - 1)
struct SignedInt {
    /// @dev sig = 1 -> positive, sig = 0 is negative
    /// using uint256 which take up full word to optimize gas and contract size
    uint256 sig;
    uint256 abs;
}

library SignedIntOps {
    function add(SignedInt memory a, SignedInt memory b) internal pure returns (SignedInt memory) {
        if (a.sig == b.sig) {
            return SignedInt({sig: a.sig, abs: a.abs + b.abs});
        }

        if (a.abs == b.abs) {
            return SignedInt(POS, 0); // always return positive zero
        }

        unchecked {
            (uint256 sig, uint256 abs) = a.abs > b.abs ? (a.sig, a.abs - b.abs) : (b.sig, b.abs - a.abs);
            return SignedInt(sig, abs);
        }
    }

    function inv(SignedInt memory a) internal pure returns (SignedInt memory) {
        return a.abs == 0 ? a : (SignedInt({sig: 1 - a.sig, abs: a.abs}));
    }

    function sub(SignedInt memory a, SignedInt memory b) internal pure returns (SignedInt memory) {
        return add(a, inv(b));
    }

    function mul(SignedInt memory a, SignedInt memory b) internal pure returns (SignedInt memory) {
        uint256 sig = (a.sig + b.sig + 1) % 2;
        uint256 abs = a.abs * b.abs;
        return SignedInt(abs == 0 ? POS : sig, abs); // zero is alway positive
    }

    function div(SignedInt memory a, SignedInt memory b) internal pure returns (SignedInt memory) {
        uint256 sig = (a.sig + b.sig + 1) % 2;
        uint256 abs = a.abs / b.abs;
        return SignedInt(sig, abs);
    }

    function add(SignedInt memory a, uint256 b) internal pure returns (SignedInt memory) {
        return add(a, wrap(b));
    }

    function sub(SignedInt memory a, uint256 b) internal pure returns (SignedInt memory) {
        return sub(a, wrap(b));
    }

    function mul(SignedInt memory a, uint256 b) internal pure returns (SignedInt memory) {
        return mul(a, wrap(b));
    }

    function div(SignedInt memory a, uint256 b) internal pure returns (SignedInt memory) {
        return div(a, wrap(b));
    }

    function wrap(uint256 a) internal pure returns (SignedInt memory) {
        return SignedInt(POS, a);
    }

    function toUint(SignedInt memory a) internal pure returns (uint256) {
        require(a.sig == POS, "SignedInt: below zero");
        return a.abs;
    }

    function gt(SignedInt memory a, uint256 b) internal pure returns (bool) {
        return a.sig == POS && a.abs > b;
    }

    function lt(SignedInt memory a, uint256 b) internal pure returns (bool) {
        return a.sig == NEG || a.abs < b;
    }

    function isNeg(SignedInt memory a) internal pure returns (bool) {
        return a.sig == NEG;
    }

    function isPos(SignedInt memory a) internal pure returns (bool) {
        return a.sig == POS;
    }

    function frac(SignedInt memory a, uint256 num, uint256 denom) internal pure returns (SignedInt memory) {
        return div(mul(a, num), denom);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;
import {IERC20} from "../../../openzeppelin/token/ERC20/utils/SafeERC20.sol";

interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint) external;
    function transfer(address to, uint value) external override returns (bool);
	function balanceOf(address account) external override view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import {SignedInt} from "../lib/SignedInt.sol";

enum Side {
    LONG,
    SHORT
}

struct TokenWeight {
    address token;
    uint256 weight;
}

interface IPool {
    function increasePosition(
        address _account,
        address _indexToken,
        address _collateralToken,
        uint256 _sizeChanged,
        Side _side
    ) external;

    function decreasePosition(
        address _account,
        address _indexToken,
        address _collateralToken,
        uint256 _desiredCollateralReduce,
        uint256 _sizeChanged,
        Side _side,
        address _receiver
    ) external;

    function liquidatePosition(address _account, address _indexToken, address _collateralToken, Side _side) external;

    function validateToken(address indexToken, address collateralToken, Side side, bool isIncrease)
        external
        view
        returns (bool);

    function swap(address _tokenIn, address _tokenOut, uint256 _minOut, address _to, bytes calldata extradata)
        external;

    function addLiquidity(address _tranche, address _token, uint256 _amountIn, uint256 _minLpAmount, address _to)
        external;

    function removeLiquidity(address _tranche, address _tokenOut, uint256 _lpAmount, uint256 _minOut, address _to)
        external;

    // =========== EVENTS ===========
    event SetOrderManager(address indexed orderManager);
    event IncreasePosition(
        bytes32 indexed key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralValue,
        uint256 sizeChanged,
        Side side,
        uint256 indexPrice,
        uint256 feeValue
    );
    event UpdatePosition(
        bytes32 indexed key,
        uint256 size,
        uint256 collateralValue,
        uint256 entryPrice,
        uint256 entryInterestRate,
        uint256 reserveAmount,
        uint256 indexPrice
    );
    event DecreasePosition(
        bytes32 indexed key,
        address account,
        address collateralToken,
        address indexToken,
        uint256 collateralChanged,
        uint256 sizeChanged,
        Side side,
        uint256 indexPrice,
        SignedInt pnl,
        uint256 feeValue
    );
    event ClosePosition(
        bytes32 indexed key,
        uint256 size,
        uint256 collateralValue,
        uint256 entryPrice,
        uint256 entryInterestRate,
        uint256 reserveAmount
    );
    event LiquidatePosition(
        bytes32 indexed key,
        address account,
        address collateralToken,
        address indexToken,
        Side side,
        uint256 size,
        uint256 collateralValue,
        uint256 reserveAmount,
        uint256 indexPrice,
        SignedInt pnl,
        uint256 feeValue
    );
    event DaoFeeWithdrawn(address indexed token, address recipient, uint256 amount);
    event DaoFeeReduced(address indexed token, uint256 amount);
    event FeeDistributorSet(address indexed feeDistributor);
    event LiquidityAdded(
        address indexed tranche, address indexed sender, address token, uint256 amount, uint256 lpAmount, uint256 fee
    );
    event LiquidityRemoved(
        address indexed tranche, address indexed sender, address token, uint256 lpAmount, uint256 amountOut, uint256 fee
    );
    event TokenWeightSet(TokenWeight[]);
    event Swap(
        address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut, uint256 fee
    );
    event PositionFeeSet(uint256 positionFee, uint256 liquidationFee);
    event DaoFeeSet(uint256 value);
    event SwapFeeSet(
        uint256 baseSwapFee, uint256 taxBasisPoint, uint256 stableCoinBaseSwapFee, uint256 stableCoinTaxBasisPoint
    );
    event InterestAccrued(address indexed token, uint256 borrowIndex);
    event MaxLeverageChanged(uint256 maxLeverage);
    event TokenWhitelisted(address indexed token);
    event TokenDelisted(address indexed token);
    event OracleChanged(address indexed oldOracle, address indexed newOracle);
    event InterestRateSet(uint256 interestRate, uint256 interval);
    event MaxPositionSizeSet(uint256 maxPositionSize);
    event PoolHookChanged(address indexed hook);
    event TrancheAdded(address indexed lpToken);
    event TokenRiskFactorUpdated(address indexed token);
    event PnLDistributed(address indexed asset, address indexed tranche, uint256 amount, bool hasProfit);
    event MaintenanceMarginChanged(uint256 ratio);
    event AddRemoveLiquidityFeeSet(uint256 value);
    event MaxGlobalShortSizeSet(address indexed token, uint256 max);
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IPermit {
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

import {IPool} from "./IPool.sol";

struct Order {
    IPool pool;
    address owner;
    address indexToken;
    address collateralToken;
    address payToken;
    uint256 expiresAt;
    uint256 submissionBlock;
    uint256 price;
    uint256 executionFee;
    bool triggerAboveThreshold;
}

struct SwapOrder {
    IPool pool;
    address owner;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 minAmountOut;
    uint256 price;
    uint256 executionFee;
}

interface IOrderManager {
    function orders(uint256 id) external view returns (Order memory);

    function swapOrders(uint256 id) external view returns (SwapOrder memory);

    function executeOrder(uint256 _key, address payable _feeTo) external;

    function executeSwapOrder(uint256 _orderId, address payable _feeTo) external;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

interface IOrderHook {
    function postPlaceOrder(uint256 orderId, bytes calldata extradata) external;

    function postPlaceSwapOrder(uint256 swapOrderId, bytes calldata extradata) external;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.6;

/// @title IOracle
/// @notice Read price of various token
interface IOracle {
    function getPrice(address token) external view returns (uint256);
    function getPrice(address token, bool max) external view returns (uint256);
    function getMultiplePrices(address[] calldata tokens, bool max) external view returns (uint256[] memory);
    function getMultipleChainlinkPrices(address[] calldata tokens) external view returns (uint256[] memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IETHUnwrapper {
    function unwrap(uint256 _amount, address _to) external;
}