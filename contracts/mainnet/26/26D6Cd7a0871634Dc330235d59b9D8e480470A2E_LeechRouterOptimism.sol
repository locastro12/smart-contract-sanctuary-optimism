// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControlUpgradeable.sol";
import "../utils/ContextUpgradeable.sol";
import "../utils/StringsUpgradeable.sol";
import "../utils/introspection/ERC165Upgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControlUpgradeable is Initializable, ContextUpgradeable, IAccessControlUpgradeable, ERC165Upgradeable {
    function __AccessControl_init() internal onlyInitializing {
    }

    function __AccessControl_init_unchained() internal onlyInitializing {
    }
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlUpgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        StringsUpgradeable.toHexString(account),
                        " is missing role ",
                        StringsUpgradeable.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControlUpgradeable {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
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
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/ContextUpgradeable.sol";
import "../proxy/utils/Initializable.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract PausableUpgradeable is Initializable, ContextUpgradeable {
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
    function __Pausable_init() internal onlyInitializing {
        __Pausable_init_unchained();
    }

    function __Pausable_init_unchained() internal onlyInitializing {
        _paused = false;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ReentrancyGuardUpgradeable is Initializable {
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

    function __ReentrancyGuard_init() internal onlyInitializing {
        __ReentrancyGuard_init_unchained();
    }

    function __ReentrancyGuard_init_unchained() internal onlyInitializing {
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
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165Upgradeable {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library MathUpgradeable {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
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
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

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
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMathUpgradeable {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/MathUpgradeable.sol";
import "./math/SignedMathUpgradeable.sol";

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = MathUpgradeable.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMathUpgradeable.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, MathUpgradeable.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/cryptography/ECDSA.sol)

pragma solidity ^0.8.0;

import "../Strings.sol";

/**
 * @dev Elliptic Curve Digital Signature Algorithm (ECDSA) operations.
 *
 * These functions can be used to verify that a message was signed by the holder
 * of the private keys of a given address.
 */
library ECDSA {
    enum RecoverError {
        NoError,
        InvalidSignature,
        InvalidSignatureLength,
        InvalidSignatureS,
        InvalidSignatureV // Deprecated in v4.8
    }

    function _throwError(RecoverError error) private pure {
        if (error == RecoverError.NoError) {
            return; // no error: do nothing
        } else if (error == RecoverError.InvalidSignature) {
            revert("ECDSA: invalid signature");
        } else if (error == RecoverError.InvalidSignatureLength) {
            revert("ECDSA: invalid signature length");
        } else if (error == RecoverError.InvalidSignatureS) {
            revert("ECDSA: invalid signature 's' value");
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature` or error string. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     *
     * Documentation for signature generation:
     * - with https://web3js.readthedocs.io/en/v1.3.4/web3-eth-accounts.html#sign[Web3.js]
     * - with https://docs.ethers.io/v5/api/signer/#Signer-signMessage[ethers]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes memory signature) internal pure returns (address, RecoverError) {
        if (signature.length == 65) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            // ecrecover takes the signature parameters, and the only way to get them
            // currently is to use assembly.
            /// @solidity memory-safe-assembly
            assembly {
                r := mload(add(signature, 0x20))
                s := mload(add(signature, 0x40))
                v := byte(0, mload(add(signature, 0x60)))
            }
            return tryRecover(hash, v, r, s);
        } else {
            return (address(0), RecoverError.InvalidSignatureLength);
        }
    }

    /**
     * @dev Returns the address that signed a hashed message (`hash`) with
     * `signature`. This address can then be used for verification purposes.
     *
     * The `ecrecover` EVM opcode allows for malleable (non-unique) signatures:
     * this function rejects them by requiring the `s` value to be in the lower
     * half order, and the `v` value to be either 27 or 28.
     *
     * IMPORTANT: `hash` _must_ be the result of a hash operation for the
     * verification to be secure: it is possible to craft signatures that
     * recover to arbitrary addresses for non-hashed data. A safe way to ensure
     * this is by receiving a hash of the original message (which may otherwise
     * be too long), and then calling {toEthSignedMessageHash} on it.
     */
    function recover(bytes32 hash, bytes memory signature) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, signature);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `r` and `vs` short-signature fields separately.
     *
     * See https://eips.ethereum.org/EIPS/eip-2098[EIP-2098 short signatures]
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(bytes32 hash, bytes32 r, bytes32 vs) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, r, vs);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Overload of {ECDSA-tryRecover} that receives the `v`,
     * `r` and `s` signature fields separately.
     *
     * _Available since v4.3._
     */
    function tryRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address, RecoverError) {
        // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
        // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
        // the valid range for s in (301): 0 < s < secp256k1n ÷ 2 + 1, and for v in (302): v ∈ {27, 28}. Most
        // signatures from current libraries generate a unique signature with an s-value in the lower half order.
        //
        // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
        // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
        // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
        // these malleable signatures as well.
        if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
            return (address(0), RecoverError.InvalidSignatureS);
        }

        // If the signature is valid (and not malleable), return the signer address
        address signer = ecrecover(hash, v, r, s);
        if (signer == address(0)) {
            return (address(0), RecoverError.InvalidSignature);
        }

        return (signer, RecoverError.NoError);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `v`,
     * `r` and `s` signature fields separately.
     */
    function recover(bytes32 hash, uint8 v, bytes32 r, bytes32 s) internal pure returns (address) {
        (address recovered, RecoverError error) = tryRecover(hash, v, r, s);
        _throwError(error);
        return recovered;
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from a `hash`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32 message) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32")
            mstore(0x1c, hash)
            message := keccak256(0x00, 0x3c)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Message, created from `s`. This
     * produces hash corresponding to the one signed with the
     * https://eth.wiki/json-rpc/API#eth_sign[`eth_sign`]
     * JSON-RPC method as part of EIP-191.
     *
     * See {recover}.
     */
    function toEthSignedMessageHash(bytes memory s) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n", Strings.toString(s.length), s));
    }

    /**
     * @dev Returns an Ethereum Signed Typed Data, created from a
     * `domainSeparator` and a `structHash`. This produces hash corresponding
     * to the one signed with the
     * https://eips.ethereum.org/EIPS/eip-712[`eth_signTypedData`]
     * JSON-RPC method as part of EIP-712.
     *
     * See {recover}.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32 data) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, "\x19\x01")
            mstore(add(ptr, 0x02), domainSeparator)
            mstore(add(ptr, 0x22), structHash)
            data := keccak256(ptr, 0x42)
        }
    }

    /**
     * @dev Returns an Ethereum Signed Data with intended validator, created from a
     * `validator` and `data` according to the version 0 of EIP-191.
     *
     * See {recover}.
     */
    function toDataWithIntendedValidatorHash(address validator, bytes memory data) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x00", validator, data));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

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
        return a > b ? a : b;
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
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
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
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

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
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

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
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ILeechTransporter {
    /**
     * @notice This function requires that `leechSwapper` is properly initialized
     * @param _destinationToken Address of the asset to be bridged
     * @param _bridgedAmount The amount of asset to send The ID of the destination chain to send to
     * @param _destinationChainId The ID of the destination chain to send to The address of the router on the destination chain
     * @param _destAddress The address on the destination chain
     */
    function bridgeOut(
        address _destinationToken,
        uint256 _bridgedAmount,
        uint256 _destinationChainId,
        address _destAddress
    ) external payable;

    /// @notice Emitted after successful bridging
    /// @param chainId Destination chain id
    /// @param routerAddress Destanation router address
    /// @param amount Amount of the underlying token
    event AssetBridged(uint256 chainId, address routerAddress, uint256 amount);
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
 * @title Leech Protocol router interface.
 * @notice The Router is the main protocol contract, for user interactions and protocol automatizations.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward here [email protected]
 */
interface ILeechRouter {
    /// @dev Struct for the strategy instance.
    struct Strategy {
        address addr;
        uint256 withdrawalFee;
        bool isLp;
    }

    /// @dev Struct for the pool instance.
    struct Pool {
        uint256 chainId; // 0 - disabled
        uint256 totalAllocation;
        uint16 strategyId;
        mapping(address => User) user;
    }

    /// @dev Struct for the LeechRouter instance.
    struct Router {
        uint256 id;
        uint256 chainId;
        address routerAddress;
    }

    /// @dev Struct for the pool user.
    struct User {
        uint256 allocation;
        uint256 delayToBlock;
    }

    /// @dev Emit in cross-chain deposits.
    event BaseBridged(
        address user,
        uint256 amountOfBase,
        uint256 poolId,
        uint256 strategyId,
        uint256 destinationChainId,
        uint256 fromChainId,
        address depositedToken
    );

    /// @dev Emit after deposit to the strategy.
    event Deposited(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 chainId,
        uint256 wantAmountDeposited,
        address depositedToken
    );

    /// @dev Emit in request withdraw function to notify back-end.
    event WithdrawalRequested(
        address user,
        uint256 poolId,
        uint256 amount,
        uint256 chainId,
        address tokenOut
    );

    /// @dev Emit after completeing withdrawal requests.
    event WithdrawCompleted(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 targetChainId,
        uint256 shares,
        uint256 wantAmount
    );

    /// @dev Emit after completeing cross-chain withdrawal requests.
    event CrosschainWithdrawCompleted(
        address user,
        uint256 poolId,
        uint256 strategyId,
        uint256 targetChainId,
        uint256 shares,
        uint256 wantAmount
    );

    /// @dev Emit after cross-chain migration is completed.
    event FinalizedCrosschainMigration(
        uint256 poolId,
        uint256 strategyId,
        uint256 chainId
    );

    /// @dev Start migration. If migration is not cross-chain this event is complete.
    event Migration(uint256 poolId, uint256 strategyId, uint256 chainId);

    error ZeroAddress();
    error ZeroValue();
    error Banned();
    error StrategyDisabled();
    error AmountTooLow();
    error AmountTooBig();
    error CrosschainError();
    error TransferFailed();
    error OnlyFinalizer();
    error BadToken();
    error BadArray();
    error BadSignature();
    error WithdrawDelay();

    /**
     * @notice User deposit method.
     * @param poolId Selected pool ID.
     * @param depositToken Deposited token address.
     * @param amount Amount of deposited token.
     * @param signature Signed message by the back-end.
     * @param maxBlockNumber Max block for the signature expiring.
     * @param data Additional pool data.
     */
    function deposit(
        uint16 poolId,
        IERC20 depositToken,
        uint256 amount,
        bytes calldata signature,
        uint256 maxBlockNumber,
        bytes memory data
    ) external payable;

    /**
     * @notice User crosschain deposit method.
     * @param poolId Selected pool ID.
     * @param depositToken Deposited token address.
     * @param bridgedToken Token for the crosschain bridging.
     * @param amount Amount of deposited token.
     * @param signature Signed message by the back-end.
     * @param maxBlockNumber Max block for the signature expiring.
     */
    function crosschainDeposit(
        uint16 poolId,
        IERC20 depositToken,
        IERC20 bridgedToken,
        uint256 amount,
        bytes calldata signature,
        uint256 maxBlockNumber
    ) external payable;

    /**
     * @notice Withdraw from the pool.
     * @notice Due to the cross-chain architecture of the protocol, share prices are stored on the BE side.
     * @param signature Signed message by the back-end.
     * @param poolId Selected pool ID.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param shares Amount of withdrawal token.
     * @param maxBlockNumber Max block for the signature expiring.
     * @param data Additional data.
     */
    function withdraw(
        uint16 poolId,
        IERC20 tokenOut,
        uint256 shares,
        uint256 maxBlockNumber,
        bytes calldata signature,
        bytes memory data
    ) external payable;

    /**
     * @notice After bridging completed we need to place tokens to farm.
     * @dev Used only to finalize cross-chain deposits.
     * @param user User address who performed a cross-chain deposit.
     * @param amount Amount of base token.
     * @param poolId Pool Id.
     * @param data Additional data.
     */
    function finalizeDeposit(
        address user,
        uint256 amount,
        uint16 poolId,
        bytes memory data
    ) external;

    /**
     * @notice User creates crosschain withdrawal request.
     * @notice Due to the cross-chain architecture of the protocol, share prices are stored on the BE side.
     * @param signature Signed message by the back-end.
     * @param poolId Selected pool ID.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param shares Amount of withdrawal token.
     * @param maxBlockNumber Max block for the signature expiring.
     */
    function crosschainWithdraw(
        uint16 poolId,
        IERC20 tokenOut,
        uint256 shares,
        uint256 maxBlockNumber,
        bytes calldata signature
    ) external payable;

    /**
     * @notice BE calls after WithdrawalRequested event was catched.
     * @notice Should be called on chain with active strategy
     * @param poolId Pool Id.
     * @param shares Amount in "want" token on strategy: LP or single token.
     * @param user User address.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param targetChainId Chain ID of the network where the withdrawal requests was created.
     * @param data Additional parameters.
     */
    function finalizeWithdrawal(
        uint16 poolId,
        uint256 shares,
        address user,
        IERC20 tokenOut,
        uint256 targetChainId,
        bytes memory data
    ) external payable;

    /**
     * @notice Move liquidity to the new strategy..
     * @dev Should be called only on active strategy chain.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Move to this strategy.
     * @param slippage Wanted slippage for swaps.
     * @param data Additional params.
     */
    function migration(
        uint16 poolId,
        uint16 newStrategyId,
        uint16 slippage,
        bytes memory data
    ) external;

    /**
     * @notice Move liquidity to another blockchain.
     * @dev Should be called only on active strategy chain.
     * @param targetChainId Move assets to this chainId.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Move to this strategy.
     * @param slippage Wanted slippage for swaps.
     * @param data Additional params.
     */
    function crosschainMigration(
        uint256 targetChainId,
        uint16 poolId,
        uint16 newStrategyId,
        uint16 slippage,
        bytes memory data
    ) external payable;

    /**
     * @notice 2nd additional step for change strategy
     * @notice Should be called only if pool total allocation on this chain is equal to zero.
     * @dev Can be called multiple times if arrays is too large.
     * @param poolId ID of the pool.
     * @param users Array of users to be migrated.
     * @param amounts Array of users amounts.
     */
    function migrateAllocations(
        uint16 poolId,
        address[] calldata users,
        uint256[] calldata amounts
    ) external;

    /**
     * @notice 3rd additional step for change strategy
     * @notice Should be called only if cross-chain migration was initialized and tokens received.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Id of the target strategy.
     * @param baseAmount Migrated amount in base stable token.
     * @param data Additional params.
     */
    function finalizeCrosschainMigration(
        uint16 poolId,
        uint16 newStrategyId,
        uint256 baseAmount,
        bytes memory data
    ) external;

    /**
     * @notice Calc potential withdraw amount from pool.
     * @param poolId ID of the pool.
     * @param shares Pool shares amount to withdraw.
     * @param token0toTokenOut May be used in some strategies.
     * @param token1toTokenOut May be used in some strategies.
     * @param data Additional params.
     * @return amountOut Amount converted from shares value to base token amount.
     */
    function quotePotentialWithdraw(
        uint16 poolId,
        uint256 shares,
        address[] calldata token0toTokenOut,
        address[] calldata token1toTokenOut,
        bytes calldata data
    ) external view returns (uint256 amountOut);

    /**
     * @notice Pool balance of user.
     * @param poolId ID of the pool.
     * @param user User's address.
     * @return User allocation.
     */
    function userAllocation(
        uint16 poolId,
        address user
    ) external view returns (uint256);

    /**
     * @notice Pool total allocation.
     * @param poolId ID of the pool.
     * @return Total allocation.
     */
    function totalAllocation(uint16 poolId) external view returns (uint256);

    /**
     * @notice Base token of current router.
     * @return Address of the base token.
     */
    function base() external view returns (address);
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/ILeechTransporter.sol";
import "../interfaces/IStrategyMasterchefFarmV2.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./ILeechRouter.sol";

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
 * @title Leech Protocol router base contract.
 * @notice The Router is the main protocol contract, for user interactions and protocol automatizations.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward here [email protected]
 */
abstract contract LeechRouterBase is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ILeechRouter
{
    /// @dev SafeERC20 library from OpenZeppelin.
    using SafeERC20 for IERC20;

    /// @dev For signer recovering.
    using ECDSA for bytes32;

    /// @notice 20% withdrawal fee limitation.
    uint256 public constant FEE_MAX = 2000;

    /// @notice withdrawal fee decimals.
    uint256 public constant FEE_DECIMALS = 10000;

    /// @notice Core team multi-sig.
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice Malicious actions observers.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Bridge interface abstraction.
    ILeechTransporter public transporter;

    /// @notice base protocol stablecoin.
    IERC20 public baseToken;

    /// @notice chain ID of the current network.
    uint256 public chainId;

    /// @notice Protocol fee receiver.
    address public treasury;

    /// @notice Signature validator address (EOA).
    address public signer;

    /// @notice Uniswap based router for simple exchanges.
    address public uniV2;

    /// @notice Finalizer role.
    address public finalizer;

    /// @notice Withdraw delay in blocks for security reasons.
    uint248 public withdrawDelay;

    /// @notice Switcher for the signature based input validation.
    bool public whitelistEnabled;

    /// @notice Token minimal deposit amount.
    mapping(address => uint256) public depositMinAmount;

    /// @notice Pools list.
    mapping(uint16 => Pool) public pools;

    /// @notice Mapping will return active strategy struct for the specific pool id.
    mapping(uint16 => Strategy) public strategies;

    /// @notice Mapping will return active router struct for the specific chain id.
    /// @dev Get router by chainId.
    mapping(uint256 => Router) public routers;

    /// @dev Mapping for disabling malicious actors.
    mapping(address => bool) public banned;

    /// @notice Modifier allows exlude banned addresses from execution, even if the valid signature exists.
    modifier enabled(address user) {
        if (banned[user]) revert Banned();
        _;
    }

    /// @notice Check pool id.
    modifier isActivePool(uint16 poolId) {
        if (pools[poolId].chainId == 0) revert StrategyDisabled();
        _;
    }

    /// @notice Limit access for early adopters.
    modifier checkWhitelist(bytes memory signature, uint256 maxBlockNumber) {
        if (whitelistEnabled) {
            if (block.number > maxBlockNumber) revert BadSignature();
            // Signature verification
            bytes32 msgHash = keccak256(abi.encode(msg.sender, maxBlockNumber));
            if (msgHash.toEthSignedMessageHash().recover(signature) != signer)
                revert BadSignature();
        }
        _;
    }

    /// @notice Prohibit zero address.
    /// @param checkAddr Address to check.
    modifier zeroAddr(address checkAddr) {
        if (checkAddr == address(0)) revert ZeroAddress();
        _;
    }

    /// @notice Prohibit zero amount.
    /// @param checkVal Value to check.
    modifier zeroVal(uint256 checkVal) {
        if (checkVal == 0) revert ZeroValue();
        _;
    }

    /// @notice Check deposit token for requirments.
    modifier checkDepositAmount(IERC20 depositToken, uint256 amount) {
        if (depositMinAmount[address(depositToken)] == 0) revert BadToken();
        if (amount < depositMinAmount[address(depositToken)])
            revert AmountTooLow();
        _;
    }

    /// @notice Check withdraw delay.
    modifier checkDelay(uint16 poolId, address user) {
        if (pools[poolId].user[user].delayToBlock >= block.number)
            revert WithdrawDelay();
        _;
    }

    /// @notice Only for finalizer service.
    modifier onlyFinalizer() {
        if (msg.sender != finalizer) revert OnlyFinalizer();
        _;
    }

    /**
     * @notice Initializer.
     * @param _baseToken Base stablecoin.
     * @param _uniV2Address Dex router address.
     * @param _treasury Fees receiver.
     * @param _signer Whitelist validator.
     * @param _finalizer Crosschain finalizer service.
     */
    function initialize(
        IERC20 _baseToken,
        address _uniV2Address,
        address _treasury,
        address _signer,
        address _finalizer
    ) public virtual initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        // Set roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        // Get current chain id
        uint256 _chainId;
        assembly {
            _chainId := chainid()
        }
        // Set initial params
        (baseToken, uniV2, chainId, treasury, signer, finalizer) = (
            _baseToken,
            _uniV2Address,
            _chainId,
            _treasury,
            _signer,
            _finalizer
        );
        // Enable whitelist access by default
        whitelistEnabled = true;
        // Set default delay to 0
        withdrawDelay = 0;
    }

    /**
     * @notice User deposit method.
     * @param poolId Selected pool ID.
     * @param depositToken Deposited token address.
     * @param amount Amount of deposited token.
     * @param signature Signed message by the back-end.
     * @param maxBlockNumber Max block for the signature expiring.
     * @param data Additional pool data.
     */
    function deposit(
        uint16 poolId,
        IERC20 depositToken,
        uint256 amount,
        bytes calldata signature,
        uint256 maxBlockNumber,
        bytes memory data
    )
        external
        payable
        virtual
        nonReentrant
        whenNotPaused
        isActivePool(poolId)
        enabled(msg.sender)
        checkWhitelist(signature, maxBlockNumber)
        zeroVal(amount)
        checkDepositAmount(depositToken, amount)
    {
        // Get active pool
        Pool storage pool = pools[poolId];
        // Check crosschain
        if (chainId != pool.chainId) revert CrosschainError();
        // If current chain is active, deposit to strategy
        depositToken.safeTransferFrom(
            msg.sender,
            strategies[pool.strategyId].addr,
            amount
        );
        // Process deposit
        uint256 deposited = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        ).deposit(poolId, depositToken, data);
        // Balance of LP before deposit
        uint256 initialBalance = balance(poolId) - deposited;
        // Calc allocation points
        if (pool.totalAllocation != 0 && initialBalance != 0) {
            deposited = (deposited * pool.totalAllocation) / initialBalance;
        }
        // Store allocation points
        pool.user[msg.sender].allocation += deposited;
        pool.totalAllocation += deposited;
        // Notify watchers
        emit Deposited(
            msg.sender,
            poolId,
            pool.strategyId,
            chainId,
            deposited,
            address(depositToken)
        );
    }

    /**
     * @notice User crosschain deposit method.
     * @param poolId Selected pool ID.
     * @param depositToken Deposited token address.
     * @param bridgedToken Token for the crosschain bridging.
     * @param amount Amount of deposited token.
     * @param signature Signed message by the back-end.
     * @param maxBlockNumber Max block for the signature expiring.
     */
    function crosschainDeposit(
        uint16 poolId,
        IERC20 depositToken,
        IERC20 bridgedToken,
        uint256 amount,
        bytes calldata signature,
        uint256 maxBlockNumber
    )
        external
        payable
        virtual
        nonReentrant
        whenNotPaused
        isActivePool(poolId)
        enabled(msg.sender)
        checkWhitelist(signature, maxBlockNumber)
        zeroVal(amount)
        checkDepositAmount(depositToken, amount)
    {
        // Get active pool
        Pool storage pool = pools[poolId];
        // Check crosschain
        if (chainId == pool.chainId) revert CrosschainError();
        // Swap
        if (depositToken != bridgedToken) {
            // Transfer token from user
            depositToken.safeTransferFrom(msg.sender, address(this), amount);
            // Make swap and get swapped amounts
            amount = _swap(amount, depositToken, bridgedToken);
            // Transfer token to the transtorder
            bridgedToken.safeTransfer(address(transporter), amount);
        } else {
            // Send token from user to the bridge transporter
            bridgedToken.safeTransferFrom(
                msg.sender,
                address(transporter),
                amount
            );
        }
        // Bridge token
        transporter.bridgeOut{value: msg.value}(
            address(bridgedToken),
            amount,
            pool.chainId,
            routers[pool.chainId].routerAddress
        );
        // Notify watchers
        emit BaseBridged(
            msg.sender,
            amount,
            poolId,
            pool.strategyId,
            pool.chainId,
            chainId,
            address(depositToken)
        );
    }

    /**
     * @notice After bridging completed we need to place tokens to farm.
     * @dev Used only to finalize cross-chain deposits.
     * @param user User address who performed a cross-chain deposit.
     * @param amount Amount of base token.
     * @param poolId Pool Id.
     * @param data Additional data.
     */
    function finalizeDeposit(
        address user,
        uint256 amount,
        uint16 poolId,
        bytes memory data
    )
        external
        onlyFinalizer
        whenNotPaused
        zeroVal(amount)
        checkDepositAmount(baseToken, amount)
        zeroAddr(user)
    {
        // Get active pool
        Pool storage pool = pools[poolId];
        // Check crosschain
        if (chainId != pool.chainId) revert CrosschainError();
        // If current chain is active, deposit to strategy
        baseToken.safeTransfer(strategies[pool.strategyId].addr, amount);
        // Process deposit
        uint256 deposited = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        ).deposit(poolId, baseToken, data);
        // Balance of LP before deposit
        uint256 initialBalance = balance(poolId) - deposited;
        // Calc allocation points
        if (pool.totalAllocation != 0 && initialBalance != 0) {
            deposited = (deposited * pool.totalAllocation) / initialBalance;
        }
        // Store allocation points
        pool.user[user].allocation += deposited;
        pool.totalAllocation += deposited;
        // Set withdraw delay
        pool.user[user].delayToBlock = block.number + withdrawDelay;
        // Notify services
        emit Deposited(
            user,
            poolId,
            pool.strategyId,
            chainId,
            deposited,
            address(baseToken)
        );
    }

    /**
     * @notice Withdraw from the pool.
     * @notice Due to the cross-chain architecture of the protocol, share prices are stored on the BE side.
     * @param signature Signed message by the back-end.
     * @param poolId Selected pool ID.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param shares Amount of withdrawal token.
     * @param maxBlockNumber Max block for the signature expiring.
     * @param data Additional data.
     */
    function withdraw(
        uint16 poolId,
        IERC20 tokenOut,
        uint256 shares,
        uint256 maxBlockNumber,
        bytes calldata signature,
        bytes memory data
    )
        external
        payable
        nonReentrant
        enabled(msg.sender)
        isActivePool(poolId)
        whenNotPaused
        checkWhitelist(signature, maxBlockNumber)
        zeroVal(shares)
        zeroAddr(address(tokenOut))
        checkDelay(poolId, msg.sender)
    {
        // Get active pool
        Pool storage pool = pools[poolId];
        // Check shares amount
        if (pool.user[msg.sender].allocation < shares) revert AmountTooBig();
        // Only in this blockchain
        if (chainId != pool.chainId) revert CrosschainError();
        // Get strategy
        IStrategyMasterchefFarmV2 strategy = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        );
        // Convert to the strategy shares
        uint256 withdrawAmount = (shares * strategy.allocationOf(poolId)) /
            pool.totalAllocation;
        // Withdraw from strategy
        uint256 amount = strategy.withdraw(
            poolId,
            withdrawAmount,
            tokenOut,
            data
        );
        // Minus fee if needed
        uint256 withdrawFee;
        if (strategies[pool.strategyId].withdrawalFee > 0) {
            withdrawFee =
                (amount * strategies[pool.strategyId].withdrawalFee) /
                FEE_DECIMALS;
            tokenOut.safeTransfer(treasury, withdrawFee);
        }
        // Reduce allocation points
        pool.totalAllocation -= shares;
        pool.user[msg.sender].allocation -= shares;
        // Send token amount to the user
        tokenOut.safeTransfer(msg.sender, amount - withdrawFee);
        // Notify services
        emit WithdrawCompleted(
            msg.sender,
            poolId,
            pool.strategyId,
            chainId,
            shares,
            amount - withdrawFee
        );
    }

    /**
     * @notice User creates crosschain withdrawal request.
     * @notice Due to the cross-chain architecture of the protocol, share prices are stored on the BE side.
     * @param signature Signed message by the back-end.
     * @param poolId Selected pool ID.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param shares Amount of withdrawal token.
     * @param maxBlockNumber Max block for the signature expiring.
     */
    function crosschainWithdraw(
        uint16 poolId,
        IERC20 tokenOut,
        uint256 shares,
        uint256 maxBlockNumber,
        bytes calldata signature
    )
        external
        payable
        enabled(msg.sender)
        isActivePool(poolId)
        whenNotPaused
        checkWhitelist(signature, maxBlockNumber)
        zeroVal(shares)
        zeroAddr(address(tokenOut))
    {
        // Transfer bridge fees to finalizer
        address payable _to = payable(finalizer);
        (bool success, ) = _to.call{value: msg.value}("");
        if (!success) revert TransferFailed();
        // Notify services
        emit WithdrawalRequested(
            msg.sender,
            poolId,
            shares,
            chainId,
            address(tokenOut)
        );
    }

    /**
     * @notice BE calls after WithdrawalRequested event was catched.
     * @notice Should be called on chain with active strategy
     * @param poolId Pool Id.
     * @param shares Amount in "want" token on strategy: LP or single token.
     * @param user User address.
     * @param tokenOut Withdrwalas token address. Filtering on the BE side.
     * @param targetChainId Chain ID of the network where the withdrawal requests was created.
     * @param data Additional parameters.
     */
    function finalizeWithdrawal(
        uint16 poolId,
        uint256 shares,
        address user,
        IERC20 tokenOut,
        uint256 targetChainId,
        bytes memory data
    )
        external
        payable
        onlyFinalizer
        whenNotPaused
        zeroVal(shares)
        zeroAddr(address(tokenOut))
        zeroAddr(user)
        checkDelay(poolId, user)
    {
        // Get active pool
        Pool storage pool = pools[poolId];
        // Get strategy
        IStrategyMasterchefFarmV2 strategy = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        );
        // Convert to the strategy shares
        uint256 withdrawAmount = (shares * strategy.allocationOf(poolId)) /
            pool.totalAllocation;
        // Withdraw from strategy
        uint256 amount = strategy.withdraw(
            poolId,
            withdrawAmount,
            tokenOut,
            data
        );
        // Minus fee if needed
        uint256 withdrawFee;
        if (strategies[pool.strategyId].withdrawalFee > 0) {
            withdrawFee =
                (amount * strategies[pool.strategyId].withdrawalFee) /
                FEE_DECIMALS;
            baseToken.safeTransfer(treasury, withdrawFee);
        }
        // Reduce allocation points
        pool.totalAllocation -= shares;
        pool.user[user].allocation -= shares;
        // Send tokens
        if (targetChainId == chainId) {
            // If requested on current chain, send tokens
            baseToken.safeTransfer(user, amount - withdrawFee);
            // Notify services
            emit WithdrawCompleted(
                user,
                poolId,
                pool.strategyId,
                targetChainId,
                shares,
                amount - withdrawFee
            );
        } else {
            // If requested on another chain, use bridge
            baseToken.safeTransfer(address(transporter), amount - withdrawFee);
            // Send to transporter and bridge
            transporter.bridgeOut{value: msg.value}(
                address(baseToken),
                amount - withdrawFee,
                targetChainId,
                user
            );
            // Notify services
            emit CrosschainWithdrawCompleted(
                user,
                poolId,
                pool.strategyId,
                targetChainId,
                shares,
                amount - withdrawFee
            );
        }
    }

    /**
     * @notice Move liquidity to the new strategy.
     * @dev Should be called only on active strategy chain.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Move to this strategy.
     * @param slippage Wanted slippage for swaps.
     * @param data Additional params.
     */
    function migration(
        uint16 poolId,
        uint16 newStrategyId,
        uint16 slippage,
        bytes memory data
    ) external virtual onlyRole(ADMIN_ROLE) {
        // Get pool
        Pool storage pool = pools[poolId];
        // Withdraw all from the previous Strategy
        uint256 amountOut = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        ).migrate(poolId, slippage, data);
        // Set new strategy
        pool.strategyId = newStrategyId;
        // Transfer base token to the new strategy
        baseToken.safeTransfer(strategies[pool.strategyId].addr, amountOut);
        // Deposit base token to the new strategy
        IStrategyMasterchefFarmV2(strategies[pool.strategyId].addr).deposit(
            poolId,
            baseToken,
            data
        );
    }

    /**
     * @notice Move liquidity to another blockchain.
     * @dev Should be called only on active strategy chain.
     * @param targetChainId Move assets to this chainId.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Move to this strategy.
     * @param slippage Wanted slippage for swaps.
     * @param data Additional params.
     */
    function crosschainMigration(
        uint256 targetChainId,
        uint16 poolId,
        uint16 newStrategyId,
        uint16 slippage,
        bytes memory data
    ) external payable onlyRole(ADMIN_ROLE) {
        // Get pool
        Pool storage pool = pools[poolId];
        // Withdraw all from the previous Strategy
        uint256 amountOut = IStrategyMasterchefFarmV2(
            strategies[pool.strategyId].addr
        ).migrate(poolId, slippage, data);
        // Set new strategy
        pool.strategyId = newStrategyId;
        // Update chainId of the pool
        pool.chainId = targetChainId;
        // Transfer to transporter
        baseToken.safeTransfer(address(transporter), amountOut);
        // Send to transporter and bridge to another router
        transporter.bridgeOut{value: msg.value}(
            address(baseToken),
            amountOut,
            targetChainId,
            routers[targetChainId].routerAddress
        );
    }

    /**
     * @notice 2nd additional step for change strategy
     * @notice Should be called only if pool total allocation on this chain is equal to zero.
     * @dev Can be called multiple times if arrays is too large.
     * @param poolId ID of the pool.
     * @param users Array of users to be migrated.
     * @param amounts Array of users amounts.
     */
    function migrateAllocations(
        uint16 poolId,
        address[] calldata users,
        uint256[] calldata amounts
    ) external onlyRole(ADMIN_ROLE) {
        // Arrays should be same size
        if (users.length != amounts.length) revert BadArray();
        // Get pool
        Pool storage pool = pools[poolId];
        // Set users allocations
        for (uint8 i = 0; i < uint8(users.length); i++) {
            pool.user[users[i]].allocation = amounts[i];
        }
    }

    /**
     * @notice 3rd additional step for change strategy
     * @notice Should be called only if cross-chain migration was initialized and tokens received.
     * @param poolId Pool Id to be migrated.
     * @param newStrategyId Id of the target strategy.
     * @param baseAmount Migrated amount in base stable token.
     * @param data Additional params.
     */
    function finalizeCrosschainMigration(
        uint16 poolId,
        uint16 newStrategyId,
        uint256 baseAmount,
        bytes memory data
    ) external onlyRole(ADMIN_ROLE) {
        // Get pool
        Pool storage pool = pools[poolId];
        // Set new strategy
        pool.strategyId = newStrategyId;
        // Transfer base token to the new strategy
        baseToken.safeTransfer(strategies[pool.strategyId].addr, baseAmount);
        // Deposit base token to the new strategy
        IStrategyMasterchefFarmV2(strategies[pool.strategyId].addr).deposit(
            poolId,
            baseToken,
            data
        );
    }

    /**
     * @notice Signer setter. Only multisig role.
     * @param _signer New signer.
     */
    function setSigner(
        address _signer
    ) external onlyRole(ADMIN_ROLE) zeroAddr(_signer) {
        signer = _signer;
    }

    /**
     * @notice Finalizer setter. Only multisig role.
     * @param _finalizer New finalizer.
     */
    function setFinalizer(
        address _finalizer
    ) external onlyRole(ADMIN_ROLE) zeroAddr(_finalizer) {
        finalizer = _finalizer;
    }

    /**
     * @notice Strategy setter. Only multisig role.
     * @dev Should be invoked with special caution to prevent overriding active strategies.
     * @dev For the active strategies with non-zero ballance migration should be used.
     * @param strategyId ID of the strategy
     * @param _strategy Tupple of the new strategy.
     */
    function setStrategy(
        uint16 strategyId,
        Strategy calldata _strategy
    ) external onlyRole(ADMIN_ROLE) {
        if (_strategy.withdrawalFee > FEE_MAX) revert AmountTooBig();
        strategies[strategyId] = _strategy;
    }

    /**
     * @notice Pool setter. Only multisig role.
     * @param poolId Id of the pool.
     * @param strategyId Id of the strategy, related to current pool.
     * @param _chainId Pool's blockchain
     */
    function setPool(
        uint16 poolId,
        uint16 strategyId,
        uint256 _chainId
    ) external onlyRole(ADMIN_ROLE) {
        pools[poolId].chainId = _chainId;
        pools[poolId].strategyId = strategyId;
    }

    /**
     * @notice Router setter. Only multisig role.
     * @dev Should be invoked with special caution to prevent overriding active routers.
     * @param _chainId Chain Id.
     * @param _router Tupple of the router.
     */
    function setRouter(
        uint256 _chainId,
        Router calldata _router
    ) external onlyRole(ADMIN_ROLE) {
        routers[_chainId] = _router;
    }

    /**
     * @notice Transporter setter. Only multisig role.
     * @dev Should be invoked with special caution to prevent blocking cross-chain operations.
     * @param _transporter New transporter.
     */
    function setTransporter(
        address _transporter
    ) external onlyRole(ADMIN_ROLE) zeroAddr(_transporter) {
        transporter = ILeechTransporter(_transporter);
    }

    /**
     * @notice Set withdraw delay.
     * @param newDelay New delay in blocks.
     */
    function setWithdrawDelay(uint248 newDelay) external onlyRole(ADMIN_ROLE) {
        withdrawDelay = newDelay;
    }

    /**
     *  @notice Disable pause. Only multisig role.
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     *  @notice On/Off signature based validation. Only multisig role.
     */
    function switchWhitelistStatus() external onlyRole(ADMIN_ROLE) {
        whitelistEnabled = !whitelistEnabled;
    }

    /**
     * @notice Uniswap based router setter. Only multisig role.
     * @dev Should be invoked with special caution to prevent blocking cross-chain operations.
     * @param _uniV2Address New uniV2 address.
     */
    function setUniV2(
        address _uniV2Address
    ) external onlyRole(ADMIN_ROLE) zeroAddr(_uniV2Address) {
        uniV2 = _uniV2Address;
    }

    /**
     * @notice Fee receiver setter. Only multisig role.
     * @param _treasury New treasury address.
     */
    function setTreasury(
        address _treasury
    ) external onlyRole(ADMIN_ROLE) zeroAddr(_treasury) {
        treasury = _treasury;
    }

    /**
     * @notice Function for disable and enable specific user
     * @param _user User addess
     * @param _status Boolean status
     */
    function setBanned(
        address _user,
        bool _status
    ) external onlyRole(ADMIN_ROLE) {
        banned[_user] = _status;
    }

    /**
     * @notice Function for disable and enable specific user
     * @param _token Token address
     * @param _minAmount Min amount of token with decimals. 0 to disable token.
     */
    function setDepositToken(
        address _token,
        uint256 _minAmount
    ) external onlyRole(ADMIN_ROLE) {
        depositMinAmount[_token] = _minAmount;
    }

    /**
     *  @notice Panic mode ON.
     *  @dev Only security observers can call this function.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Calc potential withdraw amount from pool.
     * @param poolId ID of the pool.
     * @param shares Pool shares amount to withdraw.
     * @param token0toTokenOut May be used in some strategies.
     * @param token1toTokenOut May be used in some strategies.
     * @param data Additional params.
     * @return amountOut Amount converted from shares value to base token amount.
     */
    function quotePotentialWithdraw(
        uint16 poolId,
        uint256 shares,
        address[] calldata token0toTokenOut,
        address[] calldata token1toTokenOut,
        bytes calldata data
    ) external view returns (uint256 amountOut) {
        amountOut = IStrategyMasterchefFarmV2(
            strategies[pools[poolId].strategyId].addr
        ).quotePotentialWithdraw(
                shares,
                token0toTokenOut,
                token1toTokenOut,
                data,
                0,
                0
            );
    }

    /**
     * @notice Pool balance of user.
     * @param poolId ID of the pool.
     * @param user User's address.
     * @return User allocation.
     */
    function userAllocation(
        uint16 poolId,
        address user
    ) external view returns (uint256) {
        return pools[poolId].user[user].allocation;
    }

    /**
     * @notice Pool total allocation.
     * @param poolId ID of the pool.
     * @return Total allocation.
     */
    function totalAllocation(uint16 poolId) external view returns (uint256) {
        return pools[poolId].totalAllocation;
    }

    /**
     * @notice Base token of current router.
     * @return Address of the base token.
     */
    function base() external view returns (address) {
        return address(baseToken);
    }

    /**
     * @notice Amount of LPs staked into Masterchef.
     * @param poolId Id of the Leech pool.
     * @return Strategy allocation of the pool.
     */
    function balance(uint16 poolId) public view returns (uint256) {
        return
            IStrategyMasterchefFarmV2(strategies[pools[poolId].strategyId].addr)
                .allocationOf(poolId);
    }

    /**
     * @notice Approve tokens for external contract.
     * @param token Token instance.
     * @param to Address to be approved.
     */
    function _approveAll(IERC20 token, address to) internal {
        if (token.allowance(address(this), to) != type(uint256).max) {
            token.forceApprove(address(to), type(uint256).max);
        }
    }

    /**
     * @dev Use uniswapV2Router for simple swaps. Used for the cross-chain operations.
     * @param amount TokenIn amount.
     * @param tokenIn Swap from this token.
     * @param tokenOut Swap to this token.
     * @return swapedAmount TokenOut amount.
     */
    function _swap(
        uint256 amount,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) internal virtual returns (uint256 swapedAmount) {}
}

// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IRouterVelodrome.sol";
import "./LeechRouterBase.sol";

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
 * @title A LeechProtocol Router.
 * @notice The Router is the main protocol contract, for user interactions and protocol automatizations.
 * @author Leech Protocol (https://app.leechprotocol.com/).
 * @custom:network Optimism (chainId 10).
 * @custom:version 0.2-beta.
 * @custom:security Found vulnerability? Get reward here [email protected]
 */
contract LeechRouterOptimism is LeechRouterBase {
    /// @notice Pathes for the token swaps.
    /// @dev tokenFrom => tokenTo => Array with routes
    mapping(IERC20 => mapping(IERC20 => IRouterVelodrome.route[]))
        public routes;

    /**
     * @notice Initializer.
     * @param _baseToken Base stablecoin.
     * @param _uniV2Address Dex router address.
     * @param _treasury Fees receiver.
     * @param _signer Whitelist validator.
     * @param _finalizer Crosschain finalizer.
     */
    function initialize(
        IERC20 _baseToken,
        address _uniV2Address,
        address _treasury,
        address _signer,
        address _finalizer
    ) public override initializer {
        LeechRouterBase.initialize(
            _baseToken,
            _uniV2Address,
            _treasury,
            _signer,
            _finalizer
        );
        // Init main pathes.
        // USDC > USDT
        IRouterVelodrome.route[] memory path1 = new IRouterVelodrome.route[](1);
        path1[0] = IRouterVelodrome.route(
            0x7F5c764cBc14f9669B88837ca1490cCa17c31607,
            0x94b008aA00579c1307B0EF2c499aD98a8ce58e58,
            true
        );
        setRoutes(
            IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607),
            IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58),
            path1
        );
        // USDT > USDC
        IRouterVelodrome.route[] memory path2 = new IRouterVelodrome.route[](1);
        path2[0] = IRouterVelodrome.route(
            0x94b008aA00579c1307B0EF2c499aD98a8ce58e58,
            0x7F5c764cBc14f9669B88837ca1490cCa17c31607,
            true
        );
        setRoutes(
            IERC20(0x94b008aA00579c1307B0EF2c499aD98a8ce58e58),
            IERC20(0x7F5c764cBc14f9669B88837ca1490cCa17c31607),
            path2
        );
    }

    /**
     * @notice Set routes for token swaps.
     * @param tokenFrom Token in.
     * @param tokenTo Token out.
     * @param pathes Array with routes.
     */
    function setRoutes(
        IERC20 tokenFrom,
        IERC20 tokenTo,
        IRouterVelodrome.route[] memory pathes
    ) public onlyRole(ADMIN_ROLE) {
        routes[tokenFrom][tokenTo] = pathes;
    }

    /**
     * @dev Use uniswapV2Router for simple swaps. Used for the cross-chain operations.
     * @param amount TokenIn amount.
     * @param tokenIn Swap from this token.
     * @param tokenOut Swap to this token.
     * @return swapedAmount TokenOut amount.
     */
    function _swap(
        uint256 amount,
        IERC20 tokenIn,
        IERC20 tokenOut
    ) internal override returns (uint256 swapedAmount) {
        // Approve tokenIn if needed
        _approveAll(tokenIn, uniV2);
        // Swap tokens
        uint256[] memory swapedAmounts = IRouterVelodrome(uniV2)
            .swapExactTokensForTokens(
                amount,
                0,
                routes[tokenIn][tokenOut],
                address(this),
                block.timestamp
            );
        // Check array length
        if (swapedAmounts.length == 0) revert ZeroValue();
        // Return tokenOut amount
        swapedAmount = swapedAmounts[swapedAmounts.length - 1];
    }
}