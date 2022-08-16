// SPDX-License-Identifier: ISC
pragma solidity 0.7.5;
pragma abicoder v2;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MultiDistributor is Ownable {
  struct UserTokenAmounts {
    address user;
    IERC20 token;
    uint256 amount;
  }

  mapping(address => mapping(IERC20 => uint256)) public claimableBalances;
  mapping(address => mapping(IERC20 => uint256)) public totalClaimed;

  constructor() Ownable() {}

  function addToClaims(
    UserTokenAmounts[] memory claimsToAdd,
    uint256 epochTimestamp,
    string memory tag
  ) external onlyOwner {
    for (uint256 i = 0; i < claimsToAdd.length; i++) {
      UserTokenAmounts memory claimToAdd = claimsToAdd[i];
      claimableBalances[claimToAdd.user][claimToAdd.token] += claimToAdd.amount;
      require(
        claimableBalances[claimToAdd.user][claimToAdd.token] >= claimToAdd.amount,
        "Addition overflow for balance"
      );
      emit ClaimAdded(claimToAdd.token, claimToAdd.user, claimToAdd.amount, epochTimestamp, tag);
    }
  }

  function removeClaims(address[] memory addresses, IERC20[] memory tokens) external onlyOwner {
    for (uint256 i = 0; i < addresses.length; i++) {
      for (uint256 j = 0; j < tokens.length; j++) {
        uint256 balanceToClaim = claimableBalances[addresses[i]][tokens[j]];
        claimableBalances[addresses[i]][tokens[j]] = 0;
        emit ClaimRemoved(tokens[j], addresses[i], balanceToClaim);
      }
    }
  }

  function claim(IERC20[] memory tokens) external {
    for (uint256 j = 0; j < tokens.length; j++) {
      uint256 balanceToClaim = claimableBalances[msg.sender][tokens[j]];

      if (balanceToClaim == 0) {
        continue;
      }

      claimableBalances[msg.sender][tokens[j]] = 0;
      totalClaimed[msg.sender][tokens[j]] += balanceToClaim;

      tokens[j].transfer(msg.sender, balanceToClaim);

      emit Claimed(tokens[j], msg.sender, balanceToClaim);
    }
  }

  function getClaimableForAddresses(address[] memory addresses, IERC20[] memory tokens)
    external
    view
    returns (UserTokenAmounts[] memory claimed, UserTokenAmounts[] memory claimable)
  {
    claimable = new UserTokenAmounts[](addresses.length * tokens.length);
    claimed = new UserTokenAmounts[](addresses.length * tokens.length);
    for (uint256 i = 0; i < addresses.length; i++) {
      for (uint256 j = 0; j < tokens.length; j++) {
        claimed[i] = UserTokenAmounts({
          user: addresses[i],
          token: tokens[j],
          amount: totalClaimed[addresses[i]][tokens[j]]
        });
        claimable[i] = UserTokenAmounts({
          user: addresses[i],
          token: tokens[j],
          amount: claimableBalances[addresses[i]][tokens[j]]
        });
      }
    }
  }

  //////
  // Events
  event Claimed(IERC20 indexed rewardToken, address indexed claimer, uint256 amount);
  event ClaimAdded(
    IERC20 indexed rewardToken,
    address indexed claimer,
    uint256 amount,
    uint256 indexed epochTimestamp,
    string tag
  );
  event ClaimRemoved(IERC20 indexed rewardToken, address indexed claimer, uint256 amount);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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

pragma solidity ^0.7.0;

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
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
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
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}