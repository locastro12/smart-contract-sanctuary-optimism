// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IStrategy {
    function rebalance() external returns (uint256 _profit, uint256 _loss, uint256 _payback);

    function sweep(address _fromToken) external;

    function withdraw(uint256 _amount) external;

    function feeCollector() external view returns (address);

    function isReservedToken(address _token) external view returns (bool);

    function keepers() external view returns (address[] memory);

    function migrate(address _newStrategy) external;

    function token() external view returns (address);

    function pool() external view returns (address);

    // solhint-disable-next-line func-name-mixedcase
    function VERSION() external view returns (string memory);

    function collateral() external view returns (address);
}

// SPDX-License-Identifier: MIT

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

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        // solhint-disable-next-line max-line-length
        require((value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
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
        if (returndata.length > 0) { // Return data is optional
            // solhint-disable-next-line max-line-length
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}

// SPDX-License-Identifier: MIT

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
        // solhint-disable-next-line no-inline-assembly
        assembly { size := extcodesize(account) }
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

        // solhint-disable-next-line avoid-low-level-calls, avoid-call-value
        (bool success, ) = recipient.call{ value: amount }("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain`call` is an unsafe replacement for a function call: use this
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
    function functionCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.call{ value: value }(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionStaticCall(address target, bytes memory data, string memory errorMessage) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
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
    function functionDelegateCall(address target, bytes memory data, string memory errorMessage) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns(bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
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

pragma solidity ^0.8.0;

/*
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
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT

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
        // (a + b) / 2 can overflow, so we distribute
        return (a / 2) + (b / 2) + ((a % 2 + b % 2) / 2);
    }
}

// SPDX-License-Identifier: MIT

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

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @notice Governable interface
 */
interface IGovernable {
    function governor() external view returns (address _governor);

    function transferGovernorship(address _proposedGovernor) external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @notice Pausable interface
 */
interface IPausable {
    function paused() external view returns (bool);

    function stopEverything() external view returns (bool);

    function pause() external;

    function unpause() external;

    function shutdown() external;

    function open() external;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "../../dependencies/openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./IGovernable.sol";
import "./IPausable.sol";

interface IVesperPool is IGovernable, IPausable, IERC20Metadata {
    function calculateUniversalFee(uint256 profit_) external view returns (uint256 _fee);

    function deposit(uint256 collateralAmount_) external;

    function excessDebt(address strategy_) external view returns (uint256);

    function poolAccountant() external view returns (address);

    function poolRewards() external view returns (address);

    function reportEarning(uint256 profit_, uint256 loss_, uint256 payback_) external;

    function reportLoss(uint256 loss_) external;

    function sweepERC20(address fromToken_) external;

    function withdraw(uint256 share_) external;

    function keepers() external view returns (address[] memory);

    function isKeeper(address address_) external view returns (bool);

    function maintainers() external view returns (address[] memory);

    function isMaintainer(address address_) external view returns (bool);

    function pricePerShare() external view returns (uint256);

    function strategy(
        address strategy_
    )
        external
        view
        returns (
            bool _active,
            uint256 _interestFee, // Obsolete
            uint256 _debtRate, // Obsolete
            uint256 _lastRebalance,
            uint256 _totalDebt,
            uint256 _totalLoss,
            uint256 _totalProfit,
            uint256 _debtRatio,
            uint256 _externalDepositFee
        );

    function token() external view returns (IERC20);

    function tokensHere() external view returns (uint256);

    function totalDebtOf(address strategy_) external view returns (uint256);

    function totalValue() external view returns (uint256);

    function totalDebt() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

/**
 * @notice Routed Swapper interface
 * @dev This contract doesn't support native coins (e.g. ETH, AVAX, MATIC, etc) use wrapper tokens instead
 */
interface IRoutedSwapper {
    /**
     * @notice The list of supported DEXes
     * @dev This function is gas intensive
     */
    function getAllExchanges() external view returns (address[] memory);

    /**
     * @notice Get *spot* quote
     * It will return the swap amount based on the current reserves of the best pair/path found (i.e. spot price).
     * @dev It shouldn't be used as oracle!!!
     */
    function getAmountIn(address tokenIn_, address tokenOut_, uint256 amountOut_) external returns (uint256 _amountIn);

    /**
     * @notice Get *spot* quote
     * It will return the swap amount based on the current reserves of the best pair/path found (i.e. spot price).
     * @dev It shouldn't be used as oracle!!!
     */
    function getAmountOut(address tokenIn_, address tokenOut_, uint256 amountIn_) external returns (uint256 _amountOut);

    /**
     * @notice Perform an exact input swap - will revert if there is no default routing
     */
    function swapExactInput(
        address tokenIn_,
        address tokenOut_,
        uint256 amountIn_,
        uint256 amountOutMin_,
        address _receiver
    ) external returns (uint256 _amountOut);

    /**
     * @notice Perform an exact output swap - will revert if there is no default routing
     */
    function swapExactOutput(
        address tokenIn_,
        address tokenOut_,
        uint256 amountOut_,
        uint256 amountInMax_,
        address receiver_
    ) external returns (uint256 _amountIn);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

interface IStakingRewards {
    /// @notice The balance a given user has staked.
    function balanceOf(address account) external view returns (uint256);

    /// @notice Amount of reward token pending claim by an account.
    function earned(address account) external view returns (uint256);

    /// @notice The address of our rewards token.
    function rewardsToken() external view returns (address);

    /// @notice The total tokens staked in this contract.
    function totalSupply() external view returns (uint256);

    /// @notice Unstake all of the sender's tokens and claim any outstanding rewards.
    function exit() external;

    /// @notice Claim any earned reward tokens.
    /// @dev Can claim rewards even if no tokens still staked.
    function getReward() external;

    /// @notice Deposit vault tokens to the staking pool.
    /// @dev Can't stake zero.
    /// @param amount Amount of vault tokens to deposit.
    function stake(uint256 amount) external;

    /// @notice Withdraw vault tokens from the staking pool.
    /// @dev Can't withdraw zero. If trying to claim, call getReward() instead.
    /// @param amount Amount of vault tokens to withdraw.
    function withdraw(uint256 amount) external;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

interface IYToken {
    function balanceOf(address user) external view returns (uint256);

    function pricePerShare() external view returns (uint256);

    function deposit(uint256 amount) external returns (uint256);

    function deposit() external returns (uint256);

    function withdraw(uint256 shares) external returns (uint256);

    function token() external returns (address);

    function totalAssets() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function availableDepositLimit() external view returns (uint256);

    function decimals() external view returns (uint8);

    function withdrawalQueue(uint256 index) external view returns (address);

    function maxAvailableShares() external view returns (uint256);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "vesper-pools/contracts/interfaces/vesper/IVesperPool.sol";
import "vesper-pools/contracts/dependencies/openzeppelin/contracts/token/ERC20/IERC20.sol";
import "vesper-pools/contracts/dependencies/openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "vesper-pools/contracts/dependencies/openzeppelin/contracts/utils/Context.sol";
import "vesper-pools/contracts/dependencies/openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "vesper-pools/contracts/dependencies/openzeppelin/contracts/utils/math/Math.sol";
import "vesper-commons/contracts/interfaces/vesper/IStrategy.sol";
import "../interfaces/swapper/IRoutedSwapper.sol";

abstract contract Strategy is IStrategy, Context {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC20 public immutable collateralToken;
    address public receiptToken;
    address public immutable override pool;
    address public override feeCollector;
    IRoutedSwapper public swapper;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 internal constant MAX_UINT_VALUE = type(uint256).max;

    EnumerableSet.AddressSet private _keepers;

    event UpdatedFeeCollector(address indexed previousFeeCollector, address indexed newFeeCollector);
    event UpdatedSwapper(IRoutedSwapper indexed oldSwapper, IRoutedSwapper indexed newSwapper);

    constructor(address _pool, address _swapper, address _receiptToken) {
        require(_pool != address(0), "pool-address-is-zero");
        require(_swapper != address(0), "swapper-address-is-zero");
        swapper = IRoutedSwapper(_swapper);
        pool = _pool;
        collateralToken = IVesperPool(_pool).token();
        receiptToken = _receiptToken;
        require(_keepers.add(_msgSender()), "add-keeper-failed");
    }

    modifier onlyGovernor() {
        require(_msgSender() == IVesperPool(pool).governor(), "caller-is-not-the-governor");
        _;
    }

    modifier onlyKeeper() {
        require(_keepers.contains(_msgSender()), "caller-is-not-a-keeper");
        _;
    }

    modifier onlyPool() {
        require(_msgSender() == pool, "caller-is-not-vesper-pool");
        _;
    }

    /**
     * @notice Add given address in keepers list.
     * @param _keeperAddress keeper address to add.
     */
    function addKeeper(address _keeperAddress) external onlyGovernor {
        require(_keepers.add(_keeperAddress), "add-keeper-failed");
    }

    /// @dev Approve all required tokens
    function approveToken(uint256 _approvalAmount) external onlyKeeper {
        _approveToken(_approvalAmount);
    }

    /// @notice Claim rewardToken and convert rewardToken into collateral token.
    function claimAndSwapRewards(uint256 _minAmountOut) external onlyKeeper returns (uint256 _amountOut) {
        uint256 _collateralBefore = collateralToken.balanceOf(address(this));
        _claimAndSwapRewards();
        _amountOut = collateralToken.balanceOf(address(this)) - _collateralBefore;
        require(_amountOut >= _minAmountOut, "not-enough-amountOut");
    }

    /// @notice Check whether given token is reserved or not. Reserved tokens are not allowed to sweep.
    function isReservedToken(address _token) public view virtual override returns (bool);

    /// @notice Return list of keepers
    function keepers() external view override returns (address[] memory) {
        return _keepers.values();
    }

    /**
     * @notice Migrate all asset and vault ownership,if any, to new strategy
     * @dev _beforeMigration hook can be implemented in child strategy to do extra steps.
     * @param _newStrategy Address of new strategy
     */
    function migrate(address _newStrategy) external virtual override onlyPool {
        require(_newStrategy != address(0), "new-strategy-address-is-zero");
        require(IStrategy(_newStrategy).pool() == pool, "not-valid-new-strategy");
        _beforeMigration(_newStrategy);
        IERC20(receiptToken).safeTransfer(_newStrategy, IERC20(receiptToken).balanceOf(address(this)));
        collateralToken.safeTransfer(_newStrategy, collateralToken.balanceOf(address(this)));
    }

    /**
     * @notice OnlyKeeper: Rebalance profit, loss and investment of this strategy.
     *  Calculate profit, loss and payback of this strategy and realize profit/loss and
     *  withdraw fund for payback, if any, and submit this report to pool.
     * @return _profit Realized profit in collateral.
     * @return _loss Realized loss, if any, in collateral.
     * @return _payback If strategy has any excess debt, we have to liquidate asset to payback excess debt.
     */
    function rebalance() external onlyKeeper returns (uint256 _profit, uint256 _loss, uint256 _payback) {
        return _rebalance();
    }

    /**
     * @notice Remove given address from keepers list.
     * @param _keeperAddress keeper address to remove.
     */
    function removeKeeper(address _keeperAddress) external onlyGovernor {
        require(_keepers.remove(_keeperAddress), "remove-keeper-failed");
    }

    /// @notice onlyKeeper:: Swap given token into collateral token.
    function swapToCollateral(IERC20 _tokenIn, uint256 _minAmountOut) external onlyKeeper returns (uint256 _amountOut) {
        require(address(_tokenIn) != address(collateralToken), "not-allowed-to-sweep-collateral");
        require(!isReservedToken(address(_tokenIn)), "not-allowed-to-sweep");
        uint256 _collateralBefore = collateralToken.balanceOf(address(this));
        uint256 _amountIn = _tokenIn.balanceOf(address(this));
        if (_amountIn > 0) {
            if (_amountIn > _tokenIn.allowance(address(this), address(swapper))) {
                _tokenIn.safeApprove(address(swapper), 0);
                _tokenIn.safeApprove(address(swapper), MAX_UINT_VALUE);
            }
            _swapExactInput(address(_tokenIn), address(collateralToken), _amountIn);
        }
        _amountOut = collateralToken.balanceOf(address(this)) - _collateralBefore;
        require(_amountOut >= _minAmountOut, "not-enough-amountOut");
    }

    /**
     * @notice sweep given token to feeCollector of strategy
     * @param _fromToken token address to sweep
     */
    function sweep(address _fromToken) external override onlyKeeper {
        require(feeCollector != address(0), "fee-collector-not-set");
        require(_fromToken != address(collateralToken), "not-allowed-to-sweep-collateral");
        require(!isReservedToken(_fromToken), "not-allowed-to-sweep");
        if (_fromToken == ETH) {
            Address.sendValue(payable(feeCollector), address(this).balance);
        } else {
            uint256 _amount = IERC20(_fromToken).balanceOf(address(this));
            IERC20(_fromToken).safeTransfer(feeCollector, _amount);
        }
    }

    /// @notice Returns address of token correspond to receipt token
    function token() external view override returns (address) {
        return receiptToken;
    }

    /// @notice Returns address of token correspond to collateral token
    function collateral() external view override returns (address) {
        return address(collateralToken);
    }

    /// @notice Returns total collateral locked in the strategy
    function tvl() external view virtual returns (uint256);

    /**
     * @notice Update fee collector
     * @param _feeCollector fee collector address
     */
    function updateFeeCollector(address _feeCollector) external onlyGovernor {
        require(_feeCollector != address(0), "fee-collector-address-is-zero");
        require(_feeCollector != feeCollector, "fee-collector-is-same");
        emit UpdatedFeeCollector(feeCollector, _feeCollector);
        feeCollector = _feeCollector;
    }

    /**
     * @notice Update swapper
     * @param _swapper swapper address
     */
    function updateSwapper(IRoutedSwapper _swapper) external onlyGovernor {
        require(address(_swapper) != address(0), "swapper-address-is-zero");
        require(_swapper != swapper, "swapper-is-same");
        emit UpdatedSwapper(swapper, _swapper);
        swapper = _swapper;
    }

    /**
     * @notice Withdraw collateral token from end protocol.
     * @param _amount Amount of collateral token
     */
    function withdraw(uint256 _amount) external override onlyPool {
        uint256 _collateralHere = collateralToken.balanceOf(address(this));
        if (_collateralHere >= _amount) {
            collateralToken.safeTransfer(pool, _amount);
        } else {
            _withdrawHere(_amount - _collateralHere);
            // Do not assume _withdrawHere() will withdraw exact amount. Check balance again and transfer to pool
            _collateralHere = collateralToken.balanceOf(address(this));
            collateralToken.safeTransfer(pool, Math.min(_amount, _collateralHere));
        }
    }

    function _approveToken(uint256 _amount) internal virtual {
        collateralToken.safeApprove(pool, _amount);
    }

    /**
     * @dev some strategy may want to prepare before doing migration.
     *  Example In Maker old strategy want to give vault ownership to new strategy
     * @param _newStrategy .
     */
    function _beforeMigration(address _newStrategy) internal virtual;

    function _claimAndSwapRewards() internal virtual {
        (address _rewardToken, uint256 _rewardsAmount) = _claimRewards();
        if (_rewardsAmount > 0) {
            _safeSwapExactInput(_rewardToken, address(collateralToken), _rewardsAmount);
        }
    }

    // solhint-disable-next-line no-empty-blocks
    function _claimRewards() internal virtual returns (address, uint256) {}

    function _rebalance() internal virtual returns (uint256 _profit, uint256 _loss, uint256 _payback);

    function _swapExactInput(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn
    ) internal returns (uint256 _amountOut) {
        _amountOut = swapper.swapExactInput(_tokenIn, _tokenOut, _amountIn, 1, address(this));
    }

    function _safeSwapExactInput(address _tokenIn, address _tokenOut, uint256 _amountIn) internal {
        try swapper.swapExactInput(_tokenIn, _tokenOut, _amountIn, 1, address(this)) {} catch {} //solhint-disable no-empty-blocks
    }

    // These methods must be implemented by the inheriting strategy
    function _withdrawHere(uint256 _amount) internal virtual;
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "../Strategy.sol";
import "../../interfaces/yearn/IYToken.sol";
import "../../interfaces/yearn/IStakingRewards.sol";

/// @title This strategy will deposit collateral token in a Yearn vault and stake receipt tokens
/// into staking contract to earn rewards and yield.
contract YearnStaking is Strategy {
    using SafeERC20 for IERC20;
    // solhint-disable-next-line var-name-mixedcase
    string public NAME;
    string public constant VERSION = "5.1.0";
    IYToken internal immutable yToken;
    uint256 internal immutable yTokenDecimals;
    IStakingRewards public immutable stakingRewards;
    address public immutable rewardToken;
    IYToken internal immutable yTokenReward;

    constructor(
        address pool_,
        address swapper_,
        address receiptToken_,
        address stakingRewards_,
        string memory name_
    ) Strategy(pool_, swapper_, receiptToken_) {
        require(receiptToken_ != address(0), "yToken-address-is-null");
        require(stakingRewards_ != address(0), "stakingRewards-address-is-null");
        yToken = IYToken(receiptToken_);
        yTokenDecimals = 10 ** yToken.decimals();
        stakingRewards = IStakingRewards(stakingRewards_);
        yTokenReward = IYToken(stakingRewards.rewardsToken());
        rewardToken = yTokenReward.token();
        NAME = name_;
    }

    function isReservedToken(address token_) public view virtual override returns (bool) {
        return token_ == address(yToken);
    }

    function tvl() external view override returns (uint256) {
        return _getCollateralFromYearn() + collateralToken.balanceOf(address(this));
    }

    /// @notice Approve all required tokens
    function _approveToken(uint256 amount_) internal virtual override {
        super._approveToken(amount_);
        collateralToken.safeApprove(address(yToken), amount_);
        IERC20(address(yToken)).safeApprove(address(stakingRewards), amount_);
        IERC20(rewardToken).safeApprove(address(swapper), amount_);
    }

    function _beforeMigration(address) internal override {
        // Unstake all staked tokens
        uint256 _stakedShares = stakingRewards.balanceOf(address(this));
        if (_stakedShares > 0) {
            stakingRewards.withdraw(_stakedShares);
        }
    }

    function _claimAndSwapRewards() internal override {
        // Claim reward and it will give us yToken as reward
        stakingRewards.getReward();
        uint256 _yRewardsAmount = yTokenReward.balanceOf(address(this));
        if (_yRewardsAmount > 0) {
            // Withdraw actual reward token from yToken
            yTokenReward.withdraw(_yRewardsAmount);
        }

        uint256 _rewardsAmount = IERC20(rewardToken).balanceOf(address(this));
        // Swap reward to collateral
        if (_rewardsAmount > 0 && rewardToken != address(collateralToken)) {
            _safeSwapExactInput(rewardToken, address(collateralToken), _rewardsAmount);
        }
    }

    function _convertToShares(uint256 collateralAmount_) internal view returns (uint256) {
        return (collateralAmount_ * yTokenDecimals) / yToken.pricePerShare();
    }

    function _getCollateralFromYearn() internal view returns (uint256) {
        return (_getTotalShares() * yToken.pricePerShare()) / yTokenDecimals;
    }

    function _getTotalShares() internal view returns (uint256) {
        return yToken.balanceOf(address(this)) + stakingRewards.balanceOf(address(this));
    }

    function _rebalance() internal override returns (uint256 _profit, uint256 _loss, uint256 _payback) {
        uint256 _excessDebt = IVesperPool(pool).excessDebt(address(this));
        uint256 _totalDebt = IVesperPool(pool).totalDebtOf(address(this));

        uint256 _collateralHere = collateralToken.balanceOf(address(this));
        uint256 _totalCollateral = _getCollateralFromYearn() + _collateralHere;

        if (_totalCollateral > _totalDebt) {
            _profit = _totalCollateral - _totalDebt;
        } else {
            _loss = _totalDebt - _totalCollateral;
        }
        uint256 _profitAndExcessDebt = _profit + _excessDebt;
        if (_profitAndExcessDebt > _collateralHere) {
            _withdrawHere(_profitAndExcessDebt - _collateralHere);
            _collateralHere = collateralToken.balanceOf(address(this));
        }

        // Make sure _collateralHere >= _payback + profit. set actual payback first and then profit
        _payback = Math.min(_collateralHere, _excessDebt);
        _profit = _collateralHere > _payback ? Math.min((_collateralHere - _payback), _profit) : 0;
        IVesperPool(pool).reportEarning(_profit, _loss, _payback);

        // strategy may get new fund. deposit to generate yield
        _collateralHere = collateralToken.balanceOf(address(this));
        if (_convertToShares(_collateralHere) > 0) {
            yToken.deposit(_collateralHere);
        }

        // Staking all yTokens to earn rewards
        uint256 _sharesHere = yToken.balanceOf(address(this));
        if (_sharesHere > 0) {
            stakingRewards.stake(_sharesHere);
        }
    }

    function _withdrawHere(uint256 amount_) internal override {
        // Check staked shares and shares here
        uint256 _sharesRequired = _convertToShares(amount_);
        uint256 _sharesHere = yToken.balanceOf(address(this));
        if (_sharesRequired > _sharesHere) {
            // Unstake minimum of staked and required
            uint256 _toUnstake = Math.min(stakingRewards.balanceOf(address(this)), (_sharesRequired - _sharesHere));
            if (_toUnstake > 0) {
                stakingRewards.withdraw(_toUnstake);
            }
        }

        // Withdraw all available yTokens. Reread balance as unstake will increase balance.
        _sharesHere = yToken.balanceOf(address(this));
        if (_sharesHere > 0) {
            yToken.withdraw(yToken.balanceOf(address(this)));
        }
    }
}