// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

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
 * ```
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```
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
 * accounts that have been granted it.
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
                        StringsUpgradeable.toHexString(uint160(account), 20),
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
// OpenZeppelin Contracts (last updated v4.5.0) (interfaces/draft-IERC1822.sol)

pragma solidity ^0.8.0;

/**
 * @dev ERC1822: Universal Upgradeable Proxy Standard (UUPS) documents a method for upgradeability through a simplified
 * proxy whose upgrades are fully controlled by the current implementation.
 */
interface IERC1822ProxiableUpgradeable {
    /**
     * @dev Returns the storage slot that the proxiable contract assumes is being used to store the implementation
     * address.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy.
     */
    function proxiableUUID() external view returns (bytes32);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (proxy/beacon/IBeacon.sol)

pragma solidity ^0.8.0;

/**
 * @dev This is the interface that {BeaconProxy} expects of its beacon.
 */
interface IBeaconUpgradeable {
    /**
     * @dev Must return an address that can be used as a delegate call target.
     *
     * {BeaconProxy} will check that this address is a contract.
     */
    function implementation() external view returns (address);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/ERC1967/ERC1967Upgrade.sol)

pragma solidity ^0.8.2;

import "../beacon/IBeaconUpgradeable.sol";
import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/StorageSlotUpgradeable.sol";
import "../utils/Initializable.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 *
 * _Available since v4.1._
 *
 * @custom:oz-upgrades-unsafe-allow delegatecall
 */
abstract contract ERC1967UpgradeUpgradeable is Initializable {
    function __ERC1967Upgrade_init() internal onlyInitializing {
    }

    function __ERC1967Upgrade_init_unchained() internal onlyInitializing {
    }
    // This is the keccak-256 hash of "eip1967.proxy.rollback" subtracted by 1
    bytes32 private constant _ROLLBACK_SLOT = 0x4910fdfa16fed3260ed0e7147f7cc6da11a60208b5b9406d12a635614ffd9143;

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Returns the current implementation address.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        require(AddressUpgradeable.isContract(newImplementation), "ERC1967: new implementation is not a contract");
        StorageSlotUpgradeable.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Perform implementation upgrade
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeTo(address newImplementation) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Perform implementation upgrade with additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCall(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        _upgradeTo(newImplementation);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(newImplementation, data);
        }
    }

    /**
     * @dev Perform implementation upgrade with security checks for UUPS proxies, and additional setup call.
     *
     * Emits an {Upgraded} event.
     */
    function _upgradeToAndCallUUPS(
        address newImplementation,
        bytes memory data,
        bool forceCall
    ) internal {
        // Upgrades from old implementations will perform a rollback test. This test requires the new
        // implementation to upgrade back to the old, non-ERC1822 compliant, implementation. Removing
        // this special case will break upgrade paths from old UUPS implementation to new ones.
        if (StorageSlotUpgradeable.getBooleanSlot(_ROLLBACK_SLOT).value) {
            _setImplementation(newImplementation);
        } else {
            try IERC1822ProxiableUpgradeable(newImplementation).proxiableUUID() returns (bytes32 slot) {
                require(slot == _IMPLEMENTATION_SLOT, "ERC1967Upgrade: unsupported proxiableUUID");
            } catch {
                revert("ERC1967Upgrade: new implementation is not UUPS");
            }
            _upgradeToAndCall(newImplementation, data, forceCall);
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Returns the current admin.
     */
    function _getAdmin() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        require(newAdmin != address(0), "ERC1967: new admin is the zero address");
        StorageSlotUpgradeable.getAddressSlot(_ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {AdminChanged} event.
     */
    function _changeAdmin(address newAdmin) internal {
        emit AdminChanged(_getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is bytes32(uint256(keccak256('eip1967.proxy.beacon')) - 1)) and is validated in the constructor.
     */
    bytes32 internal constant _BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Emitted when the beacon is upgraded.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Returns the current beacon.
     */
    function _getBeacon() internal view returns (address) {
        return StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        require(AddressUpgradeable.isContract(newBeacon), "ERC1967: new beacon is not a contract");
        require(
            AddressUpgradeable.isContract(IBeaconUpgradeable(newBeacon).implementation()),
            "ERC1967: beacon implementation is not a contract"
        );
        StorageSlotUpgradeable.getAddressSlot(_BEACON_SLOT).value = newBeacon;
    }

    /**
     * @dev Perform beacon upgrade with additional setup call. Note: This upgrades the address of the beacon, it does
     * not upgrade the implementation contained in the beacon (see {UpgradeableBeacon-_setImplementation} for that).
     *
     * Emits a {BeaconUpgraded} event.
     */
    function _upgradeBeaconToAndCall(
        address newBeacon,
        bytes memory data,
        bool forceCall
    ) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);
        if (data.length > 0 || forceCall) {
            _functionDelegateCall(IBeaconUpgradeable(newBeacon).implementation(), data);
        }
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return AddressUpgradeable.verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

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
 * ```
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
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
     * `onlyInitializing` functions can be used to initialize parent contracts. Equivalent to `reinitializer(1)`.
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
     * `initializer` is equivalent to `reinitializer(1)`, so a reinitializer may be used after the original
     * initialization step. This is essential to configure modules that are added through upgrades and that require
     * initialization.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
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
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized < type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (proxy/utils/UUPSUpgradeable.sol)

pragma solidity ^0.8.0;

import "../../interfaces/draft-IERC1822Upgradeable.sol";
import "../ERC1967/ERC1967UpgradeUpgradeable.sol";
import "./Initializable.sol";

/**
 * @dev An upgradeability mechanism designed for UUPS proxies. The functions included here can perform an upgrade of an
 * {ERC1967Proxy}, when this contract is set as the implementation behind such a proxy.
 *
 * A security mechanism ensures that an upgrade does not turn off upgradeability accidentally, although this risk is
 * reinstated if the upgrade retains upgradeability but removes the security mechanism, e.g. by replacing
 * `UUPSUpgradeable` with a custom implementation of upgrades.
 *
 * The {_authorizeUpgrade} function must be overridden to include access restriction to the upgrade mechanism.
 *
 * _Available since v4.1._
 */
abstract contract UUPSUpgradeable is Initializable, IERC1822ProxiableUpgradeable, ERC1967UpgradeUpgradeable {
    function __UUPSUpgradeable_init() internal onlyInitializing {
    }

    function __UUPSUpgradeable_init_unchained() internal onlyInitializing {
    }
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable state-variable-assignment
    address private immutable __self = address(this);

    /**
     * @dev Check that the execution is being performed through a delegatecall call and that the execution context is
     * a proxy contract with an implementation (as defined in ERC1967) pointing to self. This should only be the case
     * for UUPS and transparent proxies that are using the current contract as their implementation. Execution of a
     * function through ERC1167 minimal proxies (clones) would not normally pass this test, but is not guaranteed to
     * fail.
     */
    modifier onlyProxy() {
        require(address(this) != __self, "Function must be called through delegatecall");
        require(_getImplementation() == __self, "Function must be called through active proxy");
        _;
    }

    /**
     * @dev Check that the execution is not being performed through a delegate call. This allows a function to be
     * callable on the implementing contract but not through proxies.
     */
    modifier notDelegated() {
        require(address(this) == __self, "UUPSUpgradeable: must not be called through delegatecall");
        _;
    }

    /**
     * @dev Implementation of the ERC1822 {proxiableUUID} function. This returns the storage slot used by the
     * implementation. It is used to validate that the this implementation remains valid after an upgrade.
     *
     * IMPORTANT: A proxy pointing at a proxiable contract should not be considered proxiable itself, because this risks
     * bricking a proxy that upgrades to it, by delegating to itself until out of gas. Thus it is critical that this
     * function revert if invoked through a proxy. This is guaranteed by the `notDelegated` modifier.
     */
    function proxiableUUID() external view virtual override notDelegated returns (bytes32) {
        return _IMPLEMENTATION_SLOT;
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeTo(address newImplementation) external virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, new bytes(0), false);
    }

    /**
     * @dev Upgrade the implementation of the proxy to `newImplementation`, and subsequently execute the function call
     * encoded in `data`.
     *
     * Calls {_authorizeUpgrade}.
     *
     * Emits an {Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable virtual onlyProxy {
        _authorizeUpgrade(newImplementation);
        _upgradeToAndCallUUPS(newImplementation, data, true);
    }

    /**
     * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeTo} and {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal override onlyOwner {}
     * ```
     */
    function _authorizeUpgrade(address newImplementation) internal virtual;

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
// OpenZeppelin Contracts (last updated v4.7.0) (utils/StorageSlot.sol)

pragma solidity ^0.8.0;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 *
 * Example usage to set ERC1967 implementation slot:
 * ```
 * contract ERC1967 {
 *     bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
 *
 *     function _getImplementation() internal view returns (address) {
 *         return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
 *     }
 *
 *     function _setImplementation(address newImplementation) internal {
 *         require(Address.isContract(newImplementation), "ERC1967: new implementation is not a contract");
 *         StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
 *     }
 * }
 * ```
 *
 * _Available since v4.1 for `address`, `bool`, `bytes32`, and `uint256`._
 */
library StorageSlotUpgradeable {
    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function getBooleanSlot(bytes32 slot) internal pure returns (BooleanSlot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function getBytes32Slot(bytes32 slot) internal pure returns (Bytes32Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function getUint256Slot(bytes32 slot) internal pure returns (Uint256Slot storage r) {
        /// @solidity memory-safe-assembly
        assembly {
            r.slot := slot
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library StringsUpgradeable {
    bytes16 private constant _HEX_SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0x00";
        }
        uint256 temp = value;
        uint256 length = 0;
        while (temp != 0) {
            length++;
            temp >>= 8;
        }
        return toHexString(value, length);
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _HEX_SYMBOLS[value & 0xf];
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
pragma solidity >=0.8.0 <0.9.0;

library OvnMath {

    uint256 constant BASIS_DENOMINATOR = 10 ** 4;

    function abs(uint256 x, uint256 y) internal pure returns (uint256) {
        return (x > y) ? (x - y) : (y - x);
    }

    function addBasisPoints(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return amount * (BASIS_DENOMINATOR + basisPoints) / BASIS_DENOMINATOR;
    }

    function reverseAddBasisPoints(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return amount * BASIS_DENOMINATOR / (BASIS_DENOMINATOR + basisPoints);
    }

    function subBasisPoints(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return amount * (BASIS_DENOMINATOR - basisPoints) / BASIS_DENOMINATOR;
    }

    function reverseSubBasisPoints(uint256 amount, uint256 basisPoints) internal pure returns (uint256) {
        return amount * BASIS_DENOMINATOR / (BASIS_DENOMINATOR - basisPoints);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPriceFeed {

    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    // getRoundData and latestRoundData should both raise "No data present"
    // if they do not have data to report, instead of returning unset values
    // which could be misinterpreted as actual reported values.
    function getRoundData(uint80 _roundId)
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

    function latestRoundData()
    external
    view
    returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );

}


library ChainlinkLibrary {

    function convertTokenToToken(
        uint256 amount0,
        uint256 token0Denominator,
        uint256 token1Denominator,
        uint256 price0,
        uint256 price1
    ) internal pure returns (uint256 amount1) {
        amount1 = (amount0 * token1Denominator * price0) / (token0Denominator * price1);
    }

    function convertTokenToUsd(
        uint256 amount,
        uint256 tokenDenominator,
        uint256 price
    ) internal pure returns (uint256 amountUsd) {
        amountUsd = amount * price / tokenDenominator;
    }

    function convertUsdToToken(
        uint256 amountUsd,
        uint256 tokenDenominator,
        uint256 price
    ) internal pure returns (uint256 amount) {
        amount = amountUsd * tokenDenominator / price;
    }

    function convertTokenToToken(
        uint256 amount0,
        uint256 token0Denominator,
        uint256 token1Denominator,
        IPriceFeed oracle0,
        IPriceFeed oracle1
    ) internal view returns (uint256 amount1) {
        uint256 price0 = getPrice(oracle0);
        uint256 price1 = getPrice(oracle1);
        amount1 = (amount0 * token1Denominator * price0) / (token0Denominator * price1);
    }

    function getPrice(IPriceFeed oracle) internal view returns (uint256){
        (uint80 roundID, int256 price, , uint256 timeStamp, uint80 answeredInRound) = oracle.latestRoundData();
        require(answeredInRound >= roundID, "Old data");
        require(timeStamp > 0, "Round not complete");
        return uint256(price);

    }

    function convertTokenToUsd(
        uint256 amount,
        uint256 tokenDenominator,
        IPriceFeed oracle
    ) internal view returns (uint256 amountUsd) {
        amountUsd = amount * getPrice(oracle) / tokenDenominator;
    }

    function convertUsdToToken(
        uint256 amountUsd,
        uint256 tokenDenominator,
        IPriceFeed oracle
    ) internal view returns (uint256 amount) {
        amount = amountUsd * tokenDenominator / getPrice(oracle);
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface ICurveExchange {

    /**
        @notice Perform an exchange using the pool that offers the best rate
        @dev Prior to calling this function, the caller must approve
        this contract to transfer `_amount` coins from `_from`
        Does NOT check rates in factory-deployed pools
        @param _from Address of coin being sent
        @param _to Address of coin being received
        @param _amount Quantity of `_from` being sent
        @param _expected Minimum quantity of `_from` received
        in order for the transaction to succeed
        @param _receiver Address to transfer the received tokens to
        @return uint256 Amount received
    */
    function exchange_with_best_rate(address _from, address _to, uint256 _amount, uint256 _expected, address _receiver) external returns (uint256);

    function exchange_with_best_rate(address _from, address _to, uint256 _amount, uint256 _expected) external returns (uint256);

    /**
        @notice Perform an exchange using a specific pool
        @dev Prior to calling this function, the caller must approve
             this contract to transfer `_amount` coins from `_from`
             Works for both regular and factory-deployed pools
        @param _pool Address of the pool to use for the swap
        @param _from Address of coin being sent
        @param _to Address of coin being received
        @param _amount Quantity of `_from` being sent
        @param _expected Minimum quantity of `_from` received
               in order for the transaction to succeed
        @param _receiver Address to transfer the received tokens to
        @return uint256 Amount received
    */
    function exchange(address _pool, address _from, address _to, uint256 _amount, uint256 _expected, address _receiver) external returns (uint256);

    function exchange(address _pool, address _from, address _to, uint256 _amount, uint256 _expected) external returns (uint256);

    /**
        @notice Perform up to four swaps in a single transaction
        @dev Routing and swap params must be determined off-chain. This
             functionality is designed for gas efficiency over ease-of-use.
        @param _route Array of [initial token, pool, token, pool, token, ...]
                      The array is iterated until a pool address of 0x00, then the last
                      given token is transferred to `_receiver`
        @param _swap_params Multidimensional array of [i, j, swap type] where i and j are the correct
                            values for the n'th pool in `_route`. The swap type should be
                            1 for a stableswap `exchange`,
                            2 for stableswap `exchange_underlying`,
                            3 for a cryptoswap `exchange`,
                            4 for a cryptoswap `exchange_underlying`,
                            5 for factory metapools with lending base pool `exchange_underlying`,
                            6 for factory crypto-meta pools underlying exchange (`exchange` method in zap),
                            7-11 for wrapped coin (underlying for lending or fake pool) -> LP token "exchange" (actually `add_liquidity`),
                            12-14 for LP token -> wrapped coin (underlying for lending pool) "exchange" (actually `remove_liquidity_one_coin`)
                            15 for WETH -> ETH "exchange" (actually deposit/withdraw)
        @param _amount The amount of `_route[0]` token being sent.
        @param _expected The minimum amount received after the final swap.
        @param _pools Array of pools for swaps via zap contracts. This parameter is only needed for
                      Polygon meta-factories underlying swaps.
        @param _receiver Address to transfer the final output token to.
        @return Received amount of the final output token
    */
    function exchange_multiple(address[9] memory _route, uint256[3][4] memory _swap_params, uint256 _amount, uint256 _expected, address[4] memory _pools, address _receiver) external returns (uint256);

    function exchange_multiple(address[9] memory _route, uint256[3][4] memory _swap_params, uint256 _amount, uint256 _expected, address[4] memory _pools) external returns (uint256);

    function exchange_multiple(address[9] memory _route, uint256[3][4] memory _swap_params, uint256 _amount, uint256 _expected) external returns (uint256);

    /**
        @notice Find the pool offering the best rate for a given swap.
        @dev Checks rates for regular and factory pools
        @param _from Address of coin being sent
        @param _to Address of coin being received
        @param _amount Quantity of `_from` being sent
        @param _exclude_pools A list of up to 8 addresses which shouldn't be returned
        @return Pool address, amount received
    */
    function get_best_rate(address _from, address _to, uint256 _amount, address[8] memory _exclude_pools) external returns (address, uint256);

    function get_best_rate(address _from, address _to, uint256 _amount) external returns (address, uint256);

    /**
        @notice Get the current number of coins received in an exchange
        @dev Works for both regular and factory-deployed pools
        @param _pool Pool address
        @param _from Address of coin to be sent
        @param _to Address of coin to be received
        @param _amount Quantity of `_from` to be sent
        @return Quantity of `_to` to be received
    */
    function get_exchange_amount(address _pool, address _from, address _to, uint256 _amount) external returns (uint256);

    /**
        @notice Get the current number of coins required to receive the given amount in an exchange
        @param _pool Pool address
        @param _from Address of coin to be sent
        @param _to Address of coin to be received
        @param _amount Quantity of `_to` to be received
        @return Quantity of `_from` to be sent
    */
    function get_input_amount(address _pool, address _from, address _to, uint256 _amount) external returns (uint256);

    /**
        @notice Get the current number of coins required to receive the given amount in an exchange
        @param _pool Pool address
        @param _from Address of coin to be sent
        @param _to Address of coin to be received
        @param _amounts Quantity of `_to` to be received
        @return Quantity of `_from` to be sent
    */
    function get_exchange_amounts(address _pool, address _from, address _to, uint256[100] memory _amounts) external returns (uint256[100] memory);

    /**
        @notice Get the current number the final output tokens received in an exchange
        @dev Routing and swap params must be determined off-chain. This
             functionality is designed for gas efficiency over ease-of-use.
        @param _route Array of [initial token, pool, token, pool, token, ...]
                      The array is iterated until a pool address of 0x00, then the last
                      given token is transferred to `_receiver`
        @param _swap_params Multidimensional array of [i, j, swap type] where i and j are the correct
                            values for the n'th pool in `_route`. The swap type should be
                            1 for a stableswap `exchange`,
                            2 for stableswap `exchange_underlying`,
                            3 for a cryptoswap `exchange`,
                            4 for a cryptoswap `exchange_underlying`,
                            5 for factory metapools with lending base pool `exchange_underlying`,
                            6 for factory crypto-meta pools underlying exchange (`exchange` method in zap),
                            7-11 for wrapped coin (underlying for lending pool) -> LP token "exchange" (actually `add_liquidity`),
                            12-14 for LP token -> wrapped coin (underlying for lending or fake pool) "exchange" (actually `remove_liquidity_one_coin`)
                            15 for WETH -> ETH "exchange" (actually deposit/withdraw)
        @param _amount The amount of `_route[0]` token to be sent.
        @param _pools Array of pools for swaps via zap contracts. This parameter is only needed for
                      Polygon meta-factories underlying swaps.
        @return Expected amount of the final output token
    */
    function get_exchange_multiple_amount(address[9] memory _route, uint256[3][4] memory _swap_params, uint256 _amount, address[4] memory _pools) external returns (uint256);

    function get_exchange_multiple_amount(address[9] memory _route, uint256[3][4] memory _swap_params, uint256 _amount) external returns (uint256);

}

interface IStableSwapPool {

    function add_liquidity(uint256[3] memory _amounts, uint256 _min_mint_amount, bool _use_underlying) external returns (uint256);

    function add_liquidity(uint256[2] memory _amounts, uint256 _min_mint_amount) external returns (uint256);

    function remove_liquidity(uint256 _amount, uint256[3] memory _min_amounts, bool _use_underlying) external returns (uint256[3] memory);

    function remove_liquidity(uint256 _amount, uint256[2] memory _min_amounts) external returns (uint256[2] memory);

    function underlying_coins(uint256 i) external view returns (address);

    function lp_token() external view returns (address);

    function calc_token_amount(uint256[3] memory _amounts, bool _is_deposit) external view returns (uint256);

    function calc_token_amount(uint256[2] memory _amounts, bool _is_deposit) external view returns (uint256);

    function coins(uint256 i) external view returns (address);

    function get_virtual_price() external view returns (uint256);

    // Get the amount of coin j(received) one would receive for swapping _dx of coin i(send).
    function get_dy(int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    function get_dy_underlying(int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    //Perform an exchange between two coins.
    // i: Index value for the coin to send
    // j: Index value of the coin to receive
    // _dx: Amount of i being exchanged
    // _min_dy: Minimum amount of j to receive
    // Returns the actual amount of coin j received. Index values can be found via the coins public getter method.
    function exchange(int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function exchange_underlying(int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function calc_withdraw_one_coin(uint256 _token_amount, int128 i) external view returns (uint256);

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount) external returns (uint256);

    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 _min_amount, bool _use_underlying) external returns (uint256);

}

interface IMetaSwapPool {

    // Get the amount of coin j(received) one would receive for swapping _dx of coin i(send).
    function get_dy(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    function get_dy_underlying(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx) external view returns (uint256);

    //Perform an exchange between two coins.
    // i: Index value for the coin to send
    // j: Index value of the coin to receive
    // _dx: Amount of i being exchanged
    // _min_dy: Minimum amount of j to receive
    // Returns the actual amount of coin j received. Index values can be found via the coins public getter method.
    function exchange(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);

    function exchange_underlying(address _pool, int128 sendToken, int128 receivedToken, uint256 _dx, uint256 _min_dy) external returns (uint256);
}

interface IRewardsOnlyGauge is IERC20 {

    function deposit(uint256 _value, address _addr, bool _claim_rewards) external;

    function deposit(uint256 _value, address _addr) external;

    function deposit(uint256 _value, bool _claim_rewards) external;

    function deposit(uint256 _value) external;

    function withdraw(uint256 _value, bool _claim_rewards) external;

    function withdraw(uint256 _value) external;

    function lp_token() external returns (address);

    function claim_rewards(address _addr, address _receiver) external;

    function claim_rewards(address _addr) external;

    function claim_rewards() external;

    function claimed_reward(address _addr, address _token) external returns (uint256);

    function claimable_reward(address _addr, address _token) external returns (uint256);

    function claimable_reward_write(address _addr, address _token) external returns (uint256);
}

library CurveMetaLibrary {

    function swapByIndex(
        int128  indexIn,
        int128  indexOut,
        bool isUnderlying,
        uint256 amountIn,
        uint256 amountMinOut,
        address meta,
        address pool
    ) internal returns (uint256) {

        uint256 backAmount;
        if (isUnderlying) {
            backAmount = IMetaSwapPool(meta).exchange_underlying(
                pool,
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        } else {
            backAmount = IMetaSwapPool(meta).exchange(
                pool,
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        }

        return backAmount;
    }

    function getAmountOutByIndex(
        int128 indexIn,
        int128 indexOut,
        bool isUnderlying,
        uint256 amountIn,
        address meta,
        address pool
    ) internal view returns (uint256) {
        if (isUnderlying) {
            return IMetaSwapPool(meta).get_dy_underlying(pool,indexIn, indexOut, amountIn);
        } else {
            return IMetaSwapPool(meta).get_dy(pool,indexIn, indexOut, amountIn);
        }
    }
}

library CurveLibrary {

    function singleSwap(
        address curveExchange,
        address token0,
        address pool0,
        address token1,
        uint256 amount0,
        uint256 amount1Out
    ) internal returns (uint256) {
        IERC20(token0).approve(curveExchange, amount0);
        return ICurveExchange(curveExchange).exchange(pool0, token0, token1, amount0, amount1Out);
    }

    function multiSwap(
        address curveExchange,
        address token0,
        address pool0,
        address token1,
        address pool1,
        address token2,
        uint256 amount0,
        uint256 amount2Out
    ) internal returns (uint256) {
        IERC20(token0).approve(curveExchange, amount0);
        address[9] memory route;
        route[0] = token0;
        route[1] = pool0;
        route[2] = token1;
        route[3] = pool1;
        route[4] = token2;
        uint256[3][4] memory swap_params;
        return ICurveExchange(curveExchange).exchange_multiple(route, swap_params, amount0, amount2Out);
    }

    function swap(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountMinOut
    ) internal returns (uint256) {
        IERC20(tokenIn).approve(pool, amountIn);
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(pool, tokenIn, tokenOut);

        uint256 backAmount;
        if (isUnderlying) {
            backAmount = IStableSwapPool(pool).exchange_underlying(
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        } else {
            backAmount = IStableSwapPool(pool).exchange(
                indexIn,
                indexOut,
                amountIn,
                amountMinOut
            );
        }

        return backAmount;
    }

    function getAmountOut(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        (int128 indexIn, int128 indexOut, bool isUnderlying) = getIndexes(pool, tokenIn, tokenOut);
        if (isUnderlying) {
            return IStableSwapPool(pool).get_dy_underlying(indexIn, indexOut, amountIn);
        } else {
            return IStableSwapPool(pool).get_dy(indexIn, indexOut, amountIn);
        }
    }

    function getIndexes(
        address pool,
        address tokenIn,
        address tokenOut
    ) internal view returns (int128, int128, bool) {
        int128 indexIn = type(int128).max;
        int128 indexOut = type(int128).max;

        // search in coins list
        uint256 i;
        while (true) {
            address token = getCoin(pool, i);
            if (token == address(0)) {
                break;
            }

            if (token == tokenIn) {
                indexIn = int128(uint128(i));
            } else if (token == tokenOut) {
                indexOut = int128(uint128(i));
            }
            i++;
        }

        if (indexIn != type(int128).max && indexOut != type(int128).max) {
            return (indexIn, indexOut, false);
        }

        if (indexIn != type(int128).max || indexOut != type(int128).max) {
            // one of tokens found in coins but not found another - it is incorrect
            // setup case for token pairs
            revert("CurveSP: incorrect token pair setup");
        }

        // search in underlying coins list
        i = 0;
        while (true) {
            address token = getUnderlyingCoin(pool, i);
            if (token == address(0)) {
                break;
            }

            if (token == tokenIn) {
                indexIn = int128(uint128(i));
            } else if (token == tokenOut) {
                indexOut = int128(uint128(i));
            }
            i++;
        }

        if (indexIn != type(int128).max && indexOut != type(int128).max) {
            return (indexIn, indexOut, true);
        }

        revert("CurveSP: Can't find index for tokens in pool");
    }

    function getCoin(address pool, uint256 index) internal view returns (address) {
        try IStableSwapPool(pool).coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }

    function getUnderlyingCoin(address pool, uint256 index) internal view returns (address) {
        try IStableSwapPool(pool).underlying_coins(index) returns (address tokenAddress) {
            return tokenAddress;
        } catch {}
        return address(0);
    }

    /**
     * Get amount of token1 nominated in token0 where amount0Total is total getting amount nominated in token0
     *
     * precision: 0 - no correction, 1 - one correction (recommended value), 2 or more - several corrections
     */
    function getAmountToSwap(
        address pool,
        address token0,
        address token1,
        uint256 amount0Total,
        uint256 reserve0,
        uint256 reserve1,
        uint256 denominator0,
        uint256 denominator1,
        uint256 precision
    ) internal view returns (uint256 amount0) {
        amount0 = (amount0Total * reserve1) / (reserve0 * denominator1 / denominator0 + reserve1);
        for (uint i = 0; i < precision; i++) {
            uint256 amount1 = getAmountOut(pool, token0, token1, amount0);
            amount0 = (amount0Total * reserve1) / (reserve0 * amount1 / amount0 + reserve1);
        }
    }

    /**
     * Get amount of lp tokens where amount0Total is total getting amount nominated in token0
     *
     * precision: 0 - no correction, 1 - one correction (recommended value), 2 or more - several corrections
     */
    function getAmountLpTokens(
        address pool,
        address token0,
        address token1,
        uint256 amount0Total,
        uint256 totalAmountLpTokens,
        uint256 reserve0,
        uint256 reserve1,
        uint256 denominator0,
        uint256 denominator1,
        uint256 precision
    ) internal view returns (uint256 amountLpTokens) {
        amountLpTokens = (totalAmountLpTokens * amount0Total * denominator1) / (reserve0 * denominator1 + reserve1 * denominator0);
        for (uint i = 0; i < precision; i++) {
            uint256 amount1 = reserve1 * amountLpTokens / totalAmountLpTokens;
            uint256 amount0 = getAmountOut(pool, token1, token0, amount1);
            amountLpTokens = (totalAmountLpTokens * amount0Total * amount1) / (reserve0 * amount1 + reserve1 * amount0);
        }
    }

}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITridentRouter {

    struct Path {
        address pool;
        bytes data;
    }

    struct ExactInputSingleParams {
        uint256 amountIn;
        uint256 amountOutMinimum;
        address pool;
        address tokenIn;
        bytes data;
    }

    struct ExactInputParams {
        address tokenIn;
        uint256 amountIn;
        uint256 amountOutMinimum;
        Path[] path;
    }

    struct TokenInput {
        address token;
        bool native;
        uint256 amount;
    }

    struct InitialPath {
        address tokenIn;
        address pool;
        bool native;
        uint256 amount;
        bytes data;
    }

    struct PercentagePath {
        address tokenIn;
        address pool;
        uint64 balancePercentage; // Multiplied by 10^6. 100% = 100_000_000
        bytes data;
    }

    struct Output {
        address token;
        address to;
        bool unwrapBento;
        uint256 minAmount;
    }

    struct ComplexPathParams {
        InitialPath[] initialPath;
        PercentagePath[] percentagePath;
        Output[] output;
    }

    /// @dev This struct frames output tokens for burns.
    struct TokenAmount {
        address token;
        uint256 amount;
    }

    /// @notice Swaps token A to token B directly. Swaps are done on `bento` tokens.
    /// @param params This includes the address of token A, pool, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pool for the swap.
    /// @dev Ensure that the pool is trusted before calling this function. The pool can steal users' tokens.
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps token A to token B indirectly by using multiple hops.
    /// @param params This includes the addresses of the tokens, pools, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pools for the swaps.
    /// @dev Ensure that the pools are trusted before calling this function. The pools can steal users' tokens.
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps token A to token B directly. It's the same as `exactInputSingle` except
    /// it takes raw ERC-20 tokens from the users and deposits them into `bento`.
    /// @param params This includes the address of token A, pool, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pool for the swap.
    /// @dev Ensure that the pool is trusted before calling this function. The pool can steal users' tokens.
    function exactInputSingleWithNativeToken(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps token A to token B indirectly by using multiple hops. It's the same as `exactInput` except
    /// it takes raw ERC-20 tokens from the users and deposits them into `bento`.
    /// @param params This includes the addresses of the tokens, pools, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pools for the swaps.
    /// @dev Ensure that the pools are trusted before calling this function. The pools can steal users' tokens.
    function exactInputWithNativeToken(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    /// @notice Swaps multiple input tokens to multiple output tokens using multiple paths, in different percentages.
    /// For example, you can swap 50 DAI + 100 USDC into 60% ETH and 40% BTC.
    /// @param params This includes everything needed for the swap. Look at the `ComplexPathParams` struct for more details.
    /// @dev This function is not optimized for single swaps and should only be used in complex cases where
    /// the amounts are large enough that minimizing slippage by using multiple paths is worth the extra gas.
    function complexPath(ComplexPathParams calldata params) external payable;

    /// @notice Add liquidity to a pool.
    /// @param tokenInput Token address and amount to add as liquidity.
    /// @param pool Pool address to add liquidity to.
    /// @param minLiquidity Minimum output liquidity - caps slippage.
    /// @param data Data required by the pool to add liquidity.
    function addLiquidity(
        TokenInput[] calldata tokenInput,
        address pool,
        uint256 minLiquidity,
        bytes calldata data
    ) external payable returns (uint256 liquidity);

    /// @notice Burn liquidity tokens to get back `bento` tokens.
    /// @param pool Pool address.
    /// @param liquidity Amount of liquidity tokens to burn.
    /// @param data Data required by the pool to burn liquidity.
    /// @param minWithdrawals Minimum amount of `bento` tokens to be returned.
    function burnLiquidity(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        TokenAmount[] calldata minWithdrawals
    ) external payable;

    /// @notice Burn liquidity tokens to get back `bento` tokens.
    /// @dev The tokens are swapped automatically and the output is in a single token.
    /// @param pool Pool address.
    /// @param liquidity Amount of liquidity tokens to burn.
    /// @param data Data required by the pool to burn liquidity.
    /// @param minWithdrawal Minimum amount of tokens to be returned.
    function burnLiquiditySingle(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        uint256 minWithdrawal
    ) external payable;

    function approveMasterContract(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable;
}

/// @notice The (older) MasterChef contract gives out a constant number of SUSHI tokens per block.
/// It is the only address with minting rights for SUSHI.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this pool on MCV1 is the total allocation point for all pools that receive double incentives.
interface IMiniChefV2 {

    /// @notice Info of each MCV2 user.
    /// `amount` LP token amount the user has provided.
    /// `rewardDebt` The amount of SUSHI entitled to the user.
    /// @notice Info of each user that stakes LP tokens.
    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    /// @notice Deposit LP tokens to MCV2 for SUSHI allocation.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to deposit.
    /// @param to The receiver of `amount` deposit benefit.
    function deposit(uint256 pid, uint256 amount, address to) external;

    /// @notice Withdraw LP tokens from MCV2.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens.
    function withdraw(uint256 pid, uint256 amount, address to) external;

    /// @notice Harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of SUSHI rewards.
    function harvest(uint256 pid, address to) external;

    /// @notice Withdraw LP tokens from MCV2 and harvest proceeds for transaction sender to `to`.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param amount LP token amount to withdraw.
    /// @param to Receiver of the LP tokens and SUSHI rewards.
    function withdrawAndHarvest(uint256 pid, uint256 amount, address to) external;

    /// @notice Withdraw without caring about rewards. EMERGENCY ONLY.
    /// @param pid The index of the pool. See `poolInfo`.
    /// @param to Receiver of the LP tokens.
    function emergencyWithdraw(uint256 pid, address to) external;
}

interface IStablePool is IERC20 {

    function token0() external view returns (address);

    function token1() external view returns (address);

    function getAmountOut(bytes calldata data) external view returns (uint256 finalAmountOut);

    function getAssets() external view returns (address[] memory assets);

    function skim() external;

    function getReserves() external view returns (uint256 _reserve0, uint256 _reserve1);

    function getNativeReserves() external view returns (uint256 _nativeReserve0, uint256 _nativeReserve1);

}

interface IFlashBorrower {
    /// @notice The flashloan callback. `amount` + `fee` needs to repayed to msg.sender before this call returns.
    /// @param sender The address of the invoker of this flashloan.
    /// @param token The address of the token that is loaned.
    /// @param amount of the `token` that is loaned.
    /// @param fee The fee that needs to be paid on top for this loan. Needs to be the same as `token`.
    /// @param data Additional data that was passed to the flashloan function.
    function onFlashLoan(
        address sender,
        IERC20 token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

interface IBatchFlashBorrower {
    /// @notice The callback for batched flashloans. Every amount + fee needs to repayed to msg.sender before this call returns.
    /// @param sender The address of the invoker of this flashloan.
    /// @param tokens Array of addresses for ERC-20 tokens that is loaned.
    /// @param amounts A one-to-one map to `tokens` that is loaned.
    /// @param fees A one-to-one map to `tokens` that needs to be paid on top for each loan. Needs to be the same token.
    /// @param data Additional data that was passed to the flashloan function.
    function onBatchFlashLoan(
        address sender,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata fees,
        bytes calldata data
    ) external;
}

/// @title BentoBox
/// @author BoringCrypto, Keno
/// @notice The BentoBox is a vault for tokens. The stored tokens can be flash loaned and used in strategies.
/// Yield from this will go to the token depositors.
/// Rebasing tokens ARE NOT supported and WILL cause loss of funds.
/// Any funds transfered directly onto the BentoBox will be lost, use the deposit function instead.
interface IBentoBox {

    struct Rebase {
        uint128 elastic;
        uint128 base;
    }

    struct StrategyData {
        uint64 strategyStartDate;
        uint64 targetPercentage;
        uint128 balance; // the balance of the strategy that BentoBox thinks is in there
    }

    function totals(IERC20 token) external view returns (Rebase memory rebase);

    function strategyData(IERC20 token) external view returns (StrategyData memory rebase);

    // Balance per token per address/contract in shares
    function balanceOf(
        IERC20 token,
        address from
    ) external view returns (uint256 amount);

    /// @dev Helper function to represent an `amount` of `token` in shares.
    /// @param token The ERC-20 token.
    /// @param amount The `token` amount.
    /// @param roundUp If the result `share` should be rounded up.
    /// @return share The token amount represented in shares.
    function toShare(
        IERC20 token,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);

    /// @dev Helper function represent shares back into the `token` amount.
    /// @param token The ERC-20 token.
    /// @param share The amount of shares.
    /// @param roundUp If the result should be rounded up.
    /// @return amount The share amount back into native representation.
    function toAmount(
        IERC20 token,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    /// @notice Deposit an amount of `token` represented in either `amount` or `share`.
    /// @param token_ The ERC-20 token to deposit.
    /// @param from which account to pull the tokens.
    /// @param to which account to push the tokens.
    /// @param amount Token amount in native representation to deposit.
    /// @param share Token amount represented in shares to deposit. Takes precedence over `amount`.
    /// @return amountOut The amount deposited.
    /// @return shareOut The deposited amount repesented in shares.
    function deposit(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external payable returns (uint256 amountOut, uint256 shareOut);

    /// @notice Withdraws an amount of `token` from a user account.
    /// @param token_ The ERC-20 token to withdraw.
    /// @param from which user to pull the tokens.
    /// @param to which user to push the tokens.
    /// @param amount of tokens. Either one of `amount` or `share` needs to be supplied.
    /// @param share Like above, but `share` takes precedence over `amount`.
    function withdraw(
        IERC20 token_,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);

    /// @notice Transfer shares from a user account to another one.
    /// @param token The ERC-20 token to transfer.
    /// @param from which user to pull the tokens.
    /// @param to which user to push the tokens.
    /// @param share The amount of `token` in shares.
    // Clones of master contracts can transfer from any account that has approved them
    // F3 - Can it be combined with another similar function?
    // F3: This isn't combined with transferMultiple for gas optimization
    function transfer(
        IERC20 token,
        address from,
        address to,
        uint256 share
    ) external;

    /// @notice Transfer shares from a user account to multiple other ones.
    /// @param token The ERC-20 token to transfer.
    /// @param from which user to pull the tokens.
    /// @param tos The receivers of the tokens.
    /// @param shares The amount of `token` in shares for each receiver in `tos`.
    // F3 - Can it be combined with another similar function?
    // F3: This isn't combined with transfer for gas optimization
    function transferMultiple(
        IERC20 token,
        address from,
        address[] calldata tos,
        uint256[] calldata shares
    ) external;

    /// @notice Flashloan ability.
    /// @param borrower The address of the contract that implements and conforms to `IFlashBorrower` and handles the flashloan.
    /// @param receiver Address of the token receiver.
    /// @param token The address of the token to receive.
    /// @param amount of the tokens to receive.
    /// @param data The calldata to pass to the `borrower` contract.
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Not possible to follow this here, reentrancy has been reviewed
    // F6 - Check for front-running possibilities, such as the approve function (SWC-114)
    // F6: Slight grieving possible by withdrawing an amount before someone tries to flashloan close to the full amount.
    function flashLoan(
        IFlashBorrower borrower,
        address receiver,
        IERC20 token,
        uint256 amount,
        bytes calldata data
    ) external;

    /// @notice Support for batched flashloans. Useful to request multiple different `tokens` in a single transaction.
    /// @param borrower The address of the contract that implements and conforms to `IBatchFlashBorrower` and handles the flashloan.
    /// @param receivers An array of the token receivers. A one-to-one mapping with `tokens` and `amounts`.
    /// @param tokens The addresses of the tokens.
    /// @param amounts of the tokens for each receiver.
    /// @param data The calldata to pass to the `borrower` contract.
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Not possible to follow this here, reentrancy has been reviewed
    // F6 - Check for front-running possibilities, such as the approve function (SWC-114)
    // F6: Slight grieving possible by withdrawing an amount before someone tries to flashloan close to the full amount.
    function batchFlashLoan(
        IBatchFlashBorrower borrower,
        address[] calldata receivers,
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    /// @notice The actual process of yield farming. Executes the strategy of `token`.
    /// Optionally does housekeeping if `balance` is true.
    /// `maxChangeAmount` is relevant for skimming or withdrawing if `balance` is true.
    /// @param token The address of the token for which a strategy is deployed.
    /// @param balance True if housekeeping should be done.
    /// @param maxChangeAmount The maximum amount for either pulling or pushing from/to the `IStrategy` contract.
    // F5 - Checks-Effects-Interactions pattern followed? (SWC-107)
    // F5: Total amount is updated AFTER interaction. But strategy is under our control.
    // F5: Not followed to prevent reentrancy issues with flashloans and BentoBox skims?
    function harvest(
        IERC20 token,
        bool balance,
        uint256 maxChangeAmount
    ) external;

    /// @notice Approves or revokes a `masterContract` access to `user` funds.
    /// @param user The address of the user that approves or revokes access.
    /// @param masterContract The address who gains or loses access.
    /// @param approved If True approves access. If False revokes access.
    /// @param v Part of the signature. (See EIP-191)
    /// @param r Part of the signature. (See EIP-191)
    /// @param s Part of the signature. (See EIP-191)
    // F4 - Check behaviour for all function arguments when wrong or extreme
    // F4: Don't allow masterContract 0 to be approved. Unknown contracts will have a masterContract of 0.
    // F4: User can't be 0 for signed approvals because the recoveredAddress will be 0 if ecrecover fails
    function setMasterContractApproval(
        address user,
        address masterContract,
        bool approved,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface WrappedExternalBribe {

    function notifyRewardAmount(address token, uint256 amount) external;
}

interface VelodromePool {
    function sync() external;
    function skim(address to) external;
}

interface IRouter {

    struct route {
        address from;
        address to;
        bool stable;
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address tokenA, address tokenB, bool stable) external view returns (uint reserveA, uint reserveB);

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountOut(uint amountIn, address tokenIn, address tokenOut) external view returns (uint amount, bool stable);

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(uint amountIn, route[] memory routes) external view returns (uint[] memory amounts);

    function quoteAddLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint amountADesired,
        uint amountBDesired
    ) external view returns (uint amountA, uint amountB, uint liquidity);

    function quoteRemoveLiquidity(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity
    ) external view returns (uint amountA, uint amountB);

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

    function addLiquidityETH(
        address token,
        bool stable,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);

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

    function removeLiquidityETH(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        bool stable,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        bool stable,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);

    function swapExactTokensForTokensSimple(
        uint amountIn,
        uint amountOutMin,
        address tokenFrom,
        address tokenTo,
        bool stable,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        route[] calldata routes,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, route[] calldata routes, address to, uint deadline)
    external
    returns (uint[] memory amounts);

}

interface IPair {
    function getReserves() external view returns (uint _reserve0, uint _reserve1, uint _blockTimestampLast);
    function getAmountOut(uint, address) external view returns (uint);
    function balanceOf(address) external view returns (uint);
    function approve(address spender, uint amount) external returns (bool);
    function totalSupply() external view returns (uint);
    function token0() external view returns (address);
}

interface IGauge {
    function deposit(uint amount, uint tokenId) external;
    function withdraw(uint amount) external;
    function balanceOf(address) external view returns (uint);
    function getReward(address account, address[] memory tokens) external;
}

library VelodromeLibrary {

    function getAmountsOut(
        IRouter velodromeRouter,
        address inputToken,
        address outputToken,
        bool isStablePair0,
        uint256 amountInput
    ) internal view returns (uint256) {

        IRouter.route[] memory routes = new IRouter.route[](1);
        routes[0].from = inputToken;
        routes[0].to = outputToken;
        routes[0].stable = isStablePair0;

        uint[] memory amounts = velodromeRouter.getAmountsOut(amountInput, routes);

        return amounts[1];
    }

    function getAmountsOut(
        IRouter velodromeRouter,
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput
    ) internal view returns (uint256) {

        IRouter.route[] memory routes = new IRouter.route[](2);
        routes[0].from = inputToken;
        routes[0].to = middleToken;
        routes[0].stable = isStablePair0;
        routes[1].from = middleToken;
        routes[1].to = outputToken;
        routes[1].stable = isStablePair1;

        uint[] memory amounts = velodromeRouter.getAmountsOut(amountInput, routes);

        return amounts[2];
    }

    function singleSwap(
        IRouter velodromeRouter,
        address inputToken,
        address outputToken,
        bool isStablePair0,
        uint256 amountInput,
        uint256 amountOutMin,
        address recipient
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(velodromeRouter), amountInput);

        IRouter.route[] memory routes = new IRouter.route[](1);
        routes[0].from = inputToken;
        routes[0].to = outputToken;
        routes[0].stable = isStablePair0;

        uint[] memory amounts = velodromeRouter.swapExactTokensForTokens(
            amountInput,
            amountOutMin,
            routes,
            recipient,
            block.timestamp
        );

        return amounts[1];
    }

    function multiSwap(
        IRouter velodromeRouter,
        address inputToken,
        address middleToken,
        address outputToken,
        bool isStablePair0,
        bool isStablePair1,
        uint256 amountInput,
        uint256 amountOutMin,
        address recipient
    ) internal returns (uint256) {

        IERC20(inputToken).approve(address(velodromeRouter), amountInput);

        IRouter.route[] memory routes = new IRouter.route[](2);
        routes[0].from = inputToken;
        routes[0].to = middleToken;
        routes[0].stable = isStablePair0;
        routes[1].from = middleToken;
        routes[1].to = outputToken;
        routes[1].stable = isStablePair1;

        uint[] memory amounts = velodromeRouter.swapExactTokensForTokens(
            amountInput,
            amountOutMin,
            routes,
            recipient,
            block.timestamp
        );

        return amounts[2];
    }

    function getMultiAmount0(
        IRouter velodromeRouter,
        address token0,
        address token1,
        address token2,
        uint256 amount0Total,
        bool    isStable0,
        bool    isStable1,
        uint256 reserve0,
        uint256 reserve1,
        uint256 denominator0,
        uint256 denominator1,
        uint256 precision
    ) internal view returns (uint256 amount0) {
        amount0 = (amount0Total * reserve1) / (reserve0 * denominator1 / denominator0 + reserve1);
        for (uint i = 0; i < precision; i++) {
            uint256 amount1 = getAmountsOut(velodromeRouter, token0, token1, token2,  isStable0, isStable1, amount0);
            amount0 = (amount0Total * reserve1) / (reserve0 * amount1 / amount0 + reserve1);
        }
    }


    struct CalculateMultiParams {
        IRouter velodromeRouter;
        address token0;
        address token1;
        address token2;
        uint256 amount0Total;
        uint256 totalAmountLpTokens;
        bool isStable0;
        bool isStable1;
        uint256 reserve0;
        uint256 reserve1;
        uint256 denominator0;
        uint256 denominator1;
        uint256 precision;
    }

    /**
     * Get amount of lp tokens where amount0Total is total getting amount nominated in token0
     *
     * precision: 0 - no correction, 1 - one correction (recommended value), 2 or more - several corrections
     */
    function getAmountLpTokens(
        CalculateMultiParams memory params
    ) internal view returns (uint256 amountLpTokens) {
        amountLpTokens = (params.totalAmountLpTokens * params.amount0Total * params.denominator1) / (params.reserve0 * params.denominator1 + params.reserve1 * params.denominator0);
        for (uint i = 0; i < params.precision; i++) {
            uint256 amount1 = params.reserve1 * amountLpTokens / params.totalAmountLpTokens;

            uint256 amount0 = getAmountsOut(params.velodromeRouter, params.token2, params.token1, params.token0,  params.isStable1, params.isStable0, amount1);
            amountLpTokens = (params.totalAmountLpTokens * params.amount0Total * amount1) / (params.reserve0 * amount1 + params.reserve1 * amount0);
        }
    }

}

pragma solidity ^0.8.0;

interface IControlRole {

    function hasRole(bytes32 role, address account) external view returns (bool);
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IStrategy {

    event Reward(uint256 amount);
    event PortfolioManagerUpdated(address value);
    event SlippagesUpdated(uint256 swapSlippageBP, uint256 navSlippageBP, uint256 stakeSlippageBP);
    event Stake(uint256 amount);
    event Unstake(uint256 amount, uint256 amountReceived);

    function stake(
        address _asset,
        uint256 _amount
    ) external;

    function unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary,
        bool targetIsZero
    ) external returns (uint256);

    function netAssetValue() external view returns (uint256);

    function liquidationValue() external view returns (uint256);

    function claimRewards(address _to) external returns (uint256);

}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

import "./interfaces/IStrategy.sol";
import "./interfaces/IControlRole.sol";


abstract contract Strategy is IStrategy, Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PORTFOLIO_MANAGER = keccak256("PORTFOLIO_MANAGER");
    bytes32 public constant PORTFOLIO_AGENT_ROLE = keccak256("PORTFOLIO_AGENT_ROLE");

    address public portfolioManager;

    uint256 public swapSlippageBP;
    uint256 public navSlippageBP;
    uint256 public stakeSlippageBP;


    function __Strategy_init() internal initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        swapSlippageBP = 20;
        navSlippageBP = 20;
        stakeSlippageBP = 4;
    }

    function _authorizeUpgrade(address newImplementation)
    internal
    onlyRole(DEFAULT_ADMIN_ROLE)
    override
    {}


    // ---  modifiers

    modifier onlyPortfolioManager() {
        require(hasRole(PORTFOLIO_MANAGER, msg.sender), "Restricted to PORTFOLIO_MANAGER");
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted to admins");
        _;
    }

    modifier onlyPortfolioAgent() {
        require(hasRole(PORTFOLIO_AGENT_ROLE, msg.sender) ||
            IControlRole(portfolioManager).hasRole(PORTFOLIO_AGENT_ROLE, msg.sender) , "Restricted to PORTFOLIO_AGENT_ROLE");
        _;
    }

    // --- setters

    function setPortfolioManager(address _value) public onlyAdmin {
        require(_value != address(0), "Zero address not allowed");

        revokeRole(PORTFOLIO_MANAGER, portfolioManager);
        grantRole(PORTFOLIO_MANAGER, _value);

        portfolioManager = _value;
        emit PortfolioManagerUpdated(_value);
    }

    function setSlippages(
        uint256 _swapSlippageBP,
        uint256 _navSlippageBP,
        uint256 _stakeSlippageBP
    ) public onlyPortfolioAgent {
        swapSlippageBP = _swapSlippageBP;
        navSlippageBP = _navSlippageBP;
        stakeSlippageBP = _stakeSlippageBP;
        emit SlippagesUpdated(_swapSlippageBP, _navSlippageBP, _stakeSlippageBP);
    }


    // --- logic

    function stake(
        address _asset,
        uint256 _amount
    ) external override onlyPortfolioManager {

        uint256 minNavExpected = OvnMath.subBasisPoints(this.netAssetValue(), navSlippageBP);

        _stake(_asset, IERC20(_asset).balanceOf(address(this)));

        require(this.netAssetValue() >= minNavExpected, "Strategy NAV less than expected");

        emit Stake(_amount);
    }

    function unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary,
        bool _targetIsZero
    ) external override onlyPortfolioManager returns (uint256) {

        uint256 minNavExpected = OvnMath.subBasisPoints(this.netAssetValue(), navSlippageBP);

        uint256 withdrawAmount;
        uint256 rewardAmount;
        if (_targetIsZero) {
            rewardAmount = _claimRewards(_beneficiary);
            withdrawAmount = _unstakeFull(_asset, _beneficiary);
        } else {
            withdrawAmount = _unstake(_asset, _amount, _beneficiary);
            require(withdrawAmount >= _amount, 'Returned value less than requested amount');
        }

        require(this.netAssetValue() >= minNavExpected, "Strategy NAV less than expected");

        IERC20(_asset).transfer(_beneficiary, withdrawAmount);

        emit Unstake(_amount, withdrawAmount);
        if (rewardAmount > 0) {
            emit Reward(rewardAmount);
        }

        return withdrawAmount;
    }

    function claimRewards(address _to) external override onlyPortfolioManager returns (uint256) {
        uint256 rewardAmount = _claimRewards(_to);
        if (rewardAmount > 0) {
            emit Reward(rewardAmount);
        }
        return rewardAmount;
    }

    function _stake(
        address _asset,
        uint256 _amount
    ) internal virtual {
        revert("Not implemented");
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal virtual returns (uint256) {
        revert("Not implemented");
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal virtual returns (uint256) {
        revert("Not implemented");
    }

    function _claimRewards(address _to) internal virtual returns (uint256) {
        revert("Not implemented");
    }


    uint256[46] private __gap;
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Chainlink.sol";
import "@overnight-contracts/connectors/contracts/stuff/Sushiswap.sol";
import "@overnight-contracts/connectors/contracts/stuff/Curve.sol";
import "@overnight-contracts/connectors/contracts/stuff/Velodrome.sol";


contract StrategySushiswapUsdcUsdt is Strategy {

    // --- params

    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public op;
    IERC20 public sushi;

    IBentoBox public bentoBox;
    ITridentRouter public tridentRouter;
    IMiniChefV2 public miniChefV2;
    IStablePool public lpToken;
    uint256 public pid;

    IPriceFeed public oracleUsdc;
    IPriceFeed public oracleUsdt;

    address public curve3Pool;
    IRouter public velodromeRouter;
    address public rewardWallet;

    uint256 public usdcDm;
    uint256 public usdtDm;

    // --- events

    event StrategyUpdatedParams();

    // --- structs

    struct StrategyParams {
        address usdc;
        address usdt;
        address op;
        address sushi;
        address bentoBox;
        address tridentRouter;
        address miniChefV2;
        address lpToken;
        uint256 pid;
        address oracleUsdc;
        address oracleUsdt;
        address curve3Pool;
        address velodromeRouter;
        address rewardWallet;
    }

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
        usdc = IERC20(params.usdc);
        usdt = IERC20(params.usdt);
        op = IERC20(params.op);
        sushi = IERC20(params.sushi);

        bentoBox = IBentoBox(params.bentoBox);
        tridentRouter = ITridentRouter(params.tridentRouter);
        miniChefV2 = IMiniChefV2(params.miniChefV2);
        lpToken = IStablePool(params.lpToken);
        pid = params.pid;

        oracleUsdc = IPriceFeed(params.oracleUsdc);
        oracleUsdt = IPriceFeed(params.oracleUsdt);

        curve3Pool = params.curve3Pool;
        velodromeRouter = IRouter(params.velodromeRouter);
        rewardWallet = params.rewardWallet;

        usdcDm = 10 ** IERC20Metadata(params.usdc).decimals();
        usdtDm = 10 ** IERC20Metadata(params.usdt).decimals();

        bentoBox.setMasterContractApproval(address(this), address(tridentRouter), true, 0, '', '');

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {
        test_stake(_asset, _amount);
    }

    function test_stake(
        address _asset,
        uint256 _amount
    ) public {

        // swap needed amount usdc to usdt
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveUsdt) = lpToken.getReserves();
        require(reserveUsdc > 10 ** 3 && reserveUsdt > 10 ** 3, 'Liquidity lpToken reserves too low');

        uint256 usdcBalance = usdc.balanceOf(address(this));

        uint256 amountUsdc = CurveLibrary.getAmountToSwap(
            curve3Pool,
            address(usdc),
            address(usdt),
            usdcBalance,
            reserveUsdc,
            reserveUsdt,
            usdcDm,
            usdtDm,
            1
        );

        CurveLibrary.swap(
            curve3Pool,
            address(usdc),
            address(usdt),
            amountUsdc,
            OvnMath.subBasisPoints(_oracleUsdcToUsdt(amountUsdc), swapSlippageBP)
        );

        // create params and calculate min liquidity
        usdcBalance = usdc.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));

        ITridentRouter.TokenInput memory usdcInput;
        usdcInput.token = address(usdc);
        usdcInput.native = true;
        usdcInput.amount = usdcBalance;

        ITridentRouter.TokenInput memory usdtInput;
        usdtInput.token = address(usdt);
        usdcInput.native = true;
        usdtInput.amount = usdtBalance;

        ITridentRouter.TokenInput[] memory tokenInput = new ITridentRouter.TokenInput[](2);
        tokenInput[0] = usdcInput;
        tokenInput[1] = usdtInput;

        uint256 minLiquidity = OvnMath.subBasisPoints(usdcBalance * totalLpBalance / reserveUsdc, stakeSlippageBP);

        // add liquidity
        usdc.approve(address(bentoBox), usdcBalance);
        usdt.approve(address(bentoBox), usdtBalance);
        tridentRouter.addLiquidity(
            tokenInput,
            address(lpToken),
            minLiquidity,
            abi.encode(address(this))
        );

        uint256 lpTokenBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(miniChefV2), lpTokenBalance);
        miniChefV2.deposit(pid, lpTokenBalance, address(this));
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        return test_unstake(_asset, _amount, _beneficiary);
    }

    function test_unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) public returns (uint256) {

        // get lpToken amount to unstake
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveUsdt) = lpToken.getReserves();
        uint256 amountLp = CurveLibrary.getAmountLpTokens(
            curve3Pool,
            address(usdc),
            address(usdt),
            OvnMath.addBasisPoints(_amount + 10, 1),
            totalLpBalance,
            reserveUsdc,
            reserveUsdt,
            usdcDm,
            usdtDm,
            1
        );

        (uint256 lpTokenBalance,) = miniChefV2.userInfo(pid, address(this));
        if (amountLp > lpTokenBalance) {
            amountLp = lpTokenBalance;
        }

        // unstake
        miniChefV2.withdraw(pid, amountLp, address(this));

        // calculate min amounts
        uint256 amountUsdc = OvnMath.subBasisPoints(reserveUsdc * amountLp / totalLpBalance, stakeSlippageBP);
        uint256 amountUsdt = OvnMath.subBasisPoints(reserveUsdt * amountLp / totalLpBalance, stakeSlippageBP);

        ITridentRouter.TokenAmount memory usdcAmount;
        usdcAmount.token = address(usdc);
        usdcAmount.amount = amountUsdc;

        ITridentRouter.TokenAmount memory usdtAmount;
        usdtAmount.token = address(usdt);
        usdtAmount.amount = amountUsdt;

        ITridentRouter.TokenAmount[] memory minWithdrawals = new ITridentRouter.TokenAmount[](2);
        minWithdrawals[0] = usdcAmount;
        minWithdrawals[1] = usdtAmount;

        // remove liquidity
        lpToken.approve(address(tridentRouter), lpTokenBalance);
        tridentRouter.burnLiquidity(
            address(lpToken),
            lpTokenBalance,
            abi.encode(address(this), false),
            minWithdrawals
        );

        // swap usdt to usdc
        uint256 usdtBalance = usdt.balanceOf(address(this));
        CurveLibrary.swap(
            curve3Pool,
            address(usdt),
            address(usdc),
            usdtBalance,
            OvnMath.subBasisPoints(_oracleUsdtToUsdc(usdtBalance), swapSlippageBP)
        );

        return usdc.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        // get lpToken amount to unstake
        (uint256 lpTokenBalance,) = miniChefV2.userInfo(pid, address(this));
        if (lpTokenBalance == 0) {
            return usdc.balanceOf(address(this));
        }

        // unstake
        miniChefV2.withdraw(pid, lpTokenBalance, address(this));

        // calculate min amounts
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveUsdt) = lpToken.getReserves();
        uint256 amountUsdc = OvnMath.subBasisPoints(reserveUsdc * lpTokenBalance / totalLpBalance, stakeSlippageBP);
        uint256 amountUsdt = OvnMath.subBasisPoints(reserveUsdt * lpTokenBalance / totalLpBalance, stakeSlippageBP);

        ITridentRouter.TokenAmount memory usdcAmount;
        usdcAmount.token = address(usdc);
        usdcAmount.amount = amountUsdc;

        ITridentRouter.TokenAmount memory usdtAmount;
        usdtAmount.token = address(usdt);
        usdtAmount.amount = amountUsdt;

        ITridentRouter.TokenAmount[] memory minWithdrawals = new ITridentRouter.TokenAmount[](2);
        minWithdrawals[0] = usdcAmount;
        minWithdrawals[1] = usdtAmount;

        // remove liquidity
        lpToken.approve(address(tridentRouter), lpTokenBalance);
        tridentRouter.burnLiquidity(
            address(lpToken),
            lpTokenBalance,
            abi.encode(address(this), false),
            minWithdrawals
        );

        // swap usdt to usdc
        uint256 usdtBalance = usdt.balanceOf(address(this));
        CurveLibrary.swap(
            curve3Pool,
            address(usdt),
            address(usdc),
            usdtBalance,
            OvnMath.subBasisPoints(_oracleUsdtToUsdc(usdtBalance), swapSlippageBP)
        );

        return usdc.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 usdtBalance = usdt.balanceOf(address(this));

        (uint256 lpTokenBalance,) = miniChefV2.userInfo(pid, address(this));
        if (lpTokenBalance > 0) {
            uint256 totalLpBalance = lpToken.totalSupply();
            (uint256 reserveUsdc, uint256 reserveUsdt) = lpToken.getReserves();
            usdcBalance += reserveUsdc * lpTokenBalance / totalLpBalance;
            usdtBalance += reserveUsdt * lpTokenBalance / totalLpBalance;
        }

        if (usdtBalance > 0) {
            if (nav) {
                usdcBalance += _oracleUsdtToUsdc(usdtBalance);
            } else {
                usdcBalance += CurveLibrary.getAmountOut(curve3Pool, address(usdt), address(usdc), usdtBalance);
            }
        }

        return usdcBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        (uint256 lpTokenBalance,) = miniChefV2.userInfo(pid, address(this));
        if (lpTokenBalance > 0) {
            miniChefV2.harvest(pid, address(this));
        }

        // send sushi to rewardWallet
        uint256 sushiBalance = sushi.balanceOf(address(this));
        if (sushiBalance > 0) {
            sushi.transfer(rewardWallet, sushiBalance);
        }

        // sell rewards
        uint256 totalUsdc;

        uint256 opBalance = op.balanceOf(address(this));
        if (opBalance > 0) {
            uint256 amountOut = VelodromeLibrary.getAmountsOut(
                velodromeRouter,
                address(op),
                address(usdc),
                false,
                opBalance
            );
            if (amountOut > 0) {
                totalUsdc += VelodromeLibrary.singleSwap(
                    velodromeRouter,
                    address(op),
                    address(usdc),
                    false,
                    opBalance,
                    amountOut * 99 / 100,
                    address(this)
                );
            }
        }

        if (totalUsdc > 0) {
            usdc.transfer(_to, totalUsdc);
        }

        return totalUsdc;
    }

    function _oracleUsdtToUsdc(uint256 usdtAmount) internal view returns (uint256) {
        uint256 priceUsdt = ChainlinkLibrary.getPrice(oracleUsdt);
        uint256 priceUsdc = ChainlinkLibrary.getPrice(oracleUsdc);
        return ChainlinkLibrary.convertTokenToToken(usdtAmount, usdtDm, usdcDm, priceUsdt, priceUsdc);
    }

    function _oracleUsdcToUsdt(uint256 usdcAmount) internal view returns (uint256) {
        uint256 priceUsdt = ChainlinkLibrary.getPrice(oracleUsdt);
        uint256 priceUsdc = ChainlinkLibrary.getPrice(oracleUsdc);
        return ChainlinkLibrary.convertTokenToToken(usdcAmount, usdcDm, usdtDm, priceUsdc, priceUsdt);
    }
}