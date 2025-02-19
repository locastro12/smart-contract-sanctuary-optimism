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

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../errors.sol";

abstract contract Bridge {
    uint64 public constant ETHEREUM_CHAIN_ID = 1;
    uint64 public constant OPTIMISM_CHAIN_ID = 10;
    uint64 public constant BSC_CHAIN_ID = 56;
    uint64 public constant POLYGON_CHAIN_ID = 137;
    uint64 public constant FANTOM_CHAIN_ID = 250;
    uint64 public constant ARBITRUM_ONE_CHAIN_ID = 42161;
    uint64 public constant AVALANCHE_CHAIN_ID = 43114;

    function currentChainId() internal view virtual returns (uint64) {
        return uint64(block.chainid);
    }

    modifier checkChainId(uint64 chainId) {
        if (currentChainId() == chainId) revert CannotBridgeToSameNetwork();

        if (
            chainId != ETHEREUM_CHAIN_ID &&
            chainId != OPTIMISM_CHAIN_ID &&
            chainId != BSC_CHAIN_ID &&
            chainId != POLYGON_CHAIN_ID &&
            chainId != FANTOM_CHAIN_ID &&
            chainId != ARBITRUM_ONE_CHAIN_ID &&
            chainId != AVALANCHE_CHAIN_ID
        ) revert UnsupportedDestinationChain(chainId);
        _;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../errors.sol";
import {DefiOp} from "../DefiOp.sol";
import {Bridge} from "./Bridge.sol";
import {IStargate} from "../interfaces/external/IStargate.sol";

contract Stargate is Bridge, DefiOp {
    using SafeERC20 for IERC20;

    uint8 constant TYPE_SWAP_REMOTE = 1;

    IStargate public immutable stargate;

    constructor(IStargate stargate_) {
        stargate = stargate_;
    }

    /**
     * @notice Bridge ERC20 token to another chain
     * @dev This function bridge all token on balance to owner address
     * @param token ERC20 token address
     * @param slippage Max slippage, * 1M, eg. 0.5% -> 5000
     * @param chainId Destination chain id.
     */
    function useStargate(
        IERC20 token,
        uint32 slippage,
        uint64 chainId
    ) external payable checkChainId(chainId) {
        uint16 stargateChainId = getStargateChainId(chainId);
        IStargate.lzTxObj memory lzTxParams = IStargate.lzTxObj({
            dstGasForCall: 0,
            dstNativeAmount: 0,
            dstNativeAddr: abi.encodePacked(owner)
        });

        (uint256 lzFee, ) = stargate.quoteLayerZeroFee(
            stargateChainId,
            TYPE_SWAP_REMOTE,
            abi.encodePacked(owner),
            bytes(""),
            lzTxParams
        );

        {
            uint256 contractBalance = address(this).balance;
            if (contractBalance < lzFee) {
                revert NotEnougthNativeBalance(contractBalance, lzFee);
            }
        }

        uint256 tokenAmount = token.balanceOf(address(this));
        token.safeApprove(address(stargate), tokenAmount);
        stargate.swap{value: lzFee}(
            stargateChainId,
            getStargatePoolId(currentChainId(), address(token)),
            getStargatePoolId(currentChainId(), address(token)),
            payable(this),
            tokenAmount,
            (tokenAmount * (1e6 - slippage)) / 1e6,
            lzTxParams,
            abi.encodePacked(owner),
            bytes("")
        );
    }

    function getStargateChainId(uint64 chainId) public pure returns (uint16) {
        if (chainId == ETHEREUM_CHAIN_ID) return 101;
        if (chainId == BSC_CHAIN_ID) return 102;
        if (chainId == AVALANCHE_CHAIN_ID) return 103;
        if (chainId == POLYGON_CHAIN_ID) return 109;
        if (chainId == ARBITRUM_ONE_CHAIN_ID) return 110;
        if (chainId == OPTIMISM_CHAIN_ID) return 111;
        if (chainId == FANTOM_CHAIN_ID) return 112;
        revert UnsupportedDestinationChain(chainId);
    }

    function getStargatePoolId(uint64 chainId, address token)
        public
        pure
        returns (uint256)
    {
        if (chainId == ETHEREUM_CHAIN_ID) {
            if (token == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) return 1; // USDC
            if (token == 0xdAC17F958D2ee523a2206206994597C13D831ec7) return 2; // USDT
            if (token == 0x6B175474E89094C44Da98b954EedeAC495271d0F) return 3; // DAI
            if (token == 0x853d955aCEf822Db058eb8505911ED77F175b99e) return 7; // FRAX
            if (token == 0x0C10bF8FcB7Bf5412187A595ab97a3609160b5c6) return 11; // USDD
            if (token == 0x72E2F4830b9E45d52F80aC08CB2bEC0FeF72eD9c) return 13; // SGETH
            if (token == 0x57Ab1ec28D129707052df4dF418D58a2D46d5f51) return 14; // sUSD
            if (token == 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0) return 15; // LUSD
            if (token == 0x8D6CeBD76f18E1558D4DB88138e2DeFB3909fAD6) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == BSC_CHAIN_ID) {
            if (token == 0x55d398326f99059fF775485246999027B3197955) return 2; // USDT
            if (token == 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56) return 5; // BUSD
            if (token == 0xd17479997F34dd9156Deef8F95A52D81D265be9c) return 11; // USDD
            if (token == 0x3F56e0c36d275367b8C502090EDF38289b3dEa0d) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == AVALANCHE_CHAIN_ID) {
            if (token == 0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E) return 1; // USDC
            if (token == 0x9702230A8Ea53601f5cD2dc00fDBc13d4dF4A8c7) return 2; // USDT
            if (token == 0xD24C2Ad096400B6FBcd2ad8B24E7acBc21A1da64) return 7; // FRAX
            if (token == 0x5c49b268c9841AFF1Cc3B0a418ff5c3442eE3F3b) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == POLYGON_CHAIN_ID) {
            if (token == 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174) return 1; // USDC
            if (token == 0xc2132D05D31c914a87C6611C10748AEb04B58e8F) return 2; // USDT
            if (token == 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063) return 3; // DAI
            if (token == 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == ARBITRUM_ONE_CHAIN_ID) {
            if (token == 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8) return 1; // USDC
            if (token == 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9) return 2; // USDT
            if (token == 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F) return 7; // FRAX
            if (token == 0x82CbeCF39bEe528B5476FE6d1550af59a9dB6Fc0) return 13; // SGETH
            if (token == 0x3F56e0c36d275367b8C502090EDF38289b3dEa0d) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == OPTIMISM_CHAIN_ID) {
            if (token == 0x7F5c764cBc14f9669B88837ca1490cCa17c31607) return 1; // USDC
            if (token == 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1) return 3; // DAI
            if (token == 0x2E3D870790dC77A83DD1d18184Acc7439A53f475) return 7; // FRAX
            if (token == 0xb69c8CBCD90A39D8D3d3ccf0a3E968511C3856A0) return 13; // SGETH
            if (token == 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9) return 14; // sUSD
            if (token == 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819) return 15; // LUSD
            if (token == 0xdFA46478F9e5EA86d57387849598dbFB2e964b02) return 16; // MAI
            revert UnsupportedToken();
        }
        if (chainId == FANTOM_CHAIN_ID) {
            if (token == 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75) return 1; // USDC
            revert UnsupportedToken();
        }
        revert UnsupportedDestinationChain(chainId);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./errors.sol";
import {IDefiOp} from "./interfaces/IDefiOp.sol";

abstract contract DefiOp is IDefiOp {
    using SafeERC20 for IERC20;

    address public owner;

    function init(address owner_) external {
        if (owner != address(0)) {
            revert AlreadyInitialised();
        }
        owner = owner_;
    }

    /**
     * @notice Withdraw ERC20 to owner
     * @dev This function withdraw all token amount to owner address
     * @param token ERC20 token address
     */
    function withdrawERC20(address token) external onlyOwner {
        _withdrawERC20(IERC20(token));
    }

    /**
     * @notice Withdraw native coin to owner (e.g ETH, AVAX, ...)
     * @dev This function withdraw all native coins to owner address
     */
    function withdrawNative() public onlyOwner {
        _withdrawETH();
    }

    receive() external payable {}

    // internal functions
    function _withdrawERC20(IERC20 token) internal {
        uint256 tokenAmount = token.balanceOf(address(this));
        if (tokenAmount > 0) {
            token.safeTransfer(owner, tokenAmount);
        }
    }

    function _withdrawETH() internal {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            (bool success, ) = owner.call{value: balance}("");
            require(success, "Transfer failed");
        }
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// common
error AlreadyInitialised();
error OnlyOwner();
error NotEnougthNativeBalance(uint256 balance, uint256 requiredBalance);
error NotEnougthBalance(
    uint256 balance,
    uint256 requiredBalance,
    address token
);

// bridges
error CannotBridgeToSameNetwork();
error UnsupportedDestinationChain(uint64 chainId);
error UnsupportedToken();

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IStargate {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;

    function quoteLayerZeroFee(
        uint16 _dstChainId,
        uint8 _functionType,
        bytes calldata _toAddress,
        bytes calldata _transferAndCallPayload,
        lzTxObj memory _lzTxParams
    ) external view returns (uint256, uint256);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IDefiOp {
    function init(address owner_) external;

    function withdrawERC20(address token) external;

    function withdrawNative() external;
}