//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./libs/Array.sol";
import "erc721a/contracts/interfaces/IERC721A.sol";

contract OppaBearEvolutionGen1Pool is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using Array for uint256[];

    enum TypeNFT {
        COMMON,
        RARE,
        SUPER_RARE
    }

    event NFTStaked(address indexed owner, uint256 tokenId, uint256 date);
    event NFTUnstaked(address indexed owner, uint256 tokenId, uint256 value);
    event ClaimToken(address indexed owner, uint256 amount, uint256 datenit);

    uint256 public totalStaked;

    uint256 public totalNFT;

    // OPB Price
    uint256 public opbPrice = 650000000000000000; // 0.65 USD

    // Last block timestamp that GovernanceTokens distribution.
    uint256 public lastRewardBlock;

    // Next block timestamp that GovernanceTokens distribution.
    uint256 public nextRewardBlock;

    // GovernanceToken tokens destribute per days.
    // default 5 tokens per day
    uint256 public destributeTokenPerDay = 5 * 10**18;

    // Store Token ID it's staked in this contract
    uint256[] private Alltokens;

    // Max Supply NFT
    uint256 public max_supply = 2000;

    uint256 public constant COMMON_BOOST = 1; // x1
    uint256 public constant RARE_BOOST = 2; // x2
    uint256 public constant SUPER_RARE_BOOST = 3; // x3

    IERC721A public immutable nft;
    IERC20 public immutable token;

    struct Staker {
        uint256 tokenId;
        address owner;
        uint256 stakeAt;
        uint256 timeCanUnstake;
        uint256 reward;
        TypeNFT typeNFT;
    }

    mapping(uint256 => uint256) public nftInfo;

    mapping(uint256 => Staker) public vault;

    constructor(IERC721A _nft, IERC20 _token) {
        nft = _nft;
        token = _token;
    }

    function setNFTInfo(uint256[] calldata _nfts) external onlyOwner {
        for (uint256 i = 0; i < _nfts.length; i++) {
            totalNFT += 1;
            nftInfo[totalNFT] = _nfts[i];
        }
    }

    // external function
    function setDestributeToken(uint256 _destributeTokenPerDay)
        external
        onlyOwner
    {
        require(
            _destributeTokenPerDay > 0,
            "reward paid per day must be more than 0"
        );
        destributeTokenPerDay = _destributeTokenPerDay;
    }

    function setMaxNFTSupply(uint256 _maxSupply) external onlyOwner {
        require(_maxSupply > 0, "maxSupply  must be more than 0");
        max_supply = _maxSupply;
    }

    function setOPBPrice(uint256 _price) external onlyOwner {
        opbPrice = _price;
    }

    function stake(uint256[] calldata _tokenIds) external {
        updatePool();
        uint256 tokenId;
        totalStaked += _tokenIds.length;
        TypeNFT typeNFT;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];

            typeNFT = validateTypeNFT(tokenId);

            require(nft.ownerOf(tokenId) == msg.sender, "not your token");
            require(vault[tokenId].tokenId == 0, "already staked");

            nft.transferFrom(msg.sender, address(this), tokenId);
            emit NFTStaked(msg.sender, tokenId, block.timestamp);

            vault[tokenId] = Staker({
                tokenId: uint256(tokenId),
                owner: msg.sender,
                stakeAt: uint256(block.timestamp),
                timeCanUnstake: uint256(block.timestamp) + 15 days,
                reward: 0,
                typeNFT: typeNFT
            });

            Alltokens.push(tokenId);
        }
    }

    function unstake(uint256[] calldata _tokenIds) external nonReentrant {
        updatePool();
        uint256 tokenId;
        totalStaked -= _tokenIds.length;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];
            Staker memory staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");

            require(
                staked.timeCanUnstake <= block.timestamp,
                "not yet time to unstake nft"
            );

            if (staked.reward > 0) {
                safeOPBTokenTransfer(msg.sender, staked.reward);
                emit ClaimToken(msg.sender, staked.reward, block.timestamp);
            }

            delete vault[tokenId];
            Alltokens.removeElement(tokenId);

            emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            nft.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    function claim(uint256[] calldata _tokenIds) external nonReentrant {
        uint256 tokenId;
        uint256 reward;
        uint256 totalReward;
        updatePool();

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];
            Staker storage staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");
            require(
                staked.timeCanUnstake <= block.timestamp,
                "not yet time to claim token"
            );
            (, reward) = getUserRewardByNFT(tokenId);
            totalReward += reward;
            staked.reward = 0;
        }

        safeOPBTokenTransfer(msg.sender, totalReward);
        emit ClaimToken(msg.sender, totalReward, block.timestamp);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256[] calldata _tokenIds)
        external
        nonReentrant
    {
        uint256 tokenId;
        totalStaked -= _tokenIds.length;

        for (uint256 i = 0; i < _tokenIds.length; i++) {
            tokenId = _tokenIds[i];
            Staker memory staked = vault[tokenId];
            require(staked.owner == msg.sender, "not an owner");

            delete vault[tokenId];
            Alltokens.removeElement(tokenId);

            emit NFTUnstaked(msg.sender, tokenId, block.timestamp);
            nft.transferFrom(address(this), msg.sender, tokenId);
        }
    }

    // // public
    function updatePool() public {
        if (
            block.timestamp <= lastRewardBlock ||
            block.timestamp < nextRewardBlock
        ) {
            return;
        }

        if (totalStaked == 0) {
            lastRewardBlock = block.timestamp;
            nextRewardBlock = block.timestamp + 1 days;
            return;
        }

        (uint256 common, uint256 rare, uint256 superRare) = sumTypeNFT();

        (
            uint256 rewardCommonPerNFT,
            uint256 rewardRarePerNFT,
            uint256 rewardSuperRarePerNFT
        ) = calculateReward(common, rare, superRare);

        for (uint256 i = 0; i < totalStaked; i++) {
            uint256 tokenId = Alltokens[i];
            Staker storage staked = vault[tokenId];

            if (vault[tokenId].typeNFT == TypeNFT.COMMON) {
                staked.reward += rewardCommonPerNFT;
            }

            if (vault[tokenId].typeNFT == TypeNFT.RARE) {
                staked.reward += rewardRarePerNFT;
            }

            if (vault[tokenId].typeNFT == TypeNFT.SUPER_RARE) {
                staked.reward += rewardSuperRarePerNFT;
            }
        }

        lastRewardBlock = block.timestamp;
        nextRewardBlock = block.timestamp + 1 days;
    }

    // internal
    function safeOPBTokenTransfer(address _to, uint256 _amount) internal {
        uint256 OPBTokenBal = token.balanceOf(address(this));
        if (_amount > OPBTokenBal) {
            token.transfer(_to, OPBTokenBal);
        } else {
            token.transfer(_to, _amount);
        }
    }

    function calculateReward(
        uint256 cm,
        uint256 r,
        uint256 sr
    )
        internal
        view
        returns (
            uint256 rewardCommonPerNFT,
            uint256 rewardRarePerNFT,
            uint256 rewardSuperRarePerNFT
        )
    {
        uint256 reward = destributeTokenPerDay;

        uint256 boostCommon = cm.mul(COMMON_BOOST);
        uint256 boostRare = r.mul(RARE_BOOST);
        uint256 boostSuperRare = sr.mul(SUPER_RARE_BOOST);

        uint256 totalBoost = boostCommon + boostRare + boostSuperRare;

        rewardCommonPerNFT = reward.div(totalBoost);

        rewardRarePerNFT = rewardCommonPerNFT * RARE_BOOST;

        rewardSuperRarePerNFT = rewardCommonPerNFT * SUPER_RARE_BOOST;
    }

    function validateTypeNFT(uint256 _tokenId)
        internal
        view
        returns (TypeNFT typeNFT)
    {
        if (nftInfo[_tokenId] == 0) {
            return typeNFT = TypeNFT.COMMON;
        }
        if (nftInfo[_tokenId] == 1) {
            return typeNFT = TypeNFT.RARE;
        }
        if (nftInfo[_tokenId] == 2) {
            return typeNFT = TypeNFT.SUPER_RARE;
        }
    }

    function sumTypeNFT()
        internal
        view
        returns (
            uint256 common,
            uint256 rare,
            uint256 superRare
        )
    {
        for (uint256 i = 0; i < totalStaked; i++) {
            uint256 tokenId = Alltokens[i];

            if (vault[tokenId].typeNFT == TypeNFT.COMMON) {
                common += 1;
            } else if (vault[tokenId].typeNFT == TypeNFT.RARE) {
                rare += 1;
            } else if (vault[tokenId].typeNFT == TypeNFT.SUPER_RARE) {
                superRare += 1;
            }
        }
    }

    // view

    function getUserReward(address _owner)
        public
        view
        returns (uint256 totalReward, uint256 avaliableReward)
    {
        uint256[] memory tokens = tokensOfOwner(_owner);
        uint256 tokenId;

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenId = tokens[i];
            Staker memory user = vault[tokenId];

            if (user.timeCanUnstake <= block.timestamp) {
                totalReward += user.reward;
                avaliableReward += user.reward;
            } else {
                totalReward += user.reward;
            }
        }
    }

    function getTokenAvaliableForClaim(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory tokens = tokensOfOwner(_owner);
        uint256 tokenId;
        uint256 count;
        uint256 index;

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenId = tokens[i];
            Staker memory user = vault[tokenId];
            if (user.timeCanUnstake < block.timestamp && user.owner == _owner) {
                count += 1;
            }
        }

        uint256[] memory avaliableTokens = new uint256[](count);

        for (uint256 i = 0; i < tokens.length; i++) {
            tokenId = tokens[i];
            Staker memory user = vault[tokenId];
            if (user.timeCanUnstake < block.timestamp && user.owner == _owner) {
                avaliableTokens[index] = tokenId;
                index += 1;
            }
        }

        return avaliableTokens;
    }

    function getUserRewardByNFT(uint256 _tokenIds)
        public
        view
        returns (uint256 totalReward, uint256 avaliableReward)
    {
        Staker memory user = vault[_tokenIds];

        if (user.timeCanUnstake <= block.timestamp) {
            totalReward += user.reward;
            avaliableReward += user.reward;
        } else {
            totalReward += user.reward;
        }
    }

    function tokensOfOwner(address _owner)
        public
        view
        returns (uint256[] memory ownerTokens)
    {
        uint256 maxSupply = max_supply;
        uint256[] memory tmp = new uint256[](maxSupply);
        uint256 index = 0;

        for (uint256 tokenId = 1; tokenId <= maxSupply; tokenId++) {
            if (vault[tokenId].owner == _owner) {
                tmp[index] = vault[tokenId].tokenId;
                index += 1;
            }
        }

        uint256[] memory tokens = new uint256[](index);
        for (uint256 i = 0; i < index; i++) {
            tokens[i] = tmp[i];
        }

        return tokens;
    }

    function balanceOf(address _account) public view returns (uint256) {
        uint256 balance = 0;
        uint256 supply = max_supply;
        for (uint256 i = 1; i <= supply; i++) {
            if (vault[i].owner == _account) {
                balance += 1;
            }
        }
        return balance;
    }

    function amountStakedInPool() public view returns (uint256 amountNFT) {
        return nft.balanceOf(address(this));
    }
}

//SPDX-License-Identifier: Unlicense

pragma solidity ^0.8.0;

library Array {
    function removeElement(uint256[] storage _array, uint256 _element) public {
        for (uint256 i; i < _array.length; i++) {
            if (_array[i] == _element) {
                _array[i] = _array[_array.length - 1];
                _array.pop();
                break;
            }
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

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
    constructor() {
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
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.3
// Creator: Chiru Labs

pragma solidity ^0.8.4;

import '../IERC721A.sol';

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

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.3
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721A {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external payable;

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external payable;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}