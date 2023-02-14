// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (security/ReentrancyGuard.sol)

pragma solidity ^0.8.0;

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
abstract contract ReentrancyGuard {
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

    constructor() {
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
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";

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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/Math.sol)

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
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator
    ) internal pure returns (uint256 result) {
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
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1);

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
    function mulDiv(
        uint256 x,
        uint256 y,
        uint256 denominator,
        Rounding rounding
    ) internal pure returns (uint256) {
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
            if (value >= 10**64) {
                value /= 10**64;
                result += 64;
            }
            if (value >= 10**32) {
                value /= 10**32;
                result += 32;
            }
            if (value >= 10**16) {
                value /= 10**16;
                result += 16;
            }
            if (value >= 10**8) {
                value /= 10**8;
                result += 8;
            }
            if (value >= 10**4) {
                value /= 10**4;
                result += 4;
            }
            if (value >= 10**2) {
                value /= 10**2;
                result += 2;
            }
            if (value >= 10**1) {
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
            return result + (rounding == Rounding.Up && 10**result < value ? 1 : 0);
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
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result * 8) < value ? 1 : 0);
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (utils/math/SafeMath.sol)

pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is generally not needed starting with Solidity 0.8, since the compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableMap.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableMap.js.

pragma solidity ^0.8.0;

import "./EnumerableSet.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * The following map types are supported:
 *
 * - `uint256 -> address` (`UintToAddressMap`) since v3.0.0
 * - `address -> uint256` (`AddressToUintMap`) since v4.6.0
 * - `bytes32 -> bytes32` (`Bytes32ToBytes32Map`) since v4.6.0
 * - `uint256 -> uint256` (`UintToUintMap`) since v4.7.0
 * - `bytes32 -> uint256` (`Bytes32ToUintMap`) since v4.7.0
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableMap, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableMap.
 * ====
 */
library EnumerableMap {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Bytes32ToBytes32Map {
        // Storage of keys
        EnumerableSet.Bytes32Set _keys;
        mapping(bytes32 => bytes32) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        Bytes32ToBytes32Map storage map,
        bytes32 key,
        bytes32 value
    ) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToBytes32Map storage map, uint256 index) internal view returns (bytes32, bytes32) {
        bytes32 key = map._keys.at(index);
        return (key, map._values[key]);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool, bytes32) {
        bytes32 value = map._values[key];
        if (value == bytes32(0)) {
            return (contains(map, key), bytes32(0));
        } else {
            return (true, value);
        }
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), "EnumerableMap: nonexistent key");
        return value;
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToBytes32Map storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), errorMessage);
        return value;
    }

    // UintToUintMap

    struct UintToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        UintToUintMap storage map,
        uint256 key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToUintMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToUintMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToUintMap storage map, uint256 index) internal view returns (uint256, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToUintMap storage map, uint256 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key)));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        UintToUintMap storage map,
        uint256 key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key), errorMessage));
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        UintToAddressMap storage map,
        uint256 key,
        address value
    ) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        UintToAddressMap storage map,
        uint256 key,
        string memory errorMessage
    ) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key), errorMessage))));
    }

    // AddressToUintMap

    struct AddressToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        AddressToUintMap storage map,
        address key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToUintMap storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToUintMap storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToUintMap storage map, uint256 index) internal view returns (address, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (address(uint160(uint256(key))), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToUintMap storage map, address key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToUintMap storage map, address key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        AddressToUintMap storage map,
        address key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key))), errorMessage));
    }

    // Bytes32ToUintMap

    struct Bytes32ToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(
        Bytes32ToUintMap storage map,
        bytes32 key,
        uint256 value
    ) internal returns (bool) {
        return set(map._inner, key, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToUintMap storage map, bytes32 key) internal returns (bool) {
        return remove(map._inner, key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool) {
        return contains(map._inner, key);
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(Bytes32ToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the set. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToUintMap storage map, uint256 index) internal view returns (bytes32, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (key, uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, key);
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToUintMap storage map, bytes32 key) internal view returns (uint256) {
        return uint256(get(map._inner, key));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToUintMap storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, key, errorMessage));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

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
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
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
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
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
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
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

        /// @solidity memory-safe-assembly
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
     * @dev Returns the number of values in the set. O(1).
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

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
struct ActionInfo {
  uint16 actionId;
  address latest;
  address[] whitelist;
  address[] blacklist;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import '@openzeppelin/contracts/utils/structs/EnumerableMap.sol';

import './Ownable.sol';
import './ActionInfo.sol';

contract EternalStorage is Ownable {
  address internal writer;

  modifier onlyWriter() {
    require(msg.sender == writer);
    _;
  }

  constructor(address owner, address initialWriter) Ownable(owner) {
    writer = initialWriter;
  }

  event StorageWriterChanged(address oldWriter, address newWriter);

  function getWriter() public view returns (address) {
    return writer;
  }

  function setWriter(address newWriter) public onlyOwner {
    emit StorageWriterChanged(writer, newWriter);
    writer = newWriter;
  }

  mapping(bytes32 => uint256) uIntStorage;
  mapping(bytes32 => string) stringStorage;
  mapping(bytes32 => address) addressStorage;
  mapping(bytes32 => bytes) bytesStorage;
  mapping(bytes32 => bool) boolStorage;
  mapping(bytes32 => int256) intStorage;

  using EnumerableMap for EnumerableMap.UintToAddressMap;
  using EnumerableMap for EnumerableMap.AddressToUintMap;
  using EnumerableMap for EnumerableMap.Bytes32ToBytes32Map;
  using EnumerableMap for EnumerableMap.UintToUintMap;
  using EnumerableMap for EnumerableMap.Bytes32ToUintMap;
  mapping(bytes32 => EnumerableMap.UintToAddressMap) enumerableMapUintToAddressMapStorage;
  mapping(bytes32 => EnumerableMap.AddressToUintMap) enumerableMapAddressToUintMapStorage;
  mapping(bytes32 => EnumerableMap.Bytes32ToBytes32Map) enumerableMapBytes32ToBytes32MapStorage;
  mapping(bytes32 => EnumerableMap.UintToUintMap) enumerableMapUintToUintMapStorage;
  mapping(bytes32 => EnumerableMap.Bytes32ToUintMap) enumerableMapBytes32ToUintMapStorage;

  // *** Getter Methods ***
  function getUint(bytes32 _key) external view returns (uint256) {
    return uIntStorage[_key];
  }

  function getString(bytes32 _key) external view returns (string memory) {
    return stringStorage[_key];
  }

  function getAddress(bytes32 _key) external view returns (address) {
    return addressStorage[_key];
  }

  function getBytes(bytes32 _key) external view returns (bytes memory) {
    return bytesStorage[_key];
  }

  function getBool(bytes32 _key) external view returns (bool) {
    return boolStorage[_key];
  }

  function getInt(bytes32 _key) external view returns (int256) {
    return intStorage[_key];
  }

  // *** Setter Methods ***
  function setUint(bytes32 _key, uint256 _value) external onlyWriter {
    uIntStorage[_key] = _value;
  }

  function setString(bytes32 _key, string memory _value) external onlyWriter {
    stringStorage[_key] = _value;
  }

  function setAddress(bytes32 _key, address _value) external {
    addressStorage[_key] = _value;
  }

  function setBytes(bytes32 _key, bytes memory _value) external onlyWriter {
    bytesStorage[_key] = _value;
  }

  function setBool(bytes32 _key, bool _value) external onlyWriter {
    boolStorage[_key] = _value;
  }

  function setInt(bytes32 _key, int256 _value) external onlyWriter {
    intStorage[_key] = _value;
  }

  // *** Delete Methods ***
  function deleteUint(bytes32 _key) external onlyWriter {
    delete uIntStorage[_key];
  }

  function deleteString(bytes32 _key) external onlyWriter {
    delete stringStorage[_key];
  }

  function deleteAddress(bytes32 _key) external onlyWriter {
    delete addressStorage[_key];
  }

  function deleteBytes(bytes32 _key) external onlyWriter {
    delete bytesStorage[_key];
  }

  function deleteBool(bytes32 _key) external onlyWriter {
    delete boolStorage[_key];
  }

  function deleteInt(bytes32 _key) external onlyWriter {
    delete intStorage[_key];
  }

  // enumerable get

  function getEnumerableMapUintToAddress(bytes32 _key1, uint256 _key2) external view returns (address) {
    return enumerableMapUintToAddressMapStorage[_key1].get(_key2);
  }

  function getEnumerableMapAddressToUint(bytes32 _key1, address _key2) external view returns (uint256) {
    return enumerableMapAddressToUintMapStorage[_key1].get(_key2);
  }

  function getEnumerableMapBytes32ToBytes32Map(bytes32 _key1, bytes32 _key2) external view returns (bytes32) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].get(_key2);
  }

  function getEnumerableMapUintToUintMap(bytes32 _key1, uint256 _key2) external view returns (uint256) {
    return enumerableMapUintToUintMapStorage[_key1].get(_key2);
  }

  function getEnumerableMapBytes32ToUintMap(bytes32 _key1, bytes32 _key2) external view returns (uint256) {
    return enumerableMapBytes32ToUintMapStorage[_key1].get(_key2);
  }

  // enumerable tryGet

  function tryGetEnumerableMapUintToAddress(bytes32 _key1, uint256 _key2) external view returns (bool, address) {
    return enumerableMapUintToAddressMapStorage[_key1].tryGet(_key2);
  }

  function tryGetEnumerableMapAddressToUint(bytes32 _key1, address _key2) external view returns (bool, uint256) {
    return enumerableMapAddressToUintMapStorage[_key1].tryGet(_key2);
  }

  function tryGetEnumerableMapBytes32ToBytes32Map(bytes32 _key1, bytes32 _key2) external view returns (bool, bytes32) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].tryGet(_key2);
  }

  function tryGetEnumerableMapUintToUintMap(bytes32 _key1, uint256 _key2) external view returns (bool, uint256) {
    return enumerableMapUintToUintMapStorage[_key1].tryGet(_key2);
  }

  function tryGetEnumerableMapBytes32ToUintMap(bytes32 _key1, bytes32 _key2) external view returns (bool, uint256) {
    return enumerableMapBytes32ToUintMapStorage[_key1].tryGet(_key2);
  }

  // enumerable set

  function setEnumerableMapUintToAddress(
    bytes32 _key1,
    uint256 _key2,
    address _value
  ) external onlyWriter returns (bool) {
    return enumerableMapUintToAddressMapStorage[_key1].set(_key2, _value);
  }

  function setEnumerableMapAddressToUint(
    bytes32 _key1,
    address _key2,
    uint256 _value
  ) external onlyWriter returns (bool) {
    return enumerableMapAddressToUintMapStorage[_key1].set(_key2, _value);
  }

  function setEnumerableMapBytes32ToBytes32Map(
    bytes32 _key1,
    bytes32 _key2,
    bytes32 _value
  ) external onlyWriter returns (bool) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].set(_key2, _value);
  }

  function setEnumerableMapUintToUintMap(
    bytes32 _key1,
    uint256 _key2,
    uint256 _value
  ) external onlyWriter returns (bool) {
    return enumerableMapUintToUintMapStorage[_key1].set(_key2, _value);
  }

  function setEnumerableMapBytes32ToUintMap(
    bytes32 _key1,
    bytes32 _key2,
    uint256 _value
  ) external onlyWriter returns (bool) {
    return enumerableMapBytes32ToUintMapStorage[_key1].set(_key2, _value);
  }

  // enumerable remove

  function removeEnumerableMapUintToAddress(bytes32 _key1, uint256 _key2) external onlyWriter {
    enumerableMapUintToAddressMapStorage[_key1].remove(_key2);
  }

  function removeEnumerableMapAddressToUint(bytes32 _key1, address _key2) external onlyWriter {
    enumerableMapAddressToUintMapStorage[_key1].remove(_key2);
  }

  function removeEnumerableMapBytes32ToBytes32Map(bytes32 _key1, bytes32 _key2) external onlyWriter {
    enumerableMapBytes32ToBytes32MapStorage[_key1].remove(_key2);
  }

  function removeEnumerableMapUintToUintMap(bytes32 _key1, uint256 _key2) external onlyWriter {
    enumerableMapUintToUintMapStorage[_key1].remove(_key2);
  }

  function removeEnumerableMapBytes32ToUintMap(bytes32 _key1, bytes32 _key2) external onlyWriter {
    enumerableMapBytes32ToUintMapStorage[_key1].remove(_key2);
  }

  // enumerable contains

  function containsEnumerableMapUintToAddress(bytes32 _key1, uint256 _key2) external view returns (bool) {
    return enumerableMapUintToAddressMapStorage[_key1].contains(_key2);
  }

  function containsEnumerableMapAddressToUint(bytes32 _key1, address _key2) external view returns (bool) {
    return enumerableMapAddressToUintMapStorage[_key1].contains(_key2);
  }

  function containsEnumerableMapBytes32ToBytes32Map(bytes32 _key1, bytes32 _key2) external view returns (bool) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].contains(_key2);
  }

  function containsEnumerableMapUintToUintMap(bytes32 _key1, uint256 _key2) external view returns (bool) {
    return enumerableMapUintToUintMapStorage[_key1].contains(_key2);
  }

  function containsEnumerableMapBytes32ToUintMap(bytes32 _key1, bytes32 _key2) external view returns (bool) {
    return enumerableMapBytes32ToUintMapStorage[_key1].contains(_key2);
  }

  // enumerable length

  function lengthEnumerableMapUintToAddress(bytes32 _key1) external view returns (uint256) {
    return enumerableMapUintToAddressMapStorage[_key1].length();
  }

  function lengthEnumerableMapAddressToUint(bytes32 _key1) external view returns (uint256) {
    return enumerableMapAddressToUintMapStorage[_key1].length();
  }

  function lengthEnumerableMapBytes32ToBytes32Map(bytes32 _key1) external view returns (uint256) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].length();
  }

  function lengthEnumerableMapUintToUintMap(bytes32 _key1) external view returns (uint256) {
    return enumerableMapUintToUintMapStorage[_key1].length();
  }

  function lengthEnumerableMapBytes32ToUintMap(bytes32 _key1) external view returns (uint256) {
    return enumerableMapBytes32ToUintMapStorage[_key1].length();
  }

  // enumerable at

  function atEnumerableMapUintToAddress(bytes32 _key1, uint256 _index) external view returns (uint256, address) {
    return enumerableMapUintToAddressMapStorage[_key1].at(_index);
  }

  function atEnumerableMapAddressToUint(bytes32 _key1, uint256 _index) external view returns (address, uint256) {
    return enumerableMapAddressToUintMapStorage[_key1].at(_index);
  }

  function atEnumerableMapBytes32ToBytes32Map(bytes32 _key1, uint256 _index) external view returns (bytes32, bytes32) {
    return enumerableMapBytes32ToBytes32MapStorage[_key1].at(_index);
  }

  function atEnumerableMapUintToUintMap(bytes32 _key1, uint256 _index) external view returns (uint256, uint256) {
    return enumerableMapUintToUintMapStorage[_key1].at(_index);
  }

  function atEnumerableMapBytes32ToUintMap(bytes32 _key1, uint256 _index) external view returns (bytes32, uint256) {
    return enumerableMapBytes32ToUintMapStorage[_key1].at(_index);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './Ownable.sol';

contract FreeMarketBase is Ownable {
  // TODO create getters
  address public eternalStorageAddress;
  address public upstreamAddress;
  bool public isUserProxy;

  constructor(
    address owner,
    address eternalStorage,
    address upstream,
    bool userProxy
  ) Ownable(owner) {
    eternalStorageAddress = eternalStorage;
    upstreamAddress = upstream;
    isUserProxy = userProxy;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './EternalStorage.sol';
import './Proxy.sol';
import './LibStorageWriter.sol';

contract FrontDoor is Proxy {
  constructor() Proxy(msg.sender, address(new EternalStorage(msg.sender, address(this))), address(0x0), false) {
    bytes32 key = keccak256(abi.encodePacked('frontDoor'));
    StorageWriter.setAddress(eternalStorageAddress, key, address(this));
  }

  event UpstreamChanged(address oldUpstream, address newUpstream);

  function setUpstream(address newUpstream) public onlyOwner {
    address oldUpstream = upstreamAddress;
    upstreamAddress = newUpstream;
    emit UpstreamChanged(oldUpstream, newUpstream);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './ActionInfo.sol';

interface IActionManager {
  /// @dev Associate a new address with an actionId
  function setActionAddress(uint16 actionId, address actionAddress) external; // onlyOwner

  /// @dev Retrieve the address associated with an actionId
  function getActionAddress(uint16 actionId) external view returns (address);

  /// @dev getActionCount getActionInfoAt together allow enumeration of all actions
  function getActionCount() external view returns (uint256);

  function getActionInfoAt(uint256 index) external view returns (ActionInfo memory);
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

interface IHasUpstream {
  function getUpstream() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IUserProxyManager {
  function createUserProxy() external;

  function getUserProxy() external view returns (address);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './model/AssetAmount.sol';
import './model/Workflow.sol';

interface IWorkflowRunner {
  function executeWorkflow(Workflow calldata workflow) external payable;

  function continueWorkflow(
    address userAddress,
    uint256 nonce,
    Workflow memory workflow,
    AssetAmount memory startingAsset
  ) external payable;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './model/Asset.sol';
import './model/AssetAmount.sol';
import './model/WorkflowStepResult.sol';

interface IWorkflowStep {
  function execute(
    // input assets paired with amounts of each
    AssetAmount[] calldata inputAssetAmounts,
    // expected output assets (amounts not known yet)
    Asset[] calldata outputAssets,
    // additional arguments specific to this step
    bytes calldata data
  ) external payable returns (WorkflowStepResult memory);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './model/Asset.sol';

library LibAsset {
  function encodeAsset(Asset memory asset) internal pure returns (uint256) {
    return encodeAsset(asset.assetType, asset.assetAddress);
  }

  function encodeAsset(AssetType assetType, address assetAddress) internal pure returns (uint256) {
    uint160 a1 = uint160(assetAddress);
    uint256 a2 = uint256(a1);
    uint256 a3 = a2 << 16;
    uint256 t1 = uint256(assetType);
    uint256 a4 = a3 | t1;
    return a4;
    // return (uint256(uint160(assetAddress)) << 16) & uint256(assetType);
  }

  function decodeAsset(uint256 assetInt) internal pure returns (Asset memory) {
    AssetType assetType = AssetType(uint16(assetInt));
    address addr = address(uint160(assetInt >> 16));
    return Asset(assetType, addr);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import './model/AssetAmount.sol';
import './LibAsset.sol';

using Strings for uint256;

library LibAssetBalances {
  uint8 constant MAX_ENTRIES = 10;

  struct AssetBalance {
    uint256 asset;
    uint256 balance;
  }

  struct AssetBalances {
    AssetBalance[MAX_ENTRIES] entries;
    uint8 end;
  }

  function getAssetBalance(AssetBalances memory entrySet, Asset memory asset) internal pure returns (uint256) {
    AssetBalance[MAX_ENTRIES] memory entries = entrySet.entries;
    uint256 assetAsInt = LibAsset.encodeAsset(asset);
    for (uint16 i = 0; i < entrySet.end; ++i) {
      if (entries[i].asset == assetAsInt) {
        return entries[i].balance;
      }
    }
    return 0;
  }

  function credit(
    AssetBalances memory entrySet,
    uint256 assetAsInt,
    uint256 amount
  ) internal pure {
    if (amount > 0) {
      uint256 index = getAssetIndex(entrySet, assetAsInt);
      (bool success, uint256 newBalance) = SafeMath.tryAdd(entrySet.entries[index].balance, amount);
      if (!success) {
        revertArithmetic('credit', assetAsInt, entrySet.entries[index].balance, amount);
      }
      updateBalance(entrySet, index, newBalance);
    }
  }

  function debit(
    AssetBalances memory entrySet,
    uint256 assetAsInt,
    uint256 amount
  ) internal pure {
    if (amount > 0) {
      uint256 index = getAssetIndex(entrySet, assetAsInt);
      (bool success, uint256 newBalance) = SafeMath.trySub(entrySet.entries[index].balance, amount);
      if (!success) {
        revertArithmetic('debit', assetAsInt, entrySet.entries[index].balance, amount);
      }
      updateBalance(entrySet, index, newBalance);
    }
  }

  function revertArithmetic(string memory op, uint256 assetAsInt, uint256 a, uint256 b) internal pure {
    Asset memory asset = LibAsset.decodeAsset(assetAsInt);       
    revert(string.concat(
      op,
      ' assetType=', 
      uint256(asset.assetType).toString(),
      ' assetAddress=', 
      uint256(uint160(asset.assetAddress)).toHexString(),
      ' values ',
      a.toString(), 
      ', ', 
      b.toString()));
  }

  function credit(
    AssetBalances memory entrySet,
    Asset memory asset,
    uint256 amount
  ) internal pure {
    credit(entrySet, LibAsset.encodeAsset(asset), amount);
  }

  function debit(
    AssetBalances memory entrySet,
    Asset memory asset,
    uint256 amount
  ) internal pure {
    debit(entrySet, LibAsset.encodeAsset(asset), amount);
  }

  function updateBalance(
    AssetBalances memory entrySet,
    uint256 index,
    uint256 newBalance
  ) internal pure returns (uint256) {
    if (newBalance == 0) {
      removeAt(entrySet, index);
    } else {
      entrySet.entries[index].balance = newBalance;
    }
    return newBalance;
  }

  function removeAt(AssetBalances memory entrySet, uint256 index) internal pure {
    entrySet.entries[index] = entrySet.entries[entrySet.end - 1];
    --entrySet.end;
  }

  function getAssetIndex(AssetBalances memory entrySet, Asset memory asset) internal pure returns (uint256) {
    uint256 assetAsInt = LibAsset.encodeAsset(asset);
    return getAssetIndex(entrySet, assetAsInt);
  }

  function getAssetIndex(AssetBalances memory entrySet, uint256 assetAsInt) internal pure returns (uint256) {
    for (uint256 i = 0; i < entrySet.end; ++i) {
      if (entrySet.entries[i].asset == assetAsInt) {
        return i;
      }
    }
    require(entrySet.end < MAX_ENTRIES, 'too many token balances');
    entrySet.entries[entrySet.end] = AssetBalance(assetAsInt, 0);
    return entrySet.end++;
  }

  function getAssetCount(AssetBalances memory entrySet) internal pure returns (uint8) {
    return entrySet.end;
  }

  function getAssetAt(AssetBalances memory entrySet, uint8 index) internal pure returns (AssetAmount memory) {
    require(index < entrySet.end, 'index out of bounds while accessing asset balances');
    Asset memory a = LibAsset.decodeAsset(entrySet.entries[index].asset);
    return AssetAmount(a, entrySet.entries[index].balance);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// percents have 4 decimals of precision, so:
// 100% is represented as 1000000 (100.0000%)
// 1% is represented as 1000
// 1 basis point (1/100th of a percent) is 10
// the smallest possible percentage is 1/10th of a basis point
library LibPercent {
  function percentageOf(uint256 value, uint256 percent) internal pure returns (uint256) {
    require(0 <= percent && percent <= 1000000, 'percent must be between 0 and 1000000');
    uint256 x = value * percent;
    return x / 1000000;
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

library StorageWriter {
  // *** Setter Methods ***
  function setUint(
    address storageAddr,
    bytes32 key,
    uint256 value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setUint(bytes32,uint256)', key, value));
    require(success, string(returnData));
  }

  function setString(
    address storageAddr,
    bytes32 key,
    string memory value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(
      abi.encodeWithSignature('setString(bytes32,string memory)', key, value)
    );
    require(success, string(returnData));
  }

  function setAddress(
    address storageAddr,
    bytes32 key,
    address value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setAddress(bytes32,address)', key, value));
    require(success, string(returnData));
  }

  function setBytes(
    address storageAddr,
    bytes32 key,
    bytes memory value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(
      abi.encodeWithSignature('setBytes(bytes32,bytes memory)', key, value)
    );
    require(success, string(returnData));
  }

  function setBool(
    address storageAddr,
    bytes32 key,
    bool value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setBool(bytes32,bool)', key, value));
    require(success, string(returnData));
  }

  function setInt(
    address storageAddr,
    bytes32 key,
    int256 value
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setInt(bytes32,int256)', key, value));
    require(success, string(returnData));
  }

  // *** Delete Methods ***
  function deleteUint(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('deleteUint(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function deleteString(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setString(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function deleteAddress(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setString(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function deleteBytes(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setString(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function deleteBool(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setString(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function deleteInt(address storageAddr, bytes32 key) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(abi.encodeWithSignature('setString(bytes32,string memory)', key));
    require(success, string(returnData));
  }

  function setActionAddress(
    address storageAddr,
    uint16 actionId,
    address actionAddress
  ) internal {
    (bool success, bytes memory returnData) = storageAddr.delegatecall(
      abi.encodeWithSignature('setActionAddress(uint16,address)', actionId, actionAddress)
    );
    require(success, string(returnData));
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract Ownable {
  address payable public owner;

  constructor(address initialOwner) {
    owner = payable(initialOwner);
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  event LogNewOwner(address sender, address newOwner);

  function setOwner(address payable newOwner) external onlyOwner {
    require(newOwner != address(0));
    owner = newOwner;
    emit LogNewOwner(msg.sender, newOwner);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './IHasUpstream.sol';
import './FreeMarketBase.sol';

contract Proxy is FreeMarketBase, IHasUpstream {
  constructor(
    address owner,
    address storageAddress,
    address upstream,
    bool userProxy
  ) FreeMarketBase(owner, storageAddress, upstream, userProxy) {}

  function getUpstream() external view virtual returns (address) {
    return upstreamAddress;
  }

  /// @dev this forwards all calls generically to upstream, only the owner can invoke this
  fallback() external payable {
    // enforce owner authz in upstream
    // require(owner == msg.sender);
    _delegate(this.getUpstream());
  }

  /// @dev this allows this contract to receive ETH
  receive() external payable {
    // noop
  }

  /**
   * @dev Delegates execution to an implementation contract.
   * This is a low level function that doesn't return to its internal call site.
   * It will return to the external caller whatever the implementation returns.
   */
  function _delegate(address upstr) internal {
    assembly {
      // Copy msg.data. We take full control of memory in this inline assembly
      // block because it will not return to Solidity code. We overwrite the
      // Solidity scratch pad at memory position 0.
      calldatacopy(0, 0, calldatasize())
      // Call the implementation.
      // out and outsize are 0 because we don't know the size yet.
      let result := delegatecall(gas(), upstr, 0, calldatasize(), 0, 0)
      // Copy the returned data.
      returndatacopy(0, 0, returndatasize())
      switch result
      // delegatecall returns 0 on error.
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
      // let ptr := mload(0x40)
      // calldatacopy(ptr, 0, calldatasize())
      // let result := delegatecall(gas(), implementation, ptr, calldatasize(), 0, 0)
      // let size := returndatasize()
      // returndatacopy(ptr, 0, size)
      // switch result
      // case 0 {
      //   revert(ptr, size)
      // }
      // default {
      //   return(ptr, size)
      // }
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import './IHasUpstream.sol';
import './Proxy.sol';

contract UserProxy is Proxy {
  constructor(
    address owner,
    address eternalStorage,
    address frontDoor
  ) Proxy(owner, eternalStorage, frontDoor, true) {}

  function getUpstream() external view override returns (address) {
    IHasUpstream frontDoor = IHasUpstream(upstreamAddress);
    return frontDoor.getUpstream();
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

import './model/Workflow.sol';
import './FrontDoor.sol';
import './IWorkflowRunner.sol';
import './IActionManager.sol';
import './IUserProxyManager.sol';
import './UserProxy.sol';
import './LibAssetBalances.sol';
import './LibStorageWriter.sol';
import './EternalStorage.sol';
import './IWorkflowStep.sol';
import './LibAsset.sol';
import './LibPercent.sol';

contract WorkflowRunner is
  FreeMarketBase,
  ReentrancyGuard,
  IWorkflowRunner, /*IUserProxyManager,*/
  IActionManager
{
  constructor(address payable frontDoorAddress)
    FreeMarketBase(
      msg.sender, // owner
      FrontDoor(frontDoorAddress).eternalStorageAddress(), // eternal storage address
      address(0), // upstream (this doesn't have one)
      false // isUserProxy
    )
  {}

  // function createUserProxy() external {
  //   EternalStorage es = EternalStorage(eternalStorageAddress);
  //   bytes32 key = getUserProxyKey('userProxies', msg.sender);
  //   address currentAddress = es.getAddress(key);
  //   require(currentAddress != address(0x0000000000000000), 'user proxy already exists');
  //   key = keccak256(abi.encodePacked('frontDoor'));
  //   address frontDoorAddress = es.getAddress(key);
  //   UserProxy newUserProxy = new UserProxy(payable(msg.sender), eternalStorageAddress, frontDoorAddress);
  //   address userProxyAddress = address(newUserProxy);
  //   es.setAddress(key, userProxyAddress);
  // }

  // latestActionAddresses maps actionId to latest and greatest version of that action
  bytes32 constant latestActionAddresses = 0xc94d198e6194ea38dbd900920351d7f8e6c6d85b1d3b803fb93c54be008e11fd; // keccak256('latestActionAddresses')

  event ActionAddressSetEvent(uint16 actionId, address actionAddress);

  function getActionWhitelistKey(uint16 actionId) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('actionWhiteList', actionId));
  }

  function getActionBlacklistKey(uint16 actionId) internal pure returns (bytes32) {
    return keccak256(abi.encodePacked('actionBlackList', actionId));
  }

  function setActionAddress(uint16 actionId, address actionAddress) external onlyOwner {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    eternalStorage.setEnumerableMapUintToAddress(latestActionAddresses, actionId, actionAddress);
    // using the white list map like a set, we only care about the keys
    eternalStorage.setEnumerableMapAddressToUint(getActionWhitelistKey(actionId), actionAddress, 0);
    eternalStorage.removeEnumerableMapAddressToUint(getActionBlacklistKey(actionId), actionAddress);
    emit ActionAddressSetEvent(actionId, actionAddress);
  }

  function removeActionAddress(uint16 actionId, address actionAddress) external onlyOwner {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    address latest = eternalStorage.getEnumerableMapUintToAddress(latestActionAddresses, actionId);
    require(actionAddress != latest, 'cannot remove latest action address');
    eternalStorage.setEnumerableMapAddressToUint(getActionBlacklistKey(actionId), actionAddress, 0);
    eternalStorage.removeEnumerableMapAddressToUint(getActionWhitelistKey(actionId), actionAddress);
    emit ActionAddressSetEvent(actionId, actionAddress);
  }

  function getActionAddress(uint16 actionId) external view returns (address) {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    return eternalStorage.getEnumerableMapUintToAddress(latestActionAddresses, actionId);
  }

  function getActionAddressInternal(uint16 actionId) internal view returns (address) {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    return eternalStorage.getEnumerableMapUintToAddress(latestActionAddresses, actionId);
  }

  function getActionCount() external view returns (uint256) {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    return eternalStorage.lengthEnumerableMapUintToAddress(latestActionAddresses);
  }

  function getActionInfoAt(uint256 index) public view returns (ActionInfo memory) {
    EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
    (uint256 actionId, address actionAddress) = eternalStorage.atEnumerableMapUintToAddress(latestActionAddresses, index);

    bytes32 whitelistKey = getActionWhitelistKey(uint16(actionId));
    uint256 whitelistCount = eternalStorage.lengthEnumerableMapAddressToUint(whitelistKey);
    address[] memory whitelist = new address[](whitelistCount);
    for (uint256 i = 0; i < whitelistCount; ++i) {
      (address whitelistedAddress, ) = eternalStorage.atEnumerableMapAddressToUint(whitelistKey, i);
      whitelist[i] = whitelistedAddress;
    }

    bytes32 blacklistKey = getActionBlacklistKey(uint16(actionId));
    uint256 blacklistCount = eternalStorage.lengthEnumerableMapAddressToUint(blacklistKey);
    address[] memory blacklist = new address[](blacklistCount);
    for (uint256 i = 0; i < blacklistCount; ++i) {
      (address blacklistedAddress, ) = eternalStorage.atEnumerableMapAddressToUint(blacklistKey, i);
      blacklist[i] = blacklistedAddress;
    }

    return ActionInfo(uint16(actionId), actionAddress, whitelist, blacklist);
  }

  // function getUserProxyKey(string memory category, address addr) internal pure returns (bytes32) {
  //   return keccak256(abi.encodePacked(category, addr));
  // }

  // function getUserProxy() external view returns (address) {
  //   EternalStorage eternalStorage = EternalStorage(eternalStorageAddress);
  //   bytes32 key = getUserProxyKey('userProxies', msg.sender);
  //   return eternalStorage.getAddress(key);
  // }

  // event  (string msg, uint256 number);
  event WorkflowExecution(address sender, Workflow workflow);
  event WorkflowStepExecution(uint16 stepIndex, WorkflowStep step, uint16 actionId, address actionAddress, AssetAmount[] assetAmounts);
  event WorkflowStepResultEvent(WorkflowStepResult result);
  event RemainingAsset(Asset asset, uint256 totalAmount, uint256 feeAmount, uint256 userAmount);
  using LibAssetBalances for LibAssetBalances.AssetBalances;

  function executeWorkflow(Workflow calldata workflow) external payable nonReentrant {
    AssetAmount memory startingAssets = AssetAmount(Asset(AssetType.Native, address(0)), 0);
    executeWorkflow(msg.sender, workflow, startingAssets);
  }

  function executeWorkflow(
    address userAddress,
    Workflow memory workflow,
    AssetAmount memory startingAsset
  ) internal {
    emit WorkflowExecution(userAddress, workflow);
    // workflow starts on the step with index 0
    uint16 currentStepIndex = 0;
    // used to keep track of asset balances
    LibAssetBalances.AssetBalances memory assetBalances;
    // credit ETH if sent with this call
    if (msg.value != 0) {
      // TODO add event
      assetBalances.credit(0, uint256(msg.value));
    }
    // credit any starting assets (if this is a continutation workflow with assets sent by a bridge)
    if (startingAsset.amount > 0) {
      assetBalances.credit(startingAsset.asset, startingAsset.amount);
    }
    while (true) {
      // prepare to invoke the step
      WorkflowStep memory currentStep = workflow.steps[currentStepIndex];
      address actionAddress = resolveActionAddress(currentStep);
      AssetAmount[] memory inputAssetAmounts = resolveAmounts(assetBalances, currentStep.inputAssets);

      // invoke the step
      emit WorkflowStepExecution(currentStepIndex, currentStep, currentStep.actionId, actionAddress, inputAssetAmounts);
      WorkflowStepResult memory stepResult = invokeStep(actionAddress, inputAssetAmounts, currentStep.outputAssets, currentStep.data);
      emit WorkflowStepResultEvent(stepResult);
      // debit input assets
      for (uint256 i = 0; i < inputAssetAmounts.length; ++i) {
        assetBalances.debit(inputAssetAmounts[i].asset, inputAssetAmounts[i].amount);
      }
      // credit output assets
      for (uint256 i = 0; i < stepResult.outputAssetAmounts.length; ++i) {
        assetBalances.credit(stepResult.outputAssetAmounts[i].asset, stepResult.outputAssetAmounts[i].amount);
      }
      if (currentStep.nextStepIndex == -1) {
        break;
      }
      currentStepIndex = uint16(currentStep.nextStepIndex);
    }
    refundUser(userAddress, assetBalances);
  }

  function refundUser(address userAddress, LibAssetBalances.AssetBalances memory assetBalances) internal {
    for (uint8 i = 0; i < assetBalances.getAssetCount(); ++i) {
      AssetAmount memory ab = assetBalances.getAssetAt(i);
      Asset memory asset = ab.asset;
      uint256 feeAmount = LibPercent.percentageOf(ab.amount, 30);
      uint256 userAmount = ab.amount - feeAmount;
      emit RemainingAsset(asset, ab.amount, feeAmount, userAmount);
      if (asset.assetType == AssetType.Native) {
        // TODO this needs a unit test
        require(address(this).balance == ab.amount, 'computed native balance does not match actual balance');
        (bool sent, bytes memory data) = payable(userAddress).call{value: userAmount}('');
        require(sent, string(data));
      } else if (asset.assetType == AssetType.ERC20) {
        IERC20 token = IERC20(asset.assetAddress);
        uint256 amount = token.balanceOf(address(this));
        require(ab.amount == amount, 'computed token balance does not match actual balance');
        SafeERC20.safeTransfer(token, userAddress, userAmount);
      } else {
        revert('unknown asset type in assetBalances');
      }
    }
  }

  function invokeStep(
    address actionAddress,
    AssetAmount[] memory inputAssetAmounts,
    Asset[] memory outputAssets,
    bytes memory data
  ) internal returns (WorkflowStepResult memory) {
    (bool success, bytes memory returnData) = actionAddress.delegatecall(
      abi.encodeWithSelector(IWorkflowStep.execute.selector, inputAssetAmounts, outputAssets, data)
    );
    require(success, string(returnData));
    return abi.decode(returnData, (WorkflowStepResult));
  }

  function resolveActionAddress(WorkflowStep memory currentStep) internal view returns (address) {
    // non-zero actionAddress means override/ignore the actionId
    // TODO do we want a white list of addresses for a given actionId?
    if (currentStep.actionAddress == address(0)) {
      return getActionAddressInternal(currentStep.actionId);
    }
    return currentStep.actionAddress;
  }

  function resolveAmounts(LibAssetBalances.AssetBalances memory assetBalances, WorkflowStepInputAsset[] memory inputAssets)
    internal
    pure
    returns (AssetAmount[] memory)
  {
    AssetAmount[] memory rv = new AssetAmount[](inputAssets.length);
    for (uint256 i = 0; i < inputAssets.length; ++i) {
      WorkflowStepInputAsset memory stepInputAsset = inputAssets[i];
      rv[i].asset = stepInputAsset.asset;
      uint256 currentWorkflowAssetBalance = assetBalances.getAssetBalance(stepInputAsset.asset);
      if (stepInputAsset.amountIsPercent) {
        rv[i].amount = LibPercent.percentageOf(currentWorkflowAssetBalance, stepInputAsset.amount);
        // rv[i].amount = 1;
      } else {
        require(currentWorkflowAssetBalance <= stepInputAsset.amount, 'absolute amount exceeds workflow asset balance');
        rv[i].amount = stepInputAsset.amount;
      }
    }
    return rv;
  }

  event WorkflowContinuation(uint256 nonce, address userAddress, AssetAmount startingAsset);

  function continueWorkflow(
    address userAddress,
    uint256 nonce,
    Workflow memory workflow,
    AssetAmount memory startingAsset
  ) external payable {
    emit WorkflowContinuation(nonce, userAddress, startingAsset);
    executeWorkflow(userAddress, workflow, startingAsset);
  }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './AssetType.sol';

struct Asset {
  AssetType assetType;
  address assetAddress; // 0x0 for ETH, the ERC20 address.  If it's an account balance, this could represent the token of the account
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './Asset.sol';

struct AssetAmount {
  Asset asset;
  uint256 amount;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

enum AssetType {
  Native,
  ERC20,
  ERC721
  // Account,
  // AaveDebt,
  // NFT
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './Asset.sol';

// an input asset to a WorkflowStep
struct WorkflowStepInputAsset {
  // the input asset
  Asset asset;
  // the amount of the input asset
  uint256 amount;
  // if true 'amount' is treated as a percent, with 4 decimals of precision (1000000 represents 100%)
  bool amountIsPercent;
}

// Parameters for a workflow step
struct WorkflowStep {
  // The logical identifer of the step (e.g., 10 represents WrapEtherStep).
  uint16 actionId;
  // The contract address of a specific version of the action.
  // Individual step contracts may be upgraded over time, and this allows
  // workflows 'freeze' the version of contract for this step
  // A value of address(0) means use the latest and greatest version  of
  // this step based only on actionId.
  address actionAddress;
  // The input assets to this step.
  WorkflowStepInputAsset[] inputAssets;
  // The output assets for this step.
  Asset[] outputAssets;
  // Additional step-specific parameters for this step, typically serialized in standard abi encoding.
  bytes data;
  // The index of the next step in the directed graph of steps. (see the Workflow.steps array)
  int16 nextStepIndex;
}

// The main workflow data structure.
struct Workflow {
  // The nodes in the directed graph of steps.
  // The start step is defined to be at index 0.
  // The 'edges' in the graph are defined within each WorkflowStep,
  // but can be overriden in the return value of a step.
  WorkflowStep[] steps;
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import './AssetAmount.sol';

// The return value from the execution of a step.
struct WorkflowStepResult {
  // The amounts of each output asset that resulted from the step execution.
  AssetAmount[] outputAssetAmounts;
  // The index of the next step in a workflow.
  // This value allows the step to override the default nextStepIndex
  // statically defined
  // -1 means terminate the workflow
  // -2 means do not override the statically defined nextStepIndex in WorkflowStep
  int16 nextStepIndex;
}