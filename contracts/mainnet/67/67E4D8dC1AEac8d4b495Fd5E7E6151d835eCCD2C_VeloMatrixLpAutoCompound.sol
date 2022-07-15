// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/Ownable.sol)

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
// OpenZeppelin Contracts v4.4.1 (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
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
// OpenZeppelin Contracts v4.4.1 (utils/structs/EnumerableSet.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastvalue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastvalue;
                // Update the index for the moved value
                set._indexes[lastvalue] = valueIndex; // Replace lastvalue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        return _values(set._inner);
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        assembly {
            result := store
        }

        return result;
    }
}

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IGauge {

    function deposit(uint256 _amount, uint256 _tokenId) external;
    function depositAll(uint256 _tokenId) external;
    function withdraw(uint _amount) external;
    function withdrawAll() external;
    function claimFees() external;
    function getReward(address _account, address[] memory _tokens) external;
    function earned(address _token, address _account) external view returns (uint256);
    function balanceOf(address _from) external view returns (uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

interface IMasterChef {
    function pendingShare(uint256 _pid, address _user)
        external
        view
        returns (uint256);

    function deposit(uint256 _pid, uint256 _amount) external;
    function deposit(uint256 _pid, uint256 _amount, address _to) external;
    function harvest(uint256 _pid, address _to) external;

    function withdraw(uint256 _pid, uint256 _amount) external;

    function withdrawAndHarvest(uint256 _pid, uint256 _amount, address _to) external;

    function withdrawAndHarvestShort(uint256 _pid, uint128 _amount) external;
    function harvestShort(uint256 _pid) external;
    function depositShort(uint256 _pid, uint128 _amount) external;
    function userInfo(uint256 _pid, address _user)
        external
        view
        returns (uint256, uint256);

    function emergencyWithdraw(uint256 _pid) external;
    function withdrawAll(uint256 _pid) external;

    function emergencyWithdraw(uint256 _pid, address _to) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMatrixStrategy {
    function vault() external view returns (address);

    function want() external view returns (IERC20);

    function beforeDeposit() external;

    function deposit() external;

    function withdraw(uint256) external;

    function balanceOf() external view returns (uint256);

    function harvest() external;

    function retireStrat() external;

    function panic() external;

    function pause() external;

    function unpause() external;

    function paused() external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IUniswapV2Pair {
  event Approval(address indexed owner, address indexed spender, uint value);
  event Transfer(address indexed from, address indexed to, uint value);

  function name() external pure returns (string memory);

  function symbol() external pure returns (string memory);

  function decimals() external pure returns (uint8);

  function totalSupply() external view returns (uint);

  function balanceOf(address owner) external view returns (uint);

  function allowance(address owner, address spender) external view returns (uint);

  function approve(address spender, uint value) external returns (bool);

  function transfer(address to, uint value) external returns (bool);

  function transferFrom(
    address from,
    address to,
    uint value
  ) external returns (bool);

  function DOMAIN_SEPARATOR() external view returns (bytes32);

  function PERMIT_TYPEHASH() external pure returns (bytes32);

  function nonces(address owner) external view returns (uint);

  function permit(
    address owner,
    address spender,
    uint value,
    uint deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  event Mint(address indexed sender, uint amount0, uint amount1);
  event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
  event Swap(
    address indexed sender,
    uint amount0In,
    uint amount1In,
    uint amount0Out,
    uint amount1Out,
    address indexed to
  );
  event Sync(uint112 reserve0, uint112 reserve1);

  function MINIMUM_LIQUIDITY() external pure returns (uint);

  function factory() external view returns (address);

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

  function price0CumulativeLast() external view returns (uint);

  function price1CumulativeLast() external view returns (uint);

  function kLast() external view returns (uint);

  function mint(address to) external returns (uint liquidity);

  function burn(address to) external returns (uint amount0, uint amount1);

  function swap(
    uint amount0Out,
    uint amount1Out,
    address to,
    bytes calldata data
  ) external;

  function skim(address to) external;

  function sync() external;

  function initialize(address, address) external;

  function stable() external returns (bool);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

struct route {
    address from;
    address to;
    bool stable;
}

interface IVelodromeRouter {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        route[] calldata routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "./MatrixStrategyBase.sol";
import "./MatrixSwapHelper.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IMasterChef.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title Base Lp+MasterChef AutoCompound Strategy Framework,
/// all LP strategies will inherit this contract
contract MatrixLpAutoCompound is MatrixStrategyBase, MatrixSwapHelper {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public poolId;
    address public masterchef;
    address public output;
    address public lpToken0;
    address public lpToken1;
    address public USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;

    constructor(
        address _want,
        uint256 _poolId,
        address _masterchef,
        address _output,
        address _uniRouter,
        address _vault,
        address _treasury
    )
        MatrixStrategyBase(_want, _vault, _treasury)
        MatrixSwapHelper(_uniRouter)
    {
        _initialize(_masterchef, _output, _poolId);
    }

    function _initialize(
        address _masterchef,
        address _output,
        uint256 _poolId
    ) internal virtual {
        masterchef = _masterchef;
        output = _output;
        lpToken0 = IUniswapV2Pair(want).token0();
        lpToken1 = IUniswapV2Pair(want).token1();
        poolId = _poolId;

        _setWhitelistedAddresses();
        _setDefaultSwapPaths();
        _giveAllowances();
    }

    /// @notice Allows strategy governor to setup custom path and dexes for token swaps
    function setSwapPath(
        address _fromToken,
        address _toToken,
        address _unirouter,
        address[] memory _path
    ) external onlyOwner {
        _setSwapPath(_fromToken, _toToken, _unirouter, _path);
    }

    /// @notice Override this to enable other routers or token swap paths
    function _setWhitelistedAddresses() internal virtual {
        whitelistedAddresses.add(unirouter);
        whitelistedAddresses.add(USDC);
        whitelistedAddresses.add(want);
        whitelistedAddresses.add(output);
        whitelistedAddresses.add(wrapped);
        whitelistedAddresses.add(lpToken0);
        whitelistedAddresses.add(lpToken1);
    }

    function _setDefaultSwapPaths() internal virtual {
        // Default output to lp0 paths
        if (lpToken0 == wrapped) {
            address[] memory _path = new address[](2);
            _path[0] = output;
            _path[1] = wrapped;
            _setSwapPath(output, lpToken0, address(0), _path);
        } else if (lpToken0 != output) {
            address[] memory _path = new address[](3);
            _path[0] = output;
            _path[1] = wrapped;
            _path[2] = lpToken0;
            _setSwapPath(output, lpToken0, address(0), _path);
        }

        // Default output to lp1 paths
        if (lpToken1 == wrapped) {
            address[] memory _path = new address[](2);
            _path[0] = output;
            _path[1] = wrapped;
            _setSwapPath(output, lpToken1, address(0), _path);
        } else if (lpToken1 != output) {
            address[] memory _path = new address[](3);
            _path[0] = output;
            _path[1] = wrapped;
            _path[2] = lpToken1;
            _setSwapPath(output, lpToken1, address(0), _path);
        }

        if (output != wrapped) {
            address[] memory _path = new address[](2);
            _path[0] = output;
            _path[1] = wrapped;
            _setSwapPath(output, wrapped, address(0), _path);
        }
    }

    function _giveAllowances() internal override {
        IERC20(want).safeApprove(masterchef, 0);
        IERC20(want).safeApprove(masterchef, type(uint256).max);

        IERC20(output).safeApprove(unirouter, 0);
        IERC20(output).safeApprove(unirouter, type(uint256).max);

        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, type(uint256).max);

        IERC20(lpToken1).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, type(uint256).max);
    }

    function _removeAllowances() internal override {
        IERC20(want).safeApprove(masterchef, 0);
        IERC20(output).safeApprove(unirouter, 0);
        IERC20(lpToken0).safeApprove(unirouter, 0);
        IERC20(lpToken1).safeApprove(unirouter, 0);
    }

    /// @dev total value managed by strategy is want + want staked in MasterChef
    function totalValue() public view virtual override returns (uint256) {
        (uint256 _totalStaked, ) = IMasterChef(masterchef).userInfo(
            poolId,
            address(this)
        );
        return IERC20(want).balanceOf(address(this)) + _totalStaked;
    }

    function _deposit() internal virtual override {
        uint256 _wantBalance = IERC20(want).balanceOf(address(this));
        IMasterChef(masterchef).deposit(poolId, _wantBalance);
    }

    function _beforeWithdraw(uint256 _amout) internal virtual override {
        IMasterChef(masterchef).withdraw(poolId, _amout);
    }

    function _beforeHarvest() internal virtual {
        IMasterChef(masterchef).deposit(poolId, 0);
    }

    function _harvest()
        internal
        virtual
        override
        returns (uint256 _wantHarvested, uint256 _wrappedFeesAccrued)
    {
        _beforeHarvest();
        uint256 _outputBalance = IERC20(output).balanceOf(address(this));
        if (_outputBalance > 0) {
            if (output != wrapped) {
                _wrappedFeesAccrued = _swap(
                    output,
                    wrapped,
                    (_outputBalance * totalFee) / PERCENT_DIVISOR
                );
                _outputBalance = IERC20(output).balanceOf(address(this));
            } else {
                _wrappedFeesAccrued =
                    (_outputBalance * totalFee) /
                    PERCENT_DIVISOR;
                _outputBalance -= _wrappedFeesAccrued;
            }
            _wantHarvested = _addLiquidity(_outputBalance);
            
            if (lpToken0 == wrapped || lpToken1 == wrapped) {
                // Anything left here in wrapped after adding liquidity
                // Are fees accrued
                _wrappedFeesAccrued = IERC20(wrapped).balanceOf(address(this));
            }
        }
    }

    function _addLiquidity(uint256 _outputAmount)
        internal
        virtual
        returns (uint256 _wantHarvested)
    {
        uint256 _wantBalanceBefore = IERC20(want).balanceOf(address(this));
        uint256 _lpToken0BalanceBefore = IERC20(lpToken0).balanceOf(
            address(this)
        );
        uint256 _lpToken1BalanceBefore = IERC20(lpToken1).balanceOf(
            address(this)
        );
        if (output == lpToken0) {
            _swap(output, lpToken1, _outputAmount / 2);
        } else if (output == lpToken1) {
            _swap(output, lpToken0, _outputAmount / 2);
        } else {
            _swap(output, lpToken0, _outputAmount / 2);
            _swap(output, lpToken1, IERC20(output).balanceOf(address(this)));
        }

        uint256 _lp0Balance = (lpToken0 != wrapped)
            ? IERC20(lpToken0).balanceOf(address(this))
            : IERC20(lpToken0).balanceOf(address(this)) -
                _lpToken0BalanceBefore;
        uint256 _lp1Balance = (lpToken1 != wrapped)
            ? IERC20(lpToken1).balanceOf(address(this))
            : IERC20(lpToken1).balanceOf(address(this)) -
                _lpToken1BalanceBefore;

        IUniswapV2Router02(unirouter).addLiquidity(
            lpToken0,
            lpToken1,
            _lp0Balance,
            _lp1Balance,
            1,
            1,
            address(this),
            block.timestamp
        );
        return IERC20(want).balanceOf(address(this)) - _wantBalanceBefore;
    }

    function _beforePanic() internal virtual override {
        IMasterChef(masterchef).emergencyWithdraw(poolId);
    }

    /// @dev _beforeRetireStrat behaves exactly like _beforePanic hook
    function _beforeRetireStrat() internal override {
        _beforePanic();
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../interfaces/IMatrixStrategy.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/// @title Base Strategy Framework, all strategies will inherit this
abstract contract MatrixStrategyBase is Ownable, Pausable {
    using SafeERC20 for IERC20;

    // Matrix contracts
    address public immutable vault;
    address public treasury;
    address public partner;

    // Tokens used
    address public wrapped =
        address(0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83);
    address public immutable want;

    uint256 public callFee = 1000;
    uint256 public partnerFee = 0;
    uint256 public treasuryFee = 9000;
    uint256 public securityFee = 10;
    uint256 public totalFee = 450;

    /***
     * {MAX_FEE} - Maximum fee allowed by the strategy. Hard-capped at 5%.
     * {PERCENT_DIVISOR} - Constant used to safely calculate the correct percentages.
     */

    uint256 public constant MAX_FEE = 500;
    uint256 public constant PERCENT_DIVISOR = 10000;

    /**
     * {Harvested} Event that is fired each time someone harvests the strat.
     * {TotalFeeUpdated} Event that is fired each time the total fee is updated.
     * {CallFeeUpdated} Event that is fired each time the call fee is updated.
     * {TreasuryUpdated} Event that is fired each time treasury address is updated.
     */
    event Harvested(
        address indexed harvester,
        uint256 _wantHarvested,
        uint256 _totalValueBefore,
        uint256 _totalValueAfter
    );
    event TotalFeeUpdated(uint256 newFee);
    event CallFeeUpdated(uint256 newCallFee, uint256 newTreasuryFee);
    event SecurityFeeUpdated(uint256 newSecurityFee);
    event PartnerFeeUpdated(uint256 newPartnerFee, uint256 newTreasuryFee);

    event TreasuryUpdated(
        address indexed _oldTreasury,
        address indexed _newTreasury
    );

    modifier onlyVault() {
        require(msg.sender == vault, "!vault");
        _;
    }

    constructor(
        address _want,
        address _vault,
        address _treasury
    ) {
        require(_vault != address(0), "vault-is-zero");
        require(_treasury != address(0), "treasury-is-zero");
        require(_want != address(0), "want-is-zero");

        vault = _vault;
        treasury = _treasury;
        want = _want;
    }

    /**
     * @dev updates the total fee, capped at 5%
     */
    function updateTotalFee(uint256 _totalFee)
        external
        onlyOwner
        returns (bool)
    {
        require(_totalFee <= MAX_FEE, "fee-too-high");
        totalFee = _totalFee;
        emit TotalFeeUpdated(totalFee);
        return true;
    }

    /**
     * @dev updates security fee, capped at 5%
     */
    function updateSecurityFee(uint256 _securityFee)
        external
        onlyOwner
        returns (bool)
    {
        require(_securityFee <= MAX_FEE, "fee-too-high");
        securityFee = _securityFee;
        emit SecurityFeeUpdated(securityFee);
        return true;
    }

    /**
     * @dev updates the call fee and adjusts the treasury fee to cover the difference
     */
    function updateCallFee(uint256 _callFee) external onlyOwner returns (bool) {
        callFee = _callFee;
        treasuryFee = PERCENT_DIVISOR - callFee - partnerFee;
        emit CallFeeUpdated(callFee, treasuryFee);
        return true;
    }

    /**
     * @dev updates the partner fee and adjusts the treasury fee to cover the difference
     */
    function updatePartnerFee(uint256 _partnerFee) external onlyOwner returns (bool) {
        require(partner != address(0), "partner-not-set");

        partnerFee = _partnerFee;
        treasuryFee = PERCENT_DIVISOR - partnerFee - callFee;
        emit PartnerFeeUpdated(partnerFee, treasuryFee);
        return true;
    }

    function updateTreasury(address _newTreasury)
        external
        onlyOwner
        returns (bool)
    {
        require(_newTreasury != address(0), "treasury-is-zero");
        treasury = _newTreasury;
        return true;
    }

    function updatePartner(address _newPartner)
        external
        onlyOwner
        returns (bool)
    {
        require(_newPartner != address(0), "partner-is-zero");
        partner = _newPartner;
        return true;
    }

    /**
     * @dev Puts funds in strategy at work
     * @notice Only vault can call this when not paused
     */
    function deposit() external virtual whenNotPaused onlyVault {
        _deposit();
    }

    function withdraw(uint256 _amount) external virtual onlyVault {
        uint256 _balanceHere = IERC20(want).balanceOf(address(this));

        if (_balanceHere < _amount) {
            _beforeWithdraw(_amount - _balanceHere);
            _balanceHere = IERC20(want).balanceOf(address(this));
        }

        if (_balanceHere > _amount) {
            _balanceHere = _amount;
        }
        uint256 _withdrawFee = (_balanceHere * securityFee) / PERCENT_DIVISOR;
        IERC20(want).safeTransfer(vault, _balanceHere - _withdrawFee);
    }

    function pause() external virtual onlyOwner {
        _pause();
        _removeAllowances();
    }

    function unpause() external virtual onlyOwner {
        _unpause();
        _giveAllowances();
        _deposit();
    }

    function beforeDeposit() external virtual onlyVault {}

    function retireStrat() external onlyVault {
        _beforeRetireStrat();
        uint256 _wantBalance = IERC20(want).balanceOf(address(this));
        IERC20(want).safeTransfer(vault, _wantBalance);
    }

    /// @notice pauses deposits and withdraws all funds from third party systems.
    function panic() external onlyOwner {
        _pause();
        _beforePanic();
    }

    /// @notice compounds earnings and charges performance fee
    function harvest() external whenNotPaused {
        require(!Address.isContract(msg.sender), "!contract");

        uint256 _totalValueBefore = totalValue();
        (uint256 _wantHarvested, uint256 _wrappedFeesAccrued) = _harvest();

        _chargeFees(_wrappedFeesAccrued);

        uint256 _totalValueAfter = totalValue();
        _deposit();

        emit Harvested(
            msg.sender,
            _wantHarvested,
            _totalValueBefore,
            _totalValueAfter
        );
    }

    /// @notice "want" Funds held in strategy + funds deployed elsewhere
    function totalValue() public virtual view returns (uint256) {
        return IERC20(want).balanceOf(address(this));
    }

    /// @notice For vault interface retro-compatibility
    function balanceOf() public virtual view returns (uint256) {
        return totalValue();
    }
 
    function _chargeFees(uint256 _wrappedFeesAccrued) internal virtual {
        uint256 _callFeeToUser = (_wrappedFeesAccrued * callFee) /
            PERCENT_DIVISOR;

        uint256 _feeToPartner = (_wrappedFeesAccrued * partnerFee) /
            PERCENT_DIVISOR;

        IERC20(wrapped).safeTransfer(msg.sender, _callFeeToUser);
        IERC20(wrapped).safeTransfer(
            treasury,
            _wrappedFeesAccrued - _callFeeToUser - _feeToPartner
        );

        if(partner != address(0)) {
            IERC20(wrapped).safeTransfer(
                partner, 
                _feeToPartner
            );
        }
    }

    /// @notice Hooks to customize strategies behavior
    function _deposit() internal virtual {}

    function _beforeWithdraw(uint256 _amount) internal virtual {}

    function _harvest()
        internal
        virtual
        returns (uint256 _wantHarvested, uint256 _wrappedFeesAccrued)
    {}

    function _giveAllowances() internal virtual {}
    function _removeAllowances() internal virtual {}
    function _beforeRetireStrat() internal virtual {}
    function _beforePanic() internal virtual {}
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../interfaces/IUniswapV2Pair.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


/// @title Swap Helper to perform swaps and setting routes in matrix strategies
contract MatrixSwapHelper {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    address public unirouter;

    /// @dev Enumerable set of external tokens and routers
    /// strategy can interact with
    EnumerableSet.AddressSet internal whitelistedAddresses;

    struct SwapPath {
        address unirouter;
        address[] path;
    }

    mapping(bytes32 => SwapPath) internal swapPaths;

    constructor(address _uniRouter) {
        unirouter = _uniRouter;
    }

    function getWhitelistedAddresses()
        public
        virtual
        returns (address[] memory)
    {
        return whitelistedAddresses.values();
    }

    function getSwapPath(address _fromToken, address _toToken)
        public
        view
        virtual
        returns (SwapPath memory _swapPath)
    {
        bytes32 _swapKey = keccak256(abi.encodePacked(_fromToken, _toToken));
        require(swapPaths[_swapKey].unirouter != address(0), "path-not-found");
        return swapPaths[_swapKey];
    }

    function _setSwapPath(
        address _fromToken,
        address _toToken,
        address _unirouter,
        address[] memory _path
    ) internal virtual {
        require(_path[0] == _fromToken, "invalid-path");
        require(_path[_path.length - 1] == _toToken, "invalid-path");
        _checkPath(_path);

        bytes32 _swapKey = keccak256(abi.encodePacked(_fromToken, _toToken));
        address _router = _unirouter == address(0) ? unirouter : _unirouter;

        _checkRouter(_router);

        swapPaths[_swapKey] = SwapPath(_router, _path);
    }

    /// @dev Checks that tokens in path are whitelisted
    /// @notice Override this to skip checks
    function _checkPath(address[] memory _path) internal virtual {
        return;
        /*
        for (uint256 i; i < _path.length; i++)
        {
            require(
                whitelistedAddresses.contains(_path[i]),
                "token-not-whitelisted"
            );
        }
        */
    }

    /// @dev Checks that router for swap is whitelisted
    /// @notice Override this to skip checks
    function _checkRouter(address _router) internal virtual {
        require(
            whitelistedAddresses.contains(_router),
            "router-not-whitelisted"
        );
    }

    function _swap(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) internal virtual returns (uint256 _toTokenAmount) {
        if (_fromToken == _toToken) return _amount;
        SwapPath memory _swapPath = getSwapPath(_fromToken, _toToken);

        IERC20(_fromToken).safeApprove(_swapPath.unirouter, 0);
        IERC20(_fromToken).safeApprove(_swapPath.unirouter, type(uint256).max);
        
        // debugging: uncomment this block
        
        // console.log("_fromToken:", IERC20Metadata(_fromToken).symbol());
        // console.log("_toToken", IERC20Metadata(_toToken).symbol());
        // console.log("_path:");
        // for (uint i; i < _swapPath.path.length; i++) {
        //     console.log(IERC20Metadata(_swapPath.path[i]).symbol());
        // }

        uint256 _toTokenBefore = IERC20(_toToken).balanceOf(address(this));
        IUniswapV2Router02(_swapPath.unirouter).swapExactTokensForTokens(
            _amount,
            0,
            _swapPath.path,
            address(this),
            block.timestamp
        );
        _toTokenAmount =
            IERC20(_toToken).balanceOf(address(this)) -
            _toTokenBefore;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "../MatrixLpAutoCompound.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "../../interfaces/IGauge.sol";
import "../../interfaces/velodrome/IVelodromeRouter.sol";

//import "hardhat/console.sol";

/// @title Velodrome Matrix Lp AutoCompound Strategy
contract VeloMatrixLpAutoCompound is MatrixLpAutoCompound {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    bool public isStable;

    address internal constant sUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address internal constant MAI = 0xdFA46478F9e5EA86d57387849598dbFB2e964b02;
    address internal constant OP = 0x4200000000000000000000000000000000000042;
    address internal constant LYRA = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address internal constant THALES =
        0x217D47011b23BB961eB6D93cA9945B7501a5BB11;
    address internal constant LUSD = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;
    address internal constant alUSD =
        0xCB8FA9a76b8e203D8C3797bF438d8FB81Ea3326A;
    address internal constant FRAX = 0x2E3D870790dC77A83DD1d18184Acc7439A53f475;
    address internal constant sETH = 0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49;
    address internal constant HND = 0x10010078a54396F62c96dF8532dc2B4847d47ED3;

    constructor(
        address _want,
        uint256 _poolId,
        address _masterchef,
        address _output,
        address _uniRouter,
        bool _isStable,
        address _vault,
        address _treasury
    )
        MatrixLpAutoCompound(
            _want,
            _poolId,
            _masterchef,
            _output,
            _uniRouter,
            _vault,
            _treasury
        )
    {
        wrapped = 0x4200000000000000000000000000000000000006;
        treasury = 0xEaD9f532C72CF35dAb18A42223eE7A1B19bC5aBF;
        isStable = _isStable;
        USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        partner = address(0xb074ec6c37659525EEf2Fb44478077901F878012);
        treasuryFee = 4500;
        partnerFee = 4500;

        _initialize(_masterchef, _output, _poolId);
    }

    function _setDefaultSwapPaths() internal override {
        super._setDefaultSwapPaths();

        // VELO -> USDC
        address[] memory _VELOsUSD = new address[](4);
        _VELOsUSD[0] = output;
        _VELOsUSD[1] = wrapped;
        _VELOsUSD[2] = USDC;
        _VELOsUSD[3] = sUSD;
        _setSwapPath(output, sUSD, unirouter, _VELOsUSD);

        // VELO -> WETH
        address[] memory _VELOWETH = new address[](3);
        _VELOWETH[0] = output;
        _VELOWETH[1] = USDC;
        _VELOWETH[2] = wrapped;
        _setSwapPath(output, wrapped, unirouter, _VELOWETH);

        // VELO -> MAI
        address[] memory _VELOMAI = new address[](3);
        _VELOMAI[0] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        _VELOMAI[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOMAI[2] = 0xdFA46478F9e5EA86d57387849598dbFB2e964b02;
        _setSwapPath(output, MAI, unirouter, _VELOMAI);

        // VELO -> OP
        address[] memory _VELOOP = new address[](3);
        _VELOOP[0] = output;
        _VELOOP[1] = USDC;
        _VELOOP[2] = OP;
        _setSwapPath(output, OP, unirouter, _VELOOP);

        // VELO -> LYRA
        address[] memory _VELOLYRA = new address[](3);
        _VELOLYRA[0] = output;
        _VELOLYRA[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOLYRA[2] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
        _setSwapPath(output, LYRA, unirouter, _VELOLYRA);

        // VELO -> THALES
        address[] memory _VELOTHALES = new address[](3);
        _VELOTHALES[0] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        _VELOTHALES[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOTHALES[2] = 0x217D47011b23BB961eB6D93cA9945B7501a5BB11;
        _setSwapPath(output, THALES, unirouter, _VELOTHALES);

        // VELO -> LUSD
        address[] memory _VELOLUSD = new address[](3);
        _VELOLUSD[0] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        _VELOLUSD[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOLUSD[2] = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;
        _setSwapPath(output, LUSD, unirouter, _VELOLUSD);

        // VELO -> alUSD
        address[] memory _VELOalUSD = new address[](3);
        _VELOalUSD[0] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        _VELOalUSD[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOalUSD[2] = 0xCB8FA9a76b8e203D8C3797bF438d8FB81Ea3326A;
        _setSwapPath(output, alUSD, unirouter, _VELOalUSD);

        // VELO -> FRAX
        address[] memory _VELOFRAX = new address[](3);
        _VELOFRAX[0] = 0x3c8B650257cFb5f272f799F5e2b4e65093a11a05;
        _VELOFRAX[1] = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
        _VELOFRAX[2] = 0x2E3D870790dC77A83DD1d18184Acc7439A53f475;
        _setSwapPath(output, FRAX, unirouter, _VELOFRAX);

        // VELO -> sETH
        address[] memory _VELOsETH = new address[](4);
        _VELOsETH[0] = output;
        _VELOsETH[1] = USDC;
        _VELOsETH[2] = wrapped;
        _VELOsETH[3] = sETH;
        _setSwapPath(output, sETH, unirouter, _VELOsETH);

        // VELO -> HND
        address[] memory _VELOHND = new address[](3);
        _VELOHND[0] = output;
        _VELOHND[1] = USDC;
        _VELOHND[2] = HND;
        _setSwapPath(output, HND, unirouter, _VELOHND);
    }

    function totalValue() public view override returns (uint256) {
        uint256 _totalStaked = IGauge(masterchef).balanceOf(address(this));
        return IERC20(want).balanceOf(address(this)) + _totalStaked;
    }

    function _beforeWithdraw(uint256 _amount) internal override {
        IGauge(masterchef).withdraw(_amount);
    }

    function _beforeHarvest() internal override {
        address[] memory _tokens = new address[](1);
        _tokens[0] = output;
        IGauge(masterchef).getReward(address(this), _tokens);
    }

    function _deposit() internal virtual override {
        uint256 _wantBalance = IERC20(want).balanceOf(address(this));
        if (_wantBalance > 0) IGauge(masterchef).deposit(_wantBalance, poolId);
    }

    function _beforePanic() internal virtual override {
        IGauge(masterchef).withdrawAll();
    }

    function _getRatio(address _lpToken) internal view returns (uint256) {
        address _token0 = IUniswapV2Pair(_lpToken).token0();
        address _token1 = IUniswapV2Pair(_lpToken).token1();

        (uint256 opLp0, uint256 opLp1, ) = IUniswapV2Pair(_lpToken)
            .getReserves();
        uint256 lp0Amt = (opLp0 * (10**18)) /
            (10**IERC20Metadata(_token0).decimals());
        uint256 lp1Amt = (opLp1 * (10**18)) /
            (10**IERC20Metadata(_token1).decimals());
        uint256 totalSupply = lp0Amt + (lp1Amt);
        return (lp0Amt * (10**18)) / (totalSupply);
    }

    function _swap(
        address _fromToken,
        address _toToken,
        uint256 _amount
    ) internal override returns (uint256 _toTokenAmount) {
        if (_fromToken == _toToken) return _amount;
        SwapPath memory _swapPath = getSwapPath(_fromToken, _toToken);

        route[] memory _routes = new route[](_swapPath.path.length - 1);

        uint256 _lastAmountBack = _amount;
        for (uint256 i; i < _swapPath.path.length - 1; i++) {
            (uint256 _amountBack, bool _stable) = IVelodromeRouter(
                _swapPath.unirouter
            ).getAmountOut(
                    _lastAmountBack,
                    _swapPath.path[i],
                    _swapPath.path[i + 1]
                );
            _lastAmountBack = _amountBack;
            _routes[i] = route({
                from: _swapPath.path[i],
                to: _swapPath.path[i + 1],
                stable: _stable
            });
        }

        IERC20(_fromToken).safeApprove(_swapPath.unirouter, 0);
        IERC20(_fromToken).safeApprove(_swapPath.unirouter, type(uint256).max);

        // debugging: uncomment this block
        // console.log("++++++++++");
        // console.log("_fromToken:", IERC20Metadata(_fromToken).symbol());
        // console.log("_fromAddr:", _fromToken);
        // console.log("_toToken:", IERC20Metadata(_toToken).symbol());
        // console.log("_toAddr:", _toToken);
        // console.log("_amount:", _amount);
        // console.log("_path:");
        // for (uint256 i; i < _swapPath.path.length; i++) {
        //     console.log(
        //         IERC20Metadata(_swapPath.path[i]).symbol(),
        //         _swapPath.path[i]
        //     );
        //     console.log("-----");
        // }
        // console.log("++++++++++");
        // console.log("");

        uint256 _toTokenBefore = IERC20(_toToken).balanceOf(address(this));
        IVelodromeRouter(_swapPath.unirouter).swapExactTokensForTokens(
            _amount,
            0,
            _routes,
            address(this),
            block.timestamp
        );

        _toTokenAmount =
            IERC20(_toToken).balanceOf(address(this)) -
            _toTokenBefore;
    }

    function _addLiquidity(uint256 _outputAmount)
        internal
        override
        returns (uint256 _wantHarvested)
    {
        uint256 _wantBalanceBefore = IERC20(want).balanceOf(address(this));
        uint256 _lpToken0BalanceBefore = IERC20(lpToken0).balanceOf(
            address(this)
        );
        uint256 _lpToken1BalanceBefore = IERC20(lpToken1).balanceOf(
            address(this)
        );
        //console.log(IERC20(output).balanceOf(address(this)));

        if (!isStable) {
            if (output == lpToken0) {
                _swap(output, lpToken1, _outputAmount / 2);
            } else if (output == lpToken1) {
                _swap(output, lpToken0, _outputAmount / 2);
            } else {
                _swap(output, lpToken0, _outputAmount / 2);
                _swap(
                    output,
                    lpToken1,
                    IERC20(output).balanceOf(address(this))
                );
            }
        } else {
            uint256 _amount0In = (_outputAmount * _getRatio(want)) / 10**18;
            uint256 _amount1In = _outputAmount - _amount0In;
            _swap(output, lpToken0, _amount0In);
            _swap(output, lpToken1, _amount1In);
        }

        uint256 _lp0Balance = (lpToken0 != wrapped)
            ? IERC20(lpToken0).balanceOf(address(this))
            : IERC20(lpToken0).balanceOf(address(this)) -
                _lpToken0BalanceBefore;
        uint256 _lp1Balance = (lpToken1 != wrapped)
            ? IERC20(lpToken1).balanceOf(address(this))
            : IERC20(lpToken1).balanceOf(address(this)) -
                _lpToken1BalanceBefore;

        // console.log(lpToken0);
        // console.log(lpToken1);
        // console.log("_lp0Balance", _lp0Balance);
        // console.log("_lp1Balance", _lp1Balance);
        //console.log("_lp0Balance new", _lp0Balance);
        //console.log("_lp1Balance new", _lp1Balance);

        IVelodromeRouter(unirouter).addLiquidity(
            lpToken0,
            lpToken1,
            isStable,
            _lp0Balance,
            _lp1Balance,
            1,
            1,
            address(this),
            block.timestamp
        );
        return IERC20(want).balanceOf(address(this)) - _wantBalanceBefore;
    }
}