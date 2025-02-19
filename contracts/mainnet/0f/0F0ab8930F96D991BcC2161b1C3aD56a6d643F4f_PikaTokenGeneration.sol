pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import  "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/// @title Pika token generation contract(adapted from Jones Dao token generation contract)
/// Whitelist Phase 1: whitelist address can get Pika with fixed price with a maximum ETH size that is same for each whitelist addresses
/// Whitelist Phase 2: whitelist address can get Pika with fixed price with a remaining maximum ETH size allocated for each address(subtract amount in phase 1.1)
/// (example: whitelist address A has 3 eth allocation for whitelist phase, and for the first 30 mins,
/// each whitelist address can contribute 1 eth maximum, so A can contribute 1 eth in the first 30 mins, and 2 eth after 30 mins and before whitelist phase ends)
/// Public Phase: any address can contribute any amount of ETH. The final price of the phase is decided by
/// (total ETH contributed for this phase / total Pika tokens for this phase)
contract PikaTokenGeneration is ReentrancyGuard {
    using SafeMath for uint256;
    using Math for uint256;
    using SafeERC20 for IERC20;

    // Pika Token
    IERC20 public pika;
    // Withdrawer
    address public owner;
    // Keeps track of ETH deposited during whitelist phase
    uint256 public weiDepositedWhitelist;
    // Keeps track of ETH deposited
    uint256 public weiDeposited;
    // Time when the whitelist phase 1 starts for whitelisted address with limited cap
    uint256 public saleWhitelistStart;
    // Time when the whitelist phase 2 starts for whitelisted address with unlimited cap(still limited by individual cap)
    uint256 public saleWhitelist2Start;
    // Time when the token sale starts
    uint256 public saleStart;
    // Time when the token sale closes
    uint256 public saleClose;
    // Max cap on wei raised during whitelist
    uint256 public maxDepositsWhitelist;
    // Max cap on wei raised
    uint256 public maxDepositsTotal;
    // Pika Tokens allocated to this contract
    uint256 public pikaTokensAllocated;
    // Pika Tokens allocated to whitelist
    uint256 public pikaTokensAllocatedWhitelist;
    // Max deposit that can be done for each address before saleWhitelist2Start
    uint256 public whitelistDepositLimit;
    // Max ETH that can be deposited by tier 1 whitelist address for entire whitelist phase
    uint256 public whitelistMaxDeposit1;
    // Max ETH that can be deposited by tier 2 whitelist address for entire whitelist phase
    uint256 public whitelistMaxDeposit2;
    // Max ETH that can be deposited by tier 3 whitelist address for entire whitelist phase
    uint256 public whitelistMaxDeposit3;
    // Merkleroot of whitelisted addresses
    bytes32 public merkleRoot;
    // Amount each whitelisted user deposited
    mapping(address => uint256) public depositsWhitelist;
    // Amount each user deposited
    mapping(address => uint256) public deposits;

    event TokenDeposit(
        address indexed purchaser,
        address indexed beneficiary,
        bool indexed isWhitelistDeposit,
        uint256 value,
        uint256 time,
        string referralCode
    );
    event TokenClaim(
        address indexed claimer,
        address indexed beneficiary,
        uint256 amount
    );
    event EthRefundClaim(
        address indexed claimer,
        address indexed beneficiary,
        uint256 amount
    );
    event WithdrawEth(uint256 amount);
    event WithdrawPika(uint256 amount);
    event SaleStartUpdated(uint256 saleStart);
    event SaleWhitelist2StartUpdated(uint256 saleWhitelist2Start);
    event MaxDepositsWhitelistUpdated(uint256 maxDepositsWhitelist);
    event MaxDepositsTotalUpdated(uint256 maxDepositsTotal);

    /// @param _pika Pika
    /// @param _owner withdrawer
    /// @param _saleWhitelistStart time when the whitelist phase 1 starts for whitelisted addresses with limited cap
    /// @param _saleWhitelist2Start time when the whitelist phase 2 starts for whitelisted addresses with unlimited cap
    /// @param _saleStart time when the token sale starts
    /// @param _saleClose time when the token sale closes
    /// @param _maxDeposits max cap on wei raised during whitelist and max cap on wei raised
    /// @param _pikaTokensAllocated Pika tokens allocated to this contract
    /// @param _whitelistDepositLimit max deposit that can be done for each whitelist address before _saleWhitelist2Start
    /// @param _whitelistMaxDeposits max deposit that can be done via the whitelist deposit fn for 3 tiers of whitelist addresses for entire whitelist phase
    /// @param _merkleRoot the merkle root of all the whitelisted addresses
    constructor(
        address _pika,
        address _owner,
        uint256 _saleWhitelistStart,
        uint256 _saleWhitelist2Start,
        uint256 _saleStart,
        uint256 _saleClose,
        uint256[] memory _maxDeposits,
        uint256 _pikaTokensAllocated,
        uint256 _whitelistDepositLimit,
        uint256[] memory _whitelistMaxDeposits,
        bytes32 _merkleRoot
    ) {
        require(_owner != address(0), "invalid owner address");
        require(_pika != address(0), "invalid token address");
        require(_saleWhitelistStart <= _saleWhitelist2Start, "invalid saleWhitelistStart");
        require(_saleWhitelistStart >= block.timestamp, "invalid saleWhitelistStart");
        require(_saleStart > _saleWhitelist2Start, "invalid saleStart");
        require(_saleClose > _saleStart, "invalid saleClose");
        require(_maxDeposits[0] > 0, "invalid maxDepositsWhitelist");
        require(_maxDeposits[1] > 0, "invalid maxDepositsTotal");
        require(_pikaTokensAllocated > 0, "invalid pikaTokensAllocated");

        pika = IERC20(_pika);
        owner = _owner;
        saleWhitelistStart = _saleWhitelistStart;
        saleWhitelist2Start = _saleWhitelist2Start;
        saleStart = _saleStart;
        saleClose = _saleClose;
        maxDepositsWhitelist = _maxDeposits[0];
        maxDepositsTotal = _maxDeposits[1];
        pikaTokensAllocated = _pikaTokensAllocated;
        pikaTokensAllocatedWhitelist = pikaTokensAllocated.mul(50).div(190);
        whitelistDepositLimit = _whitelistDepositLimit;
        whitelistMaxDeposit1 = _whitelistMaxDeposits[0];
        whitelistMaxDeposit2 = _whitelistMaxDeposits[1];
        whitelistMaxDeposit3 = _whitelistMaxDeposits[2];
        merkleRoot = _merkleRoot;
    }

    /// Deposit fallback
    /// @dev must be equivalent to deposit(address beneficiary)
    receive() external payable isEligibleSender nonReentrant {
        address beneficiary = msg.sender;
        require(beneficiary != address(0), "invalid address");
        require(weiDeposited + msg.value <= maxDepositsTotal, "max deposit for public phase reached");
        require(saleStart <= block.timestamp, "sale hasn't started yet");
        require(block.timestamp <= saleClose, "sale has closed");

        deposits[beneficiary] = deposits[beneficiary].add(msg.value);
        require(deposits[beneficiary] <= 100 ether, "maximum deposits per address reached");
        weiDeposited = weiDeposited.add(msg.value);
        emit TokenDeposit(
            msg.sender,
            beneficiary,
            false,
            msg.value,
            block.timestamp,
            ""
        );
    }

    /// Deposit for whitelisted address
    /// @param beneficiary will be able to claim tokens after saleClose
    /// @param merkleProof the merkle proof
    function depositForWhitelistedAddress(
        address beneficiary,
        bytes32[] calldata merkleProof,
        string calldata referralCode
    ) external payable nonReentrant {
        require(beneficiary != address(0), "invalid address");
        require(beneficiary == msg.sender, "beneficiary not message sender");
        require(msg.value > 0, "must deposit greater than 0");
        require((weiDepositedWhitelist + msg.value) <= maxDepositsWhitelist, "maximum deposits for whitelist reached");
        require(saleWhitelistStart <= block.timestamp, "sale hasn't started yet");
        require(block.timestamp <= saleStart, "whitelist sale has closed");

        // Whitelist phase 1 only allows deposits up to whitelistDepositLimit
        if (block.timestamp < saleWhitelist2Start) {
            require(depositsWhitelist[beneficiary] + msg.value <= whitelistDepositLimit, "whitelist phase 1 deposit limit reached");
        }

        // Verify the merkle proof.
        uint256 whitelistMaxDeposit = verifyAndGetTierAmount(beneficiary, merkleProof);
        require(msg.value <= depositableLeftWhitelist(beneficiary, whitelistMaxDeposit), "user whitelist allocation used up");

        // Add user deposit to depositsWhitelist
        depositsWhitelist[beneficiary] = depositsWhitelist[beneficiary].add(
            msg.value
        );

        weiDepositedWhitelist = weiDepositedWhitelist.add(msg.value);
        weiDeposited = weiDeposited.add(msg.value);

        emit TokenDeposit(
            msg.sender,
            beneficiary,
            true,
            msg.value,
            block.timestamp,
            referralCode
        );
    }

    /// Deposit
    /// @param beneficiary will be able to claim tokens after saleClose
    /// @dev must be equivalent to receive()
    function deposit(address beneficiary, string calldata referralCode) public payable isEligibleSender nonReentrant {
        require(beneficiary != address(0), "invalid address");
        require(weiDeposited + msg.value <= maxDepositsTotal, "maximum deposits reached");
        require(saleStart <= block.timestamp, "sale hasn't started yet");
        require(block.timestamp <= saleClose, "sale has closed");

        deposits[beneficiary] = deposits[beneficiary].add(msg.value);
        require(deposits[beneficiary] <= 100 ether, "maximum deposits per address reached");
        weiDeposited = weiDeposited.add(msg.value);
        emit TokenDeposit(
            msg.sender,
            beneficiary,
            false,
            msg.value,
            block.timestamp,
            referralCode
        );
    }

    /// Claim
    /// @param beneficiary receives the tokens they claimed
    /// @dev claim calculation must be equivalent to claimAmount(address beneficiary)
    function claim(address beneficiary) external nonReentrant returns (uint256) {
        require(
            deposits[beneficiary] + depositsWhitelist[beneficiary] > 0,
            "no deposit"
        );
        require(block.timestamp > saleClose, "sale hasn't closed yet");

        // total Pika allocated * user share in the ETH deposited
        uint256 beneficiaryClaim = claimAmountPika(beneficiary);
        depositsWhitelist[beneficiary] = 0;
        deposits[beneficiary] = 0;

        pika.safeTransfer(beneficiary, beneficiaryClaim);

        emit TokenClaim(msg.sender, beneficiary, beneficiaryClaim);

        return beneficiaryClaim;
    }

    /// @dev Withdraws eth deposited into the contract. Only owner can call this.
    function withdraw() external {
        require(owner == msg.sender, "caller is not the owner");
        uint256 ethBalance = payable(address(this)).balance;
        payable(msg.sender).transfer(ethBalance);

        emit WithdrawEth(ethBalance);
    }

    /// @dev Withdraws unsold PIKA tokens(if any). Only owner can call this.
    function withdrawUnsoldPika() external {
        require(owner == msg.sender, "caller is not the owner");
        uint256 unsoldAmount = getUnsoldPika();
        pika.safeTransfer(owner, unsoldAmount);

        emit WithdrawPika(unsoldAmount);
    }

    function getUnsoldPika() public view returns(uint256) {
        require(block.timestamp > saleClose, "sale has not ended");
        // amount of Pika unsold during whitelist sale
        uint256 unsoldWlPika = pikaTokensAllocatedWhitelist
        .mul((maxDepositsWhitelist.sub(weiDepositedWhitelist)))
        .div(maxDepositsWhitelist);

        // amount of Pika tokens allocated to whitelist sale
        uint256 pikaForWl = pikaTokensAllocatedWhitelist.sub(unsoldWlPika);

        // amount of Pika tokens allocated to public sale
        uint256 pikaForPublic = pikaTokensAllocated.sub(pikaForWl);

        // total wei deposited during the public sale
        uint256 totalDepoPublic = weiDeposited.sub(weiDepositedWhitelist);

        // the amount of Pika sold in public if it is sold at the whitelist price
        uint256 pikaSoldPublicAtWhitelistPrice = pikaForWl.mul(totalDepoPublic).div(weiDepositedWhitelist);

        // if the amount is larger than pikaForPublic, it means the actual price in public phase is higher than
        // whitelist price and therefore all the PIKA tokens are sold out.
        if (pikaSoldPublicAtWhitelistPrice >= pikaForPublic) {
            return 0;
        }
        return pikaForPublic.sub(pikaSoldPublicAtWhitelistPrice);
    }

    /// View beneficiary's claimable token amount
    /// @param beneficiary address to view claimable token amount of
    function claimAmountPika(address beneficiary) public view returns (uint256) {
        // wei deposited during whitelist sale by beneficiary
        uint256 userDepoWl = depositsWhitelist[beneficiary];

        // wei deposited during public sale by beneficiary
        uint256 userDepoPub = deposits[beneficiary];

        if (userDepoPub.add(userDepoWl) == 0) {
            return 0;
        }

        // amount of Pika unsold during whitelist sale
        uint256 unsoldWlPika = pikaTokensAllocatedWhitelist
        .mul((maxDepositsWhitelist.sub(weiDepositedWhitelist)))
        .div(maxDepositsWhitelist);

        // amount of Pika tokens allocated to whitelist sale
        uint256 pikaForWl = pikaTokensAllocatedWhitelist.sub(unsoldWlPika);

        // amount of Pika tokens allocated to public sale
        uint256 pikaForPublic = pikaTokensAllocated.sub(pikaForWl);

        // total wei deposited during the public sale
        uint256 totalDepoPublic = weiDeposited.sub(weiDepositedWhitelist);

        uint256 userClaimablePika = 0;

        if (userDepoWl > 0) {
            userClaimablePika = pikaForWl.mul(userDepoWl).div(weiDepositedWhitelist);
        }
        if (userDepoPub > 0) {
            uint256 userClaimablePikaPublic = Math.min(pikaForPublic.mul(userDepoPub).div(totalDepoPublic),
                pikaForWl.mul(userDepoPub).div(weiDepositedWhitelist));
            userClaimablePika = userClaimablePika.add(userClaimablePikaPublic);
        }
        return userClaimablePika;
    }

    /// View leftover depositable eth for whitelisted user
    /// @param beneficiary user address
    /// @param whitelistMaxDeposit max deposit amount for user address
    function depositableLeftWhitelist(address beneficiary, uint256 whitelistMaxDeposit) public view returns (uint256) {
        return whitelistMaxDeposit.sub(depositsWhitelist[beneficiary]);
    }

    function verifyAndGetTierAmount(address beneficiary, bytes32[] calldata merkleProof) public returns(uint256) {
        bytes32 node1 = keccak256(abi.encodePacked(beneficiary, whitelistMaxDeposit1));
        if (MerkleProof.verify(merkleProof, merkleRoot, node1)) {
            return whitelistMaxDeposit1;
        }
        bytes32 node2 = keccak256(abi.encodePacked(beneficiary, whitelistMaxDeposit2));
        if (MerkleProof.verify(merkleProof, merkleRoot, node2)) {
            return whitelistMaxDeposit2;
        }
        bytes32 node3 = keccak256(abi.encodePacked(beneficiary, whitelistMaxDeposit3));
        if (MerkleProof.verify(merkleProof, merkleRoot, node3)) {
            return whitelistMaxDeposit3;
        }
        revert("invalid proof");
    }

    function getCurrentPikaPrice() external view returns(uint256) {
        uint256 minPrice = maxDepositsWhitelist.mul(1e18).div(pikaTokensAllocatedWhitelist);
        if (block.timestamp <= saleStart) {
            return minPrice;
        }
        // amount of Pika unsold during whitelist sale
        uint256 unsoldWlPika = pikaTokensAllocatedWhitelist
        .mul((maxDepositsWhitelist.sub(weiDepositedWhitelist)))
        .div(maxDepositsWhitelist);
        // amount of Pika tokens allocated to whitelist sale
        uint256 pikaForWl = pikaTokensAllocatedWhitelist.sub(unsoldWlPika);

        // amount of Pika tokens allocated to public sale
        uint256 pikaForPublic = pikaTokensAllocated.sub(pikaForWl);
        uint256 priceForPublic = (weiDeposited.sub(weiDepositedWhitelist)).mul(1e18).div(pikaForPublic);
        return priceForPublic > minPrice ? priceForPublic : minPrice;
    }

    /// option to increase whitelist phase 2 sale start time
    /// @param _saleWhitelist2Start new whitelist phase 2 start time
    function setSaleWhitelist2Start(uint256 _saleWhitelist2Start) external onlyOwner {
        // can only set new whitelist phase 2 start before sale starts
        require(block.timestamp < saleStart, "already started");
        // can only set new whitelist phase 2 start before the current public phase start, and after the current whitelist phase 2 start
        require(_saleWhitelist2Start < saleStart && _saleWhitelist2Start > saleWhitelist2Start, "invalid sale start time");
        saleWhitelist2Start = _saleWhitelist2Start;
        emit SaleWhitelist2StartUpdated(_saleWhitelist2Start);
    }

    /// adjust whitelist allocation in case whitelist is fully filled before whitelist phase 1 ends
    /// @param _maxDepositsWhitelist new whitelist allocation
    function setMaxDepositsWhitelist(uint256 _maxDepositsWhitelist) external onlyOwner {
        require(block.timestamp < saleWhitelist2Start, "whitelist phase 1 already ended");
        require(_maxDepositsWhitelist > maxDepositsWhitelist && _maxDepositsWhitelist <= maxDepositsTotal, "invalid max whitelist amount");
        pikaTokensAllocatedWhitelist = pikaTokensAllocatedWhitelist * _maxDepositsWhitelist / maxDepositsWhitelist;
        require(pikaTokensAllocatedWhitelist <= pikaTokensAllocated, "invalid max whitelist pika allocation amount");
        maxDepositsWhitelist = _maxDepositsWhitelist;
        emit MaxDepositsWhitelistUpdated(_maxDepositsWhitelist);
    }

    /// adjust max deposits amount total in case setMaxDepositsWhitelist is called or whitelist phase is not fully filled,
    /// to make sure the max token price does not change for public phase
    /// @param _maxDepositsTotal new max deposits total amount
    function setMaxDepositsTotal(uint256 _maxDepositsTotal) external onlyOwner {
        require(_maxDepositsTotal < maxDepositsTotal + maxDepositsWhitelist && _maxDepositsTotal > maxDepositsWhitelist, "invalid max deposit amount");
        maxDepositsTotal = _maxDepositsTotal;
        emit MaxDepositsTotalUpdated(_maxDepositsTotal);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "only owner");
        _;
    }

    // Modifier is eligible sender modifier
    modifier isEligibleSender() {
        require(msg.sender == tx.origin, "Contracts are not allowed to snipe the sale");
        _;
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
// OpenZeppelin Contracts (last updated v4.5.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
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
        return a / b + (a % b == 0 ? 0 : 1);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Trees proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merklee tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            bytes32 proofElement = proof[i];
            if (computedHash <= proofElement) {
                // Hash(current computed hash + current element of the proof)
                computedHash = _efficientHash(computedHash, proofElement);
            } else {
                // Hash(current element of the proof + current computed hash)
                computedHash = _efficientHash(proofElement, computedHash);
            }
        }
        return computedHash;
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
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