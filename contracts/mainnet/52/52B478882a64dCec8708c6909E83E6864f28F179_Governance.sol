// SPDX-License-Identifier: AGPL-3.0-only

// The Governance Policy submits & activates instructions in a INSTR module

pragma solidity ^0.8.10;

import {Kernel, Policy} from "../Kernel.sol";
import {Instructions, Actions, Instruction} from "../modules/INSTR.sol";
import {XBOND} from "../modules/XBOND.sol";

// proposing
error NotEnoughVotesToPropose();

// endorsing
error CannotEndorseNullProposal();
error CannotEndorseInvalidProposal();

// activating
error NotAuthorizedToActivateProposal();
error NotEnoughEndorsementsToActivateProposal();
error ProposalAlreadyActivated();
error ActiveProposalNotExpired();
error SubmittedProposalHasExpired();

// voting
error NoActiveProposalDetected();
error UserAlreadyVoted();

// executing
error NotEnoughVotesToExecute();
error ExecutionTimelockStillActive();

// claiming
error VotingTokensAlreadyReclaimed();
error CannotReclaimTokensForActiveVote();
error CannotReclaimZeroVotes();

struct ProposalMetadata {
    bytes32 proposalName;
    address proposer;
    uint256 submissionTimestamp;
}

struct ActivatedProposal {
    uint256 instructionsId;
    uint256 activationTimestamp;
}

contract Governance is Policy {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Policy Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    Instructions public INSTR;
    XBOND public xBOND;
    uint256 public deployedAt;

    constructor(Kernel kernel_) Policy(kernel_) {
        deployedAt = block.timestamp;
    }

    function configureReads() external override {
        INSTR = Instructions(getModuleAddress("INSTR"));
        xBOND = XBOND(getModuleAddress("XBOND"));
    }

    // The Governor Policy is also the Kernel's Executor.
    function requestRoles() external view override onlyKernel returns (bytes32[] memory roles) {
        roles = new bytes32[](2);
        roles[0] = INSTR.GOVERNOR();
        roles[1] = xBOND.GOVERNOR();
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Variables                                //
    /////////////////////////////////////////////////////////////////////////////////

    event ProposalSubmitted(uint256 instructionsId, ProposalMetadata proposal);
    event ProposalEndorsed(uint256 instructionsId, address voter, uint256 amount);
    event ProposalActivated(uint256 instructionsId, uint256 timestamp);
    event WalletVoted(uint256 instructionsId, address voter, bool for_, uint256 userVotes);
    event ProposalExecuted(uint256 instructionsId);

    // currently active proposal
    ActivatedProposal public activeProposal;

    mapping(uint256 => ProposalMetadata) public getProposalMetadata;

    mapping(uint256 => uint256) public totalEndorsementsForProposal;
    mapping(uint256 => mapping(address => uint256)) public userEndorsementsForProposal;
    mapping(uint256 => bool) public proposalHasBeenActivated;

    mapping(uint256 => uint256) public yesVotesForProposal;
    mapping(uint256 => uint256) public noVotesForProposal;
    mapping(uint256 => mapping(address => uint256)) public userVotesForProposal;

    mapping(uint256 => mapping(address => bool)) public tokenClaimsForProposal;

    /////////////////////////////////////////////////////////////////////////////////
    //                               User Actions                                  //
    /////////////////////////////////////////////////////////////////////////////////

    function getMetadata(uint256 instructionsId_) public view returns (ProposalMetadata memory) {
        return getProposalMetadata[instructionsId_];
    }

    function getActiveProposal() public view returns (ActivatedProposal memory) {
        return activeProposal;
    }

    function submitProposal(Instruction[] calldata instructions_, bytes32 proposalName_) external {
        require(block.timestamp > deployedAt + 2 weeks, "Must wait 2 weeks before submitting a proposal");
        // require the proposing wallet to own at least 1% of the outstanding governance power
        if (xBOND.balanceOf(msg.sender) * 100 < xBOND.totalSupply()) {
            revert NotEnoughVotesToPropose();
        }

        // store the proposed instructions in the INSTR module and save the proposal metadata to the proposal mapping
        uint256 instructionsId = INSTR.store(instructions_);
        getProposalMetadata[instructionsId] = ProposalMetadata(proposalName_, msg.sender, block.timestamp);

        // emit the corresponding event
        emit ProposalSubmitted(instructionsId, getProposalMetadata[instructionsId]);
    }

    function endorseProposal(uint256 instructionsId_) external {
        // get the current votes of the user
        uint256 userVotes = xBOND.balanceOf(msg.sender);

        // revert if endorsing null instructionsId
        if (instructionsId_ == 0) {
            revert CannotEndorseNullProposal();
        }

        // revert if endorsed instructions are empty
        Instruction[] memory instructions = INSTR.getInstructions(instructionsId_);
        if (instructions.length == 0) {
            revert CannotEndorseInvalidProposal();
        }

        // undo any previous endorsement the user made on these instructions
        uint256 previousEndorsement = userEndorsementsForProposal[instructionsId_][msg.sender];
        totalEndorsementsForProposal[instructionsId_] -= previousEndorsement;

        // reapply user endorsements with most up-to-date votes
        userEndorsementsForProposal[instructionsId_][msg.sender] = userVotes;
        totalEndorsementsForProposal[instructionsId_] += userVotes;

        // emit the corresponding event
        emit ProposalEndorsed(instructionsId_, msg.sender, userVotes);
    }

    function activateProposal(uint256 instructionsId_) external {
        // get the proposal to be activated
        ProposalMetadata memory proposal = getProposalMetadata[instructionsId_];

        // only allow the proposer to activate their proposal
        if (msg.sender != proposal.proposer) {
            revert NotAuthorizedToActivateProposal();
        }

        // proposals must be activated within 2 weeks of submission or they expire
        if (block.timestamp > proposal.submissionTimestamp + 2 weeks) {
            revert SubmittedProposalHasExpired();
        }

        // require endorsements from at least 20% of the total outstanding governance power
        if ((totalEndorsementsForProposal[instructionsId_] * 5) < xBOND.totalSupply()) {
            revert NotEnoughEndorsementsToActivateProposal();
        }

        // ensure the proposal is being activated for the first time
        if (proposalHasBeenActivated[instructionsId_]) {
            revert ProposalAlreadyActivated();
        }

        // ensure the currently active proposal has had at least a week of voting for execution
        if (block.timestamp < activeProposal.activationTimestamp + 1 weeks) {
            revert ActiveProposalNotExpired();
        }

        // activate the proposal
        activeProposal = ActivatedProposal(instructionsId_, block.timestamp);

        // record that the proposal has been activated
        proposalHasBeenActivated[instructionsId_] = true;

        // emit the corresponding event
        emit ProposalActivated(instructionsId_, block.timestamp);
    }

    function vote(bool for_) external {
        // get the amount of user votes
        uint256 userVotes = xBOND.balanceOf(msg.sender);

        // ensure an active proposal exists
        if (activeProposal.instructionsId == 0) {
            revert NoActiveProposalDetected();
        }

        // ensure the user has no pre-existing votes on the proposal
        if (userVotesForProposal[activeProposal.instructionsId][msg.sender] > 0) {
            revert UserAlreadyVoted();
        }

        // record the votes
        if (for_) {
            yesVotesForProposal[activeProposal.instructionsId] += userVotes;
        } else {
            noVotesForProposal[activeProposal.instructionsId] += userVotes;
        }

        // record that the user has casted votes
        userVotesForProposal[activeProposal.instructionsId][msg.sender] = userVotes;

        // transfer voting tokens to contract
        xBOND.transferFrom(msg.sender, address(this), userVotes);

        // emit the corresponding event
        emit WalletVoted(activeProposal.instructionsId, msg.sender, for_, userVotes);
    }

    function executeProposal() external {
        // require the net votes (yes - no) to be greater than 33% of the total voting supply
        if (
            (yesVotesForProposal[activeProposal.instructionsId] - noVotesForProposal[activeProposal.instructionsId]) *
                3 <
            xBOND.totalSupply()
        ) {
            revert NotEnoughVotesToExecute();
        }

        // ensure three days have passed before the proposal can be executed
        if (block.timestamp < activeProposal.activationTimestamp + 3 days) {
            revert ExecutionTimelockStillActive();
        }

        // execute the active proposal
        Instruction[] memory instructions = INSTR.getInstructions(activeProposal.instructionsId);

        for (uint256 step; step < instructions.length; ) {
            kernel.executeAction(instructions[step].action, instructions[step].target);
            unchecked {
                ++step;
            }
        }

        // emit the corresponding event
        emit ProposalExecuted(activeProposal.instructionsId);

        // deactivate the active proposal
        activeProposal = ActivatedProposal(0, 0);
    }

    function reclaimVotes(uint256 instructionsId_) external {
        // get the amount of tokens the user voted with
        uint256 userVotes = userVotesForProposal[instructionsId_][msg.sender];

        // ensure the user is not claiming empty votes
        if (userVotes == 0) {
            revert CannotReclaimZeroVotes();
        }

        // ensure the user is not claiming for the active propsal
        if (instructionsId_ == activeProposal.instructionsId) {
            revert CannotReclaimTokensForActiveVote();
        }

        // ensure the user has not already claimed before for this proposal
        if (tokenClaimsForProposal[instructionsId_][msg.sender]) {
            revert VotingTokensAlreadyReclaimed();
        }

        // record the voting tokens being claimed from the contract
        tokenClaimsForProposal[instructionsId_][msg.sender] = true;

        // return the tokens back to the user
        xBOND.transferFrom(address(this), msg.sender, userVotes);
    }
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

// SPDX-License-Identifier: AGPL-3.0-only

// [INSTR] The Instructions Module caches and executes batched instructions for protocol upgrades in the Kernel

pragma solidity ^0.8.10;

import "../Kernel.sol";

error INSTR_InstructionsCannotBeEmpty();
error INSTR_InvalidChangeExecutorAction();
error INSTR_InvalidTargetNotAContract();
error INSTR_InvalidModuleKeycode();

contract Instructions is Module {
    /////////////////////////////////////////////////////////////////////////////////
    //                         Kernel Module Configuration                         //
    /////////////////////////////////////////////////////////////////////////////////

    bytes32 public constant GOVERNOR = "INSTR_Governor";

    constructor(Kernel kernel_) Module(kernel_) {}

    function KEYCODE() public pure override returns (bytes5) {
        return "INSTR";
    }

    function ROLES() public pure override returns (bytes32[] memory roles) {
        roles = new bytes32[](1);
        roles[0] = GOVERNOR;
    }

    /////////////////////////////////////////////////////////////////////////////////
    //                              Module Variables                               //
    /////////////////////////////////////////////////////////////////////////////////

    event InstructionsStored(uint256 instructionsId);

    /* Imported from Kernel, just here for reference:

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
    */

    uint256 public totalInstructions;
    mapping(uint256 => Instruction[]) public storedInstructions;

    /////////////////////////////////////////////////////////////////////////////////
    //                             Policy Interface                                //
    /////////////////////////////////////////////////////////////////////////////////

    // view function for retrieving a list of instructions in an outside contract
    function getInstructions(uint256 instructionsId_) public view returns (Instruction[] memory) {
        return storedInstructions[instructionsId_];
    }

    function store(Instruction[] calldata instructions_) external onlyRole(GOVERNOR) returns (uint256) {
        uint256 length = instructions_.length;
        uint256 instructionsId = ++totalInstructions;

        // initialize an empty list of instructions that will be filled
        Instruction[] storage instructions = storedInstructions[instructionsId];

        // if there are no instructions, throw an error
        if (length == 0) {
            revert INSTR_InstructionsCannotBeEmpty();
        }

        // for each instruction, do the following actions:
        for (uint256 i; i < length; ) {
            // get the instruction
            Instruction calldata instruction = instructions_[i];

            // check the address that the instruction is being performed on is a contract (bytecode size > 0)
            _ensureContract(instruction.target);

            // if the instruction deals with a module, make sure the module has a valid keycode (UPPERCASE A-Z ONLY)
            if (instruction.action == Actions.InstallModule || instruction.action == Actions.UpgradeModule) {
                Module module = Module(instruction.target);
                _ensureValidKeycode(module.KEYCODE());
            } else if (instruction.action == Actions.ChangeExecutor && i != length - 1) {
                // throw an error if ChangeExecutor exists and is not the last Action in the instruction llist
                // this exists because if ChangeExecutor is not the last item in the list of instructions
                // the Kernel will not recognize any of the following instructions as valid, since the policy
                // executing the list of instructions no longer has permissions in the Kernel. To avoid this issue
                // and prevent invalid proposals from being saved, we perform this check.

                revert INSTR_InvalidChangeExecutorAction();
            }

            instructions.push(instructions_[i]);
            unchecked {
                ++i;
            }
        }

        emit InstructionsStored(instructionsId);

        return instructionsId;
    }

    /////////////////////////////// INTERNAL FUNCTIONS ////////////////////////////////

    function _ensureContract(address target_) internal view {
        uint256 size;
        assembly {
            size := extcodesize(target_)
        }
        if (size == 0) revert INSTR_InvalidTargetNotAContract();
    }

    function _ensureValidKeycode(bytes5 keycode_) internal pure {
        for (uint256 i = 0; i < 5; ) {
            bytes1 char = keycode_[i];

            if (char < 0x41 || char > 0x5A) revert INSTR_InvalidModuleKeycode(); // A-Z only"

            unchecked {
                i++;
            }
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0-only

// [XBOND] The xbond Module is the ERC20 token that represents voting power in the network.

pragma solidity ^0.8.10;

import {Kernel, Module} from "../Kernel.sol";
import "@rari-capital/solmate/src/tokens/ERC20.sol";

error XBOND_TransferDisabled();

contract XBOND is Module, ERC20 {
    bytes32 public constant ISSUER = "XBOND_Issuer";
    bytes32 public constant GOVERNOR = "XBOND_Governor";
    bytes32 public constant MANAGER = "XBOND_Manager";

    enum PARAMETER {
        WARMUP,
        COOLDOWN
    }

    uint256 public warmupPeriod = 7 days;
    uint256 public cooldownPeriod = 7 days;

    constructor(Kernel kernel_) Module(kernel_) ERC20("StakedBOND", "XBOND", 18) {}

    function KEYCODE() public pure override returns (bytes5) {
        return "XBOND";
    }

    function ROLES() public pure override returns (bytes32[] memory roles) {
        roles = new bytes32[](3);
        roles[0] = ISSUER;
        roles[1] = GOVERNOR;
        roles[2] = MANAGER;
    }

    /**
     *  @notice set parameters for new bonds
     *  @param _parameter PARAMETER
     *  @param _input uint
     */
    function configureStakingPeriods(PARAMETER _parameter, uint256 _input) external onlyRole(MANAGER) {
        if (_parameter == PARAMETER.WARMUP) {
            // 0
            require(_input >= 1 days, "Warmup must be greater than 1 day");
            warmupPeriod = _input;
        } else if (_parameter == PARAMETER.COOLDOWN) {
            // 1
            require(_input >= 1 days, "Cooldown must be greater than 1 day");
            cooldownPeriod = _input;
        }
    }

    // Policy Interface
    function mint(address wallet_, uint256 amount_) external onlyRole(ISSUER) {
        _mint(wallet_, amount_);
    }

    function burn(address wallet_, uint256 amount_) external onlyRole(ISSUER) {
        _burn(wallet_, amount_);
    }

    function transfer(address, uint256) public override returns (bool) {
        revert XBOND_TransferDisabled();
        return true;
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 amount_
    ) public override onlyRole(GOVERNOR) returns (bool) {
        balanceOf[from_] -= amount_;
        unchecked {
            balanceOf[to_] += amount_;
        }

        emit Transfer(from_, to_, amount_);
        return true;
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