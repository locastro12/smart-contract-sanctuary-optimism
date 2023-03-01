/**
 *Submitted for verification at Optimistic.Etherscan.io on 2023-02-24
*/

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.7;

interface IPlug {
    /**
     * @notice executes the message received from source chain
     * @dev this should be only executable by socket
     * @param srcChainSlug_ chain slug of source
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function inbound(
        uint256 srcChainSlug_,
        bytes calldata payload_
    ) external payable;
}

interface ITransmitManager {
    function isTransmitter(
        address user,
        uint256 siblingChainSlug
    ) external view returns (bool);

    function checkTransmitter(
        uint256 chainSlugs_,
        uint256 packetId,
        bytes32 root,
        bytes calldata signature
    ) external view returns (address, bool);

    function payFees(uint256 dstSlug) external payable;

    function getMinFees(uint256 dstSlug) external view returns (uint256);
}

interface IExecutionManager {
    function isExecutor(address user) external view returns (bool);

    function payFees(uint256 msgGasLimit, uint256 dstSlug) external payable;

    function getMinFees(
        uint256 msgGasLimit,
        uint256 dstSlug
    ) external view returns (uint256);
}

interface ISocket {
    /**
     * @notice emits the message details when a new message arrives at outbound
     * @param localChainSlug local chain slug
     * @param localPlug local plug address
     * @param dstChainSlug remote chain slug
     * @param dstPlug remote plug address
     * @param msgId message id packed with remoteChainSlug and nonce
     * @param msgGasLimit gas limit needed to execute the inbound at remote
     * @param fees fees provided by msg sender
     * @param payload the data which will be used by inbound at remote
     */
    event MessageTransmitted(
        uint256 localChainSlug,
        address localPlug,
        uint256 dstChainSlug,
        address dstPlug,
        uint256 msgId,
        uint256 msgGasLimit,
        uint256 executionFee,
        uint256 fees,
        bytes payload
    );

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     */
    event ExecutionSuccess(uint256 msgId);

    /**
     * @notice emits the status of message after inbound call
     * @param msgId msg id which is executed
     * @param result if message reverts, returns the revert message
     */
    event ExecutionFailed(uint256 msgId, string result);

    /**
     * @notice emits the error message in bytes after inbound call
     * @param msgId msg id which is executed
     * @param result if message reverts, returns the revert message in bytes
     */
    event ExecutionFailedBytes(uint256 msgId, bytes result);

    /**
     * @notice emits the config set by a plug for a remoteChainSlug
     * @param plug address of plug on current chain
     * @param siblingChainSlug sibling chain slug
     * @param siblingPlug address of plug on sibling chain
     * @param inboundSwitchboard inbound switchboard (select from registered options)
     * @param outboundSwitchboard outbound switchboard (select from registered options)
     * @param capacitor capacitor selected based on outbound switchboard
     * @param decapacitor decapacitor selected based on inbound switchboard
     */
    event PlugConnected(
        address plug,
        uint256 siblingChainSlug,
        address siblingPlug,
        address inboundSwitchboard,
        address outboundSwitchboard,
        address capacitor,
        address decapacitor
    );

    /**
     * @notice emits when a new transmitManager contract is set
     * @param transmitManager_ address of new transmitManager contract
     */
    event TransmitManagerSet(address transmitManager_);

    /**
     * @notice registers a message
     * @dev Packs the message and includes it in a packet with capacitor
     * @param remoteChainSlug_ the remote chain slug
     * @param msgGasLimit_ the gas limit needed to execute the payload on remote
     * @param payload_ the data which is needed by plug at inbound call on remote
     */
    function outbound(
        uint256 remoteChainSlug_,
        uint256 msgGasLimit_,
        bytes calldata payload_
    ) external payable returns (uint256 msgId);

    struct MessageDetails {
        uint256 msgId;
        uint256 executionFee;
        uint256 msgGasLimit;
        bytes payload;
        bytes decapacitorProof;
    }

    /**
     * @notice executes a message
     * @param packetId packet id
     * @param localPlug local plug address
     * @param messageDetails_ the details needed for message verification
     */
    function execute(
        uint256 packetId,
        address localPlug,
        ISocket.MessageDetails calldata messageDetails_
    ) external;

    /**
     * @notice sets the config specific to the plug
     * @param siblingChainSlug_ the sibling chain slug
     * @param siblingPlug_ address of plug present at sibling chain to call inbound
     * @param inboundSwitchboard_ the address of switchboard to use for receiving messages
     * @param outboundSwitchboard_ the address of switchboard to use for sending messages
     */
    function connect(
        uint256 siblingChainSlug_,
        address siblingPlug_,
        address inboundSwitchboard_,
        address outboundSwitchboard_
    ) external;

    function remoteRoots(uint256 packetId_) external view returns (bytes32);

    function _transmitManager__() external view returns (ITransmitManager);

    function _executionManager__() external view returns (IExecutionManager);
}

interface ISwitchboard {
    function allowPacket(
        bytes32 root,
        uint256 packetId,
        uint256 srcChainSlug,
        uint256 proposeTime
    ) external view returns (bool);

    function payFees(uint256 dstChainSlug) external payable;

    function getMinFees(
        uint256 dstChainSlug
    ) external view returns (uint256 switchboardFee, uint256 verificationFee);
}

abstract contract Ownable {
    address private _owner;
    address private _nominee;

    event OwnerNominated(address indexed nominee);
    event OwnerClaimed(address indexed claimer);

    error OnlyOwner();
    error OnlyNominee();

    constructor(address owner_) {
        _claimOwner(owner_);
    }

    modifier onlyOwner() {
        if (msg.sender != _owner) revert OnlyOwner();
        _;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function nominee() external view returns (address) {
        return _nominee;
    }

    function nominateOwner(address nominee_) external {
        if (msg.sender != _owner) revert OnlyOwner();
        _nominee = nominee_;
        emit OwnerNominated(_nominee);
    }

    function claimOwner() external {
        if (msg.sender != _nominee) revert OnlyNominee();
        _claimOwner(msg.sender);
    }

    function _claimOwner(address claimer_) internal {
        _owner = claimer_;
        _nominee = address(0);
    }
}

contract Messenger is IPlug, Ownable(msg.sender) {
    // immutables
    ISocket public immutable _socket__;
    uint256 public immutable _localChainSlug;
    ITransmitManager public _transmitManager__;
    ISwitchboard public _switchboard__;
    IExecutionManager public _executionManager__;

    bytes32 public _message;
    uint256 public _msgGasLimit;

    bytes32 public constant _PING = keccak256("PING");
    bytes32 public constant _PONG = keccak256("PONG");

    error NoSocketFee();

    constructor(address socket_, uint256 chainSlug_, uint256 msgGasLimit_) {
        _socket__ = ISocket(socket_);
        _transmitManager__ = ISocket(socket_)._transmitManager__();
        _executionManager__ = ISocket(socket_)._executionManager__();
        _localChainSlug = chainSlug_;

        _msgGasLimit = msgGasLimit_;
    }

    receive() external payable {}

    function updateMsgGasLimit(uint256 msgGasLimit_) external onlyOwner {
        _msgGasLimit = msgGasLimit_;
    }

    function removeGas(address payable receiver_) external onlyOwner {
        receiver_.transfer(address(this).balance);
    }

    function sendLocalMessage(bytes32 message_) external {
        _updateMessage(message_);
    }

    function sendRemoteMessage(
        uint256 remoteChainSlug_,
        bytes32 message_
    ) external payable {
        bytes memory payload = abi.encode(_localChainSlug, message_);
        _outbound(remoteChainSlug_, payload);
    }

    function inbound(
        uint256,
        bytes calldata payload_
    ) external payable override {
        require(msg.sender == address(_socket__), "Counter: Invalid Socket");
        (uint256 remoteChainSlug, bytes32 msgDecoded) = abi.decode(
            payload_,
            (uint256, bytes32)
        );

        _updateMessage(msgDecoded);

        bytes memory newPayload = abi.encode(
            _localChainSlug,
            msgDecoded == _PING ? _PONG : _PING
        );
        _outbound(remoteChainSlug, newPayload);
    }

    // settings
    function setSocketConfig(
        uint256 remoteChainSlug_,
        address remotePlug_,
        address switchboard_
    ) external onlyOwner {
        _switchboard__ = ISwitchboard(switchboard_);
        _socket__.connect(
            remoteChainSlug_,
            remotePlug_,
            switchboard_,
            switchboard_
        );
    }

    function message() external view returns (bytes32) {
        return _message;
    }

    function _updateMessage(bytes32 message_) private {
        _message = message_;
    }

    function _outbound(uint256 targetChain_, bytes memory payload_) private {
        (uint256 switchboardFee, uint256 verificationFee) = _switchboard__
            .getMinFees(targetChain_);
        uint256 fee = switchboardFee +
            verificationFee +
            _transmitManager__.getMinFees(targetChain_) +
            _executionManager__.getMinFees(_msgGasLimit, targetChain_);
        if (!(address(this).balance >= fee)) revert NoSocketFee();
        _socket__.outbound{value: fee}(targetChain_, _msgGasLimit, payload_);
    }
}