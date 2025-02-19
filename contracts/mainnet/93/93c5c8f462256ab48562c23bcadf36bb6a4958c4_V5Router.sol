// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

import {IV5AggregationExecutor} from "src/interfaces/IV5AggregationExecutor.sol";
import {IV5AggregationRouter} from "src/interfaces/IV5AggregationRouter.sol";
import {AggregationV5BaseRouter} from "src/AggregationBaseRouter.sol";

/// @notice A router to swap tokens using 1inch's v5 aggregation router.
contract V5Router is AggregationV5BaseRouter {
  /// @dev Thrown when a function is not supported.
  error UnsupportedFunction();

  constructor(
    IV5AggregationRouter aggregationRouter,
    IV5AggregationExecutor aggregationExecutor,
    address token
  ) AggregationV5BaseRouter(aggregationExecutor, aggregationRouter, token) {
    IERC20(token).approve(address(aggregationRouter), type(uint256).max);
  }

  /// @dev If we remove this function solc will give a missing-receive-ether warning because we have
  /// a payable fallback function. We cannot change the fallback function to a receive function
  /// because receive does not have access to msg.data. In order to prevent a missing-receive-ether
  /// warning we add a receive function and revert.
  receive() external payable {
    revert UnsupportedFunction();
  }

  // Flags match specific constant masks. There is no documentation on these.
  fallback() external payable {
    address dstToken = address(bytes20(msg.data[0:20]));
    uint256 amount = uint256(uint96(bytes12(msg.data[20:32])));
    uint256 minReturnAmount = uint256(uint96(bytes12(msg.data[32:44])));
    uint256 flags = uint256(uint8(bytes1(msg.data[44:45])));
    bytes memory data = bytes(msg.data[45:msg.data.length]);

    IERC20(TOKEN).transferFrom(msg.sender, address(this), amount);
    AGGREGATION_ROUTER.swap(
      AGGREGATION_EXECUTOR,
      IV5AggregationRouter.SwapDescription({
        srcToken: IERC20(TOKEN),
        dstToken: IERC20(dstToken),
        srcReceiver: payable(SOURCE_RECEIVER),
        dstReceiver: payable(msg.sender),
        amount: amount,
        minReturnAmount: minReturnAmount,
        flags: flags
      }),
      "",
      data
    );
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

pragma solidity >=0.8.0;

/// @title Interface for making arbitrary calls during swap
interface IV5AggregationExecutor {
  /// @notice propagates information about original msg.sender and executes arbitrary data
  function execute(address msgSender) external payable; // 0x4b64e492
}

pragma solidity >=0.8.0;

import {IV5AggregationExecutor} from "src/interfaces/IV5AggregationExecutor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IV5AggregationRouter {
  struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
  }

  function swap(
    IV5AggregationExecutor executor,
    SwapDescription calldata desc,
    bytes calldata permit,
    bytes calldata data
  ) external payable returns (uint256 returnAmount, uint256 spentAmount);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {IV5AggregationExecutor} from "src/interfaces/IV5AggregationExecutor.sol";
import {IV5AggregationRouter} from "src/interfaces/IV5AggregationRouter.sol";
import {IV4AggregationExecutor} from "src/interfaces/IV4AggregationExecutor.sol";
import {IV4AggregationRouter} from "src/interfaces/IV4AggregationRouter.sol";

/// @notice An abstract class with the necessary class variables
/// to make a 1inch v5 aggregation router optimized.
abstract contract AggregationV5BaseRouter {
  /// @notice The contract used to execute the swap along an optimized path.
  IV5AggregationExecutor public immutable AGGREGATION_EXECUTOR;

  /// @notice The 1inch v5 aggregation router contract.
  IV5AggregationRouter public immutable AGGREGATION_ROUTER;

  /// @notice The input token being swapped.
  address public immutable TOKEN;

  /// @notice Where the tokens are transferred in the 1inch v5 aggregation router.
  /// It will match the AGGREGATION_EXECUTOR address.
  address public immutable SOURCE_RECEIVER;

  constructor(
    IV5AggregationExecutor aggregationExecutor,
    IV5AggregationRouter aggregationRouter,
    address token
  ) {
    AGGREGATION_EXECUTOR = aggregationExecutor;
    AGGREGATION_ROUTER = aggregationRouter;
    TOKEN = token;
    SOURCE_RECEIVER = address(aggregationExecutor);
  }
}

/// @notice An abstract class with the necessary class variables
/// to make a 1inch v4 aggregation router optimized.
abstract contract AggregationV4BaseRouter {
  /// @notice The contract used to execute the swap along an optimized path.
  IV4AggregationExecutor public immutable AGGREGATION_EXECUTOR;

  /// @notice The 1inch v4 aggregation router contract.
  IV4AggregationRouter public immutable AGGREGATION_ROUTER;

  /// @notice The input token being swapped.
  address public immutable TOKEN;

  /// @notice Where the tokens are transferred in the 1inch v4 aggregation router.
  /// It will match the AGGREGATION_EXECUTOR address.
  address public immutable SOURCE_RECEIVER;

  constructor(
    IV4AggregationExecutor aggregationExecutor,
    IV4AggregationRouter aggregationRouter,
    address token
  ) {
    AGGREGATION_EXECUTOR = aggregationExecutor;
    AGGREGATION_ROUTER = aggregationRouter;
    TOKEN = token;
    SOURCE_RECEIVER = address(aggregationExecutor);
  }
}

// SPDX-License-Identifier: MIT
// permalink:
// https://optimistic.etherscan.io/address/0x1111111254760f7ab3f16433eea9304126dcd199#code#L990
pragma solidity >=0.8.0;

/// @title Interface for making arbitrary calls during swap
interface IV4AggregationExecutor {
  /// @notice Make calls on `msgSender` with specified data
  function callBytes(address msgSender, bytes calldata data) external payable; // 0x2636f7f8
}

pragma solidity >=0.8.0;

import {IV4AggregationExecutor} from "src/interfaces/IV4AggregationExecutor.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

interface IV4AggregationRouter {
  struct SwapDescription {
    IERC20 srcToken;
    IERC20 dstToken;
    address payable srcReceiver;
    address payable dstReceiver;
    uint256 amount;
    uint256 minReturnAmount;
    uint256 flags;
    bytes permit;
  }

  function swap(IV4AggregationExecutor executor, SwapDescription calldata desc, bytes calldata data)
    external
    payable
    returns (uint256 returnAmount, uint256 spentAmount, uint256 gasLeft);
}