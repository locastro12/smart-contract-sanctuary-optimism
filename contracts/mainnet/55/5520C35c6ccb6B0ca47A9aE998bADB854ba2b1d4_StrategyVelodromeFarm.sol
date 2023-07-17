// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

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
abstract contract OwnableUpgradeable is Initializable, ContextUpgradeable {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    function __Ownable_init() internal onlyInitializing {
        __Ownable_init_unchained();
    }

    function __Ownable_init_unchained() internal onlyInitializing {
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
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

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
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
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
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
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
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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

// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.4.0;

// computes square roots using the babylonian method
// https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method
library Babylonian {
    // credit for this implementation goes to
    // https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
    function sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        // this block is equivalent to r = uint256(1) << (BitMath.mostSignificantBit(x) / 2);
        // however that code costs significantly more gas
        uint256 xx = x;
        uint256 r = 1;
        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint256 r1 = x / r;
        return (r < r1 ? r : r1);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILeechRouter {
    function base() external view returns (address);

    function paused() external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategyMasterchefFarmV2 {
    /// @dev Universal instalation params.
    struct InstallParams {
        address controller;
        address router;
        address treasury;
        uint16 protocolFee;
        uint16 slippage;
    }

    /// @dev Emitted when reards get autocompounded.
    event Compounded(uint256 rewardAmount, uint256 fee, uint256 time);

    /// @dev Caller unauthorized.
    error Unauthorized();

    /// @dev Unexpected token address.
    error BadToken();

    /// @dev Strategy disabled.
    error NotActive();

    /// @dev Amount is zero.
    error ZeroAmount();

    /// @dev Address is zero.
    error ZeroAddress();

    /// @dev Protocol paused.
    error OnPause();

    /// @dev Slippage too big.
    error SlippageProtection();

    /// @dev Slippage percentage too big.
    error SlippageTooHigh();

    /// @dev Wrong amount.
    error BadAmount();

    /// @dev Strategy disabled.
    error StrategyDisabled();

    /// @dev Different size of arrays.
    error ArrayDifferentLength();

    /// @dev No rewards to claim.
    error NoRewardsAvailable();

    /// @dev Reentrancy detected.
    error Reentrancy();

    function balance() external view returns (uint256);

    function claimable()
        external
        view
        returns (address[] memory tokens, uint256[] memory amounts);

    function deposit(
        uint16 poolId,
        IERC20 depositToken,
        bytes memory data
    ) external returns (uint256);

    function withdraw(
        uint16 poolId,
        uint256 shares,
        IERC20 tokenOut,
        bytes memory data
    ) external returns (uint256);

    /**
     * @notice Move liquidity to another strategy.
     * @param pool Pool ID.
     * @param _slippage Slippage tolerance.
     * @param data Additional params.
     * @return amountOut Withdraw token amount.
     */
    function migrate(
        uint16 pool,
        uint16 _slippage,
        bytes memory data
    ) external returns (uint256 amountOut);

    function autocompound(uint16 slippage) external;

    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata path1,
        address[] calldata path2,
        bytes calldata data,
        uint256 price1,
        uint256 price2
    ) external view returns (uint256 amountOut);

    function allocationOf(uint16 poolId) external view returns (uint256);

    function totalAllocation() external view returns (uint256);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 *        __                   __
 *       / /   ___  ___  _____/ /_
 *      / /   / _ \/ _ \/ ___/ __ \
 *     / /___/  __/  __/ /__/ / / / v.0.2-beta
 *    /_____/\___/\___/\___/_/ /_/           __
 *    / __ \_________  / /_____  _________  / /
 *   / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ /
 *  / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /
 * /_/   /_/   \____/\__/\____/\___/\____/_/
 *
 * @title Leech Protocol helpers and utilities.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward here [email protected]
 */
library Helpers {
    /// @dev SafeERC20 library from OpenZeppelin.
    using SafeERC20 for IERC20;

    /// @notice For decimals (1 = 0.01).
    uint16 public constant DENOMINATOR = 10000;

    /// @notice Leech Protocol fee is limited by 20%.
    uint16 public constant MAX_FEE = 2000;

    /// @notice Percent is more than denominator or max fee amount.
    error PercentExeedsMaximalValue();

    /**
     * @notice Calc protocol fee amount.
     * @param amount Full amount.
     * @param fees Slippage percent.
     * @return Fee amount.
     */
    function calcFee(
        uint256 amount,
        uint16 fees
    ) external pure returns (uint256) {
        if (fees == 0) return 0;
        if (fees > MAX_FEE) revert PercentExeedsMaximalValue();

        return (amount * fees) / DENOMINATOR;
    }

    /**
     * @notice Calc minAmount for tokens swap.
     * @param amount Full amount.
     * @param slippage Slippage tolerance percentage (1% = 100).
     * @return Minimal token amount after swap.
     */
    function withSlippage(
        uint256 amount,
        uint16 slippage
    ) external pure returns (uint256) {
        if (slippage == 0) return amount;
        if (slippage > DENOMINATOR) revert PercentExeedsMaximalValue();

        return amount - ((amount * slippage) / DENOMINATOR);
    }

    /**
     * @notice Converts "abi.encode(address)" string back to address.
     * @param b Bytes with address.
     * @return decoded Recovered address.
     */
    function toAddress(
        bytes calldata b
    ) external pure returns (address decoded) {
        decoded = abi.decode(b, (address));
    }

    /**
     * @notice Emergency withdraw for stuck tokens.
     * @param token Token instance.
     */
    function rescue(IERC20 token) external {
        token.safeTransfer(msg.sender, token.balanceOf(address(this)));
    }

    /**
     * @notice Approve tokens for external contract.
     * @param token Token instance.
     * @param to Address to be approved.
     */
    function approveAll(IERC20 token, address to) external {
        if (token.allowance(address(this), to) != type(uint256).max) {
            token.forceApprove(address(to), type(uint256).max);
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IStrategyMasterchefFarmV2.sol";
import "../interfaces/ILeechRouter.sol";

/// @custom:oz-upgrades-unsafe-allow external-library-linking
/**
 *        __                   __
 *       / /   ___  ___  _____/ /_
 *      / /   / _ \/ _ \/ ___/ __ \
 *     / /___/  __/  __/ /__/ / / / v.0.2-beta
 *    /_____/\___/\___/\___/_/ /_/           __
 *    / __ \_________  / /_____  _________  / /
 *   / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ /
 *  / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /
 * /_/   /_/   \____/\__/\____/\___/\____/_/
 *
 * @title Base farming strategy.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward ([email protected]).
 */

abstract contract BaseFarmStrategy is
    OwnableUpgradeable,
    IStrategyMasterchefFarmV2
{
    /// @dev SafeERC20 library from OpenZeppelin.
    using SafeERC20 for IERC20;

    /// @notice The protocol fee limit is 12%.
    uint16 public constant MAX_FEE = 1200;

    /// @notice Used for fractional part (1 = 0.01)
    uint16 public constant DENOMINATOR = 10000;

    /// @notice Address of Leech's backend.
    address public controller;

    /// @notice Address of LeechRouter.
    address public router;

    /// @notice Treasury address.
    address public treasury;

    /// @notice Leech's comission.
    uint16 public protocolFee;

    /// @notice Sum of all pools shares.
    uint256 public totalAllocation;

    /// @notice Swap slippage.
    uint16 public slippage; // 1% by default

    /// @dev Re-entrancy lock.
    bool private locked;

    /// @notice Share of pool
    /// @dev poolId => allocPoints
    mapping(uint16 => uint256) public allocationOf;

    /// @dev Limit access for the LeechRouter only.
    modifier onlyRouter() {
        if (msg.sender != router) revert Unauthorized();
        _;
    }

    /// @dev Unsigned integer should be great than zero.
    modifier notZeroAmount(uint256 amountToCheck) {
        if (amountToCheck == 0) revert ZeroAmount();
        _;
    }

    /// @dev Address shouldn't be empty.
    modifier notZeroAddress(address addressToCheck) {
        if (addressToCheck == address(0)) revert ZeroAddress();
        _;
    }

    /// @dev Re-entrancy lock
    modifier lock() {
        if (locked) revert Reentrancy();
        locked = true;
        _;
        locked = false;
    }

    /**
     * @notice Take fees and re-invests rewards.
     */
    function autocompound(uint16) public virtual {
        // Revert if protocol paused
        if (ILeechRouter(router).paused()) revert OnPause();
    }

    /**
     * @notice Move liquidity to another strategy.
     * @param pool Pool ID.
     * @param _slippage Slippage tolerance.
     * @param data Additional params.
     * @return amountOut Withdraw token amount.
     */
    function migrate(
        uint16 pool,
        uint16 _slippage,
        bytes memory data
    ) external onlyRouter returns (uint256 amountOut) {
        // Calc amount in LP tokens
        uint256 _lpAmount = (balance() * allocationOf[pool]) / totalAllocation;
        // Reduce shares if not migration
        totalAllocation -= allocationOf[pool];
        allocationOf[pool] = 0;
        // Withdraw to, amount, path1...
        amountOut = _withdraw(
            _lpAmount,
            IERC20(ILeechRouter(router).base()),
            data,
            _slippage
        );
    }

    /**
     * @notice Depositing into the farm pool.
     * @dev Only LeechRouter can call this function.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param poolId Pool identifier.
     * @param depositToken Incoming token.
     * @param data Additional data.
     * @return share Deposit allocation.
     */
    function deposit(
        uint16 poolId,
        IERC20 depositToken,
        bytes memory data
    ) public virtual onlyRouter returns (uint256 share) {
        // Get external LP amount
        share = _deposit(data, depositToken);
        // Balance of LP before deposit
        uint256 _initialBalance = balance() - share;
        // Second+ deposit
        if (totalAllocation != 0 && _initialBalance != 0) {
            // Calc deposit share
            share = (share * totalAllocation) / _initialBalance;
        }
        // Revert is nothing to deposit
        if (share == 0) revert ZeroAmount();
        // Update pool allocation
        allocationOf[poolId] += share;
        // Update total allcation
        totalAllocation += share;
    }

    /**
     * @notice Withdrawing staking token (LP) from the strategy.
     * @dev Can only be called by LeechRouter.
     * @dev Re-entrancy lock on the LeechRouter side.
     * @param poolId Pool identifier.
     * @param shares Amount of the strategy shares to be withdrawn.
     * @param tokenOut Token to be swapped to.
     * @param data Output token encoded to bytes string.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function withdraw(
        uint16 poolId,
        uint256 shares,
        IERC20 tokenOut,
        bytes memory data
    )
        public
        virtual
        onlyRouter
        notZeroAmount(shares)
        returns (uint256 tokenOutAmount)
    {
        // Is amount more than pool have?
        if (shares > allocationOf[poolId]) revert BadAmount();
        // Calc amount in LP tokens
        uint256 _lpAmount = (balance() * shares) / totalAllocation;
        // Reduce shares if not migration
        allocationOf[poolId] -= shares;
        totalAllocation -= shares;
        // Return amount of tokenOut
        tokenOutAmount = _withdraw(_lpAmount, tokenOut, data, slippage);
    }

    /**
     * @notice Sets fee taken by the Leech protocol.
     * @dev Only owner can set the protocol fee.
     * @param _fee Fee value.
     */
    function setFee(uint16 _fee) external virtual onlyOwner {
        if (_fee > MAX_FEE) revert BadAmount();
        protocolFee = _fee;
    }

    /**
     * @notice Sets the tresury address.
     * @dev Only owner can set the treasury address.
     * @param _treasury The address to be set.
     */
    function setTreasury(address _treasury) external virtual onlyOwner {
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    /**
     * @notice Sets the controller address.
     * @dev Only owner can set the controller address.
     * @param _controller The address to be set.
     */
    function setController(address _controller) external virtual onlyOwner {
        if (_controller == address(0)) revert ZeroAddress();
        controller = _controller;
    }

    /**
     * @notice Sets slippage tolerance.
     * @dev Only owner can set the slippage tolerance.
     * @param _slippage Slippage percent (1 == 0.01%).
     */
    function setSlippage(uint16 _slippage) external virtual onlyOwner {
        if (_slippage > DENOMINATOR) revert SlippageTooHigh();
        if (_slippage == 0) revert ZeroAmount();
        slippage = _slippage;
    }

    /**
     * @notice Function returns estimated amount of token out from the LP withdrawn LP amount.
     * @param shares Amount of shares.
     * @param token0toTokenOut Path to output token.
     * @param token1toTokenOut Path to output token.
     * @param data Additional params.
     * @param price0 Price of token0.
     * @param price1 Price of token1.
     */
    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata token0toTokenOut,
        address[] calldata token1toTokenOut,
        bytes calldata data,
        uint256 price0,
        uint256 price1
    ) public view virtual returns (uint256 amountOut) {}

    /**
     * @notice Address of base token.
     * @return Base token address.
     */
    function base() public view virtual returns (address) {
        return ILeechRouter(router).base();
    }

    /**
     * @notice Amount of LPs staked into Masterchef.
     * @return amount LP amount.
     */
    function balance() public view virtual returns (uint256 amount) {}

    /**
     * @notice Amounts of pending rewards.
     * @return tokens Array of reward tokens.
     * @return amounts Array of reward amounts.
     */
    function claimable()
        public
        view
        virtual
        returns (address[] memory tokens, uint256[] memory amounts)
    {}

    /**
     * @dev Depositing into the farm pool.
     * @return share External pool deposit LP amount.
     */
    function _deposit(
        bytes memory,
        IERC20
    ) internal virtual returns (uint256 share) {}

    /**
     * @dev Withdrawing staking token (LP) from the strategy.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function _withdraw(
        uint256,
        IERC20,
        bytes memory,
        uint16
    ) internal virtual returns (uint256 tokenOutAmount) {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 */
interface IERC20Metadata {
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

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IGauge {
    function balanceOf(address) external view returns (uint256);

    function batchRewardPerToken(address token, uint256 maxRuns) external;

    function batchUpdateRewardPerToken(address token, uint256 maxRuns) external;

    function checkpoints(
        address,
        uint256
    ) external view returns (uint256 timestamp, uint256 balanceOf);

    function claimFees() external returns (uint256 claimed0, uint256 claimed1);

    function deposit(uint256 amount, uint256 tokenId) external;

    function depositAll(uint256 tokenId) external;

    function derivedBalance(address account) external view returns (uint256);

    function derivedBalances(address) external view returns (uint256);

    function derivedSupply() external view returns (uint256);

    function earned(
        address token,
        address account
    ) external view returns (uint256);

    function external_bribe() external view returns (address);

    function fees0() external view returns (uint256);

    function fees1() external view returns (uint256);

    function getPriorBalanceIndex(
        address account,
        uint256 timestamp
    ) external view returns (uint256);

    function getPriorRewardPerToken(
        address token,
        uint256 timestamp
    ) external view returns (uint256, uint256);

    function getPriorSupplyIndex(
        uint256 timestamp
    ) external view returns (uint256);

    function getReward(address account, address[] memory tokens) external;

    function internal_bribe() external view returns (address);

    function isForPair() external view returns (bool);

    function isReward(address) external view returns (bool);

    function lastEarn(address, address) external view returns (uint256);

    function lastTimeRewardApplicable(
        address token
    ) external view returns (uint256);

    function lastUpdateTime(address) external view returns (uint256);

    function left(address token) external view returns (uint256);

    function notifyRewardAmount(address token, uint256 amount) external;

    function numCheckpoints(address) external view returns (uint256);

    function periodFinish(address) external view returns (uint256);

    function rewardPerToken(address token) external view returns (uint256);

    function rewardPerTokenCheckpoints(
        address,
        uint256
    ) external view returns (uint256 timestamp, uint256 rewardPerToken);

    function rewardPerTokenNumCheckpoints(
        address
    ) external view returns (uint256);

    function rewardPerTokenStored(address) external view returns (uint256);

    function rewardRate(address) external view returns (uint256);

    function rewards(uint256) external view returns (address);

    function rewardsListLength() external view returns (uint256);

    function stake() external view returns (address);

    function supplyCheckpoints(
        uint256
    ) external view returns (uint256 timestamp, uint256 supply);

    function supplyNumCheckpoints() external view returns (uint256);

    function swapOutRewardToken(
        uint256 i,
        address oldToken,
        address newToken
    ) external;

    function tokenIds(address) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function userRewardPerTokenStored(
        address,
        address
    ) external view returns (uint256);

    function voter() external view returns (address);

    function withdraw(uint256 amount) external;

    function withdrawAll() external;

    function withdrawToken(uint256 amount, uint256 tokenId) external;
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IRouterVelodrome {
    struct route {
        address from;
        address to;
        bool stable;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function addLiquidityETH(
        address token,
        bool stable,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function factory() external view returns (address);

    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amount, bool stable);

    function getAmountsOut(
        uint amountIn,
        route[] memory routes
    ) external view returns (uint[] memory amounts);

    function getReserves(
        address tokenA,
        address tokenB,
        bool stable
    ) external view returns (uint256 reserveA, uint256 reserveB);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 amountADesired,
        uint256 amountBDesired
    )
        external
        view
        returns (uint256 amountA, uint256 amountB, uint256 liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity
    ) external view returns (uint256 amountA, uint256 amountB);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityETHWithPermit(
        address token,
        bool stable,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function sortTokens(
        address tokenA,
        address tokenB
    ) external pure returns (address token0, address token1);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        IRouterVelodrome.route[] memory routes,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        IRouterVelodrome.route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        IRouterVelodrome.route[] memory routes,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForTokensSimple(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function weth() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

interface IVelodromePair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function reserve0() external view returns (uint256 reserve0);

    function reserve1() external view returns (uint256 reserve1);

    function burn(address to) external returns (uint amount0, uint amount1);

    function totalSupply() external view returns (uint256);

    function stable() external view returns (bool);

    function getAmountOut(uint, address) external view returns (uint);

    function factory() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "./IVelodromePair.sol";
import "./IGauge.sol";
import "./IRouterVelodrome.sol";
import "./IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../libraries/Helpers.sol";
import "./../BaseFarmStrategy.sol";
import "@uniswap/lib/contracts/libraries/Babylonian.sol";

/**
 *        __                   __
 *       / /   ___  ___  _____/ /_
 *      / /   / _ \/ _ \/ ___/ __ \
 *     / /___/  __/  __/ /__/ / / / v.0.2-beta
 *    /_____/\___/\___/\___/_/ /_/           __
 *    / __ \_________  / /_____  _________  / /
 *   / /_/ / ___/ __ \/ __/ __ \/ ___/ __ \/ /
 *  / ____/ /  / /_/ / /_/ /_/ / /__/ /_/ / /
 * /_/   /_/   \____/\__/\____/\___/\____/_/
 *
 * @title Leech Protocol farming strategy for Velodrome.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @notice Only for the stable pairs on Velodrome V1.
 * @custom:version 0.2-beta.
 * @custom:network Optimism (chainId 10).
 * @custom:provider Velodrome (https://app.velodrome.finance/).
 * @custom:security Found vulnerability? Get reward ([email protected]).
 */
contract StrategyVelodromeFarm is BaseFarmStrategy {
    /// @dev OpenZeppelin's library for ERC20 tokens.
    using SafeERC20 for IERC20;

    /// @dev A library used to extract address from bytes.
    using Helpers for bytes;

    /// @dev A library used to calculate slippage.
    using Helpers for uint256;

    /// @dev A library used for max token approve.
    using Helpers for IERC20;

    /// @notice Velodrome dex router
    IRouterVelodrome public constant VELODROME_ROUTER =
        IRouterVelodrome(0x9c12939390052919aF3155f41Bf4160Fd3666A6f);

    /// @notice USD Cirle token.
    IERC20 public constant USDC =
        IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607);

    /// @notice Tether token.
    IERC20 public constant USDT =
        IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58);

    /// @notice Pool reward.
    IERC20 public constant VELO =
        IERC20(0x3c8B650257cFb5f272f799F5e2b4e65093a11a05);

    /// @notice First token of the pair.
    IERC20 public token0;

    /// @notice Second token of the pair.
    IERC20 public token1;

    /// @notice Liquidity provider token.
    IVelodromePair public lp;

    /// @notice Pair gauge.
    IGauge public gauge;

    /// @notice External pool id.
    uint16 public poolId;

    /// @notice Token exchnage route paths
    /// @dev tokenIn => tokenOut => Velodrome routes array
    mapping(IERC20 => mapping(IERC20 => IRouterVelodrome.route[]))
        public routes;

    /**
     * @notice Executes by contract deployment.
     * @param params General strategy parameters.
     * @param _token0 First token of the pair.
     * @param _token1 Second token of the pair.
     * @param _lp LP token.
     * @param _poolId Id of the farmed Velodrome pair.
     */
    function initialize(
        InstallParams memory params,
        IERC20 _token0,
        IERC20 _token1,
        IVelodromePair _lp,
        IGauge _gauge,
        uint16 _poolId
    ) external initializer {
        __Ownable_init();
        // Set params on deploy
        (controller, router, treasury, protocolFee, slippage) = (
            params.controller,
            params.router,
            params.treasury,
            params.protocolFee,
            params.slippage
        );
        (token0, token1, lp, gauge, poolId) = (
            _token0,
            _token1,
            _lp,
            _gauge,
            _poolId
        );
        // Approve ERC20 transfers
        IERC20(address(lp)).approveAll(address(gauge));
        token0.approveAll(address(VELODROME_ROUTER));
        token1.approveAll(address(VELODROME_ROUTER));
        VELO.approveAll(address(VELODROME_ROUTER));
        USDC.approveAll(address(VELODROME_ROUTER));
        USDT.approveAll(address(VELODROME_ROUTER));
    }

    /**
     * @notice Sets paths for token swap.
     * @dev Only owner can set a paths.
     * @param tokenIn From token.
     * @param tokenOut To token.
     * @param routesList Velodrome routes array.
     */
    function setRoutes(
        IERC20 tokenIn,
        IERC20 tokenOut,
        IRouterVelodrome.route[] memory routesList
    ) external onlyOwner {
        routes[tokenIn][tokenOut] = routesList;
    }

    /**
     * @notice Re-invests rewards.
     */
    function autocompound(uint16) public override {
        // Execute parent
        super.autocompound(0);
        // Do we have something to claim?
        (address[] memory _tokens, uint256[] memory _claimable) = claimable();
        if (_claimable[0] == 0) revert ZeroAmount();
        // Mint rewards
        gauge.getReward(address(this), _tokens);
        // Get reward amount
        uint256 reward = VELO.balanceOf(address(this));
        // Calc fee
        uint256 fee = (reward * protocolFee) / DENOMINATOR;
        // Send fee to the treasure
        VELO.safeTransfer(treasury, fee);
        // Re-invest reward
        _deposit("", VELO);
        // Notify services
        emit Compounded(reward, fee, block.timestamp);
    }

    /**
     * @notice Function returns estimated amount of token out from the LP withdrawn LP amount.
     * @param shares Amount of shares.
     */
    function quotePotentialWithdraw(
        uint256 shares,
        address[] calldata,
        address[] calldata,
        bytes calldata,
        uint256,
        uint256
    ) public view override returns (uint256 amountOut) {
        // Get default token
        address baseToken = ILeechRouter(router).base();
        // Convert shares to LP amount
        uint256 wantBalance = (balance() * shares) / totalAllocation;
        // Get pool reserves
        (uint256 reserve0, uint256 reserve1, ) = lp.getReserves();
        // Get pool total supply
        uint256 totalSupply = lp.totalSupply();
        // Amount of token0
        uint256 token0Amount = (wantBalance * reserve0) / totalSupply;
        // Amount of token1
        uint256 token1Amount = (wantBalance * reserve1) / totalSupply;
        // Amount of token0 in base token
        if (address(token0) != baseToken) {
            (uint256 getAmount, ) = VELODROME_ROUTER.getAmountOut(
                token0Amount,
                address(token0),
                address(baseToken)
            );
            amountOut += getAmount;
        } else {
            amountOut += token0Amount;
        }
        // Amount of token1 in base token
        if (address(token1) != baseToken) {
            (uint256 getAmount, ) = VELODROME_ROUTER.getAmountOut(
                token1Amount,
                address(token1),
                address(baseToken)
            );
            amountOut += getAmount;
        } else {
            amountOut += token1Amount;
        }
    }

    /**
     * @notice Amount of pending rewards
     * @return tokens Array of reward tokens.
     * @return amounts Array of reward amounts.
     */
    function claimable()
        public
        view
        override
        returns (address[] memory tokens, uint256[] memory amounts)
    {
        tokens = new address[](1);
        amounts = new uint256[](1);
        tokens[0] = address(VELO);
        amounts[0] = gauge.earned(address(VELO), address(this));
    }

    /**
     * @notice Amount of LPs staked into Masterchef.
     * @return Amount in want token.
     */
    function balance() public view override returns (uint256) {
        return gauge.balanceOf(address(this));
    }


    /**
     * @notice Depositing into the farm pool.
     * @param depositToken Token in.
     * @return shares Pool share of user.
     */
    function _deposit(
        bytes memory,
        IERC20 depositToken
    ) internal override returns (uint256 shares) {
        // Check depositToken
        if (
            depositToken != USDC && depositToken != USDT && depositToken != VELO
        ) revert BadToken();
        // Get balance of deposit token
        uint256 tokenBal = depositToken.balanceOf(address(this));
        // Revert if zero amount
        if (tokenBal == 0) revert ZeroAmount();
        // Convert to token0
        VELODROME_ROUTER.swapExactTokensForTokens(
            tokenBal,
            depositToken != VELO ? tokenBal.withSlippage(slippage) : 0, // autocompound check
            routes[depositToken][token0],
            address(this),
            block.timestamp
        );
        // Deposit balance in token0
        tokenBal = token0.balanceOf(address(this));
        // Quote deposit amounts
        (uint256 reserveA, uint256 reserveB,) = lp.getReserves();
        uint256 swapAmountIn = _getSwapAmount(tokenBal, reserveA, reserveB, address(token0), address(token1));

        // Swap half amount to second token
        uint256[] memory swapedAmounts = VELODROME_ROUTER
            .swapExactTokensForTokens(
                swapAmountIn,
                0,
                routes[token0][token1],
                address(this),
                block.timestamp
            );

        // Stake tokens
        VELODROME_ROUTER.addLiquidity(
            address(token0),
            address(token1),
            true, // is stable?
            tokenBal - swapAmountIn,
            swapedAmounts[swapedAmounts.length - 1],
            1,
            1,
            address(this),
            block.timestamp
        );
        // Get deposit amount in LP
        shares = IERC20(address(lp)).balanceOf(address(this));
        // Deposit into farm
        gauge.deposit(shares, 0);

        if (token0.balanceOf(address(this)) != 0) {
            token0.safeTransfer(treasury, token0.balanceOf(address(this)));
        }

        if (token1.balanceOf(address(this)) != 0) {
            token1.safeTransfer(treasury, token1.balanceOf(address(this)));
        }
    }

    /**
     * @notice Withdrawing staking token (LP) from the strategy.
     * @dev Can only be called by LeechRouter.
     * @param shares Amount of the strategy shares to be withdrawn.
     * @return tokenOutAmount Amount of the token returned to LeechRouter.
     */
    function _withdraw(
        uint256 shares,
        IERC20 withdrawToken,
        bytes memory,
        uint16
    ) internal override returns (uint256 tokenOutAmount) {
        // Unstake LPs
        gauge.withdraw(shares);
        // Disassembly LPs
        IERC20(address(lp)).safeTransfer(
            address(lp),
            IERC20(address(lp)).balanceOf(address(this))
        );
        lp.burn(address(this));
        // Swap token0 to base token if needed
        if (address(token0) != address(withdrawToken)) {
            VELODROME_ROUTER.swapExactTokensForTokens(
                token0.balanceOf(address(this)),
                0,
                routes[token0][withdrawToken],
                address(this),
                block.timestamp
            );
        }
        // Swap token1 to base token if needed
        if (address(token1) != address(withdrawToken)) {
            VELODROME_ROUTER.swapExactTokensForTokens(
                token1.balanceOf(address(this)),
                0,
                routes[token1][withdrawToken],
                address(this),
                block.timestamp
            );
        }
        // Get balance of the base token
        tokenOutAmount = withdrawToken.balanceOf(address(this));
        // Send to LeechRouter for withdraw
        withdrawToken.safeTransfer(router, tokenOutAmount);
    }

    /**
    * @dev Calculates the swap amount for a given investment in a decentralized exchange.
    * @param investmentA The amount of token A being invested.
    * @param reserveA The reserve amount of token A in the exchange.
    * @param reserveB The reserve amount of token B in the exchange.
    * @param tokenA The address of token A.
    * @param tokenB The address of token B.
    * @return swapAmount The calculated swap amount.
    */
    function _getSwapAmount(uint256 investmentA, uint256 reserveA, uint256 reserveB, address tokenA, address tokenB) private view returns (uint256 swapAmount) {
        uint256 halfInvestment = investmentA / 2;

        if (lp.stable()) {
            swapAmount = _getStableSwap(investmentA, halfInvestment, tokenA, tokenB);
        } else {
            uint256 nominator = lp.getAmountOut(halfInvestment, tokenA);
            uint256 denominator = halfInvestment * (reserveB - nominator) / (reserveA + halfInvestment);
            swapAmount = investmentA - (Babylonian.sqrt(halfInvestment * halfInvestment * nominator / denominator));
        }
    }

    /**
    * @dev Calculates the swap amount for a stable pool in a decentralized exchange.
    * @param investmentA The amount of token A being invested.
    * @param halfInvestment Half of the investment amount of token A.
    * @param tokenA The address of token A.
    * @param tokenB The address of token B.
    * @return swapAmount The calculated swap amount.
    */
    function _getStableSwap(uint256 investmentA, uint256 halfInvestment, address tokenA, address tokenB) private view returns (uint256 swapAmount) {
        uint out = lp.getAmountOut(halfInvestment, tokenA);
        (uint amountA, uint amountB,) = VELODROME_ROUTER.quoteAddLiquidity(tokenA, tokenB, lp.stable(), halfInvestment, out);

        amountA = amountA * 1e18 / 10**IERC20Metadata(tokenA).decimals();
        amountB = amountB * 1e18 / 10**IERC20Metadata(tokenB).decimals();
        out = out * 1e18 / 10**IERC20Metadata(tokenB).decimals();
        halfInvestment = halfInvestment * 1e18 / 10**IERC20Metadata(tokenA).decimals();

        uint ratio = out * 1e18 / halfInvestment * amountA / amountB;

        return investmentA * 1e18 / (ratio + 1e18);
    }
}