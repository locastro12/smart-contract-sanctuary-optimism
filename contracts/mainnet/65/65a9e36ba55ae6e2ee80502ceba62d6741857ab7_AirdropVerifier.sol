// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

/// @author: manifold.xyz

import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

interface IERC721ReceiverView {
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) external view returns (bytes4);
}


interface IERC1155ReceiverView {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external view returns (bytes4);

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) external view returns (bytes4);
}

struct ReceiverQualification {
    bool isEOA;
    bool canReceive;
}

contract AirdropVerifier {

    /**
        @notice Check a list of addresses and return which ones can receive ERC721 tokens
        @param receivers     List of addresses need to be checked
        @return result       List of ReceiverQualification indicating whether the address can receive ERC721 tokens and is an EOA
    */
    function checkERC721Receivers(address[] memory receivers) public view returns (ReceiverQualification[] memory result) {
        result = new ReceiverQualification[](receivers.length);
        for (uint i; i < receivers.length; ++i) {
            address receiver = receivers[i];
            if (isBurnOrZeroAddress(receiver)) {
                // is an EOA but we not allow user to airdrop
                result[i].isEOA = true;
                continue;
            }
            uint32 receiverContractCodeSize;
            assembly {
                receiverContractCodeSize := extcodesize(receiver)
            }
            if (receiverContractCodeSize == 0) {
                // No code at address, so it is an EOA address -> definitely can receive
                result[i] = ReceiverQualification({isEOA: true, canReceive: true});
            } else {
                // Must return proper selector to confirm the token transfer
                try IERC721ReceiverView(receiver).onERC721Received(address(this), address(this), 0, "") returns (bytes4 selector)  {
                    result[i].canReceive = (selector == IERC721Receiver.onERC721Received.selector);
                } catch { 
                    // Check supportsInterface function directly
                    try IERC165(receiver).supportsInterface(type(IERC721Receiver).interfaceId) returns (bool isSupport) {
                        result[i].canReceive = isSupport;
                    } catch {}
                }
            }
        }
    }

    /**
        @notice Check a list of addresses and return which ones can receive single ERC1155 token
        @param receivers     List of addresses need to be checked
        @return result       List of ReceiverQualification indicating whether the address can receive ERC721 tokens and is an EOA
    */
    function checkERC1155Receivers(address[] memory receivers) public view returns (ReceiverQualification[] memory result) {
        result = new ReceiverQualification[](receivers.length);
        for (uint i; i < receivers.length; ++i) {
            address receiver = receivers[i];
            if (isBurnOrZeroAddress(receiver)) {
                // is an EOA but we not allow user to airdrop
                result[i].isEOA = true;
                continue;
            }
            uint32 receiverContractCodeSize;
            assembly {
                receiverContractCodeSize := extcodesize(receiver)
            }
            if (receiverContractCodeSize == 0) {
                // No code at address, so it is an EOA address -> definitely can receive
                result[i] = ReceiverQualification({isEOA: true, canReceive: true});
            } else {
                // Must return proper selector to confirm the token transfer
                try IERC1155ReceiverView(receiver).onERC1155Received(address(this), address(this), 0, 0, "") returns (bytes4 selector)  {
                    result[i].canReceive = (selector == IERC1155Receiver.onERC1155Received.selector);
                } catch { 
                    // Check supportsInterface function directly
                    try IERC165(receiver).supportsInterface(type(IERC1155Receiver).interfaceId) returns (bool isSupport) {
                        result[i].canReceive = isSupport;
                    } catch {}
                }
            }
        }
    }

    /**
        @notice Check a list of addresses and return which ones can receive batch ERC1155 tokens
        @param receivers     List of addresses need to be checked
        @return result   List of ReceiverQualification indicating whether the address can receive ERC721 tokens and is an EOA
    */
    function checkERC1155BatchReceivers(address[] memory receivers) public view returns (ReceiverQualification[] memory result) {
        result = new ReceiverQualification[](receivers.length);
        uint256[] memory dummyBatchIds = new uint256[](1);
        uint256[] memory dummyBatchValues = new uint256[](1);
        for (uint i; i < receivers.length; ++i) {
            address receiver = receivers[i];
            if (isBurnOrZeroAddress(receiver)) {
                // is an EOA but we not allow user to airdrop
                result[i].isEOA = true;
                continue;
            }
            uint32 receiverContractCodeSize;
            assembly {
                receiverContractCodeSize := extcodesize(receiver)
            }
            if (receiverContractCodeSize == 0) {
                // No code at address, so it is an EOA address -> definitely can receive
                result[i] = ReceiverQualification({isEOA: true, canReceive: true});
            } else {
                // Must return proper selector to confirm the token transfer
                try IERC1155ReceiverView(receiver).onERC1155BatchReceived(address(this), address(this), dummyBatchIds, dummyBatchValues, "") returns (bytes4 selector)  {
                    result[i].canReceive = (selector == IERC1155Receiver.onERC1155BatchReceived.selector);
                } catch {
                    // Check supportsInterface function directly
                    try IERC165(receiver).supportsInterface(type(IERC1155Receiver).interfaceId) returns (bool isSupport) {
                        result[i].canReceive = isSupport;
                    } catch {}
                }
            }
        }
    }

    function isBurnOrZeroAddress(address addr) public pure returns (bool) {
        return (addr == address(0) || addr == address(0xdead));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
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
interface IERC165 {
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