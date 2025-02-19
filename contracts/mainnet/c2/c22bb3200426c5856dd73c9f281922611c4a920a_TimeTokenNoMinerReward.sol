// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title TIME Token contract
 * @notice Smart contract used for main interaction with the TIME tokenomics system
 **/
contract TimeTokenNoMinerReward is IERC20 {

    using Math for uint256;
    using SafeMath for uint256;

    event Mining(address indexed miner, uint256 amount, uint256 blockNumber);
    event Donation(address indexed donator, uint256 donatedAmount);

    bool private _isMintLocked = false;
    bool private _isOperationLocked;

    uint8 private constant _decimals = 18;

    address public constant DEVELOPER_ADDRESS = 0x731591207791A93fB0Ec481186fb086E16A7d6D0;

    uint256 private constant FACTOR = 10**18;
    uint256 private constant D = 10**_decimals;

    uint256 public constant BASE_FEE = 0.005 ether; // 10 ether; (Polygon) | 0.1 ether; (BSC) | 20 ether; (Fantom) | 0.01 ether; (Ethereum) | 30 ether; (Evmos)
    uint256 public constant COMISSION_RATE = 2;
    uint256 public constant SHARE_RATE = 4;
    uint256 public constant TIME_BASE_LIQUIDITY = 1_000_000 * D; // 200000 * D; (Polygon, Evmos and BSC) | 400000 * D; (Fantom) | 40000 * D; (Ethereum) | 2000000 * D; (Arbitrum)
    uint256 public constant TIME_BASE_FEE = 24_000_000 * D; // 4800000 * D; (Polygon, Evmos and BSC) | 9600000 * D; (Fantom) | 960000 * D; (Ethereum)
    uint256 public constant TOLERANCE = 10;

    uint256 private _totalSupply;
    uint256 public dividendPerToken;
    uint256 public firstBlock;
    uint256 public liquidityFactorNative = 11;
    uint256 public liquidityFactorTime = 20;
    uint256 public numberOfHolders;
    uint256 public numberOfMiners;
    uint256 public sharedBalance;
    uint256 public poolBalance;
    uint256 public totalMinted;

    string private _name;
    string private _symbol;

    mapping (address => bool) public isMiningAllowed;
    mapping (address => uint256) private _balances;
    mapping (address => uint256) private _consumedDividendPerToken;
    mapping (address => uint256) private _credits;
    mapping (address => uint256) private _lastBalances;
    mapping (address => uint256) private _lastBlockMined;
    mapping (address => mapping (address => uint256)) private _allowances;

    constructor(
        string memory name_,
        string memory symbol_
    ) {
        _name = name_;
        _symbol = symbol_;
        firstBlock = block.number;
    }

    modifier nonReentrant() {
	    require(!_isOperationLocked, "TIME: This operation is locked for security reasons");
		_isOperationLocked = true;
		_;
		_isOperationLocked = false;
	}

    receive() external payable {
        saveTime();
    }

    fallback() external payable {
        require(msg.data.length == 0);
        saveTime();
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
      	return _symbol;
    }

    function decimals() public pure returns (uint8) {
      	return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external override view returns (uint256) {
        return _balances[account];
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool success) {
        if (to == address(this))
            success = spendTime(amount);
        else
            success = _transfer(msg.sender, to, amount);
		return success;
    }

    function allowance(address owner, address spender) external override view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
		_approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
		return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool success) {
		success = _transfer(from, to, amount);
		_approve(from, msg.sender, _allowances[from][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
		return success;
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        if (_balances[to] > 0 && to != address(0) && to != address(this) && _lastBalances[to] != _balances[to] && _lastBalances[to] == 0)
            numberOfHolders++;

        if (_balances[from] == 0 && from != address(0) && to != address(this) && _lastBalances[from] != _balances[from])
            numberOfHolders--;

        _lastBalances[from] = _balances[from];
        _lastBalances[to] = _balances[to];    
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        _credit(from);
        _credit(to);
        _lastBalances[from] = _balances[from];
        _lastBalances[to] = _balances[to];
    }

    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

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

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        totalMinted += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual returns (bool) {
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

        return true;
    }

    /**
     * @notice Calculate the amount some address has to claim and credit for it
     * @param account The account address
     **/
    function _credit(address account) private {
        _credits[account] += accountShareBalance(account);
        _consumedDividendPerToken[account] = dividendPerToken;
    }

    /**
     *  @notice Obtain the aproximate amount of blocks needed to drain the whole internal LP (considering the current TIME mining rate)
     **/
    function _getAmountOfBlocksToDrainLP(bool isFeeInTime) private view returns (uint256) {
        if (averageMiningRate() == 0) {
            if (isFeeInTime)
                return TIME_BASE_FEE;
            else
                return TIME_BASE_LIQUIDITY;
        } else {
            return _balances[address(this)].mulDiv(D, averageMiningRate());
        }
    }

    /**
     * @notice Called when an investor wants to exchange ETH for TIME. A comission in ETH is paid to miner (block.coinbase) and developer
     * @param comissionAmount The amount in ETH which will be paid (two times)
    **/
    function _payComission(uint256 comissionAmount) private {
        payable(DEVELOPER_ADDRESS).transfer(comissionAmount * 2);
        sharedBalance += comissionAmount;
        dividendPerToken += comissionAmount.mulDiv(FACTOR, (_totalSupply - _balances[address(this)] + 1));
        _updatePoolBalance();
    }

    /**
     * @notice Updates the state of the internal pool balance
     *
     */
    function _updatePoolBalance() private {
        poolBalance = address(this).balance > sharedBalance ? address(this).balance - sharedBalance : 0;
    }    

    /**
     * @notice Called when an investor wants to exchange TIME for ETH. A comission in TIME token is paid to miner (block.coinbase) and developer
     * @param comissionAmount The amount in TIME tokens which will be paid (two times)
     **/
    function _payComissionInTime(uint256 comissionAmount) private {
        _transfer(msg.sender, DEVELOPER_ADDRESS, comissionAmount * 2);
        _burn(msg.sender, comissionAmount);
    }

    /**
     * @notice Returns the average rate of TIME tokens mined per block (mining rate)
     **/
    function averageMiningRate() public view returns (uint256) {
        if (totalMinted > TIME_BASE_LIQUIDITY) 
            return ((totalMinted - TIME_BASE_LIQUIDITY) / (block.number - firstBlock));
        else
            return 0;
    }

    /**
     *  @notice Just verify if the msg.value has any ETH value for donation
     **/
    function donateEth() public payable nonReentrant {
        require(msg.value > 0, "TIME: please specify any amount you would like to donate");
        emit Donation(msg.sender, msg.value);
        uint256 remaining = msg.value;
        uint256 totalComission = msg.value.mulDiv(COMISSION_RATE, 100);
        uint256 comission = totalComission / SHARE_RATE;
        _payComission(comission);
        remaining -= totalComission;
        sharedBalance += (remaining / 2);
        dividendPerToken += (remaining / 2).mulDiv(FACTOR, (_totalSupply - _balances[address(this)] + 1));
        _updatePoolBalance();
    }

    /** 
     * @notice An address call this function to be able to mine TIME by paying with ETH (native cryptocurrency)
     * @dev An additional amount of TIME should be created for the AMM address to provide initial liquidity if the contract does not have any miners enabled
    **/
    function enableMining() public payable nonReentrant {
        uint256 f = fee();
        uint256 tolerance;
        if (msg.value < f) {
            tolerance = f.mulDiv(TOLERANCE, 100);
            require(msg.value >= (f - tolerance), "TIME: to enable mining for an address you need at least the fee() amount in native currency");
        }
        require(!isMiningAllowed[msg.sender], "TIME: the address is already enabled");
        uint256 remaining = msg.value;
        isMiningAllowed[msg.sender] = true;
        _lastBlockMined[msg.sender] = block.number;
        if (numberOfMiners == 0)
            _mint(address(this), TIME_BASE_LIQUIDITY);
        
        uint256 totalComission = remaining.mulDiv(COMISSION_RATE, 100);
        uint256 comission = totalComission / SHARE_RATE;
        _payComission(comission);
        remaining -= totalComission;
        sharedBalance += (remaining / 2);
        dividendPerToken += (remaining / 2).mulDiv(FACTOR, (_totalSupply - _balances[address(this)] + 1));
        if (numberOfMiners == 0) {
            sharedBalance = 0;
            dividendPerToken = 0;
        }
        _updatePoolBalance();
        numberOfMiners++;
    }

    /**
     * @notice An address call this function to be able to mine TIME with its earned (or bought) TIME tokens
     **/
    function enableMiningWithTimeToken() public nonReentrant {
        uint256 f = feeInTime();
        require(_balances[msg.sender] >= f, "TIME: to enable mining for an address you need at least the feeInTime() amount in TIME tokens");
        require(!isMiningAllowed[msg.sender], "TIME: the address is already enabled");
        _burn(msg.sender, f);
        isMiningAllowed[msg.sender] = true;
        _lastBlockMined[msg.sender] = block.number;
        numberOfMiners++;
    }

    /**
     * @notice Query the fee amount needed, in ETH, to enable an address for mining TIME
     * @dev Function has now dynamic fee calculation. Fee should not be so expensive and not cheap at the same time
     * @return Fee amount (in native cryptocurrency)
     **/
    function fee() public view returns (uint256) {
        return BASE_FEE.mulDiv(TIME_BASE_LIQUIDITY, _getAmountOfBlocksToDrainLP(false)) / (numberOfMiners + 1);
    }

    /**
     * @notice Query the fee amount needed, in TIME, to enable an address for mining TIME
     * @dev Function has now dynamic fee calculation. Fee should not be so expensive and not cheap at the same time
     * @return Fee amount (in TIME Tokens)
     **/
    function feeInTime() public view returns (uint256) {
        return TIME_BASE_FEE.mulDiv(TIME_BASE_FEE, _getAmountOfBlocksToDrainLP(true));
    }

    /**
     * @notice An allowed address call this function in order to mint TIME tokens according to the number of blocks which has passed since it has enabled mining
     **/
    function mining() public nonReentrant {
        if (isMiningAllowed[msg.sender]) {
            uint256 miningAmount = (block.number - _lastBlockMined[msg.sender]).mulDiv(D, 1);
            _mint(msg.sender, miningAmount);
            _lastBlockMined[msg.sender] = block.number;
            emit Mining(msg.sender, miningAmount, block.number);
        }
    }

    /**
     * @notice Investor send native cryptocurrency in exchange for TIME tokens. Here, he sends some amount and the contract calculates the equivalent amount in TIME units
     * @dev msg.value - The amount of TIME in terms of ETH an investor wants to 'save'
     **/
    function saveTime() public payable nonReentrant returns (bool success) {
        if (msg.value > 0) {
            uint256 totalComission = msg.value.mulDiv(COMISSION_RATE, 100);
            uint256 comission = totalComission / SHARE_RATE;
            uint256 nativeAmountTimeValue = msg.value.mulDiv(swapPriceNative(msg.value), FACTOR);
            require(nativeAmountTimeValue <= _balances[address(this)], "TIME: the pool does not have a sufficient amount to trade");
            _payComission(comission);
            success = _transfer(address(this), msg.sender, nativeAmountTimeValue - (nativeAmountTimeValue.mulDiv(COMISSION_RATE, 100) / SHARE_RATE));
            _updatePoolBalance();
            liquidityFactorNative = liquidityFactorNative < 20 ? liquidityFactorNative + 1 : liquidityFactorNative;
            liquidityFactorTime = liquidityFactorTime > 11 ? liquidityFactorTime - 1 : liquidityFactorTime;
        }
        return success;
    }

    /**
     * @notice Investor send TIME tokens in exchange for native cryptocurrency
     * @param timeAmount The amount of TIME tokens for exchange
     **/
    function spendTime(uint256 timeAmount) public nonReentrant returns (bool success) {
        require(_balances[msg.sender] >= timeAmount, "TIME: there is no enough time to spend");
        uint256 comission = timeAmount.mulDiv(COMISSION_RATE, 100) / SHARE_RATE;
        uint256 timeAmountNativeValue = timeAmount.mulDiv(swapPriceTimeInverse(timeAmount), FACTOR);
        require(timeAmountNativeValue <= poolBalance, "TIME: the pool does not have a sufficient amount to trade");
        _payComissionInTime(comission);
        timeAmount -= comission.mulDiv(3, 1);
        success = _transfer(msg.sender, address(this), timeAmount);
        payable(msg.sender).transfer(timeAmountNativeValue - (timeAmountNativeValue.mulDiv(COMISSION_RATE, 100) / SHARE_RATE));
        _updatePoolBalance();
        liquidityFactorTime = liquidityFactorTime < 20 ? liquidityFactorTime + 1 : liquidityFactorTime;
        liquidityFactorNative = liquidityFactorNative > 11 ? liquidityFactorNative - 1 : liquidityFactorNative;
        return success;
    }

    /**
     * @notice Query for market price before swap, in TIME/ETH, in terms of native cryptocurrency (ETH)
     * @dev Constant Function Market Maker
     * @param amountNative The amount of ETH a user wants to exchange
     * @return Local market price, in TIME/ETH, given the amount of ETH a user informed
     **/
    function swapPriceNative(uint256 amountNative) public view returns (uint256) {
        if (poolBalance > 0 && _balances[address(this)] > 0) {
            uint256 ratio = poolBalance.mulDiv(FACTOR, (amountNative + 1));
            uint256 deltaSupply = (_balances[address(this)].mulDiv(amountNative, 1)).mulDiv(ratio, poolBalance + amountNative.mulDiv(liquidityFactorNative, 10));
            return (deltaSupply / poolBalance);
        } else {
            return 1;
        }
    }

    /**
     * @notice Query for market price before swap, in ETH/TIME, in terms of ETH currency
     * @param amountTime The amount of TIME a user wants to exchange
     * @return Local market price, in ETH/TIME, given the amount of TIME a user informed
     **/
    function swapPriceTimeInverse(uint256 amountTime) public view returns (uint256) {
        if (poolBalance > 0 && _balances[address(this)] > 0) {
            uint256 ratio = _balances[address(this)].mulDiv(FACTOR, (amountTime + 1));
            uint256 deltaBalance = (poolBalance.mulDiv(amountTime, 1)).mulDiv(ratio, _balances[address(this)] + amountTime.mulDiv(liquidityFactorTime, 10));
            return (deltaBalance / _balances[address(this)]);      
        } else {
            return 1;
        }
    }

    /**
     * @notice Show the amount in ETH an account address can credit to itself
     * @param account The address of some account
     * @return The claimable amount in ETH
     **/
    function accountShareBalance(address account) public view returns (uint256) {
        return _balances[account].mulDiv(dividendPerToken - _consumedDividendPerToken[account], FACTOR);
    }

    /**
     * @notice Show the amount in ETH an account address can withdraw to itself
     * @param account The address of some account
     * @return The withdrawable amount in ETH
     **/
    function withdrawableShareBalance(address account) public view returns (uint256) {
        return (accountShareBalance(account) + _credits[account]);
    }

    /**
     * @notice Withdraw the available amount returned by the accountShareBalance(address account) function
     **/
    function withdrawShare() public nonReentrant {
        uint256 withdrawableAmount = accountShareBalance(msg.sender);
        withdrawableAmount += _credits[msg.sender];
        require(withdrawableAmount > 0, "TIME: you don't have any amount to withdraw");
        require(withdrawableAmount <= sharedBalance, "TIME: there is no enough balance to share");
        _credits[msg.sender] = 0;
        _consumedDividendPerToken[msg.sender] = dividendPerToken;
        sharedBalance -= withdrawableAmount;
        payable(msg.sender).transfer(withdrawableAmount);
        _updatePoolBalance();
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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. It the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`.
        // We also know that `k`, the position of the most significant bit, is such that `msb(a) = 2**k`.
        // This gives `2**k < a <= 2**(k+1)` → `2**(k/2) <= sqrt(a) < 2 ** (k/2+1)`.
        // Using an algorithm similar to the msb conmputation, we are able to compute `result = 2**(k/2)` which is a
        // good first aproximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1;
        uint256 x = a;
        if (x >> 128 > 0) {
            x >>= 128;
            result <<= 64;
        }
        if (x >> 64 > 0) {
            x >>= 64;
            result <<= 32;
        }
        if (x >> 32 > 0) {
            x >>= 32;
            result <<= 16;
        }
        if (x >> 16 > 0) {
            x >>= 16;
            result <<= 8;
        }
        if (x >> 8 > 0) {
            x >>= 8;
            result <<= 4;
        }
        if (x >> 4 > 0) {
            x >>= 4;
            result <<= 2;
        }
        if (x >> 2 > 0) {
            result <<= 1;
        }

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        uint256 result = sqrt(a);
        if (rounding == Rounding.Up && result * result < a) {
            result += 1;
        }
        return result;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

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
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
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