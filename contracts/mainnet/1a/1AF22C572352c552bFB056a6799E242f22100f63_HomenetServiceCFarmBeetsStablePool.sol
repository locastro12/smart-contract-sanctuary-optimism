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
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/IERC20.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (interfaces/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../token/ERC20/extensions/IERC20Metadata.sol";

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/draft-IERC20Permit.sol)

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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/draft-IERC20Permit.sol";
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
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/BitMaps.sol)
pragma solidity ^0.8.0;

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largely inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "./lib/Serializer.sol";
import "./IMCeler.sol";

uint256 constant REWARD_TO_REWARD_PRECISION = 1E12;

abstract contract HomenetService is IMCeler {
    using SafeERC20 for IERC20;

    address public immutable cFarm;

    uint32 public immutable harvestInterval;
    uint32 public harvestLastTimestamp;

    // 1/10,000th
    uint16 public protocolFeePercentMultiplier = 0;

    // 1/10,000th
    uint16 public userRewardPercentMultiplier = 0;

    uint256 public userRewardToArdnRewardAmountMulitiplier;

    address public protocolFeeCollector;

    uint256 private rewardMessageNonce = 1;

    constructor(
        address _cFarm,
        address _messageBus,
        address _quoteToken,
        uint32 _harvestInterval,
        uint256 _userRewardToArdnRewardAmountMulitiplier,
        uint16 _protocolFeePercentMultiplier,
        uint16 _userRewardPercentMultiplier,
        address _protocolFeeCollector
    )
        IMCeler(_messageBus, _quoteToken)
    {
        require(_protocolFeeCollector != address(0), "PROTOCOL_FEE_COLLECTOR");

        cFarm = _cFarm;
        harvestInterval = _harvestInterval;
        userRewardToArdnRewardAmountMulitiplier = _userRewardToArdnRewardAmountMulitiplier;
        protocolFeePercentMultiplier = _protocolFeePercentMultiplier;
        userRewardPercentMultiplier = _userRewardPercentMultiplier;
        protocolFeeCollector = _protocolFeeCollector;
    }

    modifier onlyIfHarvestTimePassed() {
        require(block.timestamp - harvestLastTimestamp >= harvestInterval, "HARVEST_INTERVAL");
        _;
    }

    function getQueueLengths()
        public
        view
        returns (uint256)
    {
        return incomingMessageQueue.length;
    }

    function sendRewardMessage(uint256 rewardAmount)
        internal
        returns (uint256 fee)
    {
        if (rewardAmount == 0) {
            return 0;
        }

        bytes memory rewardMessageId = abi.encode(keccak256(abi.encode(3, block.timestamp, block.number, address(this), block.chainid, rewardMessageNonce++)));
        rewardMessageId[0] = bytes1(MESSAGE_KIND_REWARD);

        bytes memory outgoingMessage = Serializer.createRewardMessage(bytes32(rewardMessageId), rewardAmount);
        return sendMessage(outgoingMessage);
    }

    function setFees(uint256 _userRewardToArdnRewardAmountMulitiplier, uint16 _userRewardPercentMultiplier, address _protocolFeeCollector, uint16 _protocolFeePercentMultiplier)
        public
        onlyOwner
    {
        userRewardToArdnRewardAmountMulitiplier = _userRewardToArdnRewardAmountMulitiplier;
        userRewardPercentMultiplier = _userRewardPercentMultiplier;
        protocolFeeCollector = _protocolFeeCollector;
        protocolFeePercentMultiplier = _protocolFeePercentMultiplier;
        emit ConfigurationUpdated();
    }

    function shutdown()
        public
        virtual
        onlyOwner
    {
        _shutdown();

        protocolFeePercentMultiplier = 10000;
        delete userRewardPercentMultiplier;
        delete userRewardToArdnRewardAmountMulitiplier;
        protocolFeeCollector;

        // make onlyIfHarvestTimePassed panic due to underflow
        harvestLastTimestamp = 2**32-1;
        emit ConfigurationUpdated();
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "./lib/Tools.sol";
import "./lib/Serializer.sol";
import "./interfaces/ISwapHelper.sol";
import "./interfaces/ICFarmBeets.sol";
import "./HomenetService.sol";

uint256 constant PERCENT_PRECISION = 10000;

contract HomenetServiceCFarmBeetsStablePool is HomenetService {
    using SafeERC20 for IERC20;

    address public swapHelper;

    event Harvest(uint256 ardnRewardAmount);

    constructor(
        address _cFarm,
        address _messageBus,
        address _quoteToken,

        uint32 _harvestInterval,
        uint256 _userRewardToArdnRewardAmountMulitiplier,
        uint16 _protocolFeePercentMultiplier,
        uint16 _userRewardPercentMultiplier,
        address _protocolFeeCollector,

        address _swapHelper
    )
        HomenetService(
            _cFarm,
            _messageBus,
            _quoteToken,
            _harvestInterval,
            _userRewardToArdnRewardAmountMulitiplier,
            _protocolFeePercentMultiplier,
            _userRewardPercentMultiplier,
            _protocolFeeCollector
        )
    {
        swapHelper = _swapHelper;
    }

    function harvest()
        public
        payable
        onlyIfHarvestTimePassed
    {
        uint256 ardnRewardAmount = harvestImplementation();
        uint256 fee = sendRewardMessage(ardnRewardAmount);

        if (fee < msg.value) {
            payable(msg.sender).transfer(msg.value - fee);
        }
    }

    function harvestImplementation()
        internal
        returns (uint256 ardnRewardAmount)
    {
        ICFarmBeets(cFarm).harvest();

        IERC20 rewardToken = IERC20(ICFarmBeets(cFarm).rewardToken());

        uint256 amount = rewardToken.balanceOf(address(this));

        if (amount == 0) {
            emit Harvest(0);
            return 0;
        }

        uint256 userRewardAmount = amount * userRewardPercentMultiplier / PERCENT_PRECISION;
        uint256 protocolFeeAmount = amount * protocolFeePercentMultiplier / PERCENT_PRECISION;

        amount -= userRewardAmount;
        amount -= protocolFeeAmount;

        if (amount > 0) {
            rewardToken.safeTransfer(swapHelper, amount);
            ISwapHelper(swapHelper).swap(address(rewardToken), quoteToken, cFarm);
            ICFarmBeets(cFarm).addLiquidityAndStake(false);
        }

        CollectTokens._collect(address(rewardToken), protocolFeeCollector);

        ardnRewardAmount = userRewardAmount * userRewardToArdnRewardAmountMulitiplier / REWARD_TO_REWARD_PRECISION;

        emit Harvest(ardnRewardAmount);
    }

    function investImplementation(uint256 bridgedQuoteTokenAmount, QueueEntry[] memory incomingQueue)
        internal
        returns (QueueEntry[] memory outgoingQueue)
    {
        if (ICFarmBeets(cFarm).quoteToken() == quoteToken) {
            IERC20(quoteToken).safeTransfer(cFarm, bridgedQuoteTokenAmount);
        } else {
            IERC20(quoteToken).safeTransfer(swapHelper, bridgedQuoteTokenAmount);
            ISwapHelper(swapHelper).swap(quoteToken, ICFarmBeets(cFarm).quoteToken(), cFarm);
        }

        (uint256 lpAmount, uint256 cFarmAmount) = ICFarmBeets(cFarm).addLiquidityAndStake(true);
        require(lpAmount > 0, "ZERO2");

        uint256 investedQuoteTokenAmount = Tools.sumAmountFromQueue(incomingQueue);
        require(investedQuoteTokenAmount > 0, "ZERO1");

        outgoingQueue = Tools.createScaledQueueFromQueue(cFarmAmount, investedQuoteTokenAmount, incomingQueue);
    }

    function withdrawImplementation(QueueEntry[] memory incomingQueue)
        internal
        returns (QueueEntry[] memory outgoingQueue, uint256 quoteTokenAmount)
    {
        uint256 cFarmAmount = Tools.sumAmountFromQueue(incomingQueue);
        require(cFarmAmount > 0, "ZERO_CFARM");

        quoteTokenAmount = ICFarmBeets(cFarm).unstakeAndRemoveLiquidity(cFarmAmount);
        require(quoteTokenAmount > 0, "ZERO_QUOTE");

        outgoingQueue = Tools.createScaledQueueFromQueue(quoteTokenAmount, cFarmAmount, incomingQueue);
    }

    function onMessage(bytes memory incomingMessage)
        override
        internal
    {
        (bytes32 roundtripId, , QueueEntry[] memory incomingQueue) = Serializer.parseQueueMessage(incomingMessage);

        (QueueEntry[] memory outgoingQueue, uint256 quoteTokenAmount) = withdrawImplementation(incomingQueue);

        bytes memory outgoingMessage = Serializer.createQueueMessage(roundtripId, quoteTokenAmount, outgoingQueue);
        sendMessageWithTransfer(quoteTokenAmount, outgoingMessage);
    }

    function onMessageWithTransfer(bytes memory incomingMessage, uint256 tokenAmount)
        override
        internal
    {
        require(tokenAmount > 0, "ZERO0");

        (bytes32 roundtripId, , QueueEntry[] memory incomingQueue) = Serializer.parseQueueMessage(incomingMessage);

        QueueEntry[] memory outgoingQueue = investImplementation(tokenAmount, incomingQueue);

        bytes memory outgoingMessage = Serializer.createQueueMessage(roundtripId, 0, outgoingQueue);
        sendMessage(outgoingMessage);
    }

    function setSwapHelper(address _swapHelper)
        public
        onlyOwner
    {
        swapHelper = _swapHelper;
        emit ConfigurationUpdated();
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import "sgn-v2-contracts/contracts/message/libraries/MessageSenderLib.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageBus.sol";
import "sgn-v2-contracts/contracts/message/interfaces/IMessageReceiverApp.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import "./lib/Serializer.sol";
import "./lib/CollectTokens.sol";

abstract contract IMCeler is IMessageReceiverApp, Ownable {
    using SafeERC20 for IERC20;

    struct MessageWithTransferQueueEntry {
        uint256 amount;
        bool isLocalBridge;
        bytes message;
    }

    address public quoteToken;

    address public localBridgeCustodian;
    uint256 public localBridgeTresholdAmount;

    address public peerAddress;
    uint64 public peerChainId;

    uint64 private celerSendMessageWithTransferNonce;

    uint32 public maxSlippage = 30000; // 3% = 30000

    address public immutable messageBus;

    MessageWithTransferQueueEntry[] public incomingMessageQueue;

    BitMaps.BitMap private seenRoundtripId;

    event OutgoingMessageSent(bytes32 roundtripId);
    event OutgoingMessageWithTransferSent(bytes32 roundtripId, uint256 amount, bool isLocalBridge);

    event OutgoingMessageWithTransferRefund(bytes32 roundtripId, uint256 tokenAmount);
    event OutgoingMessageWithTransferFallback(bytes32 roundtripId, uint256 tokenAmount);

    event IncomingMessageQueued(bytes32 roundtripId);
    event IncomingMessageWithTransferQueued(bytes32 roundtripId, uint256 amount, bool isLocalBridge);

    // IMCeler inherited classes are responsible for firing events indicating successful processing of incoming messages

    event ConfigurationUpdated();

    constructor(address _messageBus, address _quoteToken) {
        messageBus = _messageBus;
        quoteToken = _quoteToken;
    }

    modifier onlyMessageBusOrOwner() {
        require(msg.sender == messageBus || msg.sender == owner(), "MESSAGEBUS_OR_OWNER");
        _;
    }

    modifier onlyFromPeer(address _peerAddress, uint64 _peerChainId) {
        require(peerAddress == _peerAddress && peerChainId == _peerChainId, "PEER");
        _;
    }

    modifier onlyUnique(bytes memory message) {
        uint256 roundtripId = uint256(Serializer.getRoundtripIdFromMessage(message));

        if (BitMaps.get(seenRoundtripId, roundtripId)) {
            revert("UNIQUE");
        }

        BitMaps.set(seenRoundtripId, roundtripId);

        _;
    }

    function onMessage(bytes memory message) internal virtual;
    function onMessageWithTransfer(bytes memory message, uint256 amount) internal virtual;

    function executeMessageWithTransfer(
        address sender,
        address token,
        uint256 amount,
        uint64 srcChainId,
        bytes calldata incomingMessage,
        address executor
    )
        external
        payable
        override
        onlyMessageBusOrOwner
        onlyFromPeer(sender, srcChainId)
        onlyUnique(incomingMessage)
        returns (ExecutionStatus)
    {
        require(amount > 0, "ZERO_BRIDGED");
        require(token == quoteToken, "QUOTE_TOKEN");
        require(IERC20(quoteToken).balanceOf(address(this)) >= amount, "INSUFFICIENT_BRIDGED");

        incomingMessageQueue.push(MessageWithTransferQueueEntry({
            amount: amount,
            message: incomingMessage,
            isLocalBridge: false
        }));

        bytes32 roundtripId = Serializer.getRoundtripIdFromMessage(incomingMessage);
        emit IncomingMessageWithTransferQueued(roundtripId, amount, false);

        _refundMsgValue(executor);

        return ExecutionStatus.Success;
    }

    function executeMessageWithTransferRefund(
        address token, // solhint-disable-line no-unused-vars
        uint256 amount,
        bytes calldata incomingMessage,
        address executor
    )
        external
        payable
        override
        onlyMessageBusOrOwner
        onlyUnique(incomingMessage)
        returns (ExecutionStatus)
    {
        bytes32 roundtripId = Serializer.getRoundtripIdFromMessage(incomingMessage);
        emit OutgoingMessageWithTransferRefund(roundtripId, amount);

        _refundMsgValue(executor);

        return ExecutionStatus.Success;
    }

    function executeMessageWithTransferFallback(
        address sender,
        address token, // solhint-disable-line no-unused-vars
        uint256 amount,
        uint64 srcChainId,
        bytes calldata incomingMessage,
        address executor
    )
        external
        payable
        override
        onlyMessageBusOrOwner
        onlyFromPeer(sender, srcChainId)
        onlyUnique(incomingMessage)
        returns (ExecutionStatus)
    {
        bytes32 roundtripId = Serializer.getRoundtripIdFromMessage(incomingMessage);
        emit OutgoingMessageWithTransferFallback(roundtripId, amount);

        _refundMsgValue(executor);

        return ExecutionStatus.Success;
    }

    function executeMessage(
        address sender,
        uint64 srcChainId,
        bytes calldata incomingMessage,
        address executor
    )
        external
        payable
        override
        onlyMessageBusOrOwner
        onlyFromPeer(sender, srcChainId)
        onlyUnique(incomingMessage)
        returns (ExecutionStatus)
    {
        (bytes32 roundtripId, uint256 amount, uint8 peerDecimals, bytes memory message) = abi.decode(incomingMessage, (bytes32, uint256, uint8, bytes));

        bool isLocalBridge = amount > 0;

        if (isLocalBridge) {
            uint8 myDecimals = IERC20Metadata(quoteToken).decimals();
            if (myDecimals > peerDecimals) {
                amount *= (10 ** (myDecimals - peerDecimals));
            } else if (myDecimals < peerDecimals) {
                amount /= (10 ** (peerDecimals - myDecimals));
            } // bear in mind to keep amount intact in case decimals are equal
        }

        incomingMessageQueue.push(MessageWithTransferQueueEntry({
            amount: amount,
            message: message,
            isLocalBridge: isLocalBridge
        }));

        if (isLocalBridge) {
            emit IncomingMessageWithTransferQueued(roundtripId, amount, true);

        } else {
            emit IncomingMessageQueued(roundtripId);
        }

        _refundMsgValue(executor);

        return ExecutionStatus.Success;
    }

    // non-evm variant
    function executeMessage(
        bytes calldata sender, // solhint-disable-line no-unused-vars
        uint64 srcChainId, // solhint-disable-line no-unused-vars
        bytes calldata incomingMessage,
        address executor
    )
        external
        payable
        override
        onlyMessageBusOrOwner
        // onlyFromPeer(sender, srcChainId) // not yet.
        onlyUnique(incomingMessage)
        returns (ExecutionStatus)
    {
        _refundMsgValue(executor);
        return ExecutionStatus.Fail;
    }

    function tossIncomingMessageQueue()
        public
        payable
    {
        require(incomingMessageQueue.length > 0, "EMPTY");

        uint256 originalBalance = address(this).balance;

        uint256 totalLocalBridgeAmount = 0;
        for (uint i=0; i<incomingMessageQueue.length; i++) {
            if (incomingMessageQueue[i].isLocalBridge) {
                totalLocalBridgeAmount += incomingMessageQueue[i].amount;
            }
        }

        if (totalLocalBridgeAmount > 0) {
            IERC20(quoteToken).transferFrom(localBridgeCustodian, address(this), totalLocalBridgeAmount);
        }

        for (uint i=0; i<incomingMessageQueue.length; i++) {
            if (incomingMessageQueue[i].amount == 0) {
                onMessage(incomingMessageQueue[i].message);
            } else {
                onMessageWithTransfer(incomingMessageQueue[i].message, incomingMessageQueue[i].amount);
            }
        }

        delete incomingMessageQueue;

        uint256 feePaid = originalBalance - address(this).balance;
        if (feePaid < msg.value) {
            payable(msg.sender).transfer(msg.value - feePaid);
        }
    }

    function sendMessage(bytes memory message)
        internal
        returns (uint256 fee)
    {
        bytes32 roundtripId = Serializer.getRoundtripIdFromMessage(message);

        bytes memory transferMessage = abi.encode(roundtripId, uint256(0), uint8(0), message);

        fee = IMessageBus(messageBus).calcFee(transferMessage);
        require(address(this).balance >= fee, "CELER_FEE");

        MessageSenderLib.sendMessage(peerAddress, peerChainId, transferMessage, messageBus, fee);

        emit OutgoingMessageSent(roundtripId);
    }

    function sendMessageWithTransfer(uint256 amount, bytes memory message)
        internal
        returns (uint256 fee)
    {
        bytes32 roundtripId = Serializer.getRoundtripIdFromMessage(message);

        bool isLocalBridge = amount < localBridgeTresholdAmount && localBridgeCustodian != address(0);

        if (isLocalBridge) {
            bytes memory transferMessage = abi.encode(roundtripId, amount, uint8(IERC20Metadata(quoteToken).decimals()), message);

            fee = IMessageBus(messageBus).calcFee(transferMessage);
            require(address(this).balance >= fee, "CELER_FEE");

            MessageSenderLib.sendMessage(peerAddress, peerChainId, transferMessage, messageBus, fee);

            IERC20(quoteToken).transfer(localBridgeCustodian, amount);

        } else {
            fee = IMessageBus(messageBus).calcFee(message);
            require(address(this).balance >= fee, "CELER_FEE");

            MessageSenderLib.sendMessageWithTransfer(
                peerAddress,
                quoteToken,
                amount,
                peerChainId,
                celerSendMessageWithTransferNonce,
                maxSlippage,
                message,
                MsgDataTypes.BridgeSendType.Liquidity,
                messageBus,
                fee
            );

            celerSendMessageWithTransferNonce++;
        }

        emit OutgoingMessageWithTransferSent(roundtripId, amount, isLocalBridge);
    }

    function clearIncomingMessageQueue()
        public
        onlyOwner
    {
        delete incomingMessageQueue;
    }

    function setPeer(address _peerAddress, uint64 _peerChainId)
        public
        onlyOwner
    {
        peerAddress = _peerAddress;
        peerChainId = _peerChainId;

        emit ConfigurationUpdated();
    }

    function setMaxSlippage(uint32 _maxSlippage)
        public
        onlyOwner
    {
        maxSlippage = _maxSlippage;
        emit ConfigurationUpdated();
    }

    function setQuoteToken(address _quoteToken)
        public
        onlyOwner
    {
        quoteToken = _quoteToken;
        emit ConfigurationUpdated();
    }

    function setLocalBridgeProperties(address _localBridgeCustodian, uint256 _localBridgeTresholdAmount)
        public
        onlyOwner
    {
        require(_localBridgeCustodian == address(0) || IERC20(quoteToken).allowance(_localBridgeCustodian, address(this)) > 0, "ALLOWANCE");

        localBridgeCustodian = _localBridgeCustodian;
        localBridgeTresholdAmount = _localBridgeTresholdAmount;

        emit ConfigurationUpdated();
    }

    function isSeenRoundtripId(bytes32 roundtripId)
        public
        view
        returns (bool)
    {
        return BitMaps.get(seenRoundtripId, uint256(roundtripId));
    }

    function markRoundtripId(bytes32 roundtripId, bool isUsed)
        public
        onlyOwner
    {
        if (isUsed) {
            BitMaps.set(seenRoundtripId, uint256(roundtripId));
            return;
        }

        BitMaps.unset(seenRoundtripId, uint256(roundtripId));
    }

    function collectTokens(address[] memory tokens, address to)
        public
        onlyOwner
    {
        CollectTokens._collectTokens(tokens, to);
    }

    // Some methods must be `payable` while in fact they
    // do not consume any native tokens. We refund `msg.value`
    // in full for those methods.
    function _refundMsgValue(address executor)
        internal
    {
        if (msg.value > 0) {
            payable(executor).transfer(msg.value);
        }
    }

    function _shutdown()
        internal
    {
        require(incomingMessageQueue.length == 0, "QUEUE");

        // deleting peer ensures that noone can execute messages anymore
        delete peerChainId;
        delete peerAddress;

        delete quoteToken;
        delete incomingMessageQueue;
        delete seenRoundtripId;
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.9;

/* solhint-disable */

interface ICFarmBeets {
    function addLiquidityAndStake(bool shouldIncreaseTotalLocked) external returns (uint256 lpAmount, uint256 cFarmAmount);
    function unstakeAndRemoveLiquidity(uint256 cFarmAmount) external returns (uint256 quoteTokenAmount);
    function harvest() external;
    function rewardToken() external view returns (address);
    function quoteToken() external view returns (address);
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

struct QueueEntry {
    address account;
    uint256 amount;
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

interface ISwapHelper {
    function swap(address from, address to, address recipient)
        external
        returns (uint256);
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library CollectTokens {
    using SafeERC20 for IERC20;

    function _collectTokens(address[] memory tokens, address to)
        internal
    {
        for (uint i=0; i<tokens.length; i++) {
            _collect(tokens[i], to);
        }
    }

    function _collect(address tokenAddress, address to)
        internal
    {
        if (tokenAddress == address(0)) {
            if (address(this).balance == 0) {
                return;
            }

            payable(to).transfer(address(this).balance);

            return;
        }

        uint256 _balance = IERC20(tokenAddress).balanceOf(address(this));
        if (_balance == 0) {
            return;
        }

        IERC20(tokenAddress).safeTransfer(to, _balance);
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

// we actually do use assembly to parse roundtrips
/* solhint-disable no-inline-assembly */

import "../interfaces/IQueueEntry.sol";

uint8 constant MESSAGE_KIND_INVEST = 1;
uint8 constant MESSAGE_KIND_WITHDRAW = 2;
uint8 constant MESSAGE_KIND_REWARD = 3;

library Serializer {
    function createQueueMessage(bytes32 roundtripId, uint256 totalAmount, QueueEntry[] memory queue)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(roundtripId, totalAmount, queue);
    }

    function parseQueueMessage(bytes memory message)
        internal
        pure
        returns (bytes32 roundtripId, uint256 totalAmount, QueueEntry[] memory queue)
    {
        (roundtripId, totalAmount, queue) = abi.decode(message, (bytes32, uint256, QueueEntry[]));
    }

    function createRewardMessage(bytes32 rewardMessageId, uint256 rewardAmount)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encode(rewardMessageId, rewardAmount);
    }

    function parseRewardMessage(bytes memory message)
        internal
        pure
        returns (bytes32 rewardMessageId, uint256 rewardAmount)
    {
        (rewardMessageId, rewardAmount) = abi.decode(message, (bytes32, uint256));
    }

    function getMessageKindFromMessage(bytes memory message)
        internal
        pure
        returns (uint8 messageKind)
    {
        return uint8(message[0]);
    }

    function getRoundtripIdFromMessage(bytes memory message)
        internal
        pure
        returns (bytes32 roundtripId)
    {
        assembly {
            roundtripId := mload(add(message, 32))
        }
    }
}

// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.15;

import "../interfaces/IQueueEntry.sol";

library Tools {
    function sumAmountFromQueue(QueueEntry[] memory queue)
        internal
        pure
        returns (uint256 amount)
    {
        for (uint256 i=0; i<queue.length; i++) {
            amount += queue[i].amount;
        }
    }

    function createScaledQueueFromQueue(uint256 mulAmount, uint256 divAmount, QueueEntry[] memory incomingQueue)
        internal
        pure
        returns (QueueEntry[] memory outgoingQueue)
    {
        outgoingQueue = new QueueEntry[](incomingQueue.length);

        for (uint256 i=0; i<incomingQueue.length; i++) {
            QueueEntry memory entry = incomingQueue[i];

            uint256 amount = entry.amount * mulAmount / divAmount;

            outgoingQueue[i] = QueueEntry({
                account: entry.account,
                amount: amount
            });
        }
    }

    // from @uniswap/v2-core/contracts/libraries/Math.sol
    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y)
        internal
        pure
        returns (uint z)
    {
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

    function getSwapAmountForSingleSideUniswap(uint256 amountA, uint256 reserveA, uint256 fee)
        internal
        pure
        returns (uint256)
    {
        return (sqrt(((2000 - fee) * reserveA) ** 2 + 4 * 1000 * (1000 - fee) * amountA * reserveA) - (2000 - fee) * reserveA) / (2 * (1000 - fee));
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IBridge {
    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) external;

    function sendNative(
        address _receiver,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) external payable;

    function relay(
        bytes calldata _relayRequest,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;

    function transfers(bytes32 transferId) external view returns (bool);

    function withdraws(bytes32 withdrawId) external view returns (bool);

    function withdraw(
        bytes calldata _wdmsg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;

    /**
     * @notice Verifies that a message is signed by a quorum among the signers.
     * @param _msg signed message
     * @param _sigs list of signatures sorted by signer addresses in ascending order
     * @param _signers sorted list of current signers
     * @param _powers powers of current signers
     */
    function verifySigs(
        bytes memory _msg,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external view;
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IOriginalTokenVault {
    /**
     * @notice Lock original tokens to trigger mint at a remote chain's PeggedTokenBridge
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _mintAccount destination account to receive minted tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external;

    /**
     * @notice Lock native token as original token to trigger mint at a remote chain's PeggedTokenBridge
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _mintAccount destination account to receive minted tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function depositNative(
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external payable;

    /**
     * @notice Withdraw locked original tokens triggered by a burn at a remote chain's PeggedTokenBridge.
     * @param _request The serialized Withdraw protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;

    function records(bytes32 recordId) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IOriginalTokenVaultV2 {
    /**
     * @notice Lock original tokens to trigger mint at a remote chain's PeggedTokenBridge
     * @param _token local token address
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _mintAccount destination account to receive minted tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external returns (bytes32);

    /**
     * @notice Lock native token as original token to trigger mint at a remote chain's PeggedTokenBridge
     * @param _amount locked token amount
     * @param _mintChainId destination chainId to mint tokens
     * @param _mintAccount destination account to receive minted tokens
     * @param _nonce user input to guarantee unique depositId
     */
    function depositNative(
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external payable returns (bytes32);

    /**
     * @notice Withdraw locked original tokens triggered by a burn at a remote chain's PeggedTokenBridge.
     * @param _request The serialized Withdraw protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external returns (bytes32);

    function records(bytes32 recordId) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IPeggedTokenBridge {
    /**
     * @notice Burn tokens to trigger withdrawal at a remote chain's OriginalTokenVault
     * @param _token local token address
     * @param _amount locked token amount
     * @param _withdrawAccount account who withdraw original tokens on the remote chain
     * @param _nonce user input to guarantee unique depositId
     */
    function burn(
        address _token,
        uint256 _amount,
        address _withdrawAccount,
        uint64 _nonce
    ) external;

    /**
     * @notice Mint tokens triggered by deposit at a remote chain's OriginalTokenVault.
     * @param _request The serialized Mint protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function mint(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;

    function records(bytes32 recordId) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IPeggedTokenBridgeV2 {
    /**
     * @notice Burn pegged tokens to trigger a cross-chain withdrawal of the original tokens at a remote chain's
     * OriginalTokenVault, or mint at another remote chain
     * @param _token The pegged token address.
     * @param _amount The amount to burn.
     * @param _toChainId If zero, withdraw from original vault; otherwise, the remote chain to mint tokens.
     * @param _toAccount The account to receive tokens on the remote chain
     * @param _nonce A number to guarantee unique depositId. Can be timestamp in practice.
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external returns (bytes32);

    // same with `burn` above, use openzeppelin ERC20Burnable interface
    function burnFrom(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external returns (bytes32);

    /**
     * @notice Mint tokens triggered by deposit at a remote chain's OriginalTokenVault.
     * @param _request The serialized Mint protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function mint(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external returns (bytes32);

    function records(bytes32 recordId) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "../libraries/MsgDataTypes.sol";

interface IMessageBus {
    /**
     * @notice Send a message to a contract on another chain.
     * Sender needs to make sure the uniqueness of the message Id, which is computed as
     * hash(type.MessageOnly, sender, receiver, srcChainId, srcTxHash, dstChainId, message).
     * If messages with the same Id are sent, only one of them will succeed at dst chain..
     * A fee is charged in the native gas token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessage(
        address _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable;

    // same as above, except that receiver is an non-evm chain address,
    function sendMessage(
        bytes calldata _receiver,
        uint256 _dstChainId,
        bytes calldata _message
    ) external payable;

    /**
     * @notice Send a message associated with a token transfer to a contract on another chain.
     * If messages with the same srcTransferId are sent, only one of them will succeed at dst chain..
     * A fee is charged in the native token.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _srcBridge The bridge contract to send the transfer with.
     * @param _srcTransferId The transfer ID.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     */
    function sendMessageWithTransfer(
        address _receiver,
        uint256 _dstChainId,
        address _srcBridge,
        bytes32 _srcTransferId,
        bytes calldata _message
    ) external payable;

    /**
     * @notice Execute a message not associated with a transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessage(
        bytes calldata _message,
        MsgDataTypes.RouteInfo calldata _route,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable;

    /**
     * @notice Execute a message with a successful transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransfer(
        bytes calldata _message,
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable;

    /**
     * @notice Execute a message with a refunded transfer.
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _transfer The transfer info.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function executeMessageWithTransferRefund(
        bytes calldata _message, // the same message associated with the original transfer
        MsgDataTypes.TransferInfo calldata _transfer,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external payable;

    /**
     * @notice Withdraws message fee in the form of native gas token.
     * @param _account The address receiving the fee.
     * @param _cumulativeFee The cumulative fee credited to the account. Tracked by SGN.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A withdrawal must be
     * signed-off by +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdrawFee(
        address _account,
        uint256 _cumulativeFee,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external;

    /**
     * @notice Calculates the required fee for the message.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     @ @return The required fee.
     */
    function calcFee(bytes calldata _message) external view returns (uint256);

    function liquidityBridge() external view returns (address);

    function pegBridge() external view returns (address);

    function pegBridgeV2() external view returns (address);

    function pegVault() external view returns (address);

    function pegVaultV2() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

interface IMessageReceiverApp {
    enum ExecutionStatus {
        Fail, // execution failed, finalized
        Success, // execution succeeded, finalized
        Retry // execution rejected, can retry later
    }

    /**
     * @notice Called by MessageBus to execute a message
     * @param _sender The address of the source app contract
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessage(
        address _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    // same as above, except that sender is an non-evm chain address,
    // otherwise same as above.
    function executeMessage(
        bytes calldata _sender,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus to execute a message with an associated token transfer.
     * The contract is guaranteed to have received the right amount of tokens before this function is called.
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransfer(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Only called by MessageBus if
     *         1. executeMessageWithTransfer reverts, or
     *         2. executeMessageWithTransfer returns ExecutionStatus.Fail
     * The contract is guaranteed to have received the right amount of tokens before this function is called.
     * @param _sender The address of the source app contract
     * @param _token The address of the token that comes out of the bridge
     * @param _amount The amount of tokens received at this contract through the cross-chain bridge.
     * @param _srcChainId The source chain ID where the transfer is originated from
     * @param _message Arbitrary message bytes originated from and encoded by the source app contract
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferFallback(
        address _sender,
        address _token,
        uint256 _amount,
        uint64 _srcChainId,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);

    /**
     * @notice Called by MessageBus to process refund of the original transfer from this contract.
     * The contract is guaranteed to have received the refund before this function is called.
     * @param _token The token address of the original transfer
     * @param _amount The amount of the original transfer
     * @param _message The same message associated with the original transfer
     * @param _executor Address who called the MessageBus execution function
     */
    function executeMessageWithTransferRefund(
        address _token,
        uint256 _amount,
        bytes calldata _message,
        address _executor
    ) external payable returns (ExecutionStatus);
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/IBridge.sol";
import "../../interfaces/IOriginalTokenVault.sol";
import "../../interfaces/IOriginalTokenVaultV2.sol";
import "../../interfaces/IPeggedTokenBridge.sol";
import "../../interfaces/IPeggedTokenBridgeV2.sol";
import "../interfaces/IMessageBus.sol";
import "./MsgDataTypes.sol";

library MessageSenderLib {
    using SafeERC20 for IERC20;

    // ============== Internal library functions called by apps ==============

    /**
     * @notice Sends a message to an app on another chain via MessageBus without an associated transfer.
     * @param _receiver The address of the destination app contract.
     * @param _dstChainId The destination chain ID.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     * @param _messageBus The address of the MessageBus on this chain.
     * @param _fee The fee amount to pay to MessageBus.
     */
    function sendMessage(
        address _receiver,
        uint64 _dstChainId,
        bytes memory _message,
        address _messageBus,
        uint256 _fee
    ) internal {
        IMessageBus(_messageBus).sendMessage{value: _fee}(_receiver, _dstChainId, _message);
    }

    // Send message to non-evm chain with bytes for receiver address,
    // otherwise same as above.
    function sendMessage(
        bytes calldata _receiver,
        uint64 _dstChainId,
        bytes memory _message,
        address _messageBus,
        uint256 _fee
    ) internal {
        IMessageBus(_messageBus).sendMessage{value: _fee}(_receiver, _dstChainId, _message);
    }

    /**
     * @notice Sends a message to an app on another chain via MessageBus with an associated transfer.
     * @param _receiver The address of the destination app contract.
     * @param _token The address of the token to be sent.
     * @param _amount The amount of tokens to be sent.
     * @param _dstChainId The destination chain ID.
     * @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
     * @param _maxSlippage The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
     * Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least (100% - max slippage percentage) * amount or the
     * transfer can be refunded. Only applicable to the {MsgDataTypes.BridgeSendType.Liquidity}.
     * @param _message Arbitrary message bytes to be decoded by the destination app contract.
     * @param _bridgeSendType One of the {MsgDataTypes.BridgeSendType} enum.
     * @param _messageBus The address of the MessageBus on this chain.
     * @param _fee The fee amount to pay to MessageBus.
     * @return The transfer ID.
     */
    function sendMessageWithTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        bytes memory _message,
        MsgDataTypes.BridgeSendType _bridgeSendType,
        address _messageBus,
        uint256 _fee
    ) internal returns (bytes32) {
        (bytes32 transferId, address bridge) = sendTokenTransfer(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage,
            _bridgeSendType,
            _messageBus
        );
        if (_message.length > 0) {
            IMessageBus(_messageBus).sendMessageWithTransfer{value: _fee}(
                _receiver,
                _dstChainId,
                bridge,
                transferId,
                _message
            );
        }
        return transferId;
    }

    /**
     * @notice Sends a token transfer via a bridge.
     * @param _receiver The address of the destination app contract.
     * @param _token The address of the token to be sent.
     * @param _amount The amount of tokens to be sent.
     * @param _dstChainId The destination chain ID.
     * @param _nonce A number input to guarantee uniqueness of transferId. Can be timestamp in practice.
     * @param _maxSlippage The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
     * Must be greater than minimalMaxSlippage. Receiver is guaranteed to receive at least (100% - max slippage percentage) * amount or the
     * transfer can be refunded.
     * @param _bridgeSendType One of the {MsgDataTypes.BridgeSendType} enum.
     */
    function sendTokenTransfer(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage,
        MsgDataTypes.BridgeSendType _bridgeSendType,
        address _messageBus
    ) internal returns (bytes32 transferId, address bridge) {
        if (_bridgeSendType == MsgDataTypes.BridgeSendType.Liquidity) {
            bridge = IMessageBus(_messageBus).liquidityBridge();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            IBridge(bridge).send(_receiver, _token, _amount, _dstChainId, _nonce, _maxSlippage);
            transferId = computeLiqBridgeTransferId(_receiver, _token, _amount, _dstChainId, _nonce);
        } else if (_bridgeSendType == MsgDataTypes.BridgeSendType.PegDeposit) {
            bridge = IMessageBus(_messageBus).pegVault();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            IOriginalTokenVault(bridge).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
            transferId = computePegV1DepositId(_receiver, _token, _amount, _dstChainId, _nonce);
        } else if (_bridgeSendType == MsgDataTypes.BridgeSendType.PegBurn) {
            bridge = IMessageBus(_messageBus).pegBridge();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            IPeggedTokenBridge(bridge).burn(_token, _amount, _receiver, _nonce);
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(bridge, 0);
            transferId = computePegV1BurnId(_receiver, _token, _amount, _nonce);
        } else if (_bridgeSendType == MsgDataTypes.BridgeSendType.PegV2Deposit) {
            bridge = IMessageBus(_messageBus).pegVaultV2();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            transferId = IOriginalTokenVaultV2(bridge).deposit(_token, _amount, _dstChainId, _receiver, _nonce);
        } else if (_bridgeSendType == MsgDataTypes.BridgeSendType.PegV2Burn) {
            bridge = IMessageBus(_messageBus).pegBridgeV2();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            transferId = IPeggedTokenBridgeV2(bridge).burn(_token, _amount, _dstChainId, _receiver, _nonce);
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(bridge, 0);
        } else if (_bridgeSendType == MsgDataTypes.BridgeSendType.PegV2BurnFrom) {
            bridge = IMessageBus(_messageBus).pegBridgeV2();
            IERC20(_token).safeIncreaseAllowance(bridge, _amount);
            transferId = IPeggedTokenBridgeV2(bridge).burnFrom(_token, _amount, _dstChainId, _receiver, _nonce);
            // handle cases where certain tokens do not spend allowance for role-based burn
            IERC20(_token).safeApprove(bridge, 0);
        } else {
            revert("bridge type not supported");
        }
    }

    function computeLiqBridgeTransferId(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(address(this), _receiver, _token, _amount, _dstChainId, _nonce, uint64(block.chainid))
            );
    }

    function computePegV1DepositId(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce
    ) internal view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(address(this), _token, _amount, _dstChainId, _receiver, _nonce, uint64(block.chainid))
            );
    }

    function computePegV1BurnId(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _nonce
    ) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), _token, _amount, _receiver, _nonce, uint64(block.chainid)));
    }
}

// SPDX-License-Identifier: GPL-3.0-only

pragma solidity >=0.8.0;

library MsgDataTypes {
    string constant ABORT_PREFIX = "MSG::ABORT:";

    // bridge operation type at the sender side (src chain)
    enum BridgeSendType {
        Null,
        Liquidity,
        PegDeposit,
        PegBurn,
        PegV2Deposit,
        PegV2Burn,
        PegV2BurnFrom
    }

    // bridge operation type at the receiver side (dst chain)
    enum TransferType {
        Null,
        LqRelay, // relay through liquidity bridge
        LqWithdraw, // withdraw from liquidity bridge
        PegMint, // mint through pegged token bridge
        PegWithdraw, // withdraw from original token vault
        PegV2Mint, // mint through pegged token bridge v2
        PegV2Withdraw // withdraw from original token vault v2
    }

    enum MsgType {
        MessageWithTransfer,
        MessageOnly
    }

    enum TxStatus {
        Null,
        Success,
        Fail,
        Fallback,
        Pending // transient state within a transaction
    }

    struct TransferInfo {
        TransferType t;
        address sender;
        address receiver;
        address token;
        uint256 amount;
        uint64 wdseq; // only needed for LqWithdraw (refund)
        uint64 srcChainId;
        bytes32 refId;
        bytes32 srcTxHash; // src chain msg tx hash
    }

    struct RouteInfo {
        address sender;
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash; // src chain msg tx hash
    }

    // used for msg from non-evm chains with longer-bytes address
    struct RouteInfo2 {
        bytes sender;
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash;
    }

    // combination of RouteInfo and RouteInfo2 for easier processing
    struct Route {
        address sender; // from RouteInfo
        bytes senderBytes; // from RouteInfo2
        address receiver;
        uint64 srcChainId;
        bytes32 srcTxHash;
    }

    struct MsgWithTransferExecutionParams {
        bytes message;
        TransferInfo transfer;
        bytes[] sigs;
        address[] signers;
        uint256[] powers;
    }

    struct BridgeTransferParams {
        bytes request;
        bytes[] sigs;
        address[] signers;
        uint256[] powers;
    }
}