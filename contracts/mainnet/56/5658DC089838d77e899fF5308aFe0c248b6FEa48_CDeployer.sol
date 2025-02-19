pragma solidity =0.5.16;

import "./Collateral.sol";
import "./interfaces/ICDeployer.sol";

/*
 * This contract is used by the Factory to deploy Collateral(s)
 * The bytecode would be too long to fit in the Factory
 */
 
contract CDeployer is ICDeployer {
	constructor () public {}
	
	function deployCollateral(address uniswapV2Pair) external returns (address collateral) {
		bytes memory bytecode = type(Collateral).creationCode;
		bytes32 salt = keccak256(abi.encodePacked(msg.sender, uniswapV2Pair));
		assembly {
			collateral := create2(0, add(bytecode, 32), mload(bytecode), salt)
		}
	}
}

pragma solidity =0.5.16;

import "./PoolToken.sol";
import "./CStorage.sol";
import "./CSetter.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IBorrowable.sol";
import "./interfaces/ICollateral.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ITarotSolidlyPriceOracleV2.sol";
import "./interfaces/ITarotCallee.sol";
import "./interfaces/IBaseV1Pair.sol";
import "./interfaces/IVaultToken.sol";
import "./libraries/Math.sol";

contract Collateral is ICollateral, PoolToken, CStorage, CSetter {
    constructor() public {}

    /*** Collateralization Model ***/

    function getPrices() public returns (uint256 price0, uint256 price1) {
        (uint256 reserve0, uint256 reserve1) = getReserves();
        uint256 t = IBaseV1Pair(underlying).totalSupply();
        (uint256 decimals0, uint256 decimals1, , , , , ) = IBaseV1Pair(underlying).metadata();
        
        reserve0 = reserve0.mul(1e18).div(decimals0);
        reserve1 = reserve1.mul(1e18).div(decimals1);
        uint256 f;
        {
            uint256 a = reserve0.mul(reserve0).div(1e18);
            uint256 b = reserve1.mul(reserve1).div(1e18);
            f = a.mul(3).add(b).mul(1e18).div(b.mul(3).add(a));
        }
        price0 = t.mul(f).div(f.add(1e18)).mul(1e18).div(reserve0).mul(1e18).div(decimals0);
        price1 = t.mul(1e18).div(f.add(1e18)).mul(1e18).div(reserve1).mul(1e18).div(decimals1);
    }

    function _k(uint256 x, uint256 y, uint256 d0, uint256 d1) internal pure returns (uint256) {
        uint _x = x.mul(1e18).div(d0);
        uint _y = y.mul(1e18).div(d1);
        uint _a = _x.mul(_y).div(1e18);
        uint _b = _x.mul(_x).div(1e18).add(_y.mul(_y).div(1e18));
        return _a.mul(_b).div(1e18);  // x3y+y3x >= k
    }

    function getReserves() public returns (uint112 reserve0, uint112 reserve1) {
        (uint256 _twapReserve0, uint256 _twapReserve1, ) =
            ITarotSolidlyPriceOracleV2(tarotPriceOracle).getResult(underlying);
        if (isUnderlyingVaultToken()) {
            uint256 scale = IVaultToken(underlying).getScale();
            _twapReserve0 = _twapReserve0.mul(scale).div(1e18);
            _twapReserve1 = _twapReserve1.mul(scale).div(1e18);
        }

        (uint256 decimals0, uint256 decimals1, , , , , ) = IBaseV1Pair(underlying).metadata();
        (uint256 _currReserve0, uint256 _currReserve1, ) = IBaseV1Pair(underlying).getReserves();
        
        uint256 twapK = _k(_twapReserve0, _twapReserve1, decimals0, decimals1);
        uint256 currK = _k(_currReserve0, _currReserve1, decimals0, decimals1);

        uint256 _adjustment = Math.sqrt(Math.sqrt(currK.mul(1e18).div(twapK).mul(1e18)).mul(1e18));
        reserve0 = safe112(_twapReserve0.mul(_adjustment).div(1e18));
        reserve1 = safe112(_twapReserve1.mul(_adjustment).div(1e18));

        require(reserve0 > 100 && reserve1 > 100, "Tarot: INSUFFICIENT_RESERVES");
    }

    function _fm(uint256 p1, uint256 m) internal pure returns (bool) {
        uint256 a = m.mul(m).div(1e18).mul(m).div(1e18).add(m.mul(3));
        uint256 b = p1.mul(3).mul(m).div(1e18).mul(m).div(1e18);
        return a > b && a.sub(b) > p1;
    }

    function _get_m(uint256 p1, uint256 a, uint256 b, uint256 _mTolerance) internal pure returns (uint256 m) {
        for (uint256 i = 0; i < 255; i++) {
            uint256 mid = b.sub(a).div(2);
            m = a.add(mid);
            if (mid <= _mTolerance) {
                return m;
            }
            if (_fm(p1, m)) {
                b = m;
            } else {
                a = m;
            }
        }
    }

    function _reserveRatioSwingGivenPriceSwing(ReserveInfo memory reserveInfo, uint256 _priceSwing, uint256 _mTolerance) internal pure returns (uint256 reserveRatioSwing) {
        if (_priceSwing == 1e18) {
            return 1e18;
        }

        uint256 x = reserveInfo.x;
        uint256 y = reserveInfo.y;

        uint256 a = x.mul(x).div(1e18);
        uint256 b = y.mul(y).div(1e18);
        uint256 c = a.mul(3).add(b);
        uint256 d = b.mul(3).add(a);
        uint256 p1 = y.mul(c).div(x);
        p1 = p1.mul(1e18).div(d);
        p1 = p1.mul(_priceSwing).div(1e18);

        (uint256 lower, uint256 upper) = p1 > 1e18 ? (uint256(1e18), p1.mul(3)) : (p1.div(3), uint256(1e18));
        reserveRatioSwing = _get_m(p1, lower, upper, _mTolerance);
        reserveRatioSwing = reserveRatioSwing.mul(x).div(y);
    }

    function _safetyMarginReserveRatioSwings(ReserveInfo memory reserveInfo, uint256 _safetyMargin, uint256 _mTolerance) internal pure returns (uint256 ratioSwingA, uint256 ratioSwingB) {
        ratioSwingA = _reserveRatioSwingGivenPriceSwing(reserveInfo, _safetyMargin, _mTolerance);
        ratioSwingB = _reserveRatioSwingGivenPriceSwing(reserveInfo, uint256(1e36).div(_safetyMargin), _mTolerance);
    }

    function _reserveDeltas(ReserveInfo memory reserveInfo, uint256 m) internal pure returns (uint256 deltaX, uint256 deltaY, uint256 priceFactor) {
        uint256 x = reserveInfo.x;
        uint256 y = reserveInfo.y;
        uint256 a = x.mul(x).div(1e18);
        uint256 b = y.mul(y).div(1e18);
        uint256 c = b.mul(m).div(1e18).mul(m).div(1e18);
        uint256 d = m.mul(a.add(c)).div(1e18);
        deltaX = Math.sqrt(Math.sqrt(a.add(b).mul(1e18).div(d).mul(1e18)).mul(1e18));
        deltaY = deltaX.mul(m).div(1e18);
        priceFactor = a.mul(3).add(c).mul(1e18).div(c.mul(3).add(a));
    }

    struct ReserveInfo {
        uint256 x;
        uint256 y;
    }

    // returns liquidity in  collateral's underlying
    function _calculateLiquidity(
        uint256 _amountCollateral,
        uint256 _amount0,
        uint256 _amount1
    ) internal returns (uint256 liquidity, uint256 shortfall) {
        ReserveInfo memory reserveInfo;
        (uint256 reserve0, uint256 reserve1) = getReserves();
        {
            (uint256 decimals0, uint256 decimals1, , , , , ) = IBaseV1Pair(underlying).metadata();
            reserveInfo.x = reserve0.mul(1e18).div(decimals0);
            reserveInfo.y = reserve1.mul(1e18).div(decimals1);
        }
        (uint256 ratioSwingA, uint256 ratioSwingB) = _safetyMarginReserveRatioSwings(reserveInfo, safetyMargin, mTolerance);
        uint256 totalUnderlying = IBaseV1Pair(underlying).totalSupply();
        uint256 collateralNeededA;
        uint256 amount0 = _amount0;
        uint256 amount1 = _amount1;
        uint256 amountCollateral = _amountCollateral;
        {
            (uint256 dx1, uint256 dy1, uint256 a1) = _reserveDeltas(reserveInfo, ratioSwingA);
            uint256 price0 = totalUnderlying.mul(1e18).div(reserve0);
            price0 = price0.mul(1e18).div(dx1);
            price0 = price0.mul(a1).div(a1.add(1e18));
            uint256 price1 = totalUnderlying.mul(1e18).div(reserve1);
            price1 = price1.mul(1e18).div(dy1);
            price1 = price1.mul(1e18).div(a1.add(1e18));
            collateralNeededA = amount0.mul(price0).div(1e18);
            collateralNeededA = collateralNeededA.add(amount1.mul(price1).div(1e18));
            collateralNeededA = collateralNeededA.mul(liquidationPenalty()).div(1e18);
        }
        uint256 collateralNeededB;
        {
            (uint256 dx2, uint256 dy2, uint256 a2) = _reserveDeltas(reserveInfo, ratioSwingB);
            uint256 price0 = totalUnderlying.mul(1e18).div(reserve0);
            price0 = price0.mul(1e18).div(dx2);
            price0 = price0.mul(a2).div(a2.add(1e18));
            uint256 price1 = totalUnderlying.mul(1e18).div(reserve1);
            price1 = price1.mul(1e18).div(dy2);
            price1 = price1.mul(1e18).div(a2.add(1e18));
            collateralNeededB = amount0.mul(price0).div(1e18);
            collateralNeededB = collateralNeededB.add(amount1.mul(price1).div(1e18));
            collateralNeededB = collateralNeededB.mul(liquidationPenalty()).div(1e18);
        }        
        uint256 collateralNeeded = (collateralNeededA > collateralNeededB) ? collateralNeededA : collateralNeededB;
        if (amountCollateral >= collateralNeeded) {
            return (amountCollateral - collateralNeeded, 0);
        } else {
            return (0, collateralNeeded - amountCollateral);
        }
    }

    /*** ERC20 ***/

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        require(tokensUnlocked(from, value), "Tarot: INSUFFICIENT_LIQUIDITY");
        super._transfer(from, to, value);
    }

    function tokensUnlocked(address from, uint256 value) public returns (bool) {
        uint256 _balance = balanceOf[from];
        if (value > _balance) return false;
        uint256 finalBalance = _balance - value;
        uint256 amountCollateral = finalBalance.mul(exchangeRate()).div(1e18);
        uint256 amount0 = IBorrowable(borrowable0).borrowBalance(from);
        uint256 amount1 = IBorrowable(borrowable1).borrowBalance(from);
        (, uint256 shortfall) =
            _calculateLiquidity(amountCollateral, amount0, amount1);
        return shortfall == 0;
    }

    /*** Collateral ***/

    function accountLiquidityAmounts(
        address borrower,
        uint256 amount0,
        uint256 amount1
    ) public returns (uint256 liquidity, uint256 shortfall) {
        if (amount0 == uint256(-1))
            amount0 = IBorrowable(borrowable0).borrowBalance(borrower);
        if (amount1 == uint256(-1))
            amount1 = IBorrowable(borrowable1).borrowBalance(borrower);
        uint256 amountCollateral =
            balanceOf[borrower].mul(exchangeRate()).div(1e18);
        return _calculateLiquidity(amountCollateral, amount0, amount1);
    }

    function accountLiquidity(address borrower)
        public
        returns (uint256 liquidity, uint256 shortfall)
    {
        return accountLiquidityAmounts(borrower, uint256(-1), uint256(-1));
    }

    function canBorrow(
        address borrower,
        address borrowable,
        uint256 accountBorrows
    ) public returns (bool) {
        address _borrowable0 = borrowable0;
        address _borrowable1 = borrowable1;
        require(
            borrowable == _borrowable0 || borrowable == _borrowable1,
            "Tarot: INVALID_BORROWABLE"
        );
        uint256 amount0 =
            borrowable == _borrowable0 ? accountBorrows : uint256(-1);
        uint256 amount1 =
            borrowable == _borrowable1 ? accountBorrows : uint256(-1);
        (, uint256 shortfall) =
            accountLiquidityAmounts(borrower, amount0, amount1);
        return shortfall == 0;
    }

    // this function must be called from borrowable0 or borrowable1
    function seize(
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256 seizeTokens) {
        require(
            msg.sender == borrowable0 || msg.sender == borrowable1,
            "Tarot: UNAUTHORIZED"
        );

        (, uint256 shortfall) = accountLiquidity(borrower);
        require(shortfall > 0, "Tarot: INSUFFICIENT_SHORTFALL");

        uint256 price;
        if (msg.sender == borrowable0) (price, ) = getPrices();
        else (, price) = getPrices();

        uint256 collateralEquivalent = repayAmount.mul(price).div(exchangeRate());

        seizeTokens = collateralEquivalent
            .mul(liquidationIncentive)
            .div(1e18);

        balanceOf[borrower] = balanceOf[borrower].sub(
            seizeTokens,
            "Tarot: LIQUIDATING_TOO_MUCH"
        );
        balanceOf[liquidator] = balanceOf[liquidator].add(seizeTokens);
        emit Transfer(borrower, liquidator, seizeTokens);

        if (liquidationFee > 0) {
            uint256 seizeFee = collateralEquivalent.mul(liquidationFee).div(1e18);
            address reservesManager = IFactory(factory).reservesManager();
            balanceOf[borrower] = balanceOf[borrower].sub(seizeFee, "Tarot: LIQUIDATING_TOO_MUCH");
            balanceOf[reservesManager] = balanceOf[reservesManager].add(seizeFee);
            emit Transfer(borrower, reservesManager, seizeFee);
        }
    }

    // this low-level function should be called from another contract
    function flashRedeem(
        address redeemer,
        uint256 redeemAmount,
        bytes calldata data
    ) external nonReentrant update {
        require(redeemAmount <= totalBalance, "Tarot: INSUFFICIENT_CASH");

        // optimistically transfer funds
        _safeTransfer(redeemer, redeemAmount);
        if (data.length > 0)
            ITarotCallee(redeemer).tarotRedeem(msg.sender, redeemAmount, data);

        uint256 redeemTokens = balanceOf[address(this)];
        uint256 declaredRedeemTokens =
            redeemAmount.mul(1e18).div(exchangeRate()).add(1); // rounded up
        require(
            redeemTokens >= declaredRedeemTokens,
            "Tarot: INSUFFICIENT_REDEEM_TOKENS"
        );

        _burn(address(this), redeemTokens);
        emit Redeem(msg.sender, redeemer, redeemAmount, redeemTokens);
    }

    function isUnderlyingVaultToken()
        public
        view
        returns (bool)
    {
        (bool success, bytes memory returnData) = address(underlying).staticcall(
            abi.encodeWithSelector(IVaultToken(underlying).isVaultToken.selector)
        );
        if (success) {
            return abi.decode(returnData, (bool));
        } else {
            return false;
        }
    }

    function safe112(uint256 n) internal pure returns (uint112) {
        require(n < 2**112, "Tarot: SAFE112");
        return uint112(n);
    }
}

pragma solidity >=0.5.0;

interface ICDeployer {
	function deployCollateral(address uniswapV2Pair) external returns (address collateral);
}

pragma solidity =0.5.16;

import "./TarotERC20.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IPoolToken.sol";
import "./libraries/SafeMath.sol";

contract PoolToken is IPoolToken, TarotERC20 {
    uint256 internal constant initialExchangeRate = 1e18;
    address public underlying;
    address public factory;
    uint256 public totalBalance;
    uint256 public constant MINIMUM_LIQUIDITY = 1000;

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    /*** Initialize ***/

    // called once by the factory
    function _setFactory() external {
        require(factory == address(0), "Tarot: FACTORY_ALREADY_SET");
        factory = msg.sender;
    }

    /*** PoolToken ***/

    function _update() internal {
        totalBalance = IERC20(underlying).balanceOf(address(this));
        emit Sync(totalBalance);
    }

    function exchangeRate() public returns (uint256) {
        uint256 _totalSupply = totalSupply; // gas savings
        uint256 _totalBalance = totalBalance; // gas savings
        if (_totalSupply == 0 || _totalBalance == 0) return initialExchangeRate;
        return _totalBalance.mul(1e18).div(_totalSupply);
    }

    // this low-level function should be called from another contract
    function mint(address minter)
        external
        nonReentrant
        update
        returns (uint256 mintTokens)
    {
        uint256 balance = IERC20(underlying).balanceOf(address(this));
        uint256 mintAmount = balance.sub(totalBalance);
        mintTokens = mintAmount.mul(1e18).div(exchangeRate());

        if (totalSupply == 0) {
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            mintTokens = mintTokens.sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        require(mintTokens > 0, "Tarot: MINT_AMOUNT_ZERO");
        _mint(minter, mintTokens);
        emit Mint(msg.sender, minter, mintAmount, mintTokens);
    }

    // this low-level function should be called from another contract
    function redeem(address redeemer)
        external
        nonReentrant
        update
        returns (uint256 redeemAmount)
    {
        uint256 redeemTokens = balanceOf[address(this)];
        redeemAmount = redeemTokens.mul(exchangeRate()).div(1e18);

        require(redeemAmount > 0, "Tarot: REDEEM_AMOUNT_ZERO");
        require(redeemAmount <= totalBalance, "Tarot: INSUFFICIENT_CASH");
        _burn(address(this), redeemTokens);
        _safeTransfer(redeemer, redeemAmount);
        emit Redeem(msg.sender, redeemer, redeemAmount, redeemTokens);
    }

    // force real balance to match totalBalance
    function skim(address to) external nonReentrant {
        _safeTransfer(
            to,
            IERC20(underlying).balanceOf(address(this)).sub(totalBalance)
        );
    }

    // force totalBalance to match real balance
    function sync() external nonReentrant update {}

    /*** Utilities ***/

    // same safe transfer function used by UniSwapV2 (with fixed underlying)
    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    function _safeTransfer(address to, uint256 amount) internal {
        (bool success, bytes memory data) =
            underlying.call(abi.encodeWithSelector(SELECTOR, to, amount));
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "Tarot: TRANSFER_FAILED"
        );
    }

    // prevents a contract from calling itself, directly or indirectly.
    bool internal _notEntered = true;
    modifier nonReentrant() {
        require(_notEntered, "Tarot: REENTERED");
        _notEntered = false;
        _;
        _notEntered = true;
    }

    // update totalBalance with current balance
    modifier update() {
        _;
        _update();
    }
}

pragma solidity =0.5.16;


contract CStorage {
	address public borrowable0;
	address public borrowable1;
	address public tarotPriceOracle;
	uint public safetyMargin = 1.08e18; // safetyMargin: 108%
	uint public mTolerance = 1e8;
	uint public liquidationIncentive = 1.01e18; // 101%
	uint public liquidationFee = 0.005e18; // 0.5%
	
	function liquidationPenalty() public view returns (uint) {
		return liquidationIncentive + liquidationFee;
	}
}

pragma solidity =0.5.16;

import "./CStorage.sol";
import "./PoolToken.sol";
import "./interfaces/IFactory.sol";
import "./interfaces/ITarotSolidlyPriceOracleV2.sol";

contract CSetter is PoolToken, CStorage {
    uint256 public constant SAFETY_MARGIN_MIN = 1.00e18; //safetyMargin: 100%
    uint256 public constant SAFETY_MARGIN_MAX = 1.50e18; //safetyMargin: 150%
    uint256 public constant LIQUIDATION_INCENTIVE_MIN = 1.00e18; //100%
    uint256 public constant LIQUIDATION_INCENTIVE_MAX = 1.05e18; //105%
	uint256 public constant LIQUIDATION_FEE_MAX = 0.05e18; //5%
    uint256 public constant M_TOLERANCE_MIN = 1;
    uint256 public constant M_TOLERANCE_MAX = 1e12;

    event NewSafetyMargin(uint256 newSafetyMargin);
    event NewLiquidationIncentive(uint256 newLiquidationIncentive);
    event NewLiquidationFee(uint256 newLiquidationFee);
    event NewMTolerance(uint256 newMTolerance);

    // called once by the factory at the time of deployment
    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _borrowable0,
        address _borrowable1
    ) external {
        require(msg.sender == factory, "Tarot: UNAUTHORIZED"); // sufficient check
        _setName(_name, _symbol);
        underlying = _underlying;
        borrowable0 = _borrowable0;
        borrowable1 = _borrowable1;
        tarotPriceOracle = IFactory(factory).tarotPriceOracle();
    }

    function _setSafetyMargin(uint256 newSafetyMargin)
        external
        nonReentrant
    {
        _checkSetting(
            newSafetyMargin,
            SAFETY_MARGIN_MIN,
            SAFETY_MARGIN_MAX
        );
        safetyMargin = newSafetyMargin;
        emit NewSafetyMargin(newSafetyMargin);
    }

    function _setLiquidationIncentive(uint256 newLiquidationIncentive)
        external
        nonReentrant
    {
        _checkSetting(
            newLiquidationIncentive,
            LIQUIDATION_INCENTIVE_MIN,
            LIQUIDATION_INCENTIVE_MAX
        );
        liquidationIncentive = newLiquidationIncentive;
        emit NewLiquidationIncentive(newLiquidationIncentive);
    }

    function _setLiquidationFee(uint256 newLiquidationFee)
        external
        nonReentrant
    {
        _checkSetting(
            newLiquidationFee,
            0,
            LIQUIDATION_FEE_MAX
        );
        liquidationFee = newLiquidationFee;
        emit NewLiquidationFee(newLiquidationFee);
    }

    function _setMTolerance(uint256 newMTolerance)
        external
        nonReentrant
    {
        _checkSetting(
            newMTolerance,
            M_TOLERANCE_MIN,
            M_TOLERANCE_MAX
        );
        mTolerance = newMTolerance;
        emit NewMTolerance(newMTolerance);
    }

    function _checkSetting(
        uint256 parameter,
        uint256 min,
        uint256 max
    ) internal view {
        _checkAdmin();
        require(parameter >= min, "Tarot: INVALID_SETTING");
        require(parameter <= max, "Tarot: INVALID_SETTING");
    }

    function _checkAdmin() internal view {
        require(msg.sender == IFactory(factory).admin(), "Tarot: UNAUTHORIZED");
    }
}

pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}

pragma solidity >=0.5.0;

interface IBorrowable {
    /*** Tarot ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*** Pool Token ***/

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);

    function factory() external view returns (address);

    function totalBalance() external view returns (uint256);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function exchangeRate() external returns (uint256);

    function mint(address minter) external returns (uint256 mintTokens);

    function redeem(address redeemer) external returns (uint256 redeemAmount);

    function skim(address to) external;

    function sync() external;

    function _setFactory() external;

    /*** Borrowable ***/

    event BorrowApproval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Borrow(
        address indexed sender,
        address indexed borrower,
        address indexed receiver,
        uint256 borrowAmount,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );
    event Liquidate(
        address indexed sender,
        address indexed borrower,
        address indexed liquidator,
        uint256 seizeTokens,
        uint256 repayAmount,
        uint256 accountBorrowsPrior,
        uint256 accountBorrows,
        uint256 totalBorrows
    );

    function BORROW_FEE() external pure returns (uint256);

    function collateral() external view returns (address);

    function reserveFactor() external view returns (uint256);

    function exchangeRateLast() external view returns (uint256);

    function borrowIndex() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function borrowAllowance(address owner, address spender)
        external
        view
        returns (uint256);

    function borrowBalance(address borrower) external view returns (uint256);

    function borrowTracker() external view returns (address);

    function BORROW_PERMIT_TYPEHASH() external pure returns (bytes32);

    function borrowApprove(address spender, uint256 value)
        external
        returns (bool);

    function borrowPermit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function borrow(
        address borrower,
        address receiver,
        uint256 borrowAmount,
        bytes calldata data
    ) external;

    function liquidate(address borrower, address liquidator)
        external
        returns (uint256 seizeTokens);

    function trackBorrow(address borrower) external;

    /*** Borrowable Interest Rate Model ***/

    event AccrueInterest(
        uint256 interestAccumulated,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event CalculateKink(uint256 kinkRate);
    event CalculateBorrowRate(uint256 borrowRate);

    function KINK_BORROW_RATE_MAX() external pure returns (uint256);

    function KINK_BORROW_RATE_MIN() external pure returns (uint256);

    function KINK_MULTIPLIER() external pure returns (uint256);

    function borrowRate() external view returns (uint256);

    function kinkBorrowRate() external view returns (uint256);

    function kinkUtilizationRateLower() external view returns (uint256);

    function kinkUtilizationRateUpper() external view returns (uint256);

    function adjustSpeed() external view returns (uint256);

    function rateUpdateTimestamp() external view returns (uint32);

    function accrualTimestamp() external view returns (uint32);

    function accrueInterest() external;

    /*** Borrowable Setter ***/

    event NewReserveFactor(uint256 newReserveFactor);
    event NewKinkUtilizationRates(uint256 newKinkUtilizationRateLower, uint256 newKinkUtilizationRateUpper);
    event NewAdjustSpeed(uint256 newAdjustSpeed);
    event NewBorrowTracker(address newBorrowTracker);

    function RESERVE_FACTOR_MAX() external pure returns (uint256);

    function KINK_UR_MIN() external pure returns (uint256);

    function KINK_UR_MAX() external pure returns (uint256);

    function ADJUST_SPEED_MIN() external pure returns (uint256);

    function ADJUST_SPEED_MAX() external pure returns (uint256);

    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _collateral
    ) external;

    function _setReserveFactor(uint256 newReserveFactor) external;

    function _setKinkUtilizationRates(uint256 newKinkUtilizationRateLower, uint256 newKinkUtilizationRateUpper) external;

    function _setAdjustSpeed(uint256 newAdjustSpeed) external;

    function _setBorrowTracker(address newBorrowTracker) external;
}

pragma solidity >=0.5.0;

interface ICollateral {
    /*** Tarot ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*** Pool Token ***/

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);

    function factory() external view returns (address);

    function totalBalance() external view returns (uint256);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function exchangeRate() external returns (uint256);

    function mint(address minter) external returns (uint256 mintTokens);

    function redeem(address redeemer) external returns (uint256 redeemAmount);

    function skim(address to) external;

    function sync() external;

    function _setFactory() external;

    /*** Collateral ***/

    function borrowable0() external view returns (address);

    function borrowable1() external view returns (address);

    function tarotPriceOracle() external view returns (address);

    function safetyMargin() external view returns (uint256);

    function mTolerance() external view returns (uint256);

    function liquidationIncentive() external view returns (uint256);

    function liquidationFee() external view returns (uint256);

    function liquidationPenalty() external view returns (uint256);

    function getPrices() external returns (uint256 price0, uint256 price1);

    function getReserves() external returns (uint112 reserve0, uint112 reserve1);

    function tokensUnlocked(address from, uint256 value)
        external
        returns (bool);

    function accountLiquidityAmounts(
        address account,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 liquidity, uint256 shortfall);

    function accountLiquidity(address account)
        external
        returns (uint256 liquidity, uint256 shortfall);

    function canBorrow(
        address account,
        address borrowable,
        uint256 accountBorrows
    ) external returns (bool);

    function seize(
        address liquidator,
        address borrower,
        uint256 repayAmount
    ) external returns (uint256 seizeTokens);

    function flashRedeem(
        address redeemer,
        uint256 redeemAmount,
        bytes calldata data
    ) external;

    /*** Collateral Setter ***/

    event NewSafetyMargin(uint256 newSafetyMarginSqrt);
    event NewLiquidationIncentive(uint256 newLiquidationIncentive);
    event NewLiquidationFee(uint256 newLiquidationFee);
    event NewMTolerance(uint256 mTolerance);

    function M_TOLERANCE_MIN() external pure returns (uint256);
    
    function M_TOLERANCE_MAX() external pure returns (uint256);

    function SAFETY_MARGIN_MIN() external pure returns (uint256);

    function SAFETY_MARGIN_MAX() external pure returns (uint256);

    function LIQUIDATION_INCENTIVE_MIN() external pure returns (uint256);

    function LIQUIDATION_INCENTIVE_MAX() external pure returns (uint256);

    function LIQUIDATION_FEE_MAX() external pure returns (uint256);

    function _initialize(
        string calldata _name,
        string calldata _symbol,
        address _underlying,
        address _borrowable0,
        address _borrowable1
    ) external;

    function _setSafetyMargin(uint256 newSafetyMargin) external;

    function _setLiquidationIncentive(uint256 newLiquidationIncentive) external;

    function _setLiquidationFee(uint256 newLiquidationFee) external;
    
    function _setMTolerance(uint256 newMTolerance) external;

    function isUnderlyingVaultToken() external view returns (bool);
}

pragma solidity >=0.5.0;

interface IFactory {
	event LendingPoolInitialized(address indexed uniswapV2Pair, address indexed token0, address indexed token1,
		address collateral, address borrowable0, address borrowable1, uint lendingPoolId);
	event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
	event NewAdmin(address oldAdmin, address newAdmin);
	event NewReservesPendingAdmin(address oldReservesPendingAdmin, address newReservesPendingAdmin);
	event NewReservesAdmin(address oldReservesAdmin, address newReservesAdmin);
	event NewReservesManager(address oldReservesManager, address newReservesManager);
	
	function admin() external view returns (address);
	function pendingAdmin() external view returns (address);
	function reservesAdmin() external view returns (address);
	function reservesPendingAdmin() external view returns (address);
	function reservesManager() external view returns (address);

	function getLendingPool(address uniswapV2Pair) external view returns (
		bool initialized, 
		uint24 lendingPoolId, 
		address collateral, 
		address borrowable0, 
		address borrowable1
	);
	function allLendingPools(uint) external view returns (address uniswapV2Pair);
	function allLendingPoolsLength() external view returns (uint);
	
	function bDeployer() external view returns (address);
	function cDeployer() external view returns (address);
	function tarotPriceOracle() external view returns (address);

	function createCollateral(address uniswapV2Pair) external returns (address collateral);
	function createBorrowable0(address uniswapV2Pair) external returns (address borrowable0);
	function createBorrowable1(address uniswapV2Pair) external returns (address borrowable1);
	function initializeLendingPool(address uniswapV2Pair) external;

	function _setPendingAdmin(address newPendingAdmin) external;
	function _acceptAdmin() external;
	function _setReservesPendingAdmin(address newPendingAdmin) external;
	function _acceptReservesAdmin() external;
	function _setReservesManager(address newReservesManager) external;
}

pragma solidity >=0.5;

interface ITarotSolidlyPriceOracleV2 {
    function MIN_T() external pure returns (uint32);

    function getResult(address pair) external returns (uint112 reserve0, uint112 reserve1, uint32 T);
}

pragma solidity >=0.5.0;

interface ITarotCallee {
    function tarotBorrow(
        address sender,
        address borrower,
        uint256 borrowAmount,
        bytes calldata data
    ) external;

    function tarotRedeem(
        address sender,
        uint256 redeemAmount,
        bytes calldata data
    ) external;
}

pragma solidity >=0.5.0;

interface IBaseV1Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function stable() external view returns (bool);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
	
    function token0() external view returns (address);
    function token1() external view returns (address);
    function tokens() external view returns (address, address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function observationLength() external view returns (uint);
    function observations(uint) external view returns (
        uint timestamp,
        uint reserve0Cumulative,
        uint reserve1Cumulative
    );
    function currentCumulativePrices() external view returns (
        uint reserve0Cumulative,
        uint reserve1Cumulative,
        uint timestamp
    );

    function metadata() external view returns (uint, uint, uint, uint, bool, address, address);
}

pragma solidity >=0.5.0;

interface IVaultToken {

    function isVaultToken() external pure returns (bool);

    function getScale() external view returns (uint);
}

pragma solidity =0.5.16;

// a library for performing various math operations
// forked from: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/libraries/Math.sol

library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

pragma solidity =0.5.16;

import "./libraries/SafeMath.sol";

// This contract is basically UniswapV2ERC20 with small modifications
// src: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol

contract TarotERC20 {
    using SafeMath for uint256;

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    bytes32 public DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonces;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor() public {}

    function _setName(string memory _name, string memory _symbol) internal {
        name = _name;
        symbol = _symbol;
        uint256 chainId;
        assembly {
            chainId := chainid
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    function _mint(address to, uint256 value) internal {
        totalSupply = totalSupply.add(value);
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] = balanceOf[from].sub(value);
        totalSupply = totalSupply.sub(value);
        emit Transfer(from, address(0), value);
    }

    function _approve(
        address owner,
        address spender,
        uint256 value
    ) private {
        allowance[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    function _transfer(
        address from,
        address to,
        uint256 value
    ) internal {
        balanceOf[from] = balanceOf[from].sub(
            value,
            "Tarot: TRANSFER_TOO_HIGH"
        );
        balanceOf[to] = balanceOf[to].add(value);
        emit Transfer(from, to, value);
    }

    function approve(address spender, uint256 value) external returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] != uint256(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(
                value,
                "Tarot: TRANSFER_NOT_ALLOWED"
            );
        }
        _transfer(from, to, value);
        return true;
    }

    function _checkSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 typehash
    ) internal {
        require(deadline >= block.timestamp, "Tarot: EXPIRED");
        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            typehash,
                            owner,
                            spender,
                            value,
                            nonces[owner]++,
                            deadline
                        )
                    )
                )
            );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "Tarot: INVALID_SIGNATURE"
        );
    }

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _checkSignature(
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s,
            PERMIT_TYPEHASH
        );
        _approve(owner, spender, value);
    }
}

pragma solidity >=0.5.0;

interface IPoolToken {
    /*** Tarot ERC20 ***/

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint256);

    function balanceOf(address owner) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transfer(address to, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /*** Pool Token ***/

    event Mint(
        address indexed sender,
        address indexed minter,
        uint256 mintAmount,
        uint256 mintTokens
    );
    event Redeem(
        address indexed sender,
        address indexed redeemer,
        uint256 redeemAmount,
        uint256 redeemTokens
    );
    event Sync(uint256 totalBalance);

    function underlying() external view returns (address);

    function factory() external view returns (address);

    function totalBalance() external view returns (uint256);

    function MINIMUM_LIQUIDITY() external pure returns (uint256);

    function exchangeRate() external returns (uint256);

    function mint(address minter) external returns (uint256 mintTokens);

    function redeem(address redeemer) external returns (uint256 redeemAmount);

    function skim(address to) external;

    function sync() external;

    function _setFactory() external;
}

pragma solidity =0.5.16;

// From https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/Math.sol
// Subject to the MIT license.

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
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
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
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     * - Subtraction cannot underflow.
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
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
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}