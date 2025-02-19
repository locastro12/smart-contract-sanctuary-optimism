// Copyright 2022 Binary Cat Ltd.

// SPDX-License-Identifier: Apache-2.0
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./BetLibrary.sol";
import "./BinToken.sol";
import "./BinaryStaking.sol";

contract Flip {
    int256 public PRECISION_CONSTANT = 1e27;
    //Other contracts interactions
    AggregatorV3Interface internal priceFeed1;
    AggregatorV3Interface internal priceFeed2;
    BinToken immutable token;
    BinaryStaking immutable staking;
    address payable immutable stakingAddress;

    //Betting variables
    uint256 public immutable REWARD_PER_WINDOW;
    mapping(uint256 => BetLibrary.Pool) public pools; //windowNumber => Pool
    uint256 public immutable fee;
    uint256 public immutable deployTimestamp;
    mapping(address => BetLibrary.User) user;


    //Window management
    uint256 public immutable windowDuration; //in epoch timestamp
    mapping(uint256 => uint256) public windowPrice; /*first price collection
                                                      at the window.
                                                     */
    //EVENTS
    event NewBet(
        address indexed user,
        uint256 indexed windowNumber,
        uint256 value,
        uint8 side
    );
    event BetSettled(
        uint256 indexed windowNumber,
        address indexed user,
        uint256 gain
    );
    event PriceUpdated(uint256 indexed windowNumber, uint256 price);

    constructor(
        uint256 _windowDuration, 
        uint256 _fee,
        address aggregator1,
        address aggregator2,
        address stakingContract,
        address tokenContract,
        uint256 reward
    ) {
        require(_fee <= 100);
        priceFeed1 = AggregatorV3Interface(aggregator1);
        priceFeed2 = AggregatorV3Interface(aggregator2);
        deployTimestamp = block.timestamp;
        windowDuration = _windowDuration;

        fee = _fee;

        stakingAddress = payable(stakingContract);
        staking = BinaryStaking(stakingAddress);
        token = BinToken(tokenContract);

        REWARD_PER_WINDOW = reward * 1e18;
    }

    function placeBet(uint8 side) external payable {
        require(msg.value > 0, "Only strictly positive values");
        updatePrice();
        updateBalance(msg.sender);

        uint256 windowNumber = BetLibrary.getWindowNumber(
            block.timestamp,
            windowDuration,
            deployTimestamp
        );

        BetLibrary.User storage sender = user[msg.sender];
        if (sender.bets.length == 0 ||
            windowNumber != sender.bets[sender.bets.length - 1]) {
            /*
               Only adds to the list if its the first user bet on the window.
               If length is zero, the code only evaluates the first condition,
               avoiding the possible underflow length - 1.
            */
            sender.bets.push(windowNumber);
        }

        //Update the user stake and pool for the window.
        if (BetLibrary.BetSide(side) == BetLibrary.BetSide.up) {
            sender.stake[windowNumber].upValue += msg.value;
            pools[windowNumber].upValue += msg.value;
        }
        else {
            sender.stake[windowNumber].downValue += msg.value;
            pools[windowNumber].downValue += msg.value;
        }

        emit NewBet(msg.sender, windowNumber, msg.value, side);
    }

    function updateBalance(address _user) public {
        BetLibrary.User storage userData = user[_user];
        if (userData.bets.length == 0) {
            //No bets to settle
            return;
        }

        uint256 totalGain = 0;
        uint256 totalRewards = 0;
        uint256 accumulatedFees = 0;
        for (uint256 i = userData.bets.length; i > 0; i--) {
            /*Maximum number of itens in list is 2, when the user bets
              on 2 subsequent windows and the first window is not yet settled.
            */
            uint256 window = userData.bets[i - 1];
            uint256 currentWindow = BetLibrary.getWindowNumber(
                block.timestamp,
                windowDuration,
                deployTimestamp
            );
            (
                uint256 referencePrice,
                uint256 settlementPrice
            ) = getWindowBetPrices(window);

            BetLibrary.WindowStatus status = BetLibrary.windowStatus(
                window,
                currentWindow,
                referencePrice,
                settlementPrice
            );
            if (
                status == BetLibrary.WindowStatus.notFinalized ||
                status == BetLibrary.WindowStatus.waitingPrice
            ) {
                continue;
            }

            uint8 result;
            if (status == BetLibrary.WindowStatus.finalized) {
                result = BetLibrary.betResultBinary(referencePrice, settlementPrice);
            } else if (status == BetLibrary.WindowStatus.failedUpdate) {
                result = 2;
            }

            //Remove window from list of unsettled bets.
            userData.bets[i - 1] = userData.bets[
                userData.bets.length - 1
            ];
            userData.bets.pop();

            BetLibrary.Pool memory stake = userData.stake[window];
            BetLibrary.Pool memory pool = pools[window];
            (uint256 windowGain, uint256 fees) = settleBet(
                stake.upValue,
                stake.downValue,
                pool.upValue,
                pool.downValue,
                result
            );

            totalGain += windowGain;
            accumulatedFees += fees;

            //KITTY token rewards
            totalRewards += calculateTokenReward(
                stake.upValue,
                stake.downValue,
                pool.upValue,
                pool.downValue
            );

            emit BetSettled(window, _user, windowGain);
        }

        if (totalGain > 0) {
            payable(_user).transfer(totalGain);
        }

        if (totalRewards > 0) {
            transferRewards(_user, totalRewards);
        }

        if (accumulatedFees > 0) {
            staking.receiveFunds{value: accumulatedFees}();
        }
    }


    function transferRewards(address user, uint256 amount) internal {
        if (token.balanceOf(address(this)) >= amount) {
            token.transfer(user, amount);
        } else {
            token.transfer(user, token.balanceOf(address(this)));
        }
    }

    function settleBet(
        uint256 upStake,
        uint256 downStake,
        uint256 poolUp,
        uint256 poolDown,
        uint8 res
    ) public view returns (uint256 gain, uint256 fees) {
        BetLibrary.BetResult result = BetLibrary.BetResult(res);
        uint256 poolTotal = poolUp + poolDown;
        uint256 value;
        if (result == BetLibrary.BetResult.up && poolUp != 0) {
            //(upStake/poolUp)*poolTotal
            value = BetLibrary.sharePool(poolTotal, upStake, poolUp);
            fees = BetLibrary.computeFee(value, fee);
            gain = value - fees;
        } else if (result == BetLibrary.BetResult.down && poolDown != 0) {
            //(downStake/poolDown)*poolTotal
            value = BetLibrary.sharePool(poolTotal, downStake, poolDown);
            fees = BetLibrary.computeFee(value, fee);
            gain = value - fees;
        } else if (result == BetLibrary.BetResult.tie) {
            gain = upStake + downStake;
        } else {
            //If the winning pool is empty, all stake goes to the fees.
            gain = 0;
            fees = upStake + downStake;
        }
    }

    function calculateTokenReward(
        uint256 upStake,
        uint256 downStake,
        uint256 poolUp,
        uint256 poolDown
    ) public view returns (uint256) {
        return
            BetLibrary.sharePool(
                REWARD_PER_WINDOW,
                upStake + downStake,
                poolUp + poolDown
            );
    }


    function updatePrice() public {
        uint256 window = BetLibrary.getWindowNumber(
            block.timestamp,
            windowDuration,
            deployTimestamp
        );
        if (windowPrice[window] == 0) {
            windowPrice[window] = priceOracle();
            emit PriceUpdated(window, windowPrice[window]);
        }
    }

    function priceOracle() internal view returns (uint256) {
        (, int256 price1, , , ) = priceFeed1.latestRoundData();
        (, int256 price2, , , ) = priceFeed2.latestRoundData();
        return uint256(price1 * PRECISION_CONSTANT / price2);
    }

    //Getters
    function getPoolValues(uint256 windowNumber)
        public
        view
        returns (uint256, uint256)
    {
        BetLibrary.Pool memory pool = pools[windowNumber];
        return (pool.downValue, pool.upValue);
    }

    function getUserStake(uint256 windowNumber, address _user)
        public
        view
        returns (uint256, uint256)
    {
        BetLibrary.Pool memory stake = user[_user].stake[windowNumber];
        return (stake.downValue, stake.upValue);
    }

    function getWindowBetPrices(uint256 window)
        public
        view
        returns (uint256, uint256)
    {
        return (windowPrice[window + 1], windowPrice[window + 2]);
    }

    function getUserBetList(address _user, uint256 index)
        public
        view
        returns (uint256)
    {
        return user[_user].bets[index];
    }

    function betListLen(address _user) public view returns (uint256) {
        return user[_user].bets.length;
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
pragma solidity ^0.8.0;

interface AggregatorV3Interface {

  function decimals()
    external
    view
    returns (
      uint8
    );

  function description()
    external
    view
    returns (
      string memory
    );

  function version()
    external
    view
    returns (
      uint256
    );

  // getRoundData and latestRoundData should both raise "No data present"
  // if they do not have data to report, instead of returning unset values
  // which could be misinterpreted as actual reported values.
  function getRoundData(
    uint80 _roundId
  )
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

}

// Copyright 2021 Binary Cat Ltd.

// SPDX-License-Identifier: Apache-2.0
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

pragma solidity ^0.8.0;

library BetLibrary {
    //Structs and enums
    enum BetSide {
        down,
        up
    }
    enum BetResult {
        down,
        up,
        tie
    }
    enum WindowStatus {
        notFinalized,
        waitingPrice,
        failedUpdate,
        finalized
    }

    struct Pool {
        uint256 downValue;
        uint256 upValue;
    }

    struct User {
        mapping(uint256 => Pool) stake;
        uint256[] bets;
    }



    function windowStatus(
        uint256 window,
        uint256 currentWindow,
        uint256 initialPrice,
        uint256 finalPrice
    ) public pure returns (WindowStatus status) {
        if (currentWindow < window + 2) {
            //window not yet settled
            return WindowStatus.notFinalized;
        } else if (currentWindow < window + 3 && finalPrice == 0) {
            //price not updated but update still possible.
            return WindowStatus.waitingPrice;
        } else if (initialPrice == 0 || finalPrice == 0) {
            return WindowStatus.failedUpdate;
        } else {
            return WindowStatus.finalized;
        }
    }

    function betResultBinary(uint256 referencePrice, uint256 settlementPrice)
        public
        pure
        returns (uint8)
    {
        if (settlementPrice < referencePrice) {
            return 0;
        } else if (settlementPrice > referencePrice) {
            return 1;
        }
        return 2;
    }

    function sharePool(
        uint256 value,
        uint256 shares,
        uint256 totalShares
    ) internal pure returns (uint256) {
        return (shares * value) / totalShares;
    }


    function getWindowNumber(
        uint256 currentTimestamp,
        uint256 _windowDuration,
        uint256 _deployTimestamp
    ) public pure returns (uint256 windowNumber) {
        //n = floor((currentTimestamp - deployTimestamp)/windowDuration  + 1)
        windowNumber =
            ((currentTimestamp - _deployTimestamp) / _windowDuration)
            + 1; //integer division => floor
    }

    function getWindowStartingTimestamp(
        uint256 windowNumber,
        uint256 _windowDuration,
        uint256 _deployTimestamp
    ) public pure returns (uint256 startingTimestamp) {
        //deployTimestamp + (n-1 - (offset + 1))*windowDuration
        startingTimestamp =
            _deployTimestamp +
            (windowNumber - 1) *
            _deployTimestamp;
    }

    function computeFee(uint256 value, uint256 _fee)
        public
        pure
        returns (uint256 betFee)
    {
        betFee = (value * _fee) / 100;
    }

    function computeFeeCapped(uint256 value, uint256 _fee, uint cap)
        public
        pure
        returns (uint256 betFee)
    {
        if ( (value * _fee) / 100 < cap) {
            betFee = (value * _fee) / 100;
        }
        else {
            betFee = cap;
        }
    }
}

// Copyright 2021 Binary Cat Ltd.

// SPDX-License-Identifier: Apache-2.0
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract BinToken is ERC20 {
    //using SafeMath for uint256;

    string public constant NAME = "KITTY";
    string public constant SYMBOL = "KITTY";
    uint8 public constant DECIMALS = 18;
    uint256 public constant INITIAL_SUPPLY =
        100000000 * (10**uint256(DECIMALS));
    uint256 public constant IDO_SUPPLY =
        12500000 * (10**uint256(DECIMALS));

    mapping(address => mapping(address => uint256)) allowed;

    constructor(address ido) ERC20(NAME, SYMBOL) {
        _mint(ido, IDO_SUPPLY);
        _mint(msg.sender, INITIAL_SUPPLY - IDO_SUPPLY);
    }
}

// Copyright 2021 Binary Cat Ltd.

// SPDX-License-Identifier: Apache-2.0
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use
// this file except in compliance with the License. You may obtain a copy of the
// License at http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software distributed
// under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./BinToken.sol";

contract BinaryStaking is ERC20 {
    string public constant NAME = "Staked KITTY";
    string public constant SYMBOL = "sKITTY";
    uint8 public constant DECIMALS = 18;

    IERC20 public binToken;

    uint256 internal constant PRECISION_CONSTANT = 1e27;
    address payable owner;

    mapping(address => uint256) public valueWhenLastReleased;
    uint256 public accumulatedRewards; //(per staked token)

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Release(address indexed user, uint256 amount);
    event Reward(uint256 amount);

    constructor(address token) ERC20(NAME, SYMBOL){
        owner = payable(msg.sender);
        binToken = BinToken(token);
    }

    function receiveFunds() public payable {
        uint256 value = msg.value;
        if (totalSupply() != 0) {
            accumulatedRewards =
                accumulatedRewards +
                (value * PRECISION_CONSTANT) /
                totalSupply();
        } else {
            owner.transfer(value);
        }
        emit Reward(value);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "Amount should be greater than 0");
        release(msg.sender);
        require(binToken.transferFrom(msg.sender, address(this), amount));
        _mint(msg.sender, amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "Amount should be greater than 0");
        require(
            amount <= balanceOf(msg.sender),
            "Cannot unstake more than balance"
        );

        release(msg.sender);
        _burn(msg.sender, amount);

        binToken.transfer(msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function release(address user) public {
        if (accumulatedRewards == 0) {
            return;
        }
        uint256 amount = ownedDividends(user);
        valueWhenLastReleased[user] = accumulatedRewards;

        if (amount > 0) {
            payable(user).transfer(amount);
            emit Release(user, amount);
        }
    }

    function ownedDividends(address user) public view returns (uint256) {
        return
            (balanceOf(user) *
                (accumulatedRewards - valueWhenLastReleased[user])) /
            PRECISION_CONSTANT;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal virtual override 
    {
        super._beforeTokenTransfer(from, to, amount);
        release(from);
        release(to);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

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
        _approve(owner, spender, allowance(owner, spender) + addedValue);
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
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
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
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
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