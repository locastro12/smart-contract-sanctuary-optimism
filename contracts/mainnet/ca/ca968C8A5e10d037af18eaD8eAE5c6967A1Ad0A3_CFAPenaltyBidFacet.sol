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
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC777/IERC777.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC777Token standard as defined in the EIP.
 *
 * This contract uses the
 * https://eips.ethereum.org/EIPS/eip-1820[ERC1820 registry standard] to let
 * token holders and recipients react to token movements by using setting implementers
 * for the associated interfaces in said registry. See {IERC1820Registry} and
 * {ERC1820Implementer}.
 */
interface IERC777 {
    /**
     * @dev Emitted when `amount` tokens are created by `operator` and assigned to `to`.
     *
     * Note that some additional user `data` and `operatorData` can be logged in the event.
     */
    event Minted(address indexed operator, address indexed to, uint256 amount, bytes data, bytes operatorData);

    /**
     * @dev Emitted when `operator` destroys `amount` tokens from `account`.
     *
     * Note that some additional user `data` and `operatorData` can be logged in the event.
     */
    event Burned(address indexed operator, address indexed from, uint256 amount, bytes data, bytes operatorData);

    /**
     * @dev Emitted when `operator` is made operator for `tokenHolder`.
     */
    event AuthorizedOperator(address indexed operator, address indexed tokenHolder);

    /**
     * @dev Emitted when `operator` is revoked its operator status for `tokenHolder`.
     */
    event RevokedOperator(address indexed operator, address indexed tokenHolder);

    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the smallest part of the token that is not divisible. This
     * means all token operations (creation, movement and destruction) must have
     * amounts that are a multiple of this number.
     *
     * For most token contracts, this value will equal 1.
     */
    function granularity() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by an account (`owner`).
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * If send or receive hooks are registered for the caller and `recipient`,
     * the corresponding functions will be called with `data` and empty
     * `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits a {Sent} event.
     *
     * Requirements
     *
     * - the caller must have at least `amount` tokens.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function send(
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev Destroys `amount` tokens from the caller's account, reducing the
     * total supply.
     *
     * If a send hook is registered for the caller, the corresponding function
     * will be called with `data` and empty `operatorData`. See {IERC777Sender}.
     *
     * Emits a {Burned} event.
     *
     * Requirements
     *
     * - the caller must have at least `amount` tokens.
     */
    function burn(uint256 amount, bytes calldata data) external;

    /**
     * @dev Returns true if an account is an operator of `tokenHolder`.
     * Operators can send and burn tokens on behalf of their owners. All
     * accounts are their own operator.
     *
     * See {operatorSend} and {operatorBurn}.
     */
    function isOperatorFor(address operator, address tokenHolder) external view returns (bool);

    /**
     * @dev Make an account an operator of the caller.
     *
     * See {isOperatorFor}.
     *
     * Emits an {AuthorizedOperator} event.
     *
     * Requirements
     *
     * - `operator` cannot be calling address.
     */
    function authorizeOperator(address operator) external;

    /**
     * @dev Revoke an account's operator status for the caller.
     *
     * See {isOperatorFor} and {defaultOperators}.
     *
     * Emits a {RevokedOperator} event.
     *
     * Requirements
     *
     * - `operator` cannot be calling address.
     */
    function revokeOperator(address operator) external;

    /**
     * @dev Returns the list of default operators. These accounts are operators
     * for all token holders, even if {authorizeOperator} was never called on
     * them.
     *
     * This list is immutable, but individual holders may revoke these via
     * {revokeOperator}, in which case {isOperatorFor} will return false.
     */
    function defaultOperators() external view returns (address[] memory);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient`. The caller must
     * be an operator of `sender`.
     *
     * If send or receive hooks are registered for `sender` and `recipient`,
     * the corresponding functions will be called with `data` and
     * `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * Emits a {Sent} event.
     *
     * Requirements
     *
     * - `sender` cannot be the zero address.
     * - `sender` must have at least `amount` tokens.
     * - the caller must be an operator for `sender`.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     * The caller must be an operator of `account`.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with `data` and `operatorData`. See {IERC777Sender}.
     *
     * Emits a {Burned} event.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     * - the caller must be an operator for `account`.
     */
    function operatorBurn(
        address account,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external;

    event Sent(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 amount,
        bytes data,
        bytes operatorData
    );
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

pragma solidity ^0.8.8;

library OwnableStorage {
    struct Layout {
        address owner;
    }

    bytes32 internal constant STORAGE_SLOT =
        keccak256('solidstate.contracts.storage.Ownable');

    function layout() internal pure returns (Layout storage l) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            l.slot := slot
        }
    }

    function setOwner(Layout storage l, address owner) internal {
        l.owner = owner;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title ERC165 interface registration interface
 * @dev see https://eips.ethereum.org/EIPS/eip-165
 */
interface IERC165 {
    /**
     * @notice query whether contract has registered support for given interface
     * @param interfaceId interface id
     * @return bool whether interface is supported
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import { IERC165 } from './IERC165.sol';
import { IERC721Internal } from './IERC721Internal.sol';

/**
 * @title ERC721 interface
 * @dev see https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721 is IERC721Internal, IERC165 {
    /**
     * @notice query the balance of given address
     * @return balance quantity of tokens held
     */
    function balanceOf(address account) external view returns (uint256 balance);

    /**
     * @notice query the owner of given token
     * @param tokenId token to query
     * @return owner token owner
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @notice transfer token between given addresses, checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @notice transfer token between given addresses, checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     * @param data data payload
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external payable;

    /**
     * @notice transfer token between given addresses, without checking for ERC721Receiver implementation if applicable
     * @param from sender of token
     * @param to receiver of token
     * @param tokenId token id
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external payable;

    /**
     * @notice grant approval to given account to spend token
     * @param operator address to be approved
     * @param tokenId token to approve
     */
    function approve(address operator, uint256 tokenId) external payable;

    /**
     * @notice get approval status for given token
     * @param tokenId token to query
     * @return operator address approved to spend token
     */
    function getApproved(uint256 tokenId)
        external
        view
        returns (address operator);

    /**
     * @notice grant approval to or revoke approval from given account to spend all tokens held by sender
     * @param operator address to be approved
     * @param status approval status
     */
    function setApprovalForAll(address operator, bool status) external;

    /**
     * @notice query approval status of given operator with respect to given address
     * @param account address to query for approval granted
     * @param operator address to query for approval received
     * @return status whether operator is approved to spend tokens held by account
     */
    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool status);
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

/**
 * @title Partial ERC721 interface needed by internal functions
 */
interface IERC721Internal {
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed operator,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import {
    ISuperfluid,
    ISuperfluidToken
} from "../interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "../interfaces/agreements/IConstantFlowAgreementV1.sol";

/**
 * @title Constant flow agreement v1 library
 * @author Superfluid
 * @dev for working with the constant flow agreement within solidity
 * @dev the first set of functions are each for callAgreement()
 * @dev the second set of functions are each for use in callAgreementWithContext()
 */
library CFAv1Library {

    /**
     * @dev Initialization data
     * @param host Superfluid host for calling agreements
     * @param cfa Constant Flow Agreement contract
     */
    struct InitData {
        ISuperfluid host;
        IConstantFlowAgreementV1 cfa;
    }

    /**
     * @dev Create flow without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function createFlow(
        InitData storage cfaLibrary,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal {
        createFlow(cfaLibrary, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Create flow with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function createFlow(
        InitData storage cfaLibrary,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal {
        cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.createFlow,
                (
                    token,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData
        );
    }

    /**
     * @dev Update flow without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function updateFlow(
        InitData storage cfaLibrary,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal {
        updateFlow(cfaLibrary, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Update flow with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function updateFlow(
        InitData storage cfaLibrary,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal {
        cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlow,
                (
                    token,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData
        );
    }

    /**
     * @dev Delete flow without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     */
    function deleteFlow(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token
    ) internal {
        deleteFlow(cfaLibrary, sender, receiver, token, new bytes(0));
    }

    /**
     * @dev Delete flow with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param userData The user provided data
     */
    function deleteFlow(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        bytes memory userData
    ) internal {
        cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.deleteFlow,
                (
                    token,
                    sender,
                    receiver,
                    new bytes(0) // placeholder
                )
            ),
            userData
        );
    }

    /**
     * @dev Create flow with context and userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function createFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return createFlowWithCtx(cfaLibrary, ctx, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Create flow with context and userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function createFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.createFlow,
                (
                    token,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Update flow with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function updateFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return updateFlowWithCtx(cfaLibrary, ctx, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Update flow with context and userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function updateFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlow,
                (
                    token,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Delete flow with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     */
    function deleteFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        return deleteFlowWithCtx(cfaLibrary, ctx, sender, receiver, token, new bytes(0));
    }

    /**
     * @dev Delete flow with context and userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param userData The user provided data
     */
    function deleteFlowWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.deleteFlow,
                (
                    token,
                    sender,
                    receiver,
                    new bytes(0) // placeholder
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Creates flow as an operator without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function createFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return createFlowByOperator(cfaLibrary, sender, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Creates flow as an operator with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function createFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.createFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData
        );
    }

    /**
     * @dev Creates flow as an operator without userData with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function createFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return createFlowByOperatorWithCtx(
            cfaLibrary,
            ctx,
            sender,
            receiver,
            token,
            flowRate,
            new bytes(0)
        );
    }

    /**
     * @dev Creates flow as an operator with userData and context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function createFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.createFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    flowRate,
                    new bytes(0) // placeholder
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Updates a flow as an operator without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function updateFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return updateFlowByOperator(cfaLibrary, sender, receiver, token, flowRate, new bytes(0));
    }

    /**
     * @dev Updates flow as an operator with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function updateFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    flowRate,
                    new bytes(0)
                )
            ),
            userData
        );
    }

    /**
     * @dev Updates a flow as an operator without userData with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     */
    function updateFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate
    ) internal returns (bytes memory newCtx) {
        return updateFlowByOperatorWithCtx(
            cfaLibrary,
            ctx,
            sender,
            receiver,
            token,
            flowRate,
            new bytes(0)
        );
    }

    /**
     * @dev Updates flow as an operator with userData and context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param flowRate The desired flowRate
     * @param userData The user provided data
     */
    function updateFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        int96 flowRate,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    flowRate,
                    new bytes(0)
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Deletes a flow as an operator without userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     */
    function deleteFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        return deleteFlowByOperator(cfaLibrary, sender, receiver, token, new bytes(0));
    }

    /**
     * @dev Deletes a flow as an operator with userData
     * @param cfaLibrary The cfaLibrary storage variable
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param userData The user provided data
     */
    function deleteFlowByOperator(
        InitData storage cfaLibrary,
        address sender,
        address receiver,
        ISuperfluidToken token,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.deleteFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    new bytes(0)
                )
            ),
            userData
        );
    }

    /**
     * @dev Deletes a flow as an operator without userData with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     */
    function deleteFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        return deleteFlowByOperatorWithCtx(cfaLibrary, ctx, sender, receiver, token, new bytes(0));
    }

    /**
     * @dev Deletes a flow as an operator with userData and context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param sender The sender of the flow
     * @param receiver The receiver of the flow
     * @param token The token to flow
     * @param userData The user provided data
     */
    function deleteFlowByOperatorWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address sender,
        address receiver,
        ISuperfluidToken token,
        bytes memory userData
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.deleteFlowByOperator,
                (
                    token,
                    sender,
                    receiver,
                    new bytes(0)
                )
            ),
            userData,
            ctx
        );
    }

    /**
     * @dev Updates the permissions of a flow operator
     * @param cfaLibrary The cfaLibrary storage variable
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     * @param permissions The number of the permissions: create = 1; update = 2; delete = 4;
     * To give multiple permissions, sum the above. create_delete = 5; create_update_delete = 7; etc
     * @param flowRateAllowance The allowance for flow creation. Decremented as flowRate increases
     */
    function updateFlowOperatorPermissions(
        InitData storage cfaLibrary,
        address flowOperator,
        ISuperfluidToken token,
        uint8 permissions,
        int96 flowRateAllowance
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlowOperatorPermissions,
                (
                    token,
                    flowOperator,
                    permissions,
                    flowRateAllowance,
                    new bytes(0)
                )
            ),
            new bytes(0)
        );
    }

    /**
     * @dev Updates the permissions of a flow operator with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     * @param permissions The number of the permissions: create = 1; update = 2; delete = 4;
     * To give multiple permissions, sum the above. create_delete = 5; create_update_delete = 7; etc
     * @param flowRateAllowance The allowance for flow creation. Decremented as flowRate increases
     */
    function updateFlowOperatorPermissionsWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address flowOperator,
        ISuperfluidToken token,
        uint8 permissions,
        int96 flowRateAllowance
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.updateFlowOperatorPermissions,
                (
                    token,
                    flowOperator,
                    permissions,
                    flowRateAllowance,
                    new bytes(0)
                )
            ),
            new bytes(0),
            ctx
        );
    }

    /**
     * @dev Grants full, unlimited permission to a flow operator
     * @param cfaLibrary The cfaLibrary storage variable
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     */
    function authorizeFlowOperatorWithFullControl(
        InitData storage cfaLibrary,
        address flowOperator,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.authorizeFlowOperatorWithFullControl,
                (
                    token,
                    flowOperator,
                    new bytes(0)
                )
            ),
            new bytes(0)
        );
    }

    /**
     * @dev Grants full, unlimited permission to a flow operator with context
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     */
    function authorizeFlowOperatorWithFullControlWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address flowOperator,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.authorizeFlowOperatorWithFullControl,
                (
                    token,
                    flowOperator,
                    new bytes(0)
                )
            ),
            new bytes(0),
            ctx
        );
    }

    /**
     * @dev Revokes all permissions from a flow operator
     * @param cfaLibrary The cfaLibrary storage variable
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     */
    function revokeFlowOperatorWithFullControl(
        InitData storage cfaLibrary,
        address flowOperator,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        return cfaLibrary.host.callAgreement(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.revokeFlowOperatorWithFullControl,
                (
                    token,
                    flowOperator,
                    new bytes(0)
                )
            ),
            new bytes(0)
        );
    }

    /**
     * @dev Revokes all permissions from a flow operator
     * @param cfaLibrary The cfaLibrary storage variable
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param flowOperator The operator that can create/update/delete flows
     * @param token The token of flows handled by the operator
     */
    function revokeFlowOperatorWithFullControlWithCtx(
        InitData storage cfaLibrary,
        bytes memory ctx,
        address flowOperator,
        ISuperfluidToken token
    ) internal returns (bytes memory newCtx) {
        (newCtx, ) = cfaLibrary.host.callAgreementWithContext(
            cfaLibrary.cfa,
            abi.encodeCall(
                cfaLibrary.cfa.revokeFlowOperatorWithFullControl,
                (
                    token,
                    flowOperator,
                    new bytes(0)
                )
            ),
            new bytes(0),
            ctx
        );
    }
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperAgreement } from "../superfluid/ISuperAgreement.sol";
import { ISuperfluidToken } from "../superfluid/ISuperfluidToken.sol";


/**
 * @title Constant Flow Agreement interface
 * @author Superfluid
 */
abstract contract IConstantFlowAgreementV1 is ISuperAgreement {

    /// @dev ISuperAgreement.agreementType implementation
    function agreementType() external override pure returns (bytes32) {
        return keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    /**
     * @notice Get the maximum flow rate allowed with the deposit
     * @dev The deposit is clipped and rounded down
     * @param deposit Deposit amount used for creating the flow
     * @return flowRate The maximum flow rate
     */
    function getMaximumFlowRateFromDeposit(
        ISuperfluidToken token,
        uint256 deposit)
        external view virtual
        returns (int96 flowRate);

    /**
     * @notice Get the deposit required for creating the flow
     * @dev Calculates the deposit based on the liquidationPeriod and flowRate
     * @param flowRate Flow rate to be tested
     * @return deposit The deposit amount based on flowRate and liquidationPeriod
     * @custom:note 
     * - if calculated deposit (flowRate * liquidationPeriod) is less
     *   than the minimum deposit, we use the minimum deposit otherwise
     *   we use the calculated deposit
     */
    function getDepositRequiredForFlowRate(
        ISuperfluidToken token,
        int96 flowRate)
        external view virtual
        returns (uint256 deposit);

    /**
     * @dev Returns whether it is the patrician period based on host.getNow()
     * @param account The account we are interested in
     * @return isCurrentlyPatricianPeriod Whether it is currently the patrician period dictated by governance
     * @return timestamp The value of host.getNow()
     */
    function isPatricianPeriodNow(
        ISuperfluidToken token,
        address account)
        public view virtual
        returns (bool isCurrentlyPatricianPeriod, uint256 timestamp);

    /**
     * @dev Returns whether it is the patrician period based on timestamp
     * @param account The account we are interested in
     * @param timestamp The timestamp we are interested in observing the result of isPatricianPeriod
     * @return bool Whether it is currently the patrician period dictated by governance
     */
    function isPatricianPeriod(
        ISuperfluidToken token,
        address account,
        uint256 timestamp
    )
        public view virtual
        returns (bool);

    /**
     * @dev msgSender from `ctx` updates permissions for the `flowOperator` with `flowRateAllowance`
     * @param token Super token address
     * @param flowOperator The permission grantee address
     * @param permissions A bitmask representation of the granted permissions
     * @param flowRateAllowance The flow rate allowance the `flowOperator` is granted (only goes down)
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     */
    function updateFlowOperatorPermissions(
        ISuperfluidToken token,
        address flowOperator,
        uint8 permissions,
        int96 flowRateAllowance,
        bytes calldata ctx
    ) 
        external virtual
        returns(bytes memory newCtx);

    /**
     * @dev msgSender from `ctx` grants `flowOperator` all permissions with flowRateAllowance as type(int96).max
     * @param token Super token address
     * @param flowOperator The permission grantee address
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     */
    function authorizeFlowOperatorWithFullControl(
        ISuperfluidToken token,
        address flowOperator,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

     /**
     * @notice msgSender from `ctx` revokes `flowOperator` create/update/delete permissions
     * @dev `permissions` and `flowRateAllowance` will both be set to 0
     * @param token Super token address
     * @param flowOperator The permission grantee address
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     */
    function revokeFlowOperatorWithFullControl(
        ISuperfluidToken token,
        address flowOperator,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
     * @notice Get the permissions of a flow operator between `sender` and `flowOperator` for `token`
     * @param token Super token address
     * @param sender The permission granter address
     * @param flowOperator The permission grantee address
     * @return flowOperatorId The keccak256 hash of encoded string "flowOperator", sender and flowOperator
     * @return permissions A bitmask representation of the granted permissions
     * @return flowRateAllowance The flow rate allowance the `flowOperator` is granted (only goes down)
     */
    function getFlowOperatorData(
       ISuperfluidToken token,
       address sender,
       address flowOperator
    )
        public view virtual
        returns (
            bytes32 flowOperatorId,
            uint8 permissions,
            int96 flowRateAllowance
        );

    /**
     * @notice Get flow operator using flowOperatorId
     * @param token Super token address
     * @param flowOperatorId The keccak256 hash of encoded string "flowOperator", sender and flowOperator
     * @return permissions A bitmask representation of the granted permissions
     * @return flowRateAllowance The flow rate allowance the `flowOperator` is granted (only goes down)
     */
    function getFlowOperatorDataByID(
       ISuperfluidToken token,
       bytes32 flowOperatorId
    )
        external view virtual
        returns (
            uint8 permissions,
            int96 flowRateAllowance
        );

    /**
     * @notice Create a flow betwen ctx.msgSender and receiver
     * @dev flowId (agreementId) is the keccak256 hash of encoded sender and receiver
     * @param token Super token address
     * @param receiver Flow receiver address
     * @param flowRate New flow rate in amount per second
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     *
     * @custom:callbacks 
     * - AgreementCreated
     *   - agreementId - can be used in getFlowByID
     *   - agreementData - abi.encode(address flowSender, address flowReceiver)
     *
     * @custom:note 
     * - A deposit is taken as safety margin for the solvency agents
     * - A extra gas fee may be taken to pay for solvency agent liquidations
     */
    function createFlow(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
    * @notice Create a flow between sender and receiver
    * @dev A flow created by an approved flow operator (see above for details on callbacks)
    * @param token Super token address
    * @param sender Flow sender address (has granted permissions)
    * @param receiver Flow receiver address
    * @param flowRate New flow rate in amount per second
    * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
    */
    function createFlowByOperator(
        ISuperfluidToken token,
        address sender,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
     * @notice Update the flow rate between ctx.msgSender and receiver
     * @dev flowId (agreementId) is the keccak256 hash of encoded sender and receiver
     * @param token Super token address
     * @param receiver Flow receiver address
     * @param flowRate New flow rate in amount per second
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     *
     * @custom:callbacks 
     * - AgreementUpdated
     *   - agreementId - can be used in getFlowByID
     *   - agreementData - abi.encode(address flowSender, address flowReceiver)
     *
     * @custom:note 
     * - Only the flow sender may update the flow rate
     * - Even if the flow rate is zero, the flow is not deleted
     * from the system
     * - Deposit amount will be adjusted accordingly
     * - No new gas fee is charged
     */
    function updateFlow(
        ISuperfluidToken token,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
    * @notice Update a flow between sender and receiver
    * @dev A flow updated by an approved flow operator (see above for details on callbacks)
    * @param token Super token address
    * @param sender Flow sender address (has granted permissions)
    * @param receiver Flow receiver address
    * @param flowRate New flow rate in amount per second
    * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
    */
    function updateFlowByOperator(
        ISuperfluidToken token,
        address sender,
        address receiver,
        int96 flowRate,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
     * @dev Get the flow data between `sender` and `receiver` of `token`
     * @param token Super token address
     * @param sender Flow receiver
     * @param receiver Flow sender
     * @return timestamp Timestamp of when the flow is updated
     * @return flowRate The flow rate
     * @return deposit The amount of deposit the flow
     * @return owedDeposit The amount of owed deposit of the flow
     */
    function getFlow(
        ISuperfluidToken token,
        address sender,
        address receiver
    )
        external view virtual
        returns (
            uint256 timestamp,
            int96 flowRate,
            uint256 deposit,
            uint256 owedDeposit
        );

    /**
     * @notice Get flow data using agreementId
     * @dev flowId (agreementId) is the keccak256 hash of encoded sender and receiver
     * @param token Super token address
     * @param agreementId The agreement ID
     * @return timestamp Timestamp of when the flow is updated
     * @return flowRate The flow rate
     * @return deposit The deposit amount of the flow
     * @return owedDeposit The owed deposit amount of the flow
     */
    function getFlowByID(
       ISuperfluidToken token,
       bytes32 agreementId
    )
        external view virtual
        returns (
            uint256 timestamp,
            int96 flowRate,
            uint256 deposit,
            uint256 owedDeposit
        );

    /**
     * @dev Get the aggregated flow info of the account
     * @param token Super token address
     * @param account Account for the query
     * @return timestamp Timestamp of when a flow was last updated for account
     * @return flowRate The net flow rate of token for account
     * @return deposit The sum of all deposits for account's flows
     * @return owedDeposit The sum of all owed deposits for account's flows
     */
    function getAccountFlowInfo(
        ISuperfluidToken token,
        address account
    )
        external view virtual
        returns (
            uint256 timestamp,
            int96 flowRate,
            uint256 deposit,
            uint256 owedDeposit);

    /**
     * @dev Get the net flow rate of the account
     * @param token Super token address
     * @param account Account for the query
     * @return flowRate Net flow rate
     */
    function getNetFlow(
        ISuperfluidToken token,
        address account
    )
        external view virtual
        returns (int96 flowRate);

    /**
     * @notice Delete the flow between sender and receiver
     * @dev flowId (agreementId) is the keccak256 hash of encoded sender and receiver
     * @param token Super token address
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver Flow receiver address
     *
     * @custom:callbacks 
     * - AgreementTerminated
     *   - agreementId - can be used in getFlowByID
     *   - agreementData - abi.encode(address flowSender, address flowReceiver)
     *
     * @custom:note 
     * - Both flow sender and receiver may delete the flow
     * - If Sender account is insolvent or in critical state, a solvency agent may
     *   also terminate the agreement
     * - Gas fee may be returned to the sender
     */
    function deleteFlow(
        ISuperfluidToken token,
        address sender,
        address receiver,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);

    /**
     * @notice Delete the flow between sender and receiver
     * @dev A flow deleted by an approved flow operator (see above for details on callbacks)
     * @param token Super token address
     * @param ctx Context bytes (see ISuperfluid.sol for Context struct)
     * @param receiver Flow receiver address
     */
    function deleteFlowByOperator(
        ISuperfluidToken token,
        address sender,
        address receiver,
        bytes calldata ctx
    )
        external virtual
        returns(bytes memory newCtx);
     
    /**
     * @dev Flow operator updated event
     * @param token Super token address
     * @param sender Flow sender address
     * @param flowOperator Flow operator address
     * @param permissions Octo bitmask representation of permissions
     * @param flowRateAllowance The flow rate allowance the `flowOperator` is granted (only goes down)
     */
    event FlowOperatorUpdated(
        ISuperfluidToken indexed token,
        address indexed sender,
        address indexed flowOperator,
        uint8 permissions,
        int96 flowRateAllowance
    );

    /**
     * @dev Flow updated event
     * @param token Super token address
     * @param sender Flow sender address
     * @param receiver Flow recipient address
     * @param flowRate Flow rate in amount per second for this flow
     * @param totalSenderFlowRate Total flow rate in amount per second for the sender
     * @param totalReceiverFlowRate Total flow rate in amount per second for the receiver
     * @param userData The user provided data
     *
     */
    event FlowUpdated(
        ISuperfluidToken indexed token,
        address indexed sender,
        address indexed receiver,
        int96 flowRate,
        int256 totalSenderFlowRate,
        int256 totalReceiverFlowRate,
        bytes userData
    );

    /**
     * @dev Flow updated extension event
     * @param flowOperator Flow operator address - the Context.msgSender
     * @param deposit The deposit amount for the stream
     */
    event FlowUpdatedExtension(
        address indexed flowOperator,
        uint256 deposit
    );
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

/**
 * @title Super app definitions library
 * @author Superfluid
 */
library SuperAppDefinitions {

    /**************************************************************************
    / App manifest config word
    /**************************************************************************/

    /*
     * App level is a way to allow the app to whitelist what other app it can
     * interact with (aka. composite app feature).
     *
     * For more details, refer to the technical paper of superfluid protocol.
     */
    uint256 constant internal APP_LEVEL_MASK = 0xFF;

    // The app is at the final level, hence it doesn't want to interact with any other app
    uint256 constant internal APP_LEVEL_FINAL = 1 << 0;

    // The app is at the second level, it may interact with other final level apps if whitelisted
    uint256 constant internal APP_LEVEL_SECOND = 1 << 1;

    function getAppLevel(uint256 configWord) internal pure returns (uint8) {
        return uint8(configWord & APP_LEVEL_MASK);
    }

    uint256 constant internal APP_JAIL_BIT = 1 << 15;
    function isAppJailed(uint256 configWord) internal pure returns (bool) {
        return (configWord & SuperAppDefinitions.APP_JAIL_BIT) > 0;
    }

    /**************************************************************************
    / Callback implementation bit masks
    /**************************************************************************/
    uint256 constant internal AGREEMENT_CALLBACK_NOOP_BITMASKS = 0xFF << 32;
    uint256 constant internal BEFORE_AGREEMENT_CREATED_NOOP = 1 << (32 + 0);
    uint256 constant internal AFTER_AGREEMENT_CREATED_NOOP = 1 << (32 + 1);
    uint256 constant internal BEFORE_AGREEMENT_UPDATED_NOOP = 1 << (32 + 2);
    uint256 constant internal AFTER_AGREEMENT_UPDATED_NOOP = 1 << (32 + 3);
    uint256 constant internal BEFORE_AGREEMENT_TERMINATED_NOOP = 1 << (32 + 4);
    uint256 constant internal AFTER_AGREEMENT_TERMINATED_NOOP = 1 << (32 + 5);

    /**************************************************************************
    / App Jail Reasons
    /**************************************************************************/

    uint256 constant internal APP_RULE_REGISTRATION_ONLY_IN_CONSTRUCTOR = 1;
    uint256 constant internal APP_RULE_NO_REGISTRATION_FOR_EOA = 2;
    uint256 constant internal APP_RULE_NO_REVERT_ON_TERMINATION_CALLBACK = 10;
    uint256 constant internal APP_RULE_NO_CRITICAL_SENDER_ACCOUNT = 11;
    uint256 constant internal APP_RULE_NO_CRITICAL_RECEIVER_ACCOUNT = 12;
    uint256 constant internal APP_RULE_CTX_IS_READONLY = 20;
    uint256 constant internal APP_RULE_CTX_IS_NOT_CLEAN = 21;
    uint256 constant internal APP_RULE_CTX_IS_MALFORMATED = 22;
    uint256 constant internal APP_RULE_COMPOSITE_APP_IS_NOT_WHITELISTED = 30;
    uint256 constant internal APP_RULE_COMPOSITE_APP_IS_JAILED = 31;
    uint256 constant internal APP_RULE_MAX_APP_LEVEL_REACHED = 40;

    // Validate configWord cleaness for future compatibility, or else may introduce undefined future behavior
    function isConfigWordClean(uint256 configWord) internal pure returns (bool) {
        return (configWord & ~(APP_LEVEL_MASK | APP_JAIL_BIT | AGREEMENT_CALLBACK_NOOP_BITMASKS)) == uint256(0);
    }
}

/**
 * @title Context definitions library
 * @author Superfluid
 */
library ContextDefinitions {

    /**************************************************************************
    / Call info
    /**************************************************************************/

    // app level
    uint256 constant internal CALL_INFO_APP_LEVEL_MASK = 0xFF;

    // call type
    uint256 constant internal CALL_INFO_CALL_TYPE_SHIFT = 32;
    uint256 constant internal CALL_INFO_CALL_TYPE_MASK = 0xF << CALL_INFO_CALL_TYPE_SHIFT;
    uint8 constant internal CALL_INFO_CALL_TYPE_AGREEMENT = 1;
    uint8 constant internal CALL_INFO_CALL_TYPE_APP_ACTION = 2;
    uint8 constant internal CALL_INFO_CALL_TYPE_APP_CALLBACK = 3;

    function decodeCallInfo(uint256 callInfo)
        internal pure
        returns (uint8 appLevel, uint8 callType)
    {
        appLevel = uint8(callInfo & CALL_INFO_APP_LEVEL_MASK);
        callType = uint8((callInfo & CALL_INFO_CALL_TYPE_MASK) >> CALL_INFO_CALL_TYPE_SHIFT);
    }

    function encodeCallInfo(uint8 appLevel, uint8 callType)
        internal pure
        returns (uint256 callInfo)
    {
        return uint256(appLevel) | (uint256(callType) << CALL_INFO_CALL_TYPE_SHIFT);
    }

}

/**
 * @title Flow Operator definitions library
  * @author Superfluid
 */
 library FlowOperatorDefinitions {
    uint8 constant internal AUTHORIZE_FLOW_OPERATOR_CREATE = uint8(1) << 0;
    uint8 constant internal AUTHORIZE_FLOW_OPERATOR_UPDATE = uint8(1) << 1;
    uint8 constant internal AUTHORIZE_FLOW_OPERATOR_DELETE = uint8(1) << 2;
    uint8 constant internal AUTHORIZE_FULL_CONTROL =
        AUTHORIZE_FLOW_OPERATOR_CREATE | AUTHORIZE_FLOW_OPERATOR_UPDATE | AUTHORIZE_FLOW_OPERATOR_DELETE;
    uint8 constant internal REVOKE_FLOW_OPERATOR_CREATE = ~(uint8(1) << 0);
    uint8 constant internal REVOKE_FLOW_OPERATOR_UPDATE = ~(uint8(1) << 1);
    uint8 constant internal REVOKE_FLOW_OPERATOR_DELETE = ~(uint8(1) << 2);

    function isPermissionsClean(uint8 permissions) internal pure returns (bool) {
        return (
            permissions & ~(AUTHORIZE_FLOW_OPERATOR_CREATE
                | AUTHORIZE_FLOW_OPERATOR_UPDATE
                | AUTHORIZE_FLOW_OPERATOR_DELETE)
            ) == uint8(0);
    }
 }

/**
 * @title Batch operation library
 * @author Superfluid
 */
library BatchOperation {
    /**
     * @dev ERC20.approve batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationApprove(
     *     abi.decode(data, (address spender, uint256 amount))
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_APPROVE = 1;
    /**
     * @dev ERC20.transferFrom batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationTransferFrom(
     *     abi.decode(data, (address sender, address recipient, uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_ERC20_TRANSFER_FROM = 2;
    /**
     * @dev SuperToken.upgrade batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationUpgrade(
     *     abi.decode(data, (uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_UPGRADE = 1 + 100;
    /**
     * @dev SuperToken.downgrade batch operation type
     *
     * Call spec:
     * ISuperToken(target).operationDowngrade(
     *     abi.decode(data, (uint256 amount)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERTOKEN_DOWNGRADE = 2 + 100;
    /**
     * @dev Superfluid.callAgreement batch operation type
     *
     * Call spec:
     * callAgreement(
     *     ISuperAgreement(target)),
     *     abi.decode(data, (bytes calldata, bytes userdata)
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERFLUID_CALL_AGREEMENT = 1 + 200;
    /**
     * @dev Superfluid.callAppAction batch operation type
     *
     * Call spec:
     * callAppAction(
     *     ISuperApp(target)),
     *     data
     * )
     */
    uint32 constant internal OPERATION_TYPE_SUPERFLUID_CALL_APP_ACTION = 2 + 200;
}

/**
 * @title Superfluid governance configs library
 * @author Superfluid
 */
library SuperfluidGovernanceConfigs {

    bytes32 constant internal SUPERFLUID_REWARD_ADDRESS_CONFIG_KEY =
        keccak256("org.superfluid-finance.superfluid.rewardAddress");
    bytes32 constant internal CFAV1_PPP_CONFIG_KEY =
        keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1.PPPConfiguration");
    bytes32 constant internal SUPERTOKEN_MINIMUM_DEPOSIT_KEY = 
        keccak256("org.superfluid-finance.superfluid.superTokenMinimumDeposit");

    function getTrustedForwarderConfigKey(address forwarder) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            "org.superfluid-finance.superfluid.trustedForwarder",
            forwarder));
    }

    function getAppRegistrationConfigKey(address deployer, string memory registrationKey) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            "org.superfluid-finance.superfluid.appWhiteListing.registrationKey",
            deployer,
            registrationKey));
    }

    function getAppFactoryConfigKey(address factory) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            "org.superfluid-finance.superfluid.appWhiteListing.factory",
            factory));
    }

    function decodePPPConfig(uint256 pppConfig) internal pure returns (uint256 liquidationPeriod, uint256 patricianPeriod) {
        liquidationPeriod = (pppConfig >> 32) & type(uint32).max;
        patricianPeriod = pppConfig & type(uint32).max;
    }
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperfluidToken } from "./ISuperfluidToken.sol";

/**
 * @title Super agreement interface
 * @author Superfluid
 */
interface ISuperAgreement {

    /**
     * @dev Get the type of the agreement class
     */
    function agreementType() external view returns (bytes32);

    /**
     * @dev Calculate the real-time balance for the account of this agreement class
     * @param account Account the state belongs to
     * @param time Time used for the calculation
     * @return dynamicBalance Dynamic balance portion of real-time balance of this agreement
     * @return deposit Account deposit amount of this agreement
     * @return owedDeposit Account owed deposit amount of this agreement
     */
    function realtimeBalanceOf(
        ISuperfluidToken token,
        address account,
        uint256 time
    )
        external
        view
        returns (
            int256 dynamicBalance,
            uint256 deposit,
            uint256 owedDeposit
        );

}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperToken } from "./ISuperToken.sol";

/**
 * @title SuperApp interface
 * @author Superfluid
 * @dev Be aware of the app being jailed, when the word permitted is used.
 */
interface ISuperApp {

    /**
     * @dev Callback before a new agreement is created.
     * @param superToken The super token used for the agreement.
     * @param agreementClass The agreement class address.
     * @param agreementId The agreementId
     * @param agreementData The agreement data (non-compressed)
     * @param ctx The context data.
     * @return cbdata A free format in memory data the app can use to pass
     *          arbitary information to the after-hook callback.
     *
     * @custom:note 
     * - It will be invoked with `staticcall`, no state changes are permitted.
     * - Only revert with a "reason" is permitted.
     */
    function beforeAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata ctx
    )
        external
        view
        returns (bytes memory cbdata);

    /**
     * @dev Callback after a new agreement is created.
     * @param superToken The super token used for the agreement.
     * @param agreementClass The agreement class address.
     * @param agreementId The agreementId
     * @param agreementData The agreement data (non-compressed)
     * @param cbdata The data returned from the before-hook callback.
     * @param ctx The context data.
     * @return newCtx The current context of the transaction.
     *
     * @custom:note 
     * - State changes is permitted.
     * - Only revert with a "reason" is permitted.
     */
    function afterAgreementCreated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external
        returns (bytes memory newCtx);

    /**
     * @dev Callback before a new agreement is updated.
     * @param superToken The super token used for the agreement.
     * @param agreementClass The agreement class address.
     * @param agreementId The agreementId
     * @param agreementData The agreement data (non-compressed)
     * @param ctx The context data.
     * @return cbdata A free format in memory data the app can use to pass
     *          arbitary information to the after-hook callback.
     *
     * @custom:note 
     * - It will be invoked with `staticcall`, no state changes are permitted.
     * - Only revert with a "reason" is permitted.
     */
    function beforeAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata ctx
    )
        external
        view
        returns (bytes memory cbdata);


    /**
    * @dev Callback after a new agreement is updated.
    * @param superToken The super token used for the agreement.
    * @param agreementClass The agreement class address.
    * @param agreementId The agreementId
    * @param agreementData The agreement data (non-compressed)
    * @param cbdata The data returned from the before-hook callback.
    * @param ctx The context data.
    * @return newCtx The current context of the transaction.
    *
    * @custom:note 
    * - State changes is permitted.
    * - Only revert with a "reason" is permitted.
    */
    function afterAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external
        returns (bytes memory newCtx);

    /**
    * @dev Callback before a new agreement is terminated.
    * @param superToken The super token used for the agreement.
    * @param agreementClass The agreement class address.
    * @param agreementId The agreementId
    * @param agreementData The agreement data (non-compressed)
    * @param ctx The context data.
    * @return cbdata A free format in memory data the app can use to pass arbitary information to the after-hook callback.
    *
    * @custom:note 
    * - It will be invoked with `staticcall`, no state changes are permitted.
    * - Revert is not permitted.
    */
    function beforeAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata ctx
    )
        external
        view
        returns (bytes memory cbdata);

    /**
    * @dev Callback after a new agreement is terminated.
    * @param superToken The super token used for the agreement.
    * @param agreementClass The agreement class address.
    * @param agreementId The agreementId
    * @param agreementData The agreement data (non-compressed)
    * @param cbdata The data returned from the before-hook callback.
    * @param ctx The context data.
    * @return newCtx The current context of the transaction.
    *
    * @custom:note 
    * - State changes is permitted.
    * - Revert is not permitted.
    */
    function afterAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external
        returns (bytes memory newCtx);
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.2;

import { ISuperfluidGovernance } from "./ISuperfluidGovernance.sol";
import { ISuperfluidToken } from "./ISuperfluidToken.sol";
import { ISuperToken } from "./ISuperToken.sol";
import { ISuperTokenFactory } from "./ISuperTokenFactory.sol";
import { ISuperAgreement } from "./ISuperAgreement.sol";
import { ISuperApp } from "./ISuperApp.sol";
import {
    BatchOperation,
    ContextDefinitions,
    FlowOperatorDefinitions,
    SuperAppDefinitions,
    SuperfluidGovernanceConfigs
} from "./Definitions.sol";
import { TokenInfo } from "../tokens/TokenInfo.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC777 } from "@openzeppelin/contracts/token/ERC777/IERC777.sol";

/**
 * @title Host interface
 * @author Superfluid
 * @notice This is the central contract of the system where super agreement, super app
 * and super token features are connected.
 *
 * The Superfluid host contract is also the entry point for the protocol users,
 * where batch call and meta transaction are provided for UX improvements.
 *
 */
interface ISuperfluid {

    /**************************************************************************
     * Time
     *
     * > The Oracle: You have the sight now, Neo. You are looking at the world without time.
     * > Neo: Then why can't I see what happens to her?
     * > The Oracle: We can never see past the choices we don't understand.
     * >       - The Oracle and Neo conversing about the future of Trinity and the effects of Neo's choices
     *************************************************************************/

    function getNow() external view returns (uint256);

    /**************************************************************************
     * Governance
     *************************************************************************/

    /**
     * @dev Get the current governance address of the Superfluid host
     */
    function getGovernance() external view returns(ISuperfluidGovernance governance);

    /**
     * @dev Replace the current governance with a new one
     */
    function replaceGovernance(ISuperfluidGovernance newGov) external;
    /**
     * @dev Governance replaced event
     * @param oldGov Address of the old governance contract
     * @param newGov Address of the new governance contract
     */
    event GovernanceReplaced(ISuperfluidGovernance oldGov, ISuperfluidGovernance newGov);

    /**************************************************************************
     * Agreement Whitelisting
     *************************************************************************/

    /**
     * @dev Register a new agreement class to the system
     * @param agreementClassLogic Initial agreement class code
     *
     * @custom:modifiers 
     * - onlyGovernance
     */
    function registerAgreementClass(ISuperAgreement agreementClassLogic) external;
    /**
     * @notice Agreement class registered event
     * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
     * @param agreementType The agreement type registered
     * @param code Address of the new agreement
     */
    event AgreementClassRegistered(bytes32 agreementType, address code);

    /**
    * @dev Update code of an agreement class
    * @param agreementClassLogic New code for the agreement class
    *
    * @custom:modifiers 
    *  - onlyGovernance
    */
    function updateAgreementClass(ISuperAgreement agreementClassLogic) external;
    /**
     * @notice Agreement class updated event
     * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
     * @param agreementType The agreement type updated
     * @param code Address of the new agreement
     */
    event AgreementClassUpdated(bytes32 agreementType, address code);

    /**
    * @notice Check if the agreement type is whitelisted
    * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
    */
    function isAgreementTypeListed(bytes32 agreementType) external view returns(bool yes);

    /**
    * @dev Check if the agreement class is whitelisted
    */
    function isAgreementClassListed(ISuperAgreement agreementClass) external view returns(bool yes);

    /**
    * @notice Get agreement class
    * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
    */
    function getAgreementClass(bytes32 agreementType) external view returns(ISuperAgreement agreementClass);

    /**
    * @dev Map list of the agreement classes using a bitmap
    * @param bitmap Agreement class bitmap
    */
    function mapAgreementClasses(uint256 bitmap)
        external view
        returns (ISuperAgreement[] memory agreementClasses);

    /**
    * @notice Create a new bitmask by adding a agreement class to it
    * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
    * @param bitmap Agreement class bitmap
    */
    function addToAgreementClassesBitmap(uint256 bitmap, bytes32 agreementType)
        external view
        returns (uint256 newBitmap);

    /**
    * @notice Create a new bitmask by removing a agreement class from it
    * @dev agreementType is the keccak256 hash of: "org.superfluid-finance.agreements.<AGREEMENT_NAME>.<VERSION>"
    * @param bitmap Agreement class bitmap
    */
    function removeFromAgreementClassesBitmap(uint256 bitmap, bytes32 agreementType)
        external view
        returns (uint256 newBitmap);

    /**************************************************************************
    * Super Token Factory
    **************************************************************************/

    /**
     * @dev Get the super token factory
     * @return factory The factory
     */
    function getSuperTokenFactory() external view returns (ISuperTokenFactory factory);

    /**
     * @dev Get the super token factory logic (applicable to upgradable deployment)
     * @return logic The factory logic
     */
    function getSuperTokenFactoryLogic() external view returns (address logic);

    /**
     * @dev Update super token factory
     * @param newFactory New factory logic
     */
    function updateSuperTokenFactory(ISuperTokenFactory newFactory) external;
    /**
     * @dev SuperToken factory updated event
     * @param newFactory Address of the new factory
     */
    event SuperTokenFactoryUpdated(ISuperTokenFactory newFactory);

    /**
     * @notice Update the super token logic to the latest
     * @dev Refer to ISuperTokenFactory.Upgradability for expected behaviours
     */
    function updateSuperTokenLogic(ISuperToken token) external;
    /**
     * @dev SuperToken logic updated event
     * @param code Address of the new SuperToken logic
     */
    event SuperTokenLogicUpdated(ISuperToken indexed token, address code);

    /**************************************************************************
     * App Registry
     *************************************************************************/

    /**
     * @dev Message sender (must be a contract) declares itself as a super app.
     * @custom:deprecated you should use `registerAppWithKey` or `registerAppByFactory` instead,
     * because app registration is currently governance permissioned on mainnets.
     * @param configWord The super app manifest configuration, flags are defined in
     * `SuperAppDefinitions`
     */
    function registerApp(uint256 configWord) external;
    /**
     * @dev App registered event
     * @param app Address of jailed app
     */
    event AppRegistered(ISuperApp indexed app);

    /**
     * @dev Message sender declares itself as a super app.
     * @param configWord The super app manifest configuration, flags are defined in `SuperAppDefinitions`
     * @param registrationKey The registration key issued by the governance, needed to register on a mainnet.
     * @notice See https://github.com/superfluid-finance/protocol-monorepo/wiki/Super-App-White-listing-Guide
     * On testnets or in dev environment, a placeholder (e.g. empty string) can be used.
     * While the message sender must be the super app itself, the transaction sender (tx.origin)
     * must be the deployer account the registration key was issued for.
     */
    function registerAppWithKey(uint256 configWord, string calldata registrationKey) external;

    /**
     * @dev Message sender (must be a contract) declares app as a super app
     * @param configWord The super app manifest configuration, flags are defined in `SuperAppDefinitions`
     * @notice On mainnet deployments, only factory contracts pre-authorized by governance can use this.
     * See https://github.com/superfluid-finance/protocol-monorepo/wiki/Super-App-White-listing-Guide
     */
    function registerAppByFactory(ISuperApp app, uint256 configWord) external;

    /**
     * @dev Query if the app is registered
     * @param app Super app address
     */
    function isApp(ISuperApp app) external view returns(bool);

    /**
     * @dev Query app level
     * @param app Super app address
     */
    function getAppLevel(ISuperApp app) external view returns(uint8 appLevel);

    /**
     * @dev Get the manifest of the super app
     * @param app Super app address
     */
    function getAppManifest(
        ISuperApp app
    )
        external view
        returns (
            bool isSuperApp,
            bool isJailed,
            uint256 noopMask
        );

    /**
     * @dev Query if the app has been jailed
     * @param app Super app address
     */
    function isAppJailed(ISuperApp app) external view returns (bool isJail);

    /**
     * @dev Whitelist the target app for app composition for the source app (msg.sender)
     * @param targetApp The target super app address
     */
    function allowCompositeApp(ISuperApp targetApp) external;

    /**
     * @dev Query if source app is allowed to call the target app as downstream app
     * @param app Super app address
     * @param targetApp The target super app address
     */
    function isCompositeAppAllowed(
        ISuperApp app,
        ISuperApp targetApp
    )
        external view
        returns (bool isAppAllowed);

    /**************************************************************************
     * Agreement Framework
     *
     * Agreements use these function to trigger super app callbacks, updates
     * app allowance and charge gas fees.
     *
     * These functions can only be called by registered agreements.
     *************************************************************************/

    /**
     * @dev (For agreements) StaticCall the app before callback
     * @param  app               The super app.
     * @param  callData          The call data sending to the super app.
     * @param  isTermination     Is it a termination callback?
     * @param  ctx               Current ctx, it will be validated.
     * @return cbdata            Data returned from the callback.
     */
    function callAppBeforeCallback(
        ISuperApp app,
        bytes calldata callData,
        bool isTermination,
        bytes calldata ctx
    )
        external
        // onlyAgreement
        // assertValidCtx(ctx)
        returns(bytes memory cbdata);

    /**
     * @dev (For agreements) Call the app after callback
     * @param  app               The super app.
     * @param  callData          The call data sending to the super app.
     * @param  isTermination     Is it a termination callback?
     * @param  ctx               Current ctx, it will be validated.
     * @return newCtx            The current context of the transaction.
     */
    function callAppAfterCallback(
        ISuperApp app,
        bytes calldata callData,
        bool isTermination,
        bytes calldata ctx
    )
        external
        // onlyAgreement
        // assertValidCtx(ctx)
        returns(bytes memory newCtx);

    /**
     * @dev (For agreements) Create a new callback stack
     * @param  ctx                     The current ctx, it will be validated.
     * @param  app                     The super app.
     * @param  appAllowanceGranted     App allowance granted so far.
     * @param  appAllowanceUsed        App allowance used so far.
     * @return newCtx                  The current context of the transaction.
     */
    function appCallbackPush(
        bytes calldata ctx,
        ISuperApp app,
        uint256 appAllowanceGranted,
        int256 appAllowanceUsed,
        ISuperfluidToken appAllowanceToken
    )
        external
        // onlyAgreement
        // assertValidCtx(ctx)
        returns (bytes memory newCtx);

    /**
     * @dev (For agreements) Pop from the current app callback stack
     * @param  ctx                     The ctx that was pushed before the callback stack.
     * @param  appAllowanceUsedDelta   App allowance used by the app.
     * @return newCtx                  The current context of the transaction.
     *
     * @custom:security 
     * - Here we cannot do assertValidCtx(ctx), since we do not really save the stack in memory.
     * - Hence there is still implicit trust that the agreement handles the callback push/pop pair correctly.
     */
    function appCallbackPop(
        bytes calldata ctx,
        int256 appAllowanceUsedDelta
    )
        external
        // onlyAgreement
        returns (bytes memory newCtx);

    /**
     * @dev (For agreements) Use app allowance.
     * @param  ctx                      The current ctx, it will be validated.
     * @param  appAllowanceWantedMore   See app allowance for more details.
     * @param  appAllowanceUsedDelta    See app allowance for more details.
     * @return newCtx                   The current context of the transaction.
     */
    function ctxUseAllowance(
        bytes calldata ctx,
        uint256 appAllowanceWantedMore,
        int256 appAllowanceUsedDelta
    )
        external
        // onlyAgreement
        // assertValidCtx(ctx)
        returns (bytes memory newCtx);

    /**
     * @dev (For agreements) Jail the app.
     * @param  app                     The super app.
     * @param  reason                  Jail reason code.
     * @return newCtx                  The current context of the transaction.
     */
    function jailApp(
        bytes calldata ctx,
        ISuperApp app,
        uint256 reason
    )
        external
        // onlyAgreement
        // assertValidCtx(ctx)
        returns (bytes memory newCtx);

    /**
     * @dev Jail event for the app
     * @param app Address of jailed app
     * @param reason Reason the app is jailed (see Definitions.sol for the full list)
     */
    event Jail(ISuperApp indexed app, uint256 reason);

    /**************************************************************************
     * Contextless Call Proxies
     *
     * NOTE: For EOAs or non-app contracts, they are the entry points for interacting
     * with agreements or apps.
     *
     * NOTE: The contextual call data should be generated using
     * abi.encodeWithSelector. The context parameter should be set to "0x",
     * an empty bytes array as a placeholder to be replaced by the host
     * contract.
     *************************************************************************/

     /**
      * @dev Call agreement function
      * @param agreementClass The agreement address you are calling
      * @param callData The contextual call data with placeholder ctx
      * @param userData Extra user data being sent to the super app callbacks
      */
     function callAgreement(
         ISuperAgreement agreementClass,
         bytes calldata callData,
         bytes calldata userData
     )
        external
        //cleanCtx
        //isAgreement(agreementClass)
        returns(bytes memory returnedData);

    /**
     * @notice Call app action
     * @dev Main use case is calling app action in a batch call via the host
     * @param callData The contextual call data
     *
     * @custom:note See "Contextless Call Proxies" above for more about contextual call data.
     */
    function callAppAction(
        ISuperApp app,
        bytes calldata callData
    )
        external
        //cleanCtx
        //isAppActive(app)
        //isValidAppAction(callData)
        returns(bytes memory returnedData);

    /**************************************************************************
     * Contextual Call Proxies and Context Utilities
     *
     * For apps, they must use context they receive to interact with
     * agreements or apps.
     *
     * The context changes must be saved and returned by the apps in their
     * callbacks always, any modification to the context will be detected and
     * the violating app will be jailed.
     *************************************************************************/

    /**
     * @dev Context Struct
     *
     * @custom:note on backward compatibility:
     * - Non-dynamic fields are padded to 32bytes and packed
     * - Dynamic fields are referenced through a 32bytes offset to their "parents" field (or root)
     * - The order of the fields hence should not be rearranged in order to be backward compatible:
     *    - non-dynamic fields will be parsed at the same memory location,
     *    - and dynamic fields will simply have a greater offset than it was.
     */
    struct Context {
        //
        // Call context
        //
        // callback level
        uint8 appLevel;
        // type of call
        uint8 callType;
        // the system timestamp
        uint256 timestamp;
        // The intended message sender for the call
        address msgSender;

        //
        // Callback context
        //
        // For callbacks it is used to know which agreement function selector is called
        bytes4 agreementSelector;
        // User provided data for app callbacks
        bytes userData;

        //
        // App context
        //
        // app allowance granted
        uint256 appAllowanceGranted;
        // app allowance wanted by the app callback
        uint256 appAllowanceWanted;
        // app allowance used, allowing negative values over a callback session
        int256 appAllowanceUsed;
        // app address
        address appAddress;
        // app allowance in super token
        ISuperfluidToken appAllowanceToken;
    }

    function callAgreementWithContext(
        ISuperAgreement agreementClass,
        bytes calldata callData,
        bytes calldata userData,
        bytes calldata ctx
    )
        external
        // requireValidCtx(ctx)
        // onlyAgreement(agreementClass)
        returns (bytes memory newCtx, bytes memory returnedData);

    function callAppActionWithContext(
        ISuperApp app,
        bytes calldata callData,
        bytes calldata ctx
    )
        external
        // requireValidCtx(ctx)
        // isAppActive(app)
        returns (bytes memory newCtx);

    function decodeCtx(bytes calldata ctx)
        external pure
        returns (Context memory context);

    function isCtxValid(bytes calldata ctx) external view returns (bool);

    /**************************************************************************
    * Batch call
    **************************************************************************/
    /**
     * @dev Batch operation data
     */
    struct Operation {
        // Operation type. Defined in BatchOperation (Definitions.sol)
        uint32 operationType;
        // Operation target
        address target;
        // Data specific to the operation
        bytes data;
    }

    /**
     * @dev Batch call function
     * @param operations Array of batch operations
     */
    function batchCall(Operation[] memory operations) external;

    /**
     * @dev Batch call function for trusted forwarders (EIP-2771)
     * @param operations Array of batch operations
     */
    function forwardBatchCall(Operation[] memory operations) external;

    /**************************************************************************
     * Function modifiers for access control and parameter validations
     *
     * While they cannot be explicitly stated in function definitions, they are
     * listed in function definition comments instead for clarity.
     *
     * TODO: turning these off because solidity-coverage doesn't like it
     *************************************************************************/

     /* /// @dev The current superfluid context is clean.
     modifier cleanCtx() virtual;

     /// @dev Require the ctx being valid.
     modifier requireValidCtx(bytes memory ctx) virtual;

     /// @dev Assert the ctx being valid.
     modifier assertValidCtx(bytes memory ctx) virtual;

     /// @dev The agreement is a listed agreement.
     modifier isAgreement(ISuperAgreement agreementClass) virtual;

     // onlyGovernance

     /// @dev The msg.sender must be a listed agreement.
     modifier onlyAgreement() virtual;

     /// @dev The app is registered and not jailed.
     modifier isAppActive(ISuperApp app) virtual; */
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperAgreement } from "./ISuperAgreement.sol";
import { ISuperToken } from "./ISuperToken.sol";
import { ISuperfluidToken  } from "./ISuperfluidToken.sol";
import { ISuperfluid } from "./ISuperfluid.sol";


/**
 * @title Superfluid governance interface
 * @author Superfluid
 */
interface ISuperfluidGovernance {

    /**
     * @dev Replace the current governance with a new governance
     */
    function replaceGovernance(
        ISuperfluid host,
        address newGov) external;

    /**
     * @dev Register a new agreement class
     */
    function registerAgreementClass(
        ISuperfluid host,
        address agreementClass) external;

    /**
     * @dev Update logics of the contracts
     *
     * @custom:note 
     * - Because they might have inter-dependencies, it is good to have one single function to update them all
     */
    function updateContracts(
        ISuperfluid host,
        address hostNewLogic,
        address[] calldata agreementClassNewLogics,
        address superTokenFactoryNewLogic
    ) external;

    /**
     * @dev Update supertoken logic contract to the latest that is managed by the super token factory
     */
    function batchUpdateSuperTokenLogic(
        ISuperfluid host,
        ISuperToken[] calldata tokens) external;
    
    /**
     * @dev Set configuration as address value
     */
    function setConfig(
        ISuperfluid host,
        ISuperfluidToken superToken,
        bytes32 key,
        address value
    ) external;
    
    /**
     * @dev Set configuration as uint256 value
     */
    function setConfig(
        ISuperfluid host,
        ISuperfluidToken superToken,
        bytes32 key,
        uint256 value
    ) external;

    /**
     * @dev Clear configuration
     */
    function clearConfig(
        ISuperfluid host,
        ISuperfluidToken superToken,
        bytes32 key
    ) external;

    /**
     * @dev Get configuration as address value
     */
    function getConfigAsAddress(
        ISuperfluid host,
        ISuperfluidToken superToken,
        bytes32 key) external view returns (address value);

    /**
     * @dev Get configuration as uint256 value
     */
    function getConfigAsUint256(
        ISuperfluid host,
        ISuperfluidToken superToken,
        bytes32 key) external view returns (uint256 value);

}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperAgreement } from "./ISuperAgreement.sol";


/**
 * @title Superfluid token interface
 * @author Superfluid
 */
interface ISuperfluidToken {

    /**************************************************************************
     * Basic information
     *************************************************************************/

    /**
     * @dev Get superfluid host contract address
     */
    function getHost() external view returns(address host);

    /**
     * @dev Encoded liquidation type data mainly used for handling stack to deep errors
     *
     * @custom:note 
     * - version: 1
     * - liquidationType key:
     *    - 0 = reward account receives reward (PIC period)
     *    - 1 = liquidator account receives reward (Pleb period)
     *    - 2 = liquidator account receives reward (Pirate period/bailout)
     */
    struct LiquidationTypeData {
        uint256 version;
        uint8 liquidationType;
    }

    /**************************************************************************
     * Real-time balance functions
     *************************************************************************/

    /**
    * @dev Calculate the real balance of a user, taking in consideration all agreements of the account
    * @param account for the query
    * @param timestamp Time of balance
    * @return availableBalance Real-time balance
    * @return deposit Account deposit
    * @return owedDeposit Account owed Deposit
    */
    function realtimeBalanceOf(
       address account,
       uint256 timestamp
    )
        external view
        returns (
            int256 availableBalance,
            uint256 deposit,
            uint256 owedDeposit);

    /**
     * @notice Calculate the realtime balance given the current host.getNow() value
     * @dev realtimeBalanceOf with timestamp equals to block timestamp
     * @param account for the query
     * @return availableBalance Real-time balance
     * @return deposit Account deposit
     * @return owedDeposit Account owed Deposit
     */
    function realtimeBalanceOfNow(
       address account
    )
        external view
        returns (
            int256 availableBalance,
            uint256 deposit,
            uint256 owedDeposit,
            uint256 timestamp);

    /**
    * @notice Check if account is critical
    * @dev A critical account is when availableBalance < 0
    * @param account The account to check
    * @param timestamp The time we'd like to check if the account is critical (should use future)
    * @return isCritical Whether the account is critical
    */
    function isAccountCritical(
        address account,
        uint256 timestamp
    )
        external view
        returns(bool isCritical);

    /**
    * @notice Check if account is critical now (current host.getNow())
    * @dev A critical account is when availableBalance < 0
    * @param account The account to check
    * @return isCritical Whether the account is critical
    */
    function isAccountCriticalNow(
        address account
    )
        external view
        returns(bool isCritical);

    /**
     * @notice Check if account is solvent
     * @dev An account is insolvent when the sum of deposits for a token can't cover the negative availableBalance
     * @param account The account to check
     * @param timestamp The time we'd like to check if the account is solvent (should use future)
     * @return isSolvent True if the account is solvent, false otherwise
     */
    function isAccountSolvent(
        address account,
        uint256 timestamp
    )
        external view
        returns(bool isSolvent);

    /**
     * @notice Check if account is solvent now
     * @dev An account is insolvent when the sum of deposits for a token can't cover the negative availableBalance
     * @param account The account to check
     * @return isSolvent True if the account is solvent, false otherwise
     */
    function isAccountSolventNow(
        address account
    )
        external view
        returns(bool isSolvent);

    /**
    * @notice Get a list of agreements that is active for the account
    * @dev An active agreement is one that has state for the account
    * @param account Account to query
    * @return activeAgreements List of accounts that have non-zero states for the account
    */
    function getAccountActiveAgreements(address account)
       external view
       returns(ISuperAgreement[] memory activeAgreements);


   /**************************************************************************
    * Super Agreement hosting functions
    *************************************************************************/

    /**
     * @dev Create a new agreement
     * @param id Agreement ID
     * @param data Agreement data
     */
    function createAgreement(
        bytes32 id,
        bytes32[] calldata data
    )
        external;
    /**
     * @dev Agreement created event
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @param data Agreement data
     */
    event AgreementCreated(
        address indexed agreementClass,
        bytes32 id,
        bytes32[] data
    );

    /**
     * @dev Get data of the agreement
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @return data Data of the agreement
     */
    function getAgreementData(
        address agreementClass,
        bytes32 id,
        uint dataLength
    )
        external view
        returns(bytes32[] memory data);

    /**
     * @dev Create a new agreement
     * @param id Agreement ID
     * @param data Agreement data
     */
    function updateAgreementData(
        bytes32 id,
        bytes32[] calldata data
    )
        external;
    /**
     * @dev Agreement updated event
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @param data Agreement data
     */
    event AgreementUpdated(
        address indexed agreementClass,
        bytes32 id,
        bytes32[] data
    );

    /**
     * @dev Close the agreement
     * @param id Agreement ID
     */
    function terminateAgreement(
        bytes32 id,
        uint dataLength
    )
        external;
    /**
     * @dev Agreement terminated event
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     */
    event AgreementTerminated(
        address indexed agreementClass,
        bytes32 id
    );

    /**
     * @dev Update agreement state slot
     * @param account Account to be updated
     *
     * @custom:note 
     * - To clear the storage out, provide zero-ed array of intended length
     */
    function updateAgreementStateSlot(
        address account,
        uint256 slotId,
        bytes32[] calldata slotData
    )
        external;
    /**
     * @dev Agreement account state updated event
     * @param agreementClass Contract address of the agreement
     * @param account Account updated
     * @param slotId slot id of the agreement state
     */
    event AgreementStateUpdated(
        address indexed agreementClass,
        address indexed account,
        uint256 slotId
    );

    /**
     * @dev Get data of the slot of the state of an agreement
     * @param agreementClass Contract address of the agreement
     * @param account Account to query
     * @param slotId slot id of the state
     * @param dataLength length of the state data
     */
    function getAgreementStateSlot(
        address agreementClass,
        address account,
        uint256 slotId,
        uint dataLength
    )
        external view
        returns (bytes32[] memory slotData);

    /**
     * @notice Settle balance from an account by the agreement
     * @dev The agreement needs to make sure that the balance delta is balanced afterwards
     * @param account Account to query.
     * @param delta Amount of balance delta to be settled
     *
     * @custom:modifiers 
     *  - onlyAgreement
     */
    function settleBalance(
        address account,
        int256 delta
    )
        external;

    /**
     * @dev Make liquidation payouts (v2)
     * @param id Agreement ID
     * @param liquidationTypeData Data regarding the version of the liquidation schema and the type
     * @param liquidatorAccount Address of the executor of the liquidation
     * @param useDefaultRewardAccount Whether or not the default reward account receives the rewardAmount
     * @param targetAccount Account to be liquidated
     * @param rewardAmount The amount the rewarded account will receive
     * @param targetAccountBalanceDelta The delta amount the target account balance should change by
     *
     * @custom:note 
     * - If a bailout is required (bailoutAmount > 0)
     *   - the actual reward (single deposit) goes to the executor,
     *   - while the reward account becomes the bailout account
     *   - total bailout include: bailout amount + reward amount
     *   - the targetAccount will be bailed out
     * - If a bailout is not required
     *   - the targetAccount will pay the rewardAmount
     *   - the liquidator (reward account in PIC period) will receive the rewardAmount
     *
     * @custom:modifiers 
     *  - onlyAgreement
     */
    function makeLiquidationPayoutsV2
    (
        bytes32 id,
        bytes memory liquidationTypeData,
        address liquidatorAccount,
        bool useDefaultRewardAccount,
        address targetAccount,
        uint256 rewardAmount,
        int256 targetAccountBalanceDelta
    ) external;
    /**
     * @dev Agreement liquidation event v2 (including agent account)
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @param liquidatorAccount Address of the executor of the liquidation
     * @param targetAccount Account of the stream sender
     * @param rewardAmountReceiver Account that collects the reward or bails out insolvent accounts
     * @param rewardAmount The amount the reward recipient account balance should change by
     * @param targetAccountBalanceDelta The amount the sender account balance should change by
     * @param liquidationTypeData The encoded liquidation type data including the version (how to decode)
     *
     * @custom:note 
     * Reward account rule:
     * - if the agreement is liquidated during the PIC period
     *   - the rewardAmountReceiver will get the rewardAmount (remaining deposit), regardless of the liquidatorAccount
     *   - the targetAccount will pay for the rewardAmount
     * - if the agreement is liquidated after the PIC period AND the targetAccount is solvent
     *   - the rewardAmountReceiver will get the rewardAmount (remaining deposit)
     *   - the targetAccount will pay for the rewardAmount
     * - if the targetAccount is insolvent
     *   - the liquidatorAccount will get the rewardAmount (single deposit)
     *   - the default reward account (governance) will pay for both the rewardAmount and bailoutAmount
     *   - the targetAccount will receive the bailoutAmount
     */
    event AgreementLiquidatedV2(
        address indexed agreementClass,
        bytes32 id,
        address indexed liquidatorAccount,
        address indexed targetAccount,
        address rewardAmountReceiver,
        uint256 rewardAmount,
        int256 targetAccountBalanceDelta,
        bytes liquidationTypeData
    );

    /**************************************************************************
     * Function modifiers for access control and parameter validations
     *
     * While they cannot be explicitly stated in function definitions, they are
     * listed in function definition comments instead for clarity.
     *
     * NOTE: solidity-coverage not supporting it
     *************************************************************************/

     /// @dev The msg.sender must be host contract
     //modifier onlyHost() virtual;

    /// @dev The msg.sender must be a listed agreement.
    //modifier onlyAgreement() virtual;

    /**************************************************************************
     * DEPRECATED
     *************************************************************************/

    /**
     * @dev Agreement liquidation event (DEPRECATED BY AgreementLiquidatedBy)
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @param penaltyAccount Account of the agreement to be penalized
     * @param rewardAccount Account that collect the reward
     * @param rewardAmount Amount of liquidation reward
     *
     * @custom:deprecated Use AgreementLiquidatedV2 instead
     */
    event AgreementLiquidated(
        address indexed agreementClass,
        bytes32 id,
        address indexed penaltyAccount,
        address indexed rewardAccount,
        uint256 rewardAmount
    );

    /**
     * @dev System bailout occurred (DEPRECATED BY AgreementLiquidatedBy)
     * @param bailoutAccount Account that bailout the penalty account
     * @param bailoutAmount Amount of account bailout
     *
     * @custom:deprecated Use AgreementLiquidatedV2 instead
     */
    event Bailout(
        address indexed bailoutAccount,
        uint256 bailoutAmount
    );

    /**
     * @dev Agreement liquidation event (DEPRECATED BY AgreementLiquidatedV2)
     * @param liquidatorAccount Account of the agent that performed the liquidation.
     * @param agreementClass Contract address of the agreement
     * @param id Agreement ID
     * @param penaltyAccount Account of the agreement to be penalized
     * @param bondAccount Account that collect the reward or bailout accounts
     * @param rewardAmount Amount of liquidation reward
     * @param bailoutAmount Amount of liquidation bailouot
     *
     * @custom:deprecated Use AgreementLiquidatedV2 instead
     *
     * @custom:note 
     * Reward account rule:
     * - if bailout is equal to 0, then
     *   - the bondAccount will get the rewardAmount,
     *   - the penaltyAccount will pay for the rewardAmount.
     * - if bailout is larger than 0, then
     *   - the liquidatorAccount will get the rewardAmouont,
     *   - the bondAccount will pay for both the rewardAmount and bailoutAmount,
     *   - the penaltyAccount will pay for the rewardAmount while get the bailoutAmount.
     */
    event AgreementLiquidatedBy(
        address liquidatorAccount,
        address indexed agreementClass,
        bytes32 id,
        address indexed penaltyAccount,
        address indexed bondAccount,
        uint256 rewardAmount,
        uint256 bailoutAmount
    );
}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperfluid } from "./ISuperfluid.sol";
import { ISuperfluidToken } from "./ISuperfluidToken.sol";
import { TokenInfo } from "../tokens/TokenInfo.sol";
import { IERC777 } from "@openzeppelin/contracts/token/ERC777/IERC777.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Super token (Superfluid Token + ERC20 + ERC777) interface
 * @author Superfluid
 */
interface ISuperToken is ISuperfluidToken, TokenInfo, IERC20, IERC777 {

    /**
     * @dev Initialize the contract
     */
    function initialize(
        IERC20 underlyingToken,
        uint8 underlyingDecimals,
        string calldata n,
        string calldata s
    ) external;

    /**************************************************************************
    * TokenInfo & ERC777
    *************************************************************************/

    /**
     * @dev Returns the name of the token.
     */
    function name() external view override(IERC777, TokenInfo) returns (string memory);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view override(IERC777, TokenInfo) returns (string memory);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * @custom:note SuperToken always uses 18 decimals.
     *
     * This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view override(TokenInfo) returns (uint8);

    /**************************************************************************
    * ERC20 & ERC777
    *************************************************************************/

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() external view override(IERC777, IERC20) returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by an account (`owner`).
     */
    function balanceOf(address account) external view override(IERC777, IERC20) returns(uint256 balance);

    /**************************************************************************
    * ERC20
    *************************************************************************/

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * @return Returns Success a boolean value indicating whether the operation succeeded.
     *
     * @custom:emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external override(IERC20) returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     *         allowed to spend on behalf of `owner` through {transferFrom}. This is
     *         zero by default.
     *
     * @notice This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external override(IERC20) view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * @return Returns Success a boolean value indicating whether the operation succeeded.
     *
     * @custom:note Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * @custom:emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external override(IERC20) returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     *         allowance mechanism. `amount` is then deducted from the caller's
     *         allowance.
     *
     * @return Returns Success a boolean value indicating whether the operation succeeded.
     *
     * @custom:emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override(IERC20) returns (bool);

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * @custom:emits an {Approval} event indicating the updated allowance.
     *
     * @custom:requirements 
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * @custom:emits an {Approval} event indicating the updated allowance.
     *
     * @custom:requirements 
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
     function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool);

    /**************************************************************************
    * ERC777
    *************************************************************************/

    /**
     * @dev Returns the smallest part of the token that is not divisible. This
     *         means all token operations (creation, movement and destruction) must have
     *         amounts that are a multiple of this number.
     *
     * @custom:note For super token contracts, this value is always 1
     */
    function granularity() external view override(IERC777) returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * @dev If send or receive hooks are registered for the caller and `recipient`,
     *      the corresponding functions will be called with `data` and empty
     *      `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * @custom:emits a {Sent} event.
     *
     * @custom:requirements 
     * - the caller must have at least `amount` tokens.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function send(address recipient, uint256 amount, bytes calldata data) external override(IERC777);

    /**
     * @dev Destroys `amount` tokens from the caller's account, reducing the
     * total supply.
     *
     * If a send hook is registered for the caller, the corresponding function
     * will be called with `data` and empty `operatorData`. See {IERC777Sender}.
     *
     * @custom:emits a {Burned} event.
     *
     * @custom:requirements 
     * - the caller must have at least `amount` tokens.
     */
    function burn(uint256 amount, bytes calldata data) external override(IERC777);

    /**
     * @dev Returns true if an account is an operator of `tokenHolder`.
     * Operators can send and burn tokens on behalf of their owners. All
     * accounts are their own operator.
     *
     * See {operatorSend} and {operatorBurn}.
     */
    function isOperatorFor(address operator, address tokenHolder) external override(IERC777) view returns (bool);

    /**
     * @dev Make an account an operator of the caller.
     *
     * See {isOperatorFor}.
     *
     * @custom:emits an {AuthorizedOperator} event.
     *
     * @custom:requirements 
     * - `operator` cannot be calling address.
     */
    function authorizeOperator(address operator) external override(IERC777);

    /**
     * @dev Revoke an account's operator status for the caller.
     *
     * See {isOperatorFor} and {defaultOperators}.
     *
     * @custom:emits a {RevokedOperator} event.
     *
     * @custom:requirements 
     * - `operator` cannot be calling address.
     */
    function revokeOperator(address operator) external override(IERC777);

    /**
     * @dev Returns the list of default operators. These accounts are operators
     * for all token holders, even if {authorizeOperator} was never called on
     * them.
     *
     * This list is immutable, but individual holders may revoke these via
     * {revokeOperator}, in which case {isOperatorFor} will return false.
     */
    function defaultOperators() external override(IERC777) view returns (address[] memory);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient`. The caller must
     * be an operator of `sender`.
     *
     * If send or receive hooks are registered for `sender` and `recipient`,
     * the corresponding functions will be called with `data` and
     * `operatorData`. See {IERC777Sender} and {IERC777Recipient}.
     *
     * @custom:emits a {Sent} event.
     *
     * @custom:requirements 
     * - `sender` cannot be the zero address.
     * - `sender` must have at least `amount` tokens.
     * - the caller must be an operator for `sender`.
     * - `recipient` cannot be the zero address.
     * - if `recipient` is a contract, it must implement the {IERC777Recipient}
     * interface.
     */
    function operatorSend(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external override(IERC777);

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the total supply.
     * The caller must be an operator of `account`.
     *
     * If a send hook is registered for `account`, the corresponding function
     * will be called with `data` and `operatorData`. See {IERC777Sender}.
     *
     * @custom:emits a {Burned} event.
     *
     * @custom:requirements 
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     * - the caller must be an operator for `account`.
     */
    function operatorBurn(
        address account,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external override(IERC777);

    /**************************************************************************
     * SuperToken custom token functions
     *************************************************************************/

    /**
     * @dev Mint new tokens for the account
     *
     * @custom:modifiers 
     *  - onlySelf
     */
    function selfMint(
        address account,
        uint256 amount,
        bytes memory userData
    ) external;

   /**
    * @dev Burn existing tokens for the account
    *
    * @custom:modifiers 
    *  - onlySelf
    */
   function selfBurn(
       address account,
       uint256 amount,
       bytes memory userData
   ) external;

   /**
    * @dev Transfer `amount` tokens from the `sender` to `recipient`.
    * If `spender` isn't the same as `sender`, checks if `spender` has allowance to
    * spend tokens of `sender`.
    *
    * @custom:modifiers 
    *  - onlySelf
    */
   function selfTransferFrom(
        address sender,
        address spender,
        address recipient,
        uint256 amount
   ) external;

   /**
    * @dev Give `spender`, `amount` allowance to spend the tokens of
    * `account`.
    *
    * @custom:modifiers 
    *  - onlySelf
    */
   function selfApproveFor(
        address account,
        address spender,
        uint256 amount
   ) external;

    /**************************************************************************
     * SuperToken extra functions
     *************************************************************************/

    /**
     * @dev Transfer all available balance from `msg.sender` to `recipient`
     */
    function transferAll(address recipient) external;

    /**************************************************************************
     * ERC20 wrapping
     *************************************************************************/

    /**
     * @dev Return the underlying token contract
     * @return tokenAddr Underlying token address
     */
    function getUnderlyingToken() external view returns(address tokenAddr);

    /**
     * @dev Upgrade ERC20 to SuperToken.
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     *
     * @custom:note It will use `transferFrom` to get tokens. Before calling this
     * function you should `approve` this contract
     */
    function upgrade(uint256 amount) external;

    /**
     * @dev Upgrade ERC20 to SuperToken and transfer immediately
     * @param to The account to received upgraded tokens
     * @param amount Number of tokens to be upgraded (in 18 decimals)
     * @param data User data for the TokensRecipient callback
     *
     * @custom:note It will use `transferFrom` to get tokens. Before calling this
     * function you should `approve` this contract
     */
    function upgradeTo(address to, uint256 amount, bytes calldata data) external;

    /**
     * @dev Token upgrade event
     * @param account Account where tokens are upgraded to
     * @param amount Amount of tokens upgraded (in 18 decimals)
     */
    event TokenUpgraded(
        address indexed account,
        uint256 amount
    );

    /**
     * @dev Downgrade SuperToken to ERC20.
     * @dev It will call transfer to send tokens
     * @param amount Number of tokens to be downgraded
     */
    function downgrade(uint256 amount) external;

    /**
     * @dev Token downgrade event
     * @param account Account whose tokens are upgraded
     * @param amount Amount of tokens downgraded
     */
    event TokenDowngraded(
        address indexed account,
        uint256 amount
    );

    /**************************************************************************
    * Batch Operations
    *************************************************************************/

    /**
    * @dev Perform ERC20 approve by host contract.
    * @param account The account owner to be approved.
    * @param spender The spender of account owner's funds.
    * @param amount Number of tokens to be approved.
    *
    * @custom:modifiers 
    *  - onlyHost
    */
    function operationApprove(
        address account,
        address spender,
        uint256 amount
    ) external;

    /**
    * @dev Perform ERC20 transfer from by host contract.
    * @param account The account to spend sender's funds.
    * @param spender  The account where the funds is sent from.
    * @param recipient The recipient of thefunds.
    * @param amount Number of tokens to be transferred.
    *
    * @custom:modifiers 
    *  - onlyHost
    */
    function operationTransferFrom(
        address account,
        address spender,
        address recipient,
        uint256 amount
    ) external;

    /**
    * @dev Upgrade ERC20 to SuperToken by host contract.
    * @param account The account to be changed.
    * @param amount Number of tokens to be upgraded (in 18 decimals)
    *
    * @custom:modifiers 
    *  - onlyHost
    */
    function operationUpgrade(address account, uint256 amount) external;

    /**
    * @dev Downgrade ERC20 to SuperToken by host contract.
    * @param account The account to be changed.
    * @param amount Number of tokens to be downgraded (in 18 decimals)
    *
    * @custom:modifiers 
    *  - onlyHost
    */
    function operationDowngrade(address account, uint256 amount) external;


    /**************************************************************************
    * Function modifiers for access control and parameter validations
    *
    * While they cannot be explicitly stated in function definitions, they are
    * listed in function definition comments instead for clarity.
    *
    * NOTE: solidity-coverage not supporting it
    *************************************************************************/

    /// @dev The msg.sender must be the contract itself
    //modifier onlySelf() virtual

}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { ISuperToken } from "./ISuperToken.sol";

import {
    IERC20,
    ERC20WithTokenInfo
} from "../tokens/ERC20WithTokenInfo.sol";

/**
 * @title Super token factory interface
 * @author Superfluid
 */
interface ISuperTokenFactory {

    /**
     * @dev Get superfluid host contract address
     */
    function getHost() external view returns(address host);

    /// @dev Initialize the contract
    function initialize() external;

    /**
     * @dev Get the current super token logic used by the factory
     */
    function getSuperTokenLogic() external view returns (ISuperToken superToken);

    /**
     * @dev Upgradability modes
     */
    enum Upgradability {
        /// Non upgradable super token, `host.updateSuperTokenLogic` will revert
        NON_UPGRADABLE,
        /// Upgradable through `host.updateSuperTokenLogic` operation
        SEMI_UPGRADABLE,
        /// Always using the latest super token logic
        FULL_UPGRADABE
    }

    /**
     * @dev Create new super token wrapper for the underlying ERC20 token
     * @param underlyingToken Underlying ERC20 token
     * @param underlyingDecimals Underlying token decimals
     * @param upgradability Upgradability mode
     * @param name Super token name
     * @param symbol Super token symbol
     */
    function createERC20Wrapper(
        IERC20 underlyingToken,
        uint8 underlyingDecimals,
        Upgradability upgradability,
        string calldata name,
        string calldata symbol
    )
        external
        returns (ISuperToken superToken);

    /**
     * @dev Create new super token wrapper for the underlying ERC20 token with extra token info
     * @param underlyingToken Underlying ERC20 token
     * @param upgradability Upgradability mode
     * @param name Super token name
     * @param symbol Super token symbol
     *
     * NOTE:
     * - It assumes token provide the .decimals() function
     */
    function createERC20Wrapper(
        ERC20WithTokenInfo underlyingToken,
        Upgradability upgradability,
        string calldata name,
        string calldata symbol
    )
        external
        returns (ISuperToken superToken);

    function initializeCustomSuperToken(
        address customSuperTokenProxy
    )
        external;

    /**
      * @dev Super token logic created event
      * @param tokenLogic Token logic address
      */
    event SuperTokenLogicCreated(ISuperToken indexed tokenLogic);

    /**
      * @dev Super token created event
      * @param token Newly created super token address
      */
    event SuperTokenCreated(ISuperToken indexed token);

    /**
      * @dev Custom super token created event
      * @param token Newly created custom super token address
      */
    event CustomSuperTokenCreated(ISuperToken indexed token);

}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenInfo } from "./TokenInfo.sol";

/**
 * @title ERC20 token with token info interface
 * @author Superfluid
 * @dev Using abstract contract instead of interfaces because old solidity
 *      does not support interface inheriting other interfaces
 * solhint-disable-next-line no-empty-blocks
 *
 */
// solhint-disable-next-line no-empty-blocks
abstract contract ERC20WithTokenInfo is IERC20, TokenInfo {}

// SPDX-License-Identifier: AGPLv3
pragma solidity >= 0.8.0;

/**
 * @title ERC20 token info interface
 * @author Superfluid
 * @dev ERC20 standard interface does not specify these functions, but
 *      often the token implementations have them.
 */
interface TokenInfo {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() external view returns (uint8);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface ICFABeneficiary {
    /// @notice Get last deletion for sender
    function getLastDeletion(address sender) external view returns (uint256);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../libraries/LibCFABasePCO.sol";
import "../interfaces/ICFABasePCO.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {IERC721} from "@solidstate/contracts/interfaces/IERC721.sol";
import "../../registry/interfaces/IPCOLicenseParamsStore.sol";
import "../../beneficiary/interfaces/ICFABeneficiary.sol";
import {OwnableStorage} from "@solidstate/contracts/access/ownable/OwnableStorage.sol";

contract CFABasePCOFacetModifiers {
    using OwnableStorage for OwnableStorage.Layout;

    modifier onlyOwner() {
        require(
            msg.sender == OwnableStorage.layout().owner,
            "Ownable: sender must be owner"
        );
        _;
    }

    modifier onlyPayer() {
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();
        require(
            msg.sender == _currentBid.bidder,
            "CFABasePCOFacet: Only payer is allowed to perform this action"
        );
        _;
    }

    modifier onlyIfPayerBidActive() {
        require(
            LibCFABasePCO._isPayerBidActive(),
            "CFABasePCOFacet: Can only perform action when payer bid is active"
        );
        _;
    }

    modifier onlyNotPayer() {
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();
        require(
            msg.sender != _currentBid.bidder,
            "CFABasePCOFacet: Payer is not allowed to perform this action"
        );
        _;
    }
}

/// @notice Handles basic PCO functionality using Constant Flow Agreement (CFA)
contract CFABasePCOFacet is ICFABasePCO, CFABasePCOFacetModifiers {
    using CFAv1Library for CFAv1Library.InitData;

    /**
     * @notice Initialize bid.
     *      - Must be the contract owner
     *      - Must have payment token buffer deposited
     *      - Must have permissions to create flow for bidder
     * @param paramsStore Global store for parameters
     * @param initLicense Underlying ERC721 license
     * @param initLicenseId Token ID of license
     * @param bidder Initial bidder
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intended new for sale price. Must be within rounding bounds of newContributionRate
     */
    function initializeBid(
        ICFABeneficiary beneficiary,
        IPCOLicenseParamsStore paramsStore,
        IERC721 initLicense,
        uint256 initLicenseId,
        address bidder,
        int96 newContributionRate,
        uint256 newForSalePrice
    ) external onlyOwner {
        LibCFABasePCO._initializeBid(
            beneficiary,
            paramsStore,
            initLicense,
            initLicenseId,
            bidder,
            newContributionRate,
            newForSalePrice,
            new bytes(0)
        );
    }

    /**
     * @notice Initialize bid with content hash
     *      - Must be the contract owner
     *      - Must have payment token buffer deposited
     *      - Must have permissions to create flow for bidder
     * @param paramsStore Global store for parameters
     * @param initLicense Underlying ERC721 license
     * @param initLicenseId Token ID of license
     * @param bidder Initial bidder
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     * @param _contentHash Content hash for parcel content
     */
    function initializeBid(
        ICFABeneficiary beneficiary,
        IPCOLicenseParamsStore paramsStore,
        IERC721 initLicense,
        uint256 initLicenseId,
        address bidder,
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata _contentHash
    ) external onlyOwner {
        LibCFABasePCO._initializeBid(
            beneficiary,
            paramsStore,
            initLicense,
            initLicenseId,
            bidder,
            newContributionRate,
            newForSalePrice,
            _contentHash
        );
    }

    /**
     * @notice Current payer of license
     */
    function payer() external view returns (address) {
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();
        return _currentBid.bidder;
    }

    /**
     * @notice Current contribution rate of payer
     */
    function contributionRate() external view returns (int96) {
        return LibCFABasePCO._contributionRate();
    }

    /**
     * @notice Current price needed to purchase license
     */
    function forSalePrice() external view returns (uint256) {
        if (LibCFABasePCO._isPayerBidActive()) {
            LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();
            return _currentBid.forSalePrice;
        } else {
            return 0;
        }
    }

    /**
     * @notice License Id
     */
    function licenseId() external view returns (uint256) {
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        return ds.licenseId;
    }

    /**
     * @notice License
     */
    function license() external view returns (IERC721) {
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        return ds.license;
    }

    /**
     * @notice Is current bid actively being paid
     */
    function isPayerBidActive() external view returns (bool) {
        return LibCFABasePCO._isPayerBidActive();
    }

    /**
     * @notice Get current bid
     */
    function currentBid() external pure returns (LibCFABasePCO.Bid memory) {
        LibCFABasePCO.Bid storage bid = LibCFABasePCO._currentBid();

        return bid;
    }

    /**
     * @notice Get content hash
     */
    function contentHash() external view returns (bytes memory) {
        LibCFABasePCO.Bid storage bid = LibCFABasePCO._currentBid();

        return bid.contentHash;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../libraries/LibCFABasePCO.sol";
import {CFABasePCOFacetModifiers} from "./CFABasePCOFacet.sol";
import "../libraries/LibCFAPenaltyBid.sol";
import "../interfaces/ICFAPenaltyBid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Handles bidding using CFAs and penalities
contract CFAPenaltyBidFacet is ICFAPenaltyBid, CFABasePCOFacetModifiers {
    using CFAv1Library for CFAv1Library.InitData;
    using SafeERC20 for ISuperToken;

    modifier onlyIfPendingBid() {
        // Check if pending bid exists
        require(
            this.hasPendingBid(),
            "CFAPenaltyBidFacet: Pending bid does not exist"
        );
        _;
    }

    modifier onlyIfNotPendingBid() {
        // Check if pending bid exists
        require(
            !this.hasPendingBid(),
            "CFAPenaltyBidFacet: Pending bid exists"
        );
        _;
    }

    modifier onlyAfterBidPeriod() {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();

        uint256 bidPeriodLengthInSeconds = ds
            .paramsStore
            .getBidPeriodLengthInSeconds();
        uint256 elapsedTime = block.timestamp - _pendingBid.timestamp;
        require(
            elapsedTime >= bidPeriodLengthInSeconds ||
                shouldBidPeriodEndEarly(),
            "CFAPenaltyBidFacet: Bid period has not elapsed"
        );
        _;
    }

    modifier onlyDuringBidPeriod() {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();

        uint256 bidPeriodLengthInSeconds = ds
            .paramsStore
            .getBidPeriodLengthInSeconds();
        uint256 elapsedTime = block.timestamp - _pendingBid.timestamp;
        require(
            elapsedTime < bidPeriodLengthInSeconds &&
                !shouldBidPeriodEndEarly(),
            "CFAPenaltyBidFacet: Bid period has elapsed"
        );
        _;
    }

    /**
     * @notice Should bid period end early
     */
    function shouldBidPeriodEndEarly() public view returns (bool) {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();

        LibCFABasePCO.DiamondCFAStorage storage cs = LibCFABasePCO.cfaStorage();

        (uint256 timestamp, int96 flowRate, , ) = cs.cfaV1.cfa.getFlow(
            ds.paramsStore.getPaymentToken(),
            _currentBid.bidder,
            address(this)
        );

        return
            timestamp > _pendingBid.timestamp ||
            flowRate == 0 ||
            !LibCFABasePCO._isPayerBidActive();
    }

    /**
     * @notice Get pending bid
     */
    function pendingBid() external pure returns (LibCFAPenaltyBid.Bid memory) {
        LibCFAPenaltyBid.Bid storage bid = LibCFAPenaltyBid.pendingBid();

        return bid;
    }

    /**
     * @notice Checks if there is a pending bid
     */
    function hasPendingBid() external view returns (bool) {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();

        return _pendingBid.contributionRate > 0;
    }

    /**
     * @notice Get penalty payment
     */
    function calculatePenalty() external view returns (uint256) {
        return LibCFAPenaltyBid._calculatePenalty();
    }

    /**
     * @notice Edit bid
     *      - Must be the current payer
     *      - Must have permissions to update flow for payer
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function editBid(int96 newContributionRate, uint256 newForSalePrice)
        external
        onlyPayer
        onlyIfNotPendingBid
    {
        LibCFABasePCO._editBid(newContributionRate, newForSalePrice);
    }

    /**
     * @notice Place a bid to purchase license as msg.sender
     *      - Pending bid must not exist
     *      - Must have permissions to create flow for bidder
     *      - Must have ERC-20 approval of payment token
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function placeBid(int96 newContributionRate, uint256 newForSalePrice)
        external
        onlyIfPayerBidActive
        onlyNotPayer
    {
        LibCFAPenaltyBid._placeBid(
            newContributionRate,
            newForSalePrice,
            new bytes(0)
        );
    }

    /**
     * @notice Edit content hash
     *      - Must be the current payer
     *      - Must have permissions to update flow for payer
     * @param contentHash Content hash for parcel content
     */
    function editContentHash(bytes calldata contentHash) external onlyPayer {
        LibCFABasePCO._editContentHash(contentHash);
    }

    /**
     * @notice Edit bid with content hash
     *      - Must be the current payer
     *      - Must have permissions to update flow for payer
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function editBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata contentHash
    ) external onlyPayer onlyIfNotPendingBid {
        LibCFABasePCO._editBid(
            newContributionRate,
            newForSalePrice,
            contentHash
        );
    }

    /**
     * @notice Place a bid with content hash
     *      - Pending bid must not exist
     *      - Must have permissions to create flow for bidder
     *      - Must have ERC-20 approval of payment token
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function placeBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata contentHash
    ) external onlyIfPayerBidActive onlyNotPayer {
        LibCFAPenaltyBid._placeBid(
            newContributionRate,
            newForSalePrice,
            contentHash
        );
    }

    /**
     * @notice Accept a pending bid as the current payer
     *      - Must be payer
     *      - Pending bid must exist
     *      - Must be within bidding period
     */
    function acceptBid()
        external
        onlyPayer
        onlyIfPendingBid
        onlyDuringBidPeriod
    {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();

        emit BidAccepted(
            _currentBid.bidder,
            _pendingBid.bidder,
            _currentBid.forSalePrice
        );

        // Reentrancy on ERC721 transfer
        LibCFAPenaltyBid._triggerTransfer();
    }

    /**
     * @notice Reject a pending bid as the current payer
     *      - Must be payer
     *      - Pending bid must exist
     *      - Must be within bidding period
     *      - Must approve penalty amount
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function rejectBid(int96 newContributionRate, uint256 newForSalePrice)
        external
        onlyPayer
        onlyIfPendingBid
        onlyDuringBidPeriod
    {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();

        emit BidRejected(
            _currentBid.bidder,
            _pendingBid.bidder,
            _currentBid.forSalePrice
        );

        LibCFAPenaltyBid._rejectBid(newContributionRate, newForSalePrice);
    }

    /**
     * @notice Trigger a transfer after bidding period has elapsed
     *      - Pending bid must exist
     *      - Must be after bidding period
     */
    function triggerTransfer() external onlyIfPendingBid onlyAfterBidPeriod {
        LibCFAPenaltyBid.Bid storage _pendingBid = LibCFAPenaltyBid
            .pendingBid();
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();

        emit TransferTriggered(
            msg.sender,
            _currentBid.bidder,
            _pendingBid.bidder,
            _currentBid.forSalePrice
        );

        // Reentrancy on ERC721 transfer
        LibCFAPenaltyBid._triggerTransfer();
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {IERC721} from "@solidstate/contracts/interfaces/IERC721.sol";
import "../libraries/LibCFABasePCO.sol";
import "../../registry/interfaces/IPCOLicenseParamsStore.sol";
import "../../beneficiary/interfaces/ICFABeneficiary.sol";

interface ICFABasePCO {
    /// @notice Emitted when an owner bid is updated
    event PayerContributionRateUpdated(
        address indexed _payer,
        int96 contributionRate
    );

    /// @notice Emitted when for sale price is updated
    event PayerForSalePriceUpdated(
        address indexed _payer,
        uint256 forSalePrice
    );

    /// @notice Emitted when content hash is updated
    event PayerContentHashUpdated(address indexed _payer, bytes contentHash);

    /**
     * @notice Initialize bid.
     *      - Must be the contract owner
     *      - Must have payment token buffer deposited
     *      - Must have permissions to create flow for bidder
     * @param paramsStore Global store for parameters
     * @param initLicense Underlying ERC721 license
     * @param initLicenseId Token ID of license
     * @param bidder Initial bidder
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function initializeBid(
        ICFABeneficiary beneficiary,
        IPCOLicenseParamsStore paramsStore,
        IERC721 initLicense,
        uint256 initLicenseId,
        address bidder,
        int96 newContributionRate,
        uint256 newForSalePrice
    ) external;

    /**
     * @notice Initialize bid with a content hash.
     *      - Must be the contract owner
     *      - Must have payment token buffer deposited
     *      - Must have permissions to create flow for bidder
     * @param paramsStore Global store for parameters
     * @param initLicense Underlying ERC721 license
     * @param initLicenseId Token ID of license
     * @param bidder Initial bidder
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intended new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function initializeBid(
        ICFABeneficiary beneficiary,
        IPCOLicenseParamsStore paramsStore,
        IERC721 initLicense,
        uint256 initLicenseId,
        address bidder,
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata contentHash
    ) external;

    /**
     * @notice Current payer of license
     */
    function payer() external view returns (address);

    /**
     * @notice Current contribution rate of payer
     */
    function contributionRate() external view returns (int96);

    /**
     * @notice Current price needed to purchase license
     */
    function forSalePrice() external view returns (uint256);

    /**
     * @notice License Id
     */
    function licenseId() external view returns (uint256);

    /**
     * @notice License
     */
    function license() external view returns (IERC721);

    /**
     * @notice Is current bid actively being paid
     */
    function isPayerBidActive() external view returns (bool);

    /**
     * @notice Get current bid
     */
    function currentBid() external pure returns (LibCFABasePCO.Bid memory);

    /**
     * @notice Get content hash
     */
    function contentHash() external view returns (bytes memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../libraries/LibCFAPenaltyBid.sol";

interface ICFAPenaltyBid {
    /// @notice Emitted when for sale price is updated
    event BidPlaced(
        address indexed _bidder,
        int96 contributionRate,
        uint256 forSalePrice
    );

    /// @notice Emitted when a bid is accepted
    event BidAccepted(
        address indexed _payer,
        address indexed _bidder,
        uint256 forSalePrice
    );

    /// @notice Emitted when a bid is rejected
    event BidRejected(
        address indexed _payer,
        address indexed _bidder,
        uint256 forSalePrice
    );

    /// @notice Emitted when a transfer is triggered
    event TransferTriggered(
        address indexed _sender,
        address indexed _payer,
        address indexed _bidder,
        uint256 forSalePrice
    );

    /**
     * @notice Should bid period end early
     */
    function shouldBidPeriodEndEarly() external view returns (bool);

    /**
     * @notice Get pending bid
     */
    function pendingBid() external pure returns (LibCFAPenaltyBid.Bid memory);

    /**
     * @notice Checks if there is a pending bid
     */
    function hasPendingBid() external view returns (bool);

    /**
     * @notice Get penalty payment
     */
    function calculatePenalty() external view returns (uint256);

    /**
     * @notice Edit bid
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function editBid(int96 newContributionRate, uint256 newForSalePrice)
        external;

    /**
     * @notice Place a bid to purchase license as msg.sender
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function placeBid(int96 newContributionRate, uint256 newForSalePrice)
        external;

    /**
     * @notice Accept a pending bid as the current payer
     */
    function acceptBid() external;

    /**
     * @notice Reject a pending bid as the current payer
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     */
    function rejectBid(int96 newContributionRate, uint256 newForSalePrice)
        external;

    /**
     * @notice Trigger a transfer after bidding period has elapsed
     */
    function triggerTransfer() external;

    /**
     * @notice Edit bid with a content hash
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intended new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function editBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata contentHash
    ) external;

    /**
     * @notice Place a bid with a content hash
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intended new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function placeBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes calldata contentHash
    ) external;

    /**
     * @notice Edit content hash
     *      - Must be the current payer
     *      - Must have permissions to update flow for payer
     * @param contentHash Content hash for parcel content
     */
    function editContentHash(bytes calldata contentHash) external;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../registry/interfaces/IPCOLicenseParamsStore.sol";
import "../../beneficiary/interfaces/ICFABeneficiary.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import {IERC721} from "@solidstate/contracts/interfaces/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

library LibCFABasePCO {
    using CFAv1Library for CFAv1Library.InitData;
    using SafeERC20 for ISuperToken;

    bytes32 private constant STORAGE_POSITION =
        keccak256("diamond.standard.diamond.storage.LibBasePCO");

    bytes32 private constant STORAGE_POSITION_CUR_BID =
        keccak256("diamond.standard.diamond.storage.LibBasePCO.currentBid");

    bytes32 private constant STORAGE_POSITION_CFA =
        keccak256("diamond.standard.diamond.storage.LibBasePCO.cfa");

    struct Bid {
        uint256 timestamp;
        address bidder;
        int96 contributionRate;
        uint256 perSecondFeeNumerator;
        uint256 perSecondFeeDenominator;
        uint256 forSalePrice;
        bytes contentHash;
    }

    struct DiamondStorage {
        IPCOLicenseParamsStore paramsStore;
        IERC721 license;
        uint256 licenseId;
        ICFABeneficiary beneficiary;
    }

    struct DiamondCFAStorage {
        CFAv1Library.InitData cfaV1;
    }

    /// @notice Emitted when an owner bid is updated
    event PayerContributionRateUpdated(
        address indexed _payer,
        int96 contributionRate
    );

    /// @notice Emitted when for sale price is updated
    event PayerForSalePriceUpdated(
        address indexed _payer,
        uint256 forSalePrice
    );

    /// @notice Emitted when content hash is updated
    event PayerContentHashUpdated(address indexed _payer, bytes contentHash);

    function diamondStorage()
        internal
        pure
        returns (DiamondStorage storage ds)
    {
        bytes32 position = STORAGE_POSITION;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /// @dev Store currentBid in separate position so struct is upgradeable
    function _currentBid() internal pure returns (Bid storage bid) {
        bytes32 position = STORAGE_POSITION_CUR_BID;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            bid.slot := position
        }
    }

    /// @dev Store cfa in separate position so struct is upgradeable
    function cfaStorage() internal pure returns (DiamondCFAStorage storage ds) {
        bytes32 position = STORAGE_POSITION_CFA;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /// @dev Get beneficiary or default if not set
    function _getBeneficiary() internal view returns (address) {
        DiamondStorage storage ds = diamondStorage();
        return address(ds.beneficiary);
    }

    function _checkForSalePrice(
        uint256 forSalePrice,
        int96 contributionRate,
        uint256 _perSecondFeeNumerator,
        uint256 _perSecondFeeDenominator
    ) internal pure returns (bool) {
        uint256 calculatedContributionRate = (forSalePrice *
            _perSecondFeeNumerator) / _perSecondFeeDenominator;

        return calculatedContributionRate == uint96(contributionRate);
    }

    function _contributionRate() internal view returns (int96) {
        DiamondStorage storage ds = diamondStorage();
        DiamondCFAStorage storage cs = cfaStorage();

        // Get flow rate (app -> beneficiary)
        (, int96 flowRate, , ) = cs.cfaV1.cfa.getFlow(
            ds.paramsStore.getPaymentToken(),
            address(this),
            address(_getBeneficiary())
        );

        return flowRate;
    }

    function _isPayerBidActive() internal view returns (bool) {
        return _contributionRate() > 0;
    }

    function _createBeneficiaryFlow(int96 newContributionRate) internal {
        DiamondCFAStorage storage cs = cfaStorage();
        DiamondStorage storage ds = diamondStorage();

        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();

        // Create to stored beneficiary
        cs.cfaV1.createFlow(
            address(ds.beneficiary),
            paymentToken,
            newContributionRate
        );
    }

    /**
     * @notice Initialize bid.
     * @param paramsStore Global store for parameters
     * @param initLicense Underlying ERC721 license
     * @param initLicenseId Token ID of license
     * @param bidder Initial bidder
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function _initializeBid(
        ICFABeneficiary beneficiary,
        IPCOLicenseParamsStore paramsStore,
        IERC721 initLicense,
        uint256 initLicenseId,
        address bidder,
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes memory contentHash
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        ds.paramsStore = paramsStore;
        ds.license = initLicense;
        ds.licenseId = initLicenseId;
        ds.beneficiary = beneficiary;

        require(
            newForSalePrice >= ds.paramsStore.getMinForSalePrice(),
            "CFABasePCOFacet: Minimum for sale price not met"
        );

        uint256 perSecondFeeNumerator = ds
            .paramsStore
            .getPerSecondFeeNumerator();
        uint256 perSecondFeeDenominator = ds
            .paramsStore
            .getPerSecondFeeDenominator();
        require(
            _checkForSalePrice(
                newForSalePrice,
                newContributionRate,
                perSecondFeeNumerator,
                perSecondFeeDenominator
            ),
            "LibCFABasePCO: Incorrect for sale price"
        );

        DiamondCFAStorage storage cs = cfaStorage();
        ISuperfluid host = ds.paramsStore.getHost();
        cs.cfaV1 = CFAv1Library.InitData(
            host,
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );
        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();

        Bid storage bid = _currentBid();
        bid.timestamp = block.timestamp;
        bid.bidder = bidder;
        bid.contributionRate = newContributionRate;
        bid.perSecondFeeNumerator = perSecondFeeNumerator;
        bid.perSecondFeeDenominator = perSecondFeeDenominator;
        bid.forSalePrice = newForSalePrice;
        bid.contentHash = contentHash;

        emit PayerForSalePriceUpdated(bidder, newForSalePrice);
        emit PayerContributionRateUpdated(bidder, newContributionRate);
        emit PayerContentHashUpdated(bidder, contentHash);

        // Create flow (payer -> license)
        cs.cfaV1.createFlowByOperator(
            bidder,
            address(this),
            paymentToken,
            newContributionRate
        );

        // Create flow (license -> beneficiary)
        cs.cfaV1.createFlow(
            address(beneficiary),
            paymentToken,
            newContributionRate
        );
    }

    function _editBid(int96 newContributionRate, uint256 newForSalePrice)
        internal
    {
        Bid storage bid = _currentBid();

        _editBid(newContributionRate, newForSalePrice, bid.contentHash);
    }

    function _editContentHash(bytes memory contentHash) internal {
        Bid storage bid = _currentBid();

        bid.contentHash = contentHash;

        emit PayerContentHashUpdated(bid.bidder, contentHash);
    }

    function _editBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes memory contentHash
    ) internal {
        DiamondStorage storage ds = diamondStorage();
        DiamondCFAStorage storage cs = cfaStorage();
        Bid storage bid = _currentBid();

        require(
            newForSalePrice >= ds.paramsStore.getMinForSalePrice(),
            "LibCFABasePCO: Minimum for sale price not met"
        );

        uint256 perSecondFeeNumerator = ds
            .paramsStore
            .getPerSecondFeeNumerator();
        uint256 perSecondFeeDenominator = ds
            .paramsStore
            .getPerSecondFeeDenominator();
        require(
            _checkForSalePrice(
                newForSalePrice,
                newContributionRate,
                perSecondFeeNumerator,
                perSecondFeeDenominator
            ),
            "LibCFABasePCO: Incorrect for sale price"
        );

        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();

        bid.timestamp = block.timestamp;
        bid.bidder = bid.bidder;
        bid.contributionRate = newContributionRate;
        bid.perSecondFeeNumerator = perSecondFeeNumerator;
        bid.perSecondFeeDenominator = perSecondFeeDenominator;
        bid.forSalePrice = newForSalePrice;
        bid.contentHash = contentHash;

        emit PayerForSalePriceUpdated(bid.bidder, newForSalePrice);
        emit PayerContributionRateUpdated(bid.bidder, newContributionRate);
        emit PayerContentHashUpdated(bid.bidder, contentHash);

        (, uint256 deposit, , ) = paymentToken.realtimeBalanceOfNow(
            address(this)
        );
        uint256 requiredBuffer = cs.cfaV1.cfa.getDepositRequiredForFlowRate(
            paymentToken,
            newContributionRate
        );

        // Transfer required buffer in
        if (requiredBuffer > deposit) {
            paymentToken.safeTransferFrom(
                msg.sender,
                address(this),
                requiredBuffer - deposit
            );
        }

        (, int96 flowRate, , ) = cs.cfaV1.cfa.getFlow(
            paymentToken,
            bid.bidder,
            address(this)
        );
        if (flowRate > 0) {
            // Update flow (payer -> license)
            cs.cfaV1.updateFlowByOperator(
                bid.bidder,
                address(this),
                paymentToken,
                newContributionRate
            );
        } else {
            // Recreate flow (payer -> license)
            cs.cfaV1.createFlowByOperator(
                bid.bidder,
                address(this),
                paymentToken,
                newContributionRate
            );
        }

        address beneficiary = address(_getBeneficiary());
        (, flowRate, , ) = cs.cfaV1.cfa.getFlow(
            paymentToken,
            address(this),
            beneficiary
        );

        if (flowRate > 0) {
            // Update flow (license -> beneficiary)
            cs.cfaV1.updateFlow(beneficiary, paymentToken, newContributionRate);
        } else {
            // Recreate flow (license -> beneficiary)
            _createBeneficiaryFlow(newContributionRate);
        }

        // Refund buffer
        if (deposit > requiredBuffer) {
            paymentToken.safeTransfer(msg.sender, deposit - requiredBuffer);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "../../registry/interfaces/IPCOLicenseParamsStore.sol";
import {CFAv1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";
import "./LibCFABasePCO.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library LibCFAPenaltyBid {
    using CFAv1Library for CFAv1Library.InitData;
    using SafeERC20 for ISuperToken;

    bytes32 private constant STORAGE_POSITION_OUT_BID =
        keccak256(
            "diamond.standard.diamond.storage.LibCFAPenaltyBid.pendingBid"
        );

    struct Bid {
        uint256 timestamp;
        address bidder;
        int96 contributionRate;
        uint256 perSecondFeeNumerator;
        uint256 perSecondFeeDenominator;
        uint256 forSalePrice;
        bytes contentHash;
    }

    /// @notice Emitted when for sale price is updated
    event BidPlaced(
        address indexed _bidder,
        int96 contributionRate,
        uint256 forSalePrice
    );

    function pendingBid() internal pure returns (Bid storage ds) {
        bytes32 position = STORAGE_POSITION_OUT_BID;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            ds.slot := position
        }
    }

    /// @dev From ConstantFlowAgreementV1

    enum FlowChangeType {
        CREATE_FLOW,
        UPDATE_FLOW,
        DELETE_FLOW
    }

    function _getBooleanFlowOperatorPermissions(
        uint8 permissions,
        FlowChangeType flowChangeType
    ) internal pure returns (bool flowchangeTypeAllowed) {
        if (flowChangeType == FlowChangeType.CREATE_FLOW) {
            flowchangeTypeAllowed = permissions & uint8(1) == 1;
        } else if (flowChangeType == FlowChangeType.UPDATE_FLOW) {
            flowchangeTypeAllowed = (permissions >> 1) & uint8(1) == 1;
        } else {
            /** flowChangeType === FlowChangeType.DELETE_FLOW */
            flowchangeTypeAllowed = (permissions >> 2) & uint8(1) == 1;
        }
    }

    /// @notice Calculate the penalty needed for the pending bid to be rejected
    function _calculatePenalty() internal view returns (uint256) {
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        Bid storage _pendingBid = pendingBid();

        uint256 penaltyNumerator = ds.paramsStore.getPenaltyNumerator();
        uint256 penaltyDenominator = ds.paramsStore.getPenaltyDenominator();

        uint256 value = (_pendingBid.forSalePrice * penaltyNumerator) /
            penaltyDenominator;

        return value;
    }

    function _clearPendingBid() internal {
        Bid storage _pendingBid = pendingBid();
        _pendingBid.contributionRate = 0;
        _pendingBid.timestamp = block.timestamp;
    }

    /**
     * @notice Place a bid to purchase license as msg.sender
     * @param newContributionRate New contribution rate for bid
     * @param newForSalePrice Intented new for sale price. Must be within rounding bounds of newContributionRate
     * @param contentHash Content hash for parcel content
     */
    function _placeBid(
        int96 newContributionRate,
        uint256 newForSalePrice,
        bytes memory contentHash
    ) internal {
        Bid storage _pendingBid = pendingBid();

        // Check if pending bid exists
        require(
            _pendingBid.contributionRate <= 0,
            "LibCFAPenaltyBid: Pending bid already exists"
        );

        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        LibCFABasePCO.DiamondCFAStorage storage cs = LibCFABasePCO.cfaStorage();

        uint256 perSecondFeeNumerator = ds
            .paramsStore
            .getPerSecondFeeNumerator();
        uint256 perSecondFeeDenominator = ds
            .paramsStore
            .getPerSecondFeeDenominator();

        // Check for sale price
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();

        require(
            LibCFABasePCO._checkForSalePrice(
                newForSalePrice,
                newContributionRate,
                perSecondFeeNumerator,
                perSecondFeeDenominator
            ),
            "LibCFAPenaltyBid: Incorrect for sale price"
        );

        require(
            newContributionRate >= _currentBid.contributionRate,
            "LibCFAPenaltyBid: New contribution rate is not high enough"
        );

        // Check operator permissions
        (, uint8 permissions, int96 flowRateAllowance) = cs
            .cfaV1
            .cfa
            .getFlowOperatorData(
                ds.paramsStore.getPaymentToken(),
                msg.sender,
                address(this)
            );

        require(
            _getBooleanFlowOperatorPermissions(
                permissions,
                FlowChangeType.CREATE_FLOW
            ),
            "LibCFAPenaltyBid: CREATE_FLOW permission not granted"
        );
        require(
            flowRateAllowance >= newContributionRate,
            "LibCFAPenaltyBid: CREATE_FLOW permission does not have enough allowance"
        );

        // Save pending bid
        _pendingBid.timestamp = block.timestamp;
        _pendingBid.bidder = msg.sender;
        _pendingBid.contributionRate = newContributionRate;
        _pendingBid.perSecondFeeNumerator = perSecondFeeNumerator;
        _pendingBid.perSecondFeeDenominator = perSecondFeeDenominator;
        _pendingBid.forSalePrice = newForSalePrice;
        _pendingBid.contentHash = contentHash;

        emit BidPlaced(msg.sender, newContributionRate, newForSalePrice);

        // Collect deposit
        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();
        uint256 requiredBuffer = cs.cfaV1.cfa.getDepositRequiredForFlowRate(
            paymentToken,
            newContributionRate
        );
        uint256 requiredCollateral = requiredBuffer + newForSalePrice;
        paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            requiredCollateral
        );
    }

    /// @notice Trigger transfer of license
    function _triggerTransfer() internal {
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        LibCFABasePCO.DiamondCFAStorage storage cs = LibCFABasePCO.cfaStorage();
        LibCFABasePCO.Bid storage _currentBid = LibCFABasePCO._currentBid();
        LibCFABasePCO.Bid memory oldCurrentBid = _currentBid;
        Bid memory _pendingBid = pendingBid();
        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();

        // Update current bid
        _currentBid.timestamp = _pendingBid.timestamp;
        _currentBid.bidder = _pendingBid.bidder;
        _currentBid.contributionRate = _pendingBid.contributionRate;
        _currentBid.perSecondFeeNumerator = _pendingBid.perSecondFeeNumerator;
        _currentBid.perSecondFeeDenominator = _pendingBid
            .perSecondFeeDenominator;
        _currentBid.forSalePrice = _pendingBid.forSalePrice;
        _currentBid.contentHash = _pendingBid.contentHash;

        // Update pending bid
        _clearPendingBid();

        (int256 availableBalance, uint256 deposit, , ) = paymentToken
            .realtimeBalanceOfNow(address(this));
        uint256 remainingBalance = 0;
        if (availableBalance + int256(deposit) >= 0) {
            remainingBalance = uint256(availableBalance + int256(deposit));
        }
        uint256 newBuffer = cs.cfaV1.cfa.getDepositRequiredForFlowRate(
            paymentToken,
            _pendingBid.contributionRate
        );

        // Check if beneficiary flow needs to be deleted
        address beneficiary = address(LibCFABasePCO._getBeneficiary());
        if (remainingBalance < newBuffer) {
            cs.cfaV1.deleteFlow(address(this), beneficiary, paymentToken);

            (availableBalance, deposit, , ) = paymentToken.realtimeBalanceOfNow(
                address(this)
            );
            remainingBalance = uint256(availableBalance + int256(deposit));
        }

        // Create bidder flow
        if (remainingBalance >= newBuffer) {
            /* solhint-disable no-empty-blocks */
            try
                cs.cfaV1.host.callAgreement(
                    cs.cfaV1.cfa,
                    abi.encodeCall(
                        cs.cfaV1.cfa.createFlowByOperator,
                        (
                            paymentToken,
                            _pendingBid.bidder,
                            address(this),
                            _pendingBid.contributionRate,
                            new bytes(0)
                        )
                    ),
                    new bytes(0)
                )
            {} catch {}
            /* solhint-enable no-empty-blocks  */
        }

        // Update beneficiary flow
        (, int96 flowRate, , ) = cs.cfaV1.cfa.getFlow(
            paymentToken,
            address(this),
            beneficiary
        );
        if (flowRate > 0) {
            cs.cfaV1.updateFlow(
                beneficiary,
                paymentToken,
                _pendingBid.contributionRate
            );
        } else if (remainingBalance >= newBuffer) {
            LibCFABasePCO._createBeneficiaryFlow(_pendingBid.contributionRate);
        }

        {
            // Transfer payments
            uint256 withdrawToBidder = 0;
            uint256 withdrawToPayer = 0;

            if (remainingBalance > newBuffer) {
                // Keep full newBuffer
                remainingBalance -= newBuffer;
                uint256 bidderPayment = _pendingBid.forSalePrice -
                    oldCurrentBid.forSalePrice;
                if (remainingBalance > bidderPayment) {
                    // Transfer bidder full payment
                    withdrawToBidder = bidderPayment;
                    remainingBalance -= withdrawToBidder;

                    // Transfer remaining to payer
                    withdrawToPayer = remainingBalance;
                } else {
                    // Transfer remaining to bidder
                    withdrawToBidder = remainingBalance;
                }
            }

            if (withdrawToBidder > 0) {
                paymentToken.safeTransfer(_pendingBid.bidder, withdrawToBidder);
            }
            if (withdrawToPayer > 0) {
                paymentToken.safeTransfer(
                    oldCurrentBid.bidder,
                    withdrawToPayer
                );
            }
        }

        // Delete payer flow (reentrancy on potential SuperApp callback)
        (, flowRate, , ) = cs.cfaV1.cfa.getFlow(
            paymentToken,
            oldCurrentBid.bidder,
            address(this)
        );
        if (flowRate > 0) {
            cs.cfaV1.deleteFlow(
                oldCurrentBid.bidder,
                address(this),
                paymentToken
            );
        }

        // Transfer license (reentrancy on ERC721 transfer)
        ds.license.safeTransferFrom(
            oldCurrentBid.bidder,
            _pendingBid.bidder,
            ds.licenseId
        );
    }

    /// @notice Reject Bid
    function _rejectBid(int96 newContributionRate, uint256 newForSalePrice)
        internal
    {
        LibCFABasePCO.DiamondStorage storage ds = LibCFABasePCO
            .diamondStorage();
        LibCFABasePCO.DiamondCFAStorage storage cs = LibCFABasePCO.cfaStorage();
        Bid memory _pendingBid = pendingBid();

        ISuperToken paymentToken = ds.paramsStore.getPaymentToken();

        uint256 penaltyAmount = _calculatePenalty();

        require(
            newContributionRate >= _pendingBid.contributionRate,
            "LibCFAPenaltyBid: New contribution rate must be >= pending bid"
        );

        _clearPendingBid();

        // Transfer payments
        (int256 availableBalance, uint256 deposit, , ) = paymentToken
            .realtimeBalanceOfNow(address(this));
        uint256 remainingBalance = 0;
        if (availableBalance + int256(deposit) >= 0) {
            remainingBalance = uint256(availableBalance + int256(deposit));
        }
        uint256 newBuffer = cs.cfaV1.cfa.getDepositRequiredForFlowRate(
            paymentToken,
            _pendingBid.contributionRate
        );

        // Check if beneficiary flow needs to be deleted
        address beneficiary = address(LibCFABasePCO._getBeneficiary());
        if (availableBalance < 0) {
            cs.cfaV1.deleteFlow(address(this), beneficiary, paymentToken);

            (availableBalance, deposit, , ) = paymentToken.realtimeBalanceOfNow(
                address(this)
            );
            remainingBalance = uint256(availableBalance + int256(deposit));
        }

        LibCFABasePCO._editBid(newContributionRate, newForSalePrice);

        uint256 withdrawToBidder = _pendingBid.forSalePrice + newBuffer;
        uint256 withdrawToPayer = 0;
        uint256 depositFromPayer = 0;
        if (remainingBalance > deposit) {
            // Keep full deposit
            remainingBalance -= deposit;
            if (remainingBalance > withdrawToBidder) {
                // Transfer bidder full payment
                remainingBalance -= withdrawToBidder;

                // Transfer remaining to payer
                withdrawToPayer = remainingBalance;
            } else {
                // Transfer depleted amount from payer
                depositFromPayer = withdrawToBidder - remainingBalance;
            }
        } else {
            depositFromPayer = withdrawToBidder;
        }

        // msg.sender is _currentBid.bidder due to onlyPayer modifier check
        if (depositFromPayer > 0) {
            paymentToken.safeTransferFrom(
                msg.sender,
                address(this),
                depositFromPayer
            );
        }
        paymentToken.safeTransfer(_pendingBid.bidder, withdrawToBidder);
        if (withdrawToPayer > 0) {
            paymentToken.safeTransfer(msg.sender, withdrawToPayer);
        }
        paymentToken.safeTransferFrom(
            msg.sender,
            address(LibCFABasePCO._getBeneficiary()),
            penaltyAmount
        );
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import "../../beneficiary/interfaces/ICFABeneficiary.sol";

interface IPCOLicenseParamsStore {
    /**
     * @notice Initialize.
     *      - Must be the contract owner
     * @param beneficiary Beneficiary of funds.
     * @param paymentToken Payment token.
     * @param host Superfluid host
     * @param perSecondFeeNumerator The numerator of the network-wide per second contribution fee.
     * @param perSecondFeeDenominator The denominator of the network-wide per second contribution fee.
     * @param penaltyNumerator The numerator of the penalty to pay to reject a bid.
     * @param penaltyDenominator The denominator of the penalty to pay to reject a bid.
     * @param bidPeriodLengthInSeconds Bid period length in seconds
     * @param reclaimAuctionLength when the required bid amount reaches its minimum value.
     */
    function initializeParams(
        ICFABeneficiary beneficiary,
        ISuperToken paymentToken,
        ISuperfluid host,
        uint256 perSecondFeeNumerator,
        uint256 perSecondFeeDenominator,
        uint256 penaltyNumerator,
        uint256 penaltyDenominator,
        uint256 bidPeriodLengthInSeconds,
        uint256 reclaimAuctionLength,
        uint256 minForSalePrice
    ) external;

    /// @notice Superfluid Host
    function getHost() external view returns (ISuperfluid);

    /// @notice Set Superfluid Host
    function setHost(ISuperfluid host) external;

    /// @notice Payment token
    function getPaymentToken() external view returns (ISuperToken);

    /// @notice Set Payment Token
    function setPaymentToken(ISuperToken paymentToken) external;

    /// @notice Beneficiary
    function getBeneficiary() external view returns (ICFABeneficiary);

    /// @notice Set Beneficiary
    function setBeneficiary(ICFABeneficiary beneficiary) external;

    /// @notice The numerator of the network-wide per second contribution fee.
    function getPerSecondFeeNumerator() external view returns (uint256);

    /// @notice Set Per Second Fee Numerator
    function setPerSecondFeeNumerator(uint256 perSecondFeeNumerator) external;

    /// @notice The denominator of the network-wide per second contribution fee.
    function getPerSecondFeeDenominator() external view returns (uint256);

    /// @notice Set Per Second Fee Denominator
    function setPerSecondFeeDenominator(uint256 perSecondFeeDenominator)
        external;

    /// @notice The numerator of the penalty rate.
    function getPenaltyNumerator() external view returns (uint256);

    /// @notice Set Penalty Numerator
    function setPenaltyNumerator(uint256 penaltyNumerator) external;

    /// @notice The denominator of the penalty rate.
    function getPenaltyDenominator() external view returns (uint256);

    /// @notice Set Penalty Denominator
    function setPenaltyDenominator(uint256 penaltyDenominator) external;

    /// @notice the final/minimum required bid reached and maintained at the end of the auction.
    function getReclaimAuctionLength() external view returns (uint256);

    /// @notice Set Reclaim Auction Length
    function setReclaimAuctionLength(uint256 reclaimAuctionLength) external;

    /// @notice Bid period length in seconds
    function getBidPeriodLengthInSeconds() external view returns (uint256);

    /// @notice Set Bid Period Length in seconds
    function setBidPeriodLengthInSeconds(uint256 bidPeriodLengthInSeconds)
        external;

    /// @notice Minimum for sale price
    function getMinForSalePrice() external view returns (uint256);

    /// @notice Set minimum for sale price
    function setMinForSalePrice(uint256 minForSalePrice) external;
}