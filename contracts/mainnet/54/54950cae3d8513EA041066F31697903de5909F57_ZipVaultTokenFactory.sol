pragma solidity =0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./ZipVaultToken.sol";
import "./interfaces/IZipRewards.sol";
import "./interfaces/IZipVaultTokenFactory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";

contract ZipVaultTokenFactory is Ownable, IZipVaultTokenFactory {
    address public optiSwap;
    address public rewarderHelper;
    address public router;
    address public masterChef;
    address public rewardsToken;
    uint256 public swapFeeFactor;

    mapping(uint256 => address) public getVaultToken;
    address[] public allVaultTokens;

    event VaultTokenCreated(
        uint256 indexed pid,
        address vaultToken,
        uint256 vaultTokenIndex
    );

    constructor(
        address _optiSwap,
        address _rewarderHelper,
        address _router,
        address _masterChef,
        address _rewardsToken,
        uint256 _swapFeeFactor
    ) public {
        require(
            _swapFeeFactor >= 900 && _swapFeeFactor <= 1000,
            "VaultTokenFactory: INVALID_FEE_FACTOR"
        );
        optiSwap = _optiSwap;
        rewarderHelper = _rewarderHelper;
        router = _router;
        masterChef = _masterChef;
        rewardsToken = _rewardsToken;
        swapFeeFactor = _swapFeeFactor;
    }

    function allVaultTokensLength() external view returns (uint256) {
        return allVaultTokens.length;
    }

    function createVaultToken(uint256 pid)
        external
        returns (address vaultToken)
    {
        require(
            getVaultToken[pid] == address(0),
            "VaultTokenFactory: PID_EXISTS"
        );
        bytes memory bytecode = type(ZipVaultToken).creationCode;
        assembly {
            vaultToken := create2(0, add(bytecode, 32), mload(bytecode), pid)
        }
        ZipVaultToken(vaultToken)._initialize(
            optiSwap,
            rewarderHelper,
            IUniswapV2Router01(router),
            IZipRewards(masterChef),
            rewardsToken,
            swapFeeFactor,
            pid
        );
        getVaultToken[pid] = vaultToken;
        allVaultTokens.push(vaultToken);
        emit VaultTokenCreated(pid, vaultToken, allVaultTokens.length);
    }
}

pragma solidity ^0.5.0;

import "../GSN/Context.sol";
/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
contract Ownable is Context {
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
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(isOwner(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Returns true if the caller is the current owner.
     */
    function isOwner() public view returns (bool) {
        return _msgSender() == _owner;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     */
    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

pragma solidity =0.5.16;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./PoolToken.sol";
import "./interfaces/IZipRewards.sol";
import "./interfaces/IZipVaultToken.sol";
import "./interfaces/IOptiSwap.sol";
import "./interfaces/IRewarderHelper.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./libraries/SafeToken.sol";
import "./libraries/Math.sol";

interface OptiSwapPair {
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

contract ZipVaultToken is IZipVaultToken, IUniswapV2Pair, PoolToken {
    using SafeToken for address;

    bool public constant isVaultToken = true;

    address public optiSwap;
    address public rewarderHelper;
    IUniswapV2Router01 public router;
    IZipRewards public masterChef;
    address public rewardsToken;
    address public WETH;
    address public token0;
    address public token1;
    uint256 public swapFeeFactor;
    uint256 public pid;
    uint256 public constant MIN_REINVEST_BOUNTY = 0.001e18;
    uint256 public constant MAX_REINVEST_BOUNTY = 0.01e18;
    uint256 public REINVEST_BOUNTY = MAX_REINVEST_BOUNTY;

    event ReinvestRewardToken(address indexed caller, address rewardToken, uint256 reward, uint256 bounty);
    event UpdateReinvestBounty(uint256 _newReinvestBounty);

    function _initialize(
        address _optiSwap,
        address _rewarderHelper,
        IUniswapV2Router01 _router,
        IZipRewards _masterChef,
        address _rewardsToken,
        uint256 _swapFeeFactor,
        uint256 _pid
    ) external {
        require(factory == address(0), "VaultToken: FACTORY_ALREADY_SET"); // sufficient check
        optiSwap = _optiSwap;
        rewarderHelper = _rewarderHelper;
        factory = msg.sender;
        _setName("Tarot Vault Token", "vTAROT");
        WETH = _router.WETH();
        router = _router;
        masterChef = _masterChef;
        swapFeeFactor = _swapFeeFactor;
        pid = _pid;
        underlying = masterChef.lpToken(_pid);
        token0 = IUniswapV2Pair(underlying).token0();
        token1 = IUniswapV2Pair(underlying).token1();
        rewardsToken = _rewardsToken;
        rewardsToken.safeApprove(address(router), uint256(-1));
        WETH.safeApprove(address(router), uint256(-1));
        underlying.safeApprove(address(masterChef), uint256(-1));
    }

    function updateReinvestBounty(uint256 _newReinvestBounty) external onlyFactoryOwner {
        require(_newReinvestBounty >= MIN_REINVEST_BOUNTY && _newReinvestBounty <= MAX_REINVEST_BOUNTY, "VaultToken: INVLD_REINVEST_BOUNTY");
        REINVEST_BOUNTY = _newReinvestBounty;

        emit UpdateReinvestBounty(_newReinvestBounty);
    }

    function getRewardTokenInfo()
        public
        view
        returns (
            address[] memory rewardTokens,
            uint256[] memory pendingAmounts,
            uint256[] memory rewardRates
        ) {
            address rewarder = masterChef.rewarder(pid);
            if (rewarder != address(0)) {
                return IRewarderHelper(rewarderHelper).getRewardTokenInfo(rewarder, address(this));
            }
        }

    function getRewardTokenInfoWithBalances()
        public
        view
        returns (
            address[] memory rewardTokens,
            uint256[] memory pendingAmounts,
            uint256[] memory rewardRates,
            uint256[] memory balances
        ) {
            address rewarder = masterChef.rewarder(pid);
            if (rewarder != address(0)) {
                (rewardTokens, pendingAmounts, rewardRates) = IRewarderHelper(rewarderHelper).getRewardTokenInfo(rewarder, address(this));
                balances = new uint256[](rewardTokens.length);
                for (uint256 i = 0; i < rewardTokens.length; i++) {
                    balances[i] = rewardTokens[i].myBalance();
                }
            }
        }

    /*** PoolToken Overrides ***/

    function _update() internal {
        (uint256 _totalBalance, ) = masterChef.userInfo(pid, address(this));
        totalBalance = _totalBalance;
        emit Sync(totalBalance);
    }

    // this low-level function should be called from another contract
    function mint(address minter)
        external
        nonReentrant
        update
        returns (uint256 mintTokens)
    {
        uint256 mintAmount = underlying.myBalance();
        // handle pools with deposit fees by checking balance before and after deposit
        (uint256 _totalBalanceBefore, ) = masterChef.userInfo(
            pid,
            address(this)
        );
        masterChef.depositShort(pid, uint128(mintAmount));
        (uint256 _totalBalanceAfter, ) = masterChef.userInfo(
            pid,
            address(this)
        );

        mintTokens = _totalBalanceAfter.sub(_totalBalanceBefore).mul(1e18).div(
            exchangeRate()
        );

        if (totalSupply == 0) {
            // permanently lock the first MINIMUM_LIQUIDITY tokens
            mintTokens = mintTokens.sub(MINIMUM_LIQUIDITY);
            _mint(address(0), MINIMUM_LIQUIDITY);
        }
        require(mintTokens > 0, "VaultToken: MINT_AMOUNT_ZERO");
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

        require(redeemAmount > 0, "VaultToken: REDEEM_AMOUNT_ZERO");
        require(redeemAmount <= totalBalance, "VaultToken: INSUFFICIENT_CASH");
        _burn(address(this), redeemTokens);
        masterChef.withdrawShort(pid, uint128(redeemAmount));
        _safeTransfer(redeemer, redeemAmount);
        emit Redeem(msg.sender, redeemer, redeemAmount, redeemTokens);
    }

    /*** Reinvest ***/

    function _optimalDepositA(
        uint256 _amountA,
        uint256 _reserveA,
        uint256 _swapFeeFactor
    ) internal pure returns (uint256) {
        uint256 a = uint256(1000).add(_swapFeeFactor).mul(_reserveA);
        uint256 b = _amountA.mul(1000).mul(_reserveA).mul(4).mul(
            _swapFeeFactor
        );
        uint256 c = Math.sqrt(a.mul(a).add(b));
        uint256 d = uint256(2).mul(_swapFeeFactor);
        return c.sub(a).div(d);
    }

    function approveRouter(address token, uint256 amount) internal {
        if (IERC20(token).allowance(address(this), address(router)) >= amount)
            return;
        token.safeApprove(address(router), uint256(-1));
    }

    function swapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amount
    ) internal {
        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);
        approveRouter(tokenIn, amount);
        router.swapExactTokensForTokens(amount, 0, path, address(this), now);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    ) internal returns (uint256 liquidity) {
        approveRouter(tokenA, amountA);
        approveRouter(tokenB, amountB);
        (, , liquidity) = router.addLiquidity(
            tokenA,
            tokenB,
            amountA,
            amountB,
            0,
            0,
            address(this),
            now
        );
    }

    function swapTokensForBestAmountOut(
        IOptiSwap _optiSwap,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        if (tokenIn == tokenOut) {
            return amountIn;
        }
        address pair;
        (pair, amountOut) = _optiSwap.getBestAmountOut(amountIn, tokenIn, tokenOut);
        require(pair != address(0), "NO_PAIR");
        tokenIn.safeTransfer(pair, amountIn);
        if (tokenIn < tokenOut) {
            OptiSwapPair(pair).swap(0, amountOut, address(this), new bytes(0));
        } else {
            OptiSwapPair(pair).swap(amountOut, 0, address(this), new bytes(0));
        }
    }

    function optiSwapExactTokensForTokens(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        if (tokenIn == tokenOut) {
            return amountIn;
        }
        IOptiSwap _optiSwap = IOptiSwap(optiSwap);
        address nextHop = _optiSwap.getBridgeToken(tokenIn);
        if (nextHop == tokenOut) {
            return swapTokensForBestAmountOut(_optiSwap, tokenIn, tokenOut, amountIn);
        }
        address waypoint = _optiSwap.getBridgeToken(tokenOut);
        if (tokenIn == waypoint) {
            return swapTokensForBestAmountOut(_optiSwap, tokenIn, tokenOut, amountIn);
        }
        uint256 hopAmountOut;
        if (nextHop != tokenIn) {
            hopAmountOut = swapTokensForBestAmountOut(_optiSwap, tokenIn, nextHop, amountIn);
        } else {
            hopAmountOut = amountIn;
        }
        if (nextHop == waypoint) {
            return swapTokensForBestAmountOut(_optiSwap, nextHop, tokenOut, hopAmountOut);
        } else if (waypoint == tokenOut) {
            return optiSwapExactTokensForTokens(nextHop, tokenOut, hopAmountOut);
        } else {
            uint256 waypointAmountOut = optiSwapExactTokensForTokens(nextHop, waypoint, hopAmountOut);
            return swapTokensForBestAmountOut(_optiSwap, waypoint, tokenOut, waypointAmountOut);
        }
    }

    function reinvest() external nonReentrant update {
        require(msg.sender == tx.origin);
        // 1. Withdraw all the rewards.
        masterChef.harvestShort(pid);

        uint256 liquidity = reinvestOne(rewardsToken);
        (address[] memory rewardTokens, ,) = getRewardTokenInfo();
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            liquidity += reinvestOne(rewardTokens[i]);
        }

        // 5. Stake the LP Tokens.
        masterChef.depositShort(pid, uint128(liquidity));
    }

    function reinvestOne(address _rewardToken) internal returns (uint256 liquidity) {
        uint256 reward = _rewardToken.myBalance();
        if (reward == 0) return 0;
        // 2. Send the reward bounty to the caller.
        uint256 bounty = reward.mul(REINVEST_BOUNTY) / 1e18;
        _rewardToken.safeTransfer(msg.sender, bounty);
        // 3. Convert all the remaining rewards to token0 or token1.
        address tokenA;
        address tokenB;
        if (token0 == _rewardToken || token1 == _rewardToken) {
            (tokenA, tokenB) = token0 == _rewardToken
                ? (token0, token1)
                : (token1, token0);
        } else {
            if (token1 == WETH) {
                (tokenA, tokenB) = (token1, token0);
            } else {
                (tokenA, tokenB) = (token0, token1);
            }
            optiSwapExactTokensForTokens(_rewardToken, tokenA, reward.sub(bounty));
        }
        // 4. Convert tokenA to LP Token underlyings.
        uint256 totalAmountA = tokenA.myBalance();
        assert(totalAmountA > 0);
        (uint256 r0, uint256 r1, ) = IUniswapV2Pair(underlying).getReserves();
        uint256 reserveA = tokenA == token0 ? r0 : r1;
        uint256 swapAmount = _optimalDepositA(
            totalAmountA,
            reserveA,
            swapFeeFactor
        );
        uint256 balanceBeforeB = tokenB.myBalance();
        swapExactTokensForTokens(tokenA, tokenB, swapAmount);
        uint256 balanceAfterB = tokenB.myBalance();
        uint256 deltaB = balanceAfterB.sub(balanceBeforeB);
        liquidity = addLiquidity(
            tokenA,
            tokenB,
            totalAmountA.sub(swapAmount),
            deltaB
        );
        emit ReinvestRewardToken(msg.sender, _rewardToken, reward, bounty);
    }

    /*** Mirrored From uniswapV2Pair ***/

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        )
    {
        (reserve0, reserve1, blockTimestampLast) = IUniswapV2Pair(underlying)
        .getReserves();
        // if no token has been minted yet mirror uniswap getReserves
        if (totalSupply == 0) return (reserve0, reserve1, blockTimestampLast);
        // else, return the underlying reserves of this contract
        uint256 _totalBalance = totalBalance;
        uint256 _totalSupply = IUniswapV2Pair(underlying).totalSupply();
        reserve0 = safe112(_totalBalance.mul(reserve0).div(_totalSupply));
        reserve1 = safe112(_totalBalance.mul(reserve1).div(_totalSupply));
        require(
            reserve0 > 100 && reserve1 > 100,
            "VaultToken: INSUFFICIENT_RESERVES"
        );
    }

    function price0CumulativeLast() external view returns (uint256) {
        return IUniswapV2Pair(underlying).price0CumulativeLast();
    }

    function price1CumulativeLast() external view returns (uint256) {
        return IUniswapV2Pair(underlying).price1CumulativeLast();
    }

    /*** Utilities ***/

    function safe112(uint256 n) internal pure returns (uint112) {
        require(n < 2**112, "VaultToken: SAFE112");
        return uint112(n);
    }

    /*** Modifiers ***/

    modifier onlyFactoryOwner() {
        require(Ownable(factory).owner() == msg.sender, "NOT_AUTHORIZED");
        _;
    }
}

pragma solidity 0.5.16;

contract IZipRewards {
    struct UserInfo {
        uint128 amount;
        int128 rewardDebt;
    }

    struct PoolInfo {
        uint256 accZipPerShare;
        uint64 lastRewardTime;
        uint64 allocPoint;
    }

    // Info of each user that stakes LP tokens.
    mapping(uint256 => PoolInfo) public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    function depositShort(uint256 _pid, uint128 _amount) external {}

    function withdrawShort(uint256 _pid, uint128 _amount) external {}

    function harvestShort(uint256 _pid) external returns (uint) {}

    function rewarder(uint256 pid) external view returns (address);

    function lpToken(uint256 pid) external view returns (address);
}

pragma solidity >=0.5.0;

interface IZipVaultTokenFactory {
    event VaultTokenCreated(
        uint256 indexed pid,
        address vaultToken,
        uint256 vaultTokenIndex
    );

    function optiSwap() external view returns (address);

    function rewarderHelper() external view returns (address);

    function router() external view returns (address);

    function masterChef() external view returns (address);

    function rewardsToken() external view returns (address);

    function swapFeeFactor() external view returns (uint256);

    function getVaultToken(uint256) external view returns (address);

    function allVaultTokens(uint256) external view returns (address);

    function allVaultTokensLength() external view returns (uint256);

    function createVaultToken(uint256 pid)
        external
        returns (address vaultToken);
}

pragma solidity >=0.5.0;

interface IUniswapV2Pair {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

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

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);
}

pragma solidity >=0.5.0;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);

    function getAmountsIn(uint256 amountOut, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

pragma solidity ^0.5.0;

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
contract Context {
    // Empty internal constructor, to prevent people from mistakenly deploying
    // an instance of this contract, which should be used via inheritance.
    constructor () internal { }
    // solhint-disable-previous-line no-empty-blocks

    function _msgSender() internal view returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
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

    function exchangeRate() public view returns (uint256) {
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
        (bool success, bytes memory data) = underlying.call(
            abi.encodeWithSelector(SELECTOR, to, amount)
        );
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

pragma solidity >=0.5.0;

import "./IZipRewards.sol";
import "./IUniswapV2Router01.sol";

interface IZipVaultToken {
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

    function exchangeRate() external view returns (uint256);

    function mint(address minter) external returns (uint256 mintTokens);

    function redeem(address redeemer) external returns (uint256 redeemAmount);

    function skim(address to) external;

    function sync() external;

    function _setFactory() external;

    /*** VaultToken ***/

    event Reinvest(address indexed caller, uint256 reward, uint256 bounty);

    function isVaultToken() external pure returns (bool);

    function router() external view returns (IUniswapV2Router01);

    function masterChef() external view returns (IZipRewards);

    function rewardsToken() external view returns (address);

    function WETH() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function swapFeeFactor() external view returns (uint256);

    function pid() external view returns (uint256);

    function REINVEST_BOUNTY() external pure returns (uint256);

    function getReserves()
        external
        view
        returns (
            uint112 reserve0,
            uint112 reserve1,
            uint32 blockTimestampLast
        );

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function _initialize(
        address _optiSwap,
        address _rewarderHelper,
        IUniswapV2Router01 _router,
        IZipRewards _masterChef,
        address _rewardsToken,
        uint256 _swapFeeFactor,
        uint256 _pid
    ) external;

    function reinvest() external;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IOptiSwap {
    function weth() external view returns (address);

    function bridgeFromTokens(uint256 index) external view returns (address token);

    function bridgeFromTokensLength() external view returns (uint256);

    function getBridgeToken(address _token) external view returns (address bridgeToken);

    function addBridgeToken(address _token, address _bridgeToken) external;

    function getDexInfo(uint256 index) external view returns (address dex, address handler);

    function dexListLength() external view returns (uint256);

    function indexOfDex(address _dex) external view returns (uint256);

    function getDexEnabled(address _dex) external view returns (bool);

    function addDex(address _dex, address _handler) external;

    function removeDex(address _dex) external;

    function getBestAmountOut(
        uint256 _amountIn,
        address _tokenIn,
        address _tokenOut
    ) external view returns (address pair, uint256 amountOut);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0;

interface IRewarderHelper {
    function getRewardTokenInfo(address _rewarder, address _vaultToken)
        external
        view
        returns (
            address[] memory rewardTokens,
            uint256[] memory pendingAmounts,
            uint256[] memory rewardRates
        );
}

pragma solidity >=0.5.0;

interface IERC20 {
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event Transfer(address indexed from, address indexed to, uint256 value);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

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
}

pragma solidity 0.5.16;

interface ERC20Interface {
    function balanceOf(address user) external view returns (uint256);
}

library SafeToken {
    function myBalance(address token) internal view returns (uint256) {
        return ERC20Interface(token).balanceOf(address(this));
    }

    function balanceOf(address token, address user)
        internal
        view
        returns (uint256)
    {
        return ERC20Interface(token).balanceOf(user);
    }

    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x095ea7b3, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeApprove"
        );
    }

    function safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeTransfer"
        );
    }

    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "!safeTransferFrom"
        );
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call.value(value)(new bytes(0));
        require(success, "!safeTransferETH");
    }
}

pragma solidity =0.5.16;

// a library for performing various math operations
// forked from: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/libraries/Math.sol

library Math {
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
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
        bytes32 digest = keccak256(
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

    function exchangeRate() external view returns (uint256);

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
    function add(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mul(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
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
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}