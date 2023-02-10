// SPDX-License-Identifier: Apache-2.0-or-later
/*

 Copyright 2023 Rigo Intl.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/

pragma solidity 0.8.17;

import "./RigoblockGovernanceProxy.sol";
import "../IRigoblockGovernance.sol";
import "../interfaces/IRigoblockGovernanceFactory.sol";

// solhint-disable-next-line
contract RigoblockGovernanceFactory is IRigoblockGovernanceFactory {
    Parameters private _parameters;

    // @inheritdoc IRigoblockGovernanceFactory
    function createGovernance(
        address implementation,
        address governanceStrategy,
        uint256 proposalThreshold,
        uint256 quorumThreshold,
        IRigoblockGovernance.TimeType timeType,
        string calldata name
    ) external returns (address governance) {
        assert(_isContract(implementation));
        assert(_isContract(governanceStrategy));

        // we write to storage to allow proxy to read initialization parameters
        _parameters = Parameters({
            implementation: implementation,
            governanceStrategy: governanceStrategy,
            proposalThreshold: proposalThreshold,
            quorumThreshold: quorumThreshold,
            timeType: timeType,
            name: name
        });
        governance = address(new RigoblockGovernanceProxy{salt: keccak256(abi.encode(msg.sender, name))}());

        delete _parameters;
        emit GovernanceCreated(governance);
    }

    // @inheritdoc IRigoblockGovernanceFactory
    function parameters() external view override returns (Parameters memory) {
        return _parameters;
    }

    /// @dev Returns whether an address is a contract.
    /// @return Bool target address has code.
    function _isContract(address target) private view returns (bool) {
        return target.code.length > 0;
    }
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.8.17;

import "../interfaces/IRigoblockGovernanceFactory.sol";

contract RigoblockGovernanceProxy {
    /// @notice Emitted when implementation written to proxy storage.
    /// @dev Emitted also at first variable initialization.
    /// @param newImplementation Address of the new implementation.
    event Upgraded(address indexed newImplementation);

    // implementation slot is used to store implementation address, a contract which implements the governance logic.
    // Reduced deployment cost by using internal variable.
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice Sets address of implementation contract.
    constructor() payable {
        // store implementation address in implementation slot value
        assert(_IMPLEMENTATION_SLOT == bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1));

        // we retrieve the set implementation from the factory storage
        address implementation = IRigoblockGovernanceFactory(msg.sender).parameters().implementation;

        // we store the implementation address
        _getImplementation().implementation = implementation;
        emit Upgraded(implementation);

        // initialize governance
        // abi.encodeWithSelector(IRigoblockGovernance.initializeGovernance.selector)
        (, bytes memory returnData) = implementation.delegatecall(abi.encodeWithSelector(0xe9134903));

        // we must assert initialization didn't fail, otherwise it could fail silently and still deploy the governance.
        assert(returnData.length == 0);
    }

    /* solhint-disable no-complex-fallback */
    /// @notice Fallback function forwards all transactions and returns all received return data.
    fallback() external payable {
        address implementation = _getImplementation().implementation;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldatacopy(0, 0, calldatasize())
            let success := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            if eq(success, 0) {
                revert(0, returndatasize())
            }
            return(0, returndatasize())
        }
    }

    /// @notice Allows this contract to receive ether.
    receive() external payable {}

    /* solhint-enable no-complex-fallback */

    /// @notice Implementation slot is accessed directly.
    /// @dev Saves gas compared to using storage slot library.
    /// @param implementation Address of the implementation.
    struct ImplementationSlot {
        address implementation;
    }

    /// @notice Method to read/write from/to implementation slot.
    /// @return s Storage slot of the governance implementation.
    function _getImplementation() private pure returns (ImplementationSlot storage s) {
        assembly {
            s.slot := _IMPLEMENTATION_SLOT
        }
    }
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

import "./interfaces/governance/IGovernanceEvents.sol";
import "./interfaces/governance/IGovernanceInitializer.sol";
import "./interfaces/governance/IGovernanceState.sol";
import "./interfaces/governance/IGovernanceUpgrade.sol";
import "./interfaces/governance/IGovernanceVoting.sol";

interface IRigoblockGovernance is
    IGovernanceEvents,
    IGovernanceInitializer,
    IGovernanceUpgrade,
    IGovernanceVoting,
    IGovernanceState
{}

// SPDX-License-Identifier: Apache-2.0-or-later
/*

 Copyright 2017-2022 RigoBlock, Rigo Investment Sagl, Rigo Intl.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

import "../IRigoblockGovernance.sol";

// solhint-disable-next-line
interface IRigoblockGovernanceFactory {
    /// @notice Emitted when a governance is created.
    /// @param governance Address of the governance proxy.
    event GovernanceCreated(address governance);

    /// @notice Creates a new governance proxy.
    /// @param implementation Address of the governance implementation contract.
    /// @param governanceStrategy Address of the voting strategy.
    /// @param proposalThreshold Number of votes required for creating a new proposal.
    /// @param quorumThreshold Number of votes required for execution.
    /// @param timeType Enum of time type (block number or timestamp).
    /// @param name Human readable string of the name.
    /// @return governance Address of the new governance.
    function createGovernance(
        address implementation,
        address governanceStrategy,
        uint256 proposalThreshold,
        uint256 quorumThreshold,
        IRigoblockGovernance.TimeType timeType,
        string calldata name
    ) external returns (address governance);

    struct Parameters {
        /// @notice Address of the governance implementation contract.
        address implementation;
        /// @notice Address of the voting strategy.
        address governanceStrategy;
        /// @notice Number of votes required for creating a new proposal.
        uint256 proposalThreshold;
        /// @notice Number of votes required for execution.
        uint256 quorumThreshold;
        /// @notice Type of time chosed, block number of timestamp.
        IRigoblockGovernance.TimeType timeType;
        /// @notice String of the name of the application.
        string name;
    }

    /// @notice Returns the governance initialization parameters at proxy deploy.
    /// @return Tuple of the governance parameters.
    function parameters() external view returns (Parameters memory);
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

import "./IGovernanceVoting.sol";

interface IGovernanceEvents {
    /// @notice Emitted when a new proposal is created.
    /// @param proposer Address of the proposer.
    /// @param proposalId Number of the proposal.
    /// @param actions Struct array of actions (targets, datas, values).
    /// @param startBlockOrTime Timestamp in seconds after which proposal can be voted on.
    /// @param endBlockOrTime Timestamp in seconds after which proposal can be executed.
    /// @param description String description of proposal.
    event ProposalCreated(
        address proposer,
        uint256 proposalId,
        IGovernanceVoting.ProposedAction[] actions,
        uint256 startBlockOrTime,
        uint256 endBlockOrTime,
        string description
    );

    /// @notice Emitted when a proposal is executed.
    /// @param proposalId Number of the proposal.
    event ProposalExecuted(uint256 proposalId);

    /// @notice Emmited when the governance strategy is upgraded.
    /// @param newStrategy Address of the new strategy contract.
    event StrategyUpgraded(address newStrategy);

    /// @notice Emitted when voting thresholds get updated.
    /// @dev Only governance can update thresholds.
    /// @param proposalThreshold Number of votes required to add a proposal.
    /// @param quorumThreshold Number of votes required to execute a proposal.
    event ThresholdsUpdated(uint256 proposalThreshold, uint256 quorumThreshold);

    /// @notice Emitted when implementation written to proxy storage.
    /// @dev Emitted also at first variable initialization.
    /// @param newImplementation Address of the new implementation.
    event Upgraded(address indexed newImplementation);

    /// @notice Emitted when a voter votes.
    /// @param voter Address of the voter.
    /// @param proposalId Number of the proposal.
    /// @param voteType Number of vote type.
    /// @param votingPower Number of votes.
    event VoteCast(address voter, uint256 proposalId, IGovernanceVoting.VoteType voteType, uint256 votingPower);
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

interface IGovernanceInitializer {
    /// @notice Initializes the Rigoblock Governance.
    /// @dev Params are stored in factory and read from there.
    function initializeGovernance() external;
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

import "./IGovernanceVoting.sol";

interface IGovernanceState {
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Qualified,
        Defeated,
        Succeeded,
        Queued,
        Expired,
        Executed
    }

    enum TimeType {
        Blocknumber,
        Timestamp
    }

    struct Proposal {
        uint256 actionsLength;
        uint256 startBlockOrTime;
        uint256 endBlockOrTime;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 votesAbstain;
        bool executed;
    }

    struct ProposalWrapper {
        Proposal proposal;
        IGovernanceVoting.ProposedAction[] proposedAction;
    }

    /// @notice Returns the actions proposed for a given proposal.
    /// @param proposalId Number of the proposal.
    /// @return proposedActions Array of tuple of proposed actions.
    function getActions(uint256 proposalId)
        external
        view
        returns (IGovernanceVoting.ProposedAction[] memory proposedActions);

    /// @notice Returns a proposal for a given id.
    /// @param proposalId The number of the proposal.
    /// @return proposalWrapper Tuple wrapper of the proposal and proposed actions tuples.
    function getProposalById(uint256 proposalId) external view returns (ProposalWrapper memory proposalWrapper);

    /// @notice Returns the state of a proposal.
    /// @param proposalId Number of the proposal.
    /// @return Number of proposal state.
    function getProposalState(uint256 proposalId) external view returns (ProposalState);

    struct Receipt {
        bool hasVoted;
        uint96 votes;
        IGovernanceVoting.VoteType voteType;
    }

    /// @notice Returns the receipt of a voter for a given proposal.
    /// @param proposalId Number of the proposal.
    /// @param voter Address of the voter.
    /// @return Tuple of voter receipt.
    function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);

    /// @notice Computes the current voting power of the given account.
    /// @param account The address of the account.
    /// @return votingPower The current voting power of the given account.
    function getVotingPower(address account) external view returns (uint256 votingPower);

    struct GovernanceParameters {
        address strategy;
        uint256 proposalThreshold;
        uint256 quorumThreshold;
        TimeType timeType;
    }

    struct EnhancedParams {
        GovernanceParameters params;
        string name;
        string version;
    }

    /// @notice Returns the governance parameters.
    /// @return Tuple of the governance parameters.
    function governanceParameters() external view returns (EnhancedParams memory);

    /// @notice Returns the name of the governace.
    /// @return Human readable string of the name.
    function name() external view returns (string memory);

    /// @notice Returns the total number of proposals.
    /// @return count The number of proposals.
    function proposalCount() external view returns (uint256 count);

    /// @notice Returns all proposals ever made to the governance.
    /// @return proposalWrapper Tuple array of all governance proposals.
    function proposals() external view returns (ProposalWrapper[] memory proposalWrapper);

    /// @notice Returns the voting period.
    /// @return Number of blocks or seconds.
    function votingPeriod() external view returns (uint256);
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

interface IGovernanceUpgrade {
    /// @notice Updates the proposal and quorum thresholds to the given values.
    /// @dev Only callable by the governance contract itself.
    /// @dev Thresholds can only be updated via a successful governance proposal.
    /// @param newProposalThreshold The new value for the proposal threshold.
    /// @param newQuorumThreshold The new value for the quorum threshold.
    function updateThresholds(uint256 newProposalThreshold, uint256 newQuorumThreshold) external;

    /// @notice Updates the governance implementation address.
    /// @dev Only callable after successful voting.
    /// @param newImplementation Address of the new governance implementation contract.
    function upgradeImplementation(address newImplementation) external;

    /// @notice Updates the governance strategy plugin.
    /// @dev Only callable by the governance contract itself.
    /// @param newStrategy Address of the new strategy contract.
    function upgradeStrategy(address newStrategy) external;
}

// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2023 Rigo Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity >=0.8.0 <0.9.0;

import "./IGovernanceEvents.sol";

interface IGovernanceVoting {
    enum VoteType {
        For,
        Against,
        Abstain
    }

    /// @notice Casts a vote for the given proposal.
    /// @dev Only callable during the voting period for that proposal. One address can only vote once.
    /// @param proposalId The ID of the proposal to vote on.
    /// @param voteType Whether to support, not support or abstain.
    function castVote(uint256 proposalId, VoteType voteType) external;

    /// @notice Casts a vote for the given proposal, by signature.
    /// @dev Only callable during the voting period for that proposal. One voter can only vote once.
    /// @param proposalId The ID of the proposal to vote on.
    /// @param voteType Whether to support, not support or abstain.
    /// @param v the v field of the signature.
    /// @param r the r field of the signature.
    /// @param s the s field of the signature.
    function castVoteBySignature(
        uint256 proposalId,
        VoteType voteType,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Executes a proposal that has passed and is currently executable.
    /// @param proposalId The ID of the proposal to execute.
    function execute(uint256 proposalId) external payable;

    struct ProposedAction {
        address target;
        bytes data;
        uint256 value;
    }

    /// @notice Creates a proposal on the the given actions. Must have at least `proposalThreshold`.
    /// @dev Must have at least `proposalThreshold` of voting power to call this function.
    /// @param actions The proposed actions. An action specifies a contract call.
    /// @param description A text description for the proposal.
    /// @return proposalId The ID of the newly created proposal.
    function propose(ProposedAction[] calldata actions, string calldata description)
        external
        returns (uint256 proposalId);
}