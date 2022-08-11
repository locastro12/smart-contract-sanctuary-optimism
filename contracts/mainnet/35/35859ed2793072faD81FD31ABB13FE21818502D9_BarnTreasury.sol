pragma solidity ^0.8.10;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";

import "../interfaces/ITreasury.sol";
import "../Kernel.sol";

contract BarnTreasury is Module, ITreasury {
    bytes32 public constant MANAGER = "TRSRY_Manager";
    bytes32 public constant EXECUTIVE = "TRSRY_Executive";

    //////////////////////////////////////////////////////////////////////////////
    //                              SYSTEM CONFIG                               //
    //////////////////////////////////////////////////////////////////////////////

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (bytes5) {
        return "TRSRY";
    }

    function ROLES() public pure override returns (bytes32[] memory roles) {
        roles = new bytes32[](2);
        roles[0] = EXECUTIVE;
        roles[1] = MANAGER;
    }

    // function KEYCODE() public pure override returns (bytes5) {
    //     return "TRSRY";
    // }

    mapping(address => bool) public trackedAsset;
    mapping(address => uint256) public totalInflowsForAsset;
    mapping(address => uint256) public totalOutflowsForAsset;

    ////////////////////////////////////////////////////////////////////////////
    //                           POLICY INTERFACE                             //
    ////////////////////////////////////////////////////////////////////////////

    function addTrackedAsset(address token_) external override onlyRole(MANAGER) {
        trackedAsset[token_] = true;

        emit AssetAdded(token_);
    }

    function deposit(
        address token_,
        address from_,
        uint256 amount_
    ) external override onlyRole(EXECUTIVE) {
        require(trackedAsset[token_], "cannot deposit(): token is not an accepted currency by the treasury");

        ERC20(token_).transferFrom(from_, address(this), amount_);

        totalInflowsForAsset[token_] += amount_;

        emit FundsDeposited(from_, token_, amount_);
    }

    function withdraw(address token_, uint256 amount_) external override onlyRole(EXECUTIVE) {
        require(trackedAsset[token_], "cannot withdraw(): token is not an accepted currency by the treasury");

        ERC20(token_).transfer(msg.sender, amount_);

        totalOutflowsForAsset[token_] += amount_;

        emit FundsWithdrawn(msg.sender, token_, amount_);
    }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

/// @notice Modern and gas efficient ERC20 + EIP-2612 implementation.
/// @author Solmate (https://github.com/Rari-Capital/solmate/blob/main/src/tokens/ERC20.sol)
/// @author Modified from Uniswap (https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/UniswapV2ERC20.sol)
/// @dev Do not manually set balances without updating totalSupply, as the sum of all user balances must not exceed it.
abstract contract ERC20 {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);

    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

    string public name;

    string public symbol;

    uint8 public immutable decimals;

    /*//////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;

    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                            EIP-2612 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 internal immutable INITIAL_CHAIN_ID;

    bytes32 internal immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => uint256) public nonces;

    /*//////////////////////////////////////////////////////////////
                               CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = computeDomainSeparator();
    }

    /*//////////////////////////////////////////////////////////////
                               ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) public virtual returns (bool) {
        allowance[msg.sender][spender] = amount;

        emit Approval(msg.sender, spender, amount);

        return true;
    }

    function transfer(address to, uint256 amount) public virtual returns (bool) {
        balanceOf[msg.sender] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(msg.sender, to, amount);

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual returns (bool) {
        uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;

        balanceOf[from] -= amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /*//////////////////////////////////////////////////////////////
                             EIP-2612 LOGIC
    //////////////////////////////////////////////////////////////*/

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(deadline >= block.timestamp, "PERMIT_DEADLINE_EXPIRED");

        // Unchecked because the only math done is incrementing
        // the owner's nonce which cannot realistically overflow.
        unchecked {
            address recoveredAddress = ecrecover(
                keccak256(
                    abi.encodePacked(
                        "\x19\x01",
                        DOMAIN_SEPARATOR(),
                        keccak256(
                            abi.encode(
                                keccak256(
                                    "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
                                ),
                                owner,
                                spender,
                                value,
                                nonces[owner]++,
                                deadline
                            )
                        )
                    )
                ),
                v,
                r,
                s
            );

            require(recoveredAddress != address(0) && recoveredAddress == owner, "INVALID_SIGNER");

            allowance[recoveredAddress][spender] = value;
        }

        emit Approval(owner, spender, value);
    }

    function DOMAIN_SEPARATOR() public view virtual returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID ? INITIAL_DOMAIN_SEPARATOR : computeDomainSeparator();
    }

    function computeDomainSeparator() internal view virtual returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256(bytes(name)),
                    keccak256("1"),
                    block.chainid,
                    address(this)
                )
            );
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

    function _mint(address to, uint256 amount) internal virtual {
        totalSupply += amount;

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            balanceOf[to] += amount;
        }

        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal virtual {
        balanceOf[from] -= amount;

        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}

pragma solidity ^0.8.0;

interface ITreasury {
    event AssetAdded(address indexed token);
    event FundsDeposited(address indexed from, address indexed token, uint256 amount);
    event FundsWithdrawn(address indexed to, address indexed token, uint256 amount);

    function addTrackedAsset(address token_) external;

    function deposit(
        address from_,
        address token_,
        uint256 amount_
    ) external;

    function withdraw(address token_, uint256 amount_) external;
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

// ######################## ~ ERRORS ~ ########################

// MODULE

error Module_NotAuthorized();

// POLICY

// error Policy_ModuleDoesNotExist(Kernel.Keycode keycode_);
error Policy_ModuleDoesNotExist(bytes5 keycode_);
error Policy_OnlyKernel(address caller_);

// KERNEL

error Kernel_OnlyExecutor(address caller_);
// error Kernel_ModuleAlreadyInstalled(Kernel.Keycode module_);
// error Kernel_ModuleAlreadyExists(Kernel.Keycode module_);
error Kernel_ModuleAlreadyInstalled(bytes5 module_);
error Kernel_ModuleAlreadyExists(bytes5 module_);
error Kernel_PolicyAlreadyApproved(address policy_);
error Kernel_PolicyNotApproved(address policy_);

// ######################## ~ GLOBAL TYPES ~ ########################

enum Actions {
    InstallModule,
    UpgradeModule,
    ApprovePolicy,
    TerminatePolicy,
    ChangeExecutor
}

struct Instruction {
    Actions action;
    address target;
}

// ######################## ~ CONTRACT TYPES ~ ########################

abstract contract Module {
    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    // Kernel.Role role_
    modifier onlyRole(bytes32 role_) {
        if (!kernel.hasRole(msg.sender, role_)) {
            revert Module_NotAuthorized();
        }
        _;
    }

    // function KEYCODE() public pure virtual returns (Kernel.Keycode);
    function KEYCODE() public pure virtual returns (bytes5);

    // function ROLES() public pure virtual returns (Kernel.Role[] memory roles);
    function ROLES() public pure virtual returns (bytes32[] memory roles);

    /// @notice Specify which version of a module is being implemented.
    /// @dev Minor version change retains interface. Major version upgrade indicates
    ///      breaking change to the interface.
    function VERSION() external pure virtual returns (uint8 major, uint8 minor) {}
}

abstract contract Policy {
    Kernel public kernel;

    constructor(Kernel kernel_) {
        kernel = kernel_;
    }

    modifier onlyKernel() {
        if (msg.sender != address(kernel)) revert Policy_OnlyKernel(msg.sender);
        _;
    }

    function configureReads() external virtual onlyKernel {}

    // function requestRoles() external view virtual returns (Kernel.Role[] memory roles) {}
    function requestRoles() external view virtual returns (bytes32[] memory roles) {}

    function getModuleAddress(bytes5 keycode) internal view returns (address) {
        // Kernel.Keycode keycode = Kernel.Keycode.wrap(keycode_);
        address moduleForKeycode = kernel.getModuleForKeycode(keycode);

        if (moduleForKeycode == address(0)) revert Policy_ModuleDoesNotExist(keycode);

        return moduleForKeycode;
    }
}

contract Kernel {
    // ######################## ~ TYPES ~ ########################

    // TODEV: throw error in @openzeppelin/hardhat-upgrades
    // type Role is bytes32;
    // type Keycode is bytes5;

    // ######################## ~ VARS ~ ########################

    address public executor;

    // ######################## ~ DEPENDENCY MANAGEMENT ~ ########################

    address[] public allPolicies;

    // Keycode => address
    mapping(bytes5 => address) public getModuleForKeycode; // get contract for module keycode

    // address => Keycode
    mapping(address => bytes5) public getKeycodeForModule; // get module keycode for contract

    mapping(address => bool) public approvedPolicies; // whitelisted apps

    // address => Role => bool
    mapping(address => mapping(bytes32 => bool)) public hasRole;

    // ######################## ~ EVENTS ~ ########################

    event RolesUpdated(bytes32 indexed role_, address indexed policy_, bool indexed granted_);

    event ActionExecuted(Actions indexed action_, address indexed target_);

    // ######################## ~ BODY ~ ########################

    constructor() {
        executor = msg.sender;
    }

    // ######################## ~ MODIFIERS ~ ########################

    modifier onlyExecutor() {
        if (msg.sender != executor) revert Kernel_OnlyExecutor(msg.sender);
        _;
    }

    // ######################## ~ KERNEL INTERFACE ~ ########################

    function executeAction(Actions action_, address target_) external onlyExecutor {
        if (action_ == Actions.InstallModule) {
            _installModule(target_);
        } else if (action_ == Actions.UpgradeModule) {
            _upgradeModule(target_);
        } else if (action_ == Actions.ApprovePolicy) {
            _approvePolicy(target_);
        } else if (action_ == Actions.TerminatePolicy) {
            _terminatePolicy(target_);
        } else if (action_ == Actions.ChangeExecutor) {
            executor = target_;
        }

        emit ActionExecuted(action_, target_);
    }

    // ######################## ~ KERNEL INTERNAL ~ ########################

    function _installModule(address newModule_) internal {
        // Keycode keycode = Module(newModule_).KEYCODE();
        bytes5 keycode = Module(newModule_).KEYCODE();

        // @NOTE check newModule_ != 0
        if (getModuleForKeycode[keycode] != address(0)) revert Kernel_ModuleAlreadyInstalled(keycode);

        getModuleForKeycode[keycode] = newModule_;
        getKeycodeForModule[newModule_] = keycode;
    }

    function _upgradeModule(address newModule_) internal {
        // Keycode keycode = Module(newModule_).KEYCODE();
        bytes5 keycode = Module(newModule_).KEYCODE();
        address oldModule = getModuleForKeycode[keycode];

        if (oldModule == address(0) || oldModule == newModule_) revert Kernel_ModuleAlreadyExists(keycode);

        // getKeycodeForModule[oldModule] = Keycode.wrap(bytes5(0));
        getKeycodeForModule[oldModule] = bytes5(0);
        getKeycodeForModule[newModule_] = keycode;
        getModuleForKeycode[keycode] = newModule_;

        _reconfigurePolicies();
    }

    function _approvePolicy(address policy_) internal {
        if (approvedPolicies[policy_]) revert Kernel_PolicyAlreadyApproved(policy_);

        approvedPolicies[policy_] = true;

        Policy(policy_).configureReads();

        // Role[] memory requests = Policy(policy_).requestRoles();
        bytes32[] memory requests = Policy(policy_).requestRoles();

        _setPolicyRoles(policy_, requests, true);

        allPolicies.push(policy_);
    }

    function _terminatePolicy(address policy_) internal {
        if (!approvedPolicies[policy_]) revert Kernel_PolicyNotApproved(policy_);

        approvedPolicies[policy_] = false;

        // Role[] memory requests = Policy(policy_).requestRoles();
        bytes32[] memory requests = Policy(policy_).requestRoles();

        _setPolicyRoles(policy_, requests, false);
    }

    function _reconfigurePolicies() internal {
        for (uint256 i = 0; i < allPolicies.length; i++) {
            address policy_ = allPolicies[i];

            if (approvedPolicies[policy_]) Policy(policy_).configureReads();
        }
    }

    // Role[] memory requests_,
    function _setPolicyRoles(
        address policy_,
        bytes32[] memory requests_,
        bool grant_
    ) internal {
        uint256 l = requests_.length;

        for (uint256 i = 0; i < l; ) {
            bytes32 request = requests_[i];

            hasRole[policy_][request] = grant_;

            emit RolesUpdated(request, policy_, grant_);

            unchecked {
                i++;
            }
        }
    }
}