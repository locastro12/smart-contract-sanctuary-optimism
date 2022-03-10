// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IOwnable {
  function manager() external view returns (address);

  function renounceManagement() external;

  function pushManagement(address newOwner_) external;

  function pullManagement() external;
}

contract Ownable is IOwnable {
  address internal _owner;
  address internal _newOwner;

  event OwnershipPushed(
    address indexed previousOwner,
    address indexed newOwner
  );
  event OwnershipPulled(
    address indexed previousOwner,
    address indexed newOwner
  );

  constructor() {
    _owner = msg.sender;
    emit OwnershipPushed(address(0), _owner);
  }

  function manager() public view override returns (address) {
    return _owner;
  }

  modifier onlyManager() {
    require(_owner == msg.sender, "Ownable: caller is not the owner");
    _;
  }

  function renounceManagement() public virtual override onlyManager {
    emit OwnershipPushed(_owner, address(0));
    _owner = address(0);
  }

  function pushManagement(address newOwner_)
    public
    virtual
    override
    onlyManager
  {
    require(newOwner_ != address(0), "Ownable: new owner is the zero address");
    emit OwnershipPushed(_owner, newOwner_);
    _newOwner = newOwner_;
  }

  function pullManagement() public virtual override {
    require(msg.sender == _newOwner, "Ownable: must be new owner to pull");
    emit OwnershipPulled(_owner, _newOwner);
    _owner = _newOwner;
  }
}

interface IERC20Mintable {
  function mint(uint256 amount_) external;

  function mint(address account_, uint256 ammount_) external;
}

interface IPEGAERC20 {
  function burnFrom(address account_, uint256 amount_) external;

  function decimals() external view returns (uint8);
}

interface IBondCalculator {
  function valuation(address pair_, uint256 amount_)
    external
    view
    returns (uint256 _value);
}

interface ILiquidityPool {
  function poolBalance() external view returns (uint256 _value);

  function liquidityToken() external view returns (address _liquidityToken);
}

interface INFT {
  function totalPegaValue() external view returns (uint256);
}

contract PegasusTreasury is Ownable {
  /* ========== DEPENDENCIES ========== */

  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  /* ========== EVENTS ========== */

  event Deposit(address indexed token, uint256 amount, uint256 value);
  event DepositReserve(address indexed token, uint256 amount, uint256 value);
  event Withdrawal(address indexed token, uint256 amount, uint256 value);
  event CreateDebt(
    address indexed debtor,
    address indexed token,
    uint256 amount,
    uint256 value
  );
  event RepayDebt(
    address indexed debtor,
    address indexed token,
    uint256 amount,
    uint256 value
  );
  event ReservesManaged(address indexed token, uint256 amount);
  event ReservesUpdated(uint256 indexed totalReserves);
  event ReservesAudited(uint256 indexed totalReserves);
  event RewardsMinted(
    address indexed caller,
    address indexed recipient,
    uint256 amount
  );
  event ChangeQueued(MANAGING indexed managing, address queued);
  event ChangeActivated(
    MANAGING indexed managing,
    address activated,
    bool result
  );
  /* ========== DATA STRUCTURES ========== */

  enum MANAGING {
    RESERVEDEPOSITOR,
    RESERVESPENDER,
    RESERVETOKEN,
    RESERVEMANAGER,
    LIQUIDITYDEPOSITOR,
    LIQUIDITYTOKEN,
    LIQUIDITYMANAGER,
    DEBTOR,
    REWARDMANAGER,
    RESERVERATIO
  }
  /* ========== STATE VARIABLES ========== */

  address public immutable PEGA;
  address public immutable PegapalNFT;
  uint256 public timeNeededForQueue;
  address public liquidityPool;

  address[] public reserveTokens; // Push only, beware false-positives.
  mapping(address => bool) public isReserveToken;
  mapping(address => uint256) public reserveBackingRatio; // Adjustable ratio for a reserve token
  mapping(address => uint256) public reserveTokenQueue; // Delays changes to mapping.

  address[] public reserveDepositors; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isReserveDepositor;
  mapping(address => uint256) public reserveDepositorQueue; // Delays changes to mapping.

  address[] public reserveSpenders; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isReserveSpender;
  mapping(address => uint256) public reserveSpenderQueue; // Delays changes to mapping.

  address[] public liquidityTokens; // Push only, beware false-positives.
  mapping(address => bool) public isLiquidityToken;
  mapping(address => uint256) public LiquidityTokenQueue; // Delays changes to mapping.

  address[] public liquidityDepositors; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isLiquidityDepositor;
  mapping(address => uint256) public LiquidityDepositorQueue; // Delays changes to mapping.

  mapping(address => address) public bondCalculator; // bond calculator for liquidity token

  address[] public reserveManagers; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isReserveManager;
  mapping(address => uint256) public ReserveManagerQueue; // Delays changes to mapping.

  address[] public liquidityManagers; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isLiquidityManager;
  mapping(address => uint256) public LiquidityManagerQueue; // Delays changes to mapping.

  address[] public debtors; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isDebtor;
  mapping(address => uint256) public debtorQueue; // Delays changes to mapping.
  mapping(address => uint256) public debtorBalance;

  address[] public rewardManagers; // Push only, beware false-positives. Only for viewing.
  mapping(address => bool) public isRewardManager;
  mapping(address => uint256) public rewardManagerQueue; // Delays changes to mapping.

  uint256 public totalReserves; // Risk-free value of all assets
  uint256 public totalDebt;
  uint256 public ethPegaRatio;

  /* ========== CONSTRUCTOR ========== */

  constructor(
    address _PEGA,
    address _WETH,
    address _pegapalNFT,
    uint256 _initialReserveRatio,
    uint256 _timeNeededForQueue
  ) {
    require(_PEGA != address(0), "Pegasus Token address is null");
    require(_pegapalNFT != address(0), "NFT address is null");

    PEGA = _PEGA;
    PegapalNFT = _pegapalNFT;

    isReserveToken[_WETH] = true;
    reserveTokens.push(_WETH);
    reserveBackingRatio[_WETH] = _initialReserveRatio;

    timeNeededForQueue = _timeNeededForQueue;
  }

  /* ========== MUTATIVE FUNCTIONS ========== */

  /**
        @notice allow approved address to deposit an asset as reserves
        @param _amount uint
        @param _token address
     */
  function depositReserves(uint256 _amount, address _token) external {
    require(isReserveToken[_token], "Not accepted");
    require(isReserveDepositor[msg.sender], "Not approved");

    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    uint256 value = valueOfToken(_token, _amount);

    totalReserves = totalReserves.add(value);
    emit ReservesUpdated(totalReserves);

    emit DepositReserve(_token, _amount, value);
  }

  /**
        @notice allow approved address to deposit an asset for FUEL
        @param _amount uint
        @param _token address
        @param _profit uint
        @return send_ uint
     */
  function deposit(
    uint256 _amount,
    address _token,
    uint256 _profit
  ) external returns (uint256 send_) {
    require(isReserveToken[_token] || isLiquidityToken[_token], "Not accepted");
    IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);

    if (isReserveToken[_token]) {
      require(isReserveDepositor[msg.sender], "Not approved");
    } else {
      require(isLiquidityDepositor[msg.sender], "Not approved");
    }

    uint256 value = valueOfToken(_token, _amount);
    (_token, _amount);
    // mint FUEL needed and store amount of rewards for distribution
    send_ = value.sub(_profit);
    IERC20Mintable(PEGA).mint(msg.sender, send_);

    totalReserves = totalReserves.add(value);
    emit ReservesUpdated(totalReserves);

    emit Deposit(_token, _amount, value);
  }

  /**
        @notice allow approved address to burn FUEL for reserves
        @param _amount uint
        @param _token address
     */
  function withdraw(uint256 _amount, address _token) external {
    require(isReserveToken[_token], "Not accepted"); // Only reserves can be used for redemptions
    require(isReserveSpender[msg.sender] == true, "Not approved");

    uint256 value = valueOfToken(_token, _amount);
    IPEGAERC20(PEGA).burnFrom(msg.sender, value);

    totalReserves = totalReserves.sub(value);
    emit ReservesUpdated(totalReserves);

    IERC20(_token).safeTransfer(msg.sender, _amount);

    emit Withdrawal(_token, _amount, value);
  }

  /**
        @notice allow approved address to withdraw assets
        @param _token address
        @param _amount uint
     */
  function manage(address _token, uint256 _amount) external {
    if (isLiquidityToken[_token]) {
      require(isLiquidityManager[msg.sender], "Not approved");
    } else {
      require(isReserveManager[msg.sender], "Not approved");
    }

    uint256 value = valueOfToken(_token, _amount);
    require(value <= excessReserves(), "Insufficient reserves");

    totalReserves = totalReserves.sub(value);
    emit ReservesUpdated(totalReserves);

    IERC20(_token).safeTransfer(msg.sender, _amount);

    emit ReservesManaged(_token, _amount);
  }

  /**
        @notice send epoch reward to staking contract
     */
  function mintRewards(address _recipient, uint256 _amount) external {
    require(isRewardManager[msg.sender], "Not approved");
    require(_amount <= excessReserves(), "Insufficient reserves");
    IERC20Mintable(PEGA).mint(_recipient, _amount);
    emit RewardsMinted(msg.sender, _recipient, _amount / 10**9);
  }

  /**
        @notice returns excess reserves not backing $Pega Tokens
        @return uint
     */
  function excessReserves() public view returns (uint256) {
    // Total minted $PEGA
    uint256 totalSupply = IERC20(PEGA).totalSupply().add(totalDebt).add(
      INFT(PegapalNFT).totalPegaValue()
    );

    // Balance in Liquidity Pool
    uint256 liquidityPoolReserves = 0;
    if (liquidityPool != address(0)) {
      uint256 liquidityPoolBalance = ILiquidityPool(liquidityPool)
        .poolBalance();
      address liquidityTokenAddress = ILiquidityPool(liquidityPool)
        .liquidityToken();
      liquidityPoolReserves = valueOfToken(
        liquidityTokenAddress,
        liquidityPoolBalance
      );
    }
    uint256 netReserves = totalReserves.add(liquidityPoolReserves);
    return netReserves.sub(totalSupply);
  }

  /**
        @notice takes inventory of all tracked assets
        @notice always consolidate to recognized reserves before audit
     */
  function auditReserves() public onlyManager {
    uint256 reserves;
    for (uint256 i = 0; i < reserveTokens.length; i++) {
      reserves = reserves.add(
        valueOfToken(
          reserveTokens[i],
          IERC20(reserveTokens[i]).balanceOf(address(this))
        )
      );
    }
    for (uint256 i = 0; i < liquidityTokens.length; i++) {
      reserves = reserves.add(
        valueOfToken(
          liquidityTokens[i],
          IERC20(liquidityTokens[i]).balanceOf(address(this))
        )
      );
    }
    totalReserves = reserves;
    emit ReservesUpdated(reserves);
    emit ReservesAudited(reserves);
  }

  /**
        @notice returns Pega valuation of asset
        @param _token address
        @param _amount uint
        @return value_ uint
     */
  function valueOfToken(address _token, uint256 _amount)
    public
    view
    returns (uint256 value_)
  {
    if (isReserveToken[_token]) {
      // ie 0.00001 Eth = 1 Pega Token; 100 Pega Token = 1 NFT; 1 NFT = .001 Eth
      uint256 ratioAdjustedAmount = reserveBackingRatio[_token].mul(_amount);
      value_ = ratioAdjustedAmount.mul(10**IPEGAERC20(PEGA).decimals()).div(
        10**IPEGAERC20(_token).decimals()
      );
    } else if (isLiquidityToken[_token]) {
      value_ = IBondCalculator(bondCalculator[_token]).valuation(
        _token,
        _amount
      );
    }
  }

  /* ========== MANAGERIAL FUNCTIONS ========== */

  /**
        @notice queue address to change boolean in mapping
        @param _managing MANAGING
        @param _address address
        @return bool
     */
  function queue(MANAGING _managing, address _address)
    external
    onlyManager
    returns (bool)
  {
    require(_address != address(0));
    if (_managing == MANAGING.RESERVEDEPOSITOR) {
      // 0
      reserveDepositorQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.RESERVESPENDER) {
      // 1
      reserveSpenderQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.RESERVETOKEN) {
      // 2
      reserveTokenQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.RESERVEMANAGER) {
      // 3
      ReserveManagerQueue[_address] = block.timestamp.add(
        timeNeededForQueue.mul(2)
      );
    } else if (_managing == MANAGING.LIQUIDITYDEPOSITOR) {
      // 4
      LiquidityDepositorQueue[_address] = block.timestamp.add(
        timeNeededForQueue
      );
    } else if (_managing == MANAGING.LIQUIDITYTOKEN) {
      // 5
      LiquidityTokenQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.LIQUIDITYMANAGER) {
      // 6
      LiquidityManagerQueue[_address] = block.timestamp.add(
        timeNeededForQueue.mul(2)
      );
    } else if (_managing == MANAGING.DEBTOR) {
      // 7
      debtorQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.REWARDMANAGER) {
      // 8
      rewardManagerQueue[_address] = block.timestamp.add(timeNeededForQueue);
    } else if (_managing == MANAGING.RESERVERATIO) {
      // 9
    } else return false;

    emit ChangeQueued(_managing, _address);
    return true;
  }

  /**
        @notice verify queue then set boolean in mapping
        @param _managing MANAGING
        @param _address address
        @param _calculator address
        @return bool
     */
  function toggle(
    MANAGING _managing,
    address _address,
    address _calculator
  ) external onlyManager returns (bool) {
    require(_address != address(0));
    bool result;
    if (_managing == MANAGING.RESERVEDEPOSITOR) {
      // 0
      if (requirements(reserveDepositorQueue, isReserveDepositor, _address)) {
        reserveDepositorQueue[_address] = 0;
        if (!listContains(reserveDepositors, _address)) {
          reserveDepositors.push(_address);
        }
      }
      result = !isReserveDepositor[_address];
      isReserveDepositor[_address] = result;
    } else if (_managing == MANAGING.RESERVESPENDER) {
      // 1
      if (requirements(reserveSpenderQueue, isReserveSpender, _address)) {
        reserveSpenderQueue[_address] = 0;
        if (!listContains(reserveSpenders, _address)) {
          reserveSpenders.push(_address);
        }
      }
      result = !isReserveSpender[_address];
      isReserveSpender[_address] = result;
    } else if (_managing == MANAGING.RESERVETOKEN) {
      // 2
      if (requirements(reserveTokenQueue, isReserveToken, _address)) {
        reserveTokenQueue[_address] = 0;
        if (!listContains(reserveTokens, _address)) {
          reserveTokens.push(_address);
        }
      }
      result = !isReserveToken[_address];
      isReserveToken[_address] = result;
    } else if (_managing == MANAGING.RESERVEMANAGER) {
      // 3
      if (requirements(ReserveManagerQueue, isReserveManager, _address)) {
        reserveManagers.push(_address);
        ReserveManagerQueue[_address] = 0;
        if (!listContains(reserveManagers, _address)) {
          reserveManagers.push(_address);
        }
      }
      result = !isReserveManager[_address];
      isReserveManager[_address] = result;
    } else if (_managing == MANAGING.LIQUIDITYDEPOSITOR) {
      // 4
      if (
        requirements(LiquidityDepositorQueue, isLiquidityDepositor, _address)
      ) {
        liquidityDepositors.push(_address);
        LiquidityDepositorQueue[_address] = 0;
        if (!listContains(liquidityDepositors, _address)) {
          liquidityDepositors.push(_address);
        }
      }
      result = !isLiquidityDepositor[_address];
      isLiquidityDepositor[_address] = result;
    } else if (_managing == MANAGING.LIQUIDITYTOKEN) {
      // 5
      if (requirements(LiquidityTokenQueue, isLiquidityToken, _address)) {
        LiquidityTokenQueue[_address] = 0;
        if (!listContains(liquidityTokens, _address)) {
          liquidityTokens.push(_address);
        }
      }
      result = !isLiquidityToken[_address];
      isLiquidityToken[_address] = result;
      bondCalculator[_address] = _calculator;
    } else if (_managing == MANAGING.LIQUIDITYMANAGER) {
      // 6
      if (requirements(LiquidityManagerQueue, isLiquidityManager, _address)) {
        LiquidityManagerQueue[_address] = 0;
        if (!listContains(liquidityManagers, _address)) {
          liquidityManagers.push(_address);
        }
      }
      result = !isLiquidityManager[_address];
      isLiquidityManager[_address] = result;
    } else if (_managing == MANAGING.DEBTOR) {
      // 7
      if (requirements(debtorQueue, isDebtor, _address)) {
        debtorQueue[_address] = 0;
        if (!listContains(debtors, _address)) {
          debtors.push(_address);
        }
      }
      result = !isDebtor[_address];
      isDebtor[_address] = result;
    } else if (_managing == MANAGING.REWARDMANAGER) {
      // 8
      if (requirements(rewardManagerQueue, isRewardManager, _address)) {
        rewardManagerQueue[_address] = 0;
        if (!listContains(rewardManagers, _address)) {
          rewardManagers.push(_address);
        }
      }
      result = !isRewardManager[_address];
      isRewardManager[_address] = result;
    } else if (_managing == MANAGING.RESERVERATIO) {} else return false;

    emit ChangeActivated(_managing, _address, result);
    return true;
  }

  /**
        @notice Updates the Reserve Ratio for an asset
        @param _reserveAddress address
        @param _ratio uint256
     */
  function updateReserveRatio(address _reserveAddress, uint256 _ratio)
    external
    onlyManager
  {
    require(_ratio > 0, "Ratio cannot be 0");
    reserveBackingRatio[_reserveAddress] = _ratio;
    auditReserves();
  }

  /**
        @notice Updates the liquidity pool address for the perpetual
        @param _liquidityPool address
     */
  function setLiquidityPool(address _liquidityPool) external onlyManager {
    liquidityPool = _liquidityPool;
  }

  function setQueueTimeLock(uint256 newTimestamp) external onlyManager {
    timeNeededForQueue = newTimestamp;
  }

  /**
        @notice checks requirements and returns altered structs
        @param queue_ mapping( address => uint )
        @param status_ mapping( address => bool )
        @param _address address
        @return bool 
     */
  function requirements(
    mapping(address => uint256) storage queue_,
    mapping(address => bool) storage status_,
    address _address
  ) internal view returns (bool) {
    if (!status_[_address]) {
      require(queue_[_address] != 0, "Must queue");
      require(queue_[_address] <= block.timestamp, "Queue not expired");
      return true;
    }
    return false;
  }

  /**
        @notice checks array to ensure against duplicate
        @param _list address[]
        @param _token address
        @return bool
     */
  function listContains(address[] storage _list, address _token)
    internal
    view
    returns (bool)
  {
    for (uint256 i = 0; i < _list.length; i++) {
      if (_list[i] == _token) {
        return true;
      }
    }
    return false;
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