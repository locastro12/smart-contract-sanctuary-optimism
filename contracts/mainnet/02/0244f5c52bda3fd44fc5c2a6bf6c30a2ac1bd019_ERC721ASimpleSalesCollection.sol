// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721CollectionMetadataExtension.sol";

interface IERC721AutoIdMinterExtension {
    function setMaxSupply(uint256 newValue) external;

    function freezeMaxSupply() external;

    function totalSupply() external view returns (uint256);
}

/**
 * @dev Extension to add minting capability with an auto incremented ID for each token and a maximum supply setting.
 */
abstract contract ERC721AutoIdMinterExtension is
    IERC721AutoIdMinterExtension,
    ERC721CollectionMetadataExtension
{
    using SafeMath for uint256;

    uint256 public maxSupply;
    bool public maxSupplyFrozen;

    uint256 internal _currentTokenId = 0;

    function __ERC721AutoIdMinterExtension_init(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        __ERC721AutoIdMinterExtension_init_unchained(_maxSupply);
    }

    function __ERC721AutoIdMinterExtension_init_unchained(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        maxSupply = _maxSupply;

        _registerInterface(type(IERC721AutoIdMinterExtension).interfaceId);
        _registerInterface(type(IERC721).interfaceId);
    }

    /* ADMIN */

    function setMaxSupply(uint256 newValue) public virtual override onlyOwner {
        require(!maxSupplyFrozen, "FROZEN");
        require(newValue >= totalSupply(), "LOWER_THAN_SUPPLY");
        maxSupply = newValue;
    }

    function freezeMaxSupply() external onlyOwner {
        maxSupplyFrozen = true;
    }

    /* PUBLIC */

    function totalSupply() public view returns (uint256) {
        return _currentTokenId;
    }

    /* INTERNAL */

    function _mintTo(address to, uint256 count) internal {
        require(totalSupply() + count <= maxSupply, "EXCEEDS_SUPPLY");

        for (uint256 i = 0; i < count; i++) {
            uint256 newTokenId = _currentTokenId;
            _safeMint(to, newTokenId);
            _incrementTokenId();
        }
    }

    /**
     * Increments the value of _currentTokenId
     */
    function _incrementTokenId() internal {
        _currentTokenId++;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

interface IERC721CollectionMetadataExtension {
    function setContractURI(string memory newValue) external;

    function contractURI() external view returns (string memory);
}

/**
 * @dev Extension to allow configuring contract-level collection metadata URI.
 */
abstract contract ERC721CollectionMetadataExtension is
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721
{
    string private _name;

    string private _symbol;

    string private _contractURI;

    function __ERC721CollectionMetadataExtension_init(
        string memory name_,
        string memory symbol_,
        string memory contractURI_
    ) internal onlyInitializing {
        __ERC721CollectionMetadataExtension_init_unchained(
            name_,
            symbol_,
            contractURI_
        );
    }

    function __ERC721CollectionMetadataExtension_init_unchained(
        string memory name_,
        string memory symbol_,
        string memory contractURI_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
        _contractURI = contractURI_;

        _registerInterface(
            type(IERC721CollectionMetadataExtension).interfaceId
        );
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    /* ADMIN */

    function setContractURI(string memory newValue) external onlyOwner {
        _contractURI = newValue;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165Storage.sol)

pragma solidity ^0.8.0;

import "./ERC165.sol";

/**
 * @dev Storage based implementation of the {IERC165} interface.
 *
 * Contracts may inherit from this and call {_registerInterface} to declare
 * their support of an interface.
 */
abstract contract ERC165Storage is ERC165 {
    /**
     * @dev Mapping of interface ids to whether or not it's supported.
     */
    mapping(bytes4 => bool) private _supportedInterfaces;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return super.supportsInterface(interfaceId) || _supportedInterfaces[interfaceId];
    }

    /**
     * @dev Registers the contract as an implementer of the interface defined by
     * `interfaceId`. Support of the actual ERC165 interface is automatic and
     * registering its interface id is not required.
     *
     * See {IERC165-supportsInterface}.
     *
     * Requirements:
     *
     * - `interfaceId` cannot be the ERC165 invalid interface (`0xffffffff`).
     */
    function _registerInterface(bytes4 interfaceId) internal virtual {
        require(interfaceId != 0xffffffff, "ERC165: invalid interface id");
        _supportedInterfaces[interfaceId] = true;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.0;

import "./IERC721.sol";
import "./IERC721Receiver.sol";
import "./extensions/IERC721Metadata.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/Strings.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
contract ERC721 is Context, ERC165, IERC721, IERC721Metadata {
    using Address for address;
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // Mapping from token ID to approved address
    mapping(uint256 => address) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-balanceOf}.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        require(owner != address(0), "ERC721: address zero is not a valid owner");
        return _balances[owner];
    }

    /**
     * @dev See {IERC721-ownerOf}.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: invalid token ID");
        return owner;
    }

    /**
     * @dev See {IERC721Metadata-name}.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev See {IERC721Metadata-symbol}.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    /**
     * @dev See {IERC721-approve}.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ERC721.ownerOf(tokenId);
        require(to != owner, "ERC721: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "ERC721: approve caller is not token owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    /**
     * @dev See {IERC721-getApproved}.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        _requireMinted(tokenId);

        return _tokenApprovals[tokenId];
    }

    /**
     * @dev See {IERC721-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner nor approved");
        _safeTransfer(from, to, tokenId, data);
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is equivalent to {safeTransferFrom}, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _transfer(from, to, tokenId);
        require(_checkOnERC721Received(from, to, tokenId, data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted (`_mint`),
     * and stop existing when they are burned (`_burn`).
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return _owners[tokenId] != address(0);
    }

    /**
     * @dev Returns whether `spender` is allowed to manage `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual returns (bool) {
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    /**
     * @dev Safely mints `tokenId` and transfers it to `to`.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeMint(address to, uint256 tokenId) internal virtual {
        _safeMint(to, tokenId, "");
    }

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(
        address to,
        uint256 tokenId,
        bytes memory data
    ) internal virtual {
        _mint(to, tokenId);
        require(
            _checkOnERC721Received(address(0), to, tokenId, data),
            "ERC721: transfer to non ERC721Receiver implementer"
        );
    }

    /**
     * @dev Mints `tokenId` and transfers it to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - `to` cannot be the zero address.
     *
     * Emits a {Transfer} event.
     */
    function _mint(address to, uint256 tokenId) internal virtual {
        require(to != address(0), "ERC721: mint to the zero address");
        require(!_exists(tokenId), "ERC721: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(address(0), to, tokenId);

        _afterTokenTransfer(address(0), to, tokenId);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual {
        address owner = ERC721.ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        _afterTokenTransfer(owner, address(0), tokenId);
    }

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer from incorrect owner");
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        _afterTokenTransfer(from, to, tokenId);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * Emits an {Approval} event.
     */
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
        require(owner != operator, "ERC721: approve to caller");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Reverts if the `tokenId` has not been minted yet.
     */
    function _requireMinted(uint256 tokenId) internal view virtual {
        require(_exists(tokenId), "ERC721: invalid token ID");
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from address representing the previous owner of the given token ID
     * @param to target address that will receive the tokens
     * @param tokenId uint256 ID of the token to be transferred
     * @param data bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    /// @solidity memory-safe-assembly
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual {}
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
// OpenZeppelin Contracts (last updated v4.7.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/Address.sol";

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
            (isTopLevelCall && _initialized < 1) || (!Address.isContract(address(this)) && _initialized == 1),
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
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/IERC721Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional metadata extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Metadata is IERC721 {
    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

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
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Address.sol)

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
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
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
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

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
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
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

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

/**
 * @dev String operations.
 */
library Strings {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/IERC721.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "erc721a/contracts/ERC721A.sol";

import {IERC721AutoIdMinterExtension} from "../../ERC721/extensions/ERC721AutoIdMinterExtension.sol";

import "./ERC721ACollectionMetadataExtension.sol";

/**
 * @dev Extension to add minting capability with an auto incremented ID for each token and a maximum supply setting.
 */
abstract contract ERC721AMinterExtension is ERC721ACollectionMetadataExtension {
    using SafeMath for uint256;

    uint256 public maxSupply;
    bool public maxSupplyFrozen;

    function __ERC721AMinterExtension_init(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        __ERC721AMinterExtension_init_unchained(_maxSupply);
    }

    function __ERC721AMinterExtension_init_unchained(uint256 _maxSupply)
        internal
        onlyInitializing
    {
        maxSupply = _maxSupply;

        _registerInterface(type(IERC721AutoIdMinterExtension).interfaceId);
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721A).interfaceId);
    }

    /* ADMIN */

    function setMaxSupply(uint256 newValue) public virtual onlyOwner {
        require(!maxSupplyFrozen, "BASE_URI_FROZEN");
        require(newValue >= totalSupply(), "LOWER_THAN_SUPPLY");
        maxSupply = newValue;
    }

    function freezeMaxSupply() external onlyOwner {
        maxSupplyFrozen = true;
    }

    /* INTERNAL */

    function _mintTo(address to, uint256 count) internal {
        require(totalSupply() + count <= maxSupply, "EXCEEDS_SUPPLY");
        _safeMint(to, count);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

import "erc721a/contracts/ERC721A.sol";

import {IERC721CollectionMetadataExtension} from "../../ERC721/extensions/ERC721CollectionMetadataExtension.sol";

/**
 * @dev Extension to allow configuring contract-level collection metadata URI.
 */
abstract contract ERC721ACollectionMetadataExtension is
    IERC721CollectionMetadataExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721A
{
    string private _name;

    string private _symbol;

    string private _contractURI;

    function __ERC721ACollectionMetadataExtension_init(
        string memory name_,
        string memory symbol_,
        string memory contractURI_
    ) internal onlyInitializing {
        __ERC721ACollectionMetadataExtension_init_unchained(
            name_,
            symbol_,
            contractURI_
        );
    }

    function __ERC721ACollectionMetadataExtension_init_unchained(
        string memory name_,
        string memory symbol_,
        string memory contractURI_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
        _contractURI = contractURI_;

        _registerInterface(
            type(IERC721CollectionMetadataExtension).interfaceId
        );
        _registerInterface(type(IERC721).interfaceId);
        _registerInterface(type(IERC721A).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    /* ADMIN */

    function setContractURI(string memory newValue) external onlyOwner {
        _contractURI = newValue;
    }

    /* PUBLIC */

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721A)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creator: Chiru Labs

pragma solidity ^0.8.4;

import './IERC721A.sol';

/**
 * @dev Interface of ERC721 token receiver.
 */
interface ERC721A__IERC721Receiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}

/**
 * @title ERC721A
 *
 * @dev Implementation of the [ERC721](https://eips.ethereum.org/EIPS/eip-721)
 * Non-Fungible Token Standard, including the Metadata extension.
 * Optimized for lower gas during batch mints.
 *
 * Token IDs are minted in sequential order (e.g. 0, 1, 2, 3, ...)
 * starting from `_startTokenId()`.
 *
 * Assumptions:
 *
 * - An owner cannot have more than 2**64 - 1 (max value of uint64) of supply.
 * - The maximum token ID cannot exceed 2**256 - 1 (max value of uint256).
 */
contract ERC721A is IERC721A {
    // Reference type for token approval.
    struct TokenApprovalRef {
        address value;
    }

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    // Mask of an entry in packed address data.
    uint256 private constant _BITMASK_ADDRESS_DATA_ENTRY = (1 << 64) - 1;

    // The bit position of `numberMinted` in packed address data.
    uint256 private constant _BITPOS_NUMBER_MINTED = 64;

    // The bit position of `numberBurned` in packed address data.
    uint256 private constant _BITPOS_NUMBER_BURNED = 128;

    // The bit position of `aux` in packed address data.
    uint256 private constant _BITPOS_AUX = 192;

    // Mask of all 256 bits in packed address data except the 64 bits for `aux`.
    uint256 private constant _BITMASK_AUX_COMPLEMENT = (1 << 192) - 1;

    // The bit position of `startTimestamp` in packed ownership.
    uint256 private constant _BITPOS_START_TIMESTAMP = 160;

    // The bit mask of the `burned` bit in packed ownership.
    uint256 private constant _BITMASK_BURNED = 1 << 224;

    // The bit position of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITPOS_NEXT_INITIALIZED = 225;

    // The bit mask of the `nextInitialized` bit in packed ownership.
    uint256 private constant _BITMASK_NEXT_INITIALIZED = 1 << 225;

    // The bit position of `extraData` in packed ownership.
    uint256 private constant _BITPOS_EXTRA_DATA = 232;

    // Mask of all 256 bits in a packed ownership except the 24 bits for `extraData`.
    uint256 private constant _BITMASK_EXTRA_DATA_COMPLEMENT = (1 << 232) - 1;

    // The mask of the lower 160 bits for addresses.
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    // The maximum `quantity` that can be minted with {_mintERC2309}.
    // This limit is to prevent overflows on the address data entries.
    // For a limit of 5000, a total of 3.689e15 calls to {_mintERC2309}
    // is required to cause an overflow, which is unrealistic.
    uint256 private constant _MAX_MINT_ERC2309_QUANTITY_LIMIT = 5000;

    // The `Transfer` event signature is given by:
    // `keccak256(bytes("Transfer(address,address,uint256)"))`.
    bytes32 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    // =============================================================
    //                            STORAGE
    // =============================================================

    // The next token ID to be minted.
    uint256 private _currentIndex;

    // The number of tokens burned.
    uint256 private _burnCounter;

    // Token name
    string private _name;

    // Token symbol
    string private _symbol;

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned.
    // See {_packedOwnershipOf} implementation for details.
    //
    // Bits Layout:
    // - [0..159]   `addr`
    // - [160..223] `startTimestamp`
    // - [224]      `burned`
    // - [225]      `nextInitialized`
    // - [232..255] `extraData`
    mapping(uint256 => uint256) private _packedOwnerships;

    // Mapping owner address to address data.
    //
    // Bits Layout:
    // - [0..63]    `balance`
    // - [64..127]  `numberMinted`
    // - [128..191] `numberBurned`
    // - [192..255] `aux`
    mapping(address => uint256) private _packedAddressData;

    // Mapping from token ID to approved address.
    mapping(uint256 => TokenApprovalRef) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _currentIndex = _startTokenId();
    }

    // =============================================================
    //                   TOKEN COUNTING OPERATIONS
    // =============================================================

    /**
     * @dev Returns the starting token ID.
     * To change the starting token ID, please override this function.
     */
    function _startTokenId() internal view virtual returns (uint256) {
        return 0;
    }

    /**
     * @dev Returns the next token ID to be minted.
     */
    function _nextTokenId() internal view virtual returns (uint256) {
        return _currentIndex;
    }

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        // Counter underflow is impossible as _burnCounter cannot be incremented
        // more than `_currentIndex - _startTokenId()` times.
        unchecked {
            return _currentIndex - _burnCounter - _startTokenId();
        }
    }

    /**
     * @dev Returns the total amount of tokens minted in the contract.
     */
    function _totalMinted() internal view virtual returns (uint256) {
        // Counter underflow is impossible as `_currentIndex` does not decrement,
        // and it is initialized to `_startTokenId()`.
        unchecked {
            return _currentIndex - _startTokenId();
        }
    }

    /**
     * @dev Returns the total number of tokens burned.
     */
    function _totalBurned() internal view virtual returns (uint256) {
        return _burnCounter;
    }

    // =============================================================
    //                    ADDRESS DATA OPERATIONS
    // =============================================================

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert BalanceQueryForZeroAddress();
        return _packedAddressData[owner] & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens minted by `owner`.
     */
    function _numberMinted(address owner) internal view returns (uint256) {
        return (_packedAddressData[owner] >> _BITPOS_NUMBER_MINTED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the number of tokens burned by or on behalf of `owner`.
     */
    function _numberBurned(address owner) internal view returns (uint256) {
        return (_packedAddressData[owner] >> _BITPOS_NUMBER_BURNED) & _BITMASK_ADDRESS_DATA_ENTRY;
    }

    /**
     * Returns the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     */
    function _getAux(address owner) internal view returns (uint64) {
        return uint64(_packedAddressData[owner] >> _BITPOS_AUX);
    }

    /**
     * Sets the auxiliary data for `owner`. (e.g. number of whitelist mint slots used).
     * If there are multiple variables, please pack them into a uint64.
     */
    function _setAux(address owner, uint64 aux) internal virtual {
        uint256 packed = _packedAddressData[owner];
        uint256 auxCasted;
        // Cast `aux` with assembly to avoid redundant masking.
        assembly {
            auxCasted := aux
        }
        packed = (packed & _BITMASK_AUX_COMPLEMENT) | (auxCasted << _BITPOS_AUX);
        _packedAddressData[owner] = packed;
    }

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        // The interface IDs are constants representing the first 4 bytes
        // of the XOR of all function selectors in the interface.
        // See: [ERC165](https://eips.ethereum.org/EIPS/eip-165)
        // (e.g. `bytes4(i.functionA.selector ^ i.functionB.selector ^ ...)`)
        return
            interfaceId == 0x01ffc9a7 || // ERC165 interface ID for ERC165.
            interfaceId == 0x80ac58cd || // ERC165 interface ID for ERC721.
            interfaceId == 0x5b5e139f; // ERC165 interface ID for ERC721Metadata.
    }

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        string memory baseURI = _baseURI();
        return bytes(baseURI).length != 0 ? string(abi.encodePacked(baseURI, _toString(tokenId))) : '';
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, it can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return '';
    }

    // =============================================================
    //                     OWNERSHIPS OPERATIONS
    // =============================================================

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        return address(uint160(_packedOwnershipOf(tokenId)));
    }

    /**
     * @dev Gas spent here starts off proportional to the maximum mint batch size.
     * It gradually moves to O(1) as tokens get transferred around over time.
     */
    function _ownershipOf(uint256 tokenId) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(_packedOwnershipOf(tokenId));
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct at `index`.
     */
    function _ownershipAt(uint256 index) internal view virtual returns (TokenOwnership memory) {
        return _unpackedOwnership(_packedOwnerships[index]);
    }

    /**
     * @dev Initializes the ownership slot minted at `index` for efficiency purposes.
     */
    function _initializeOwnershipAt(uint256 index) internal virtual {
        if (_packedOwnerships[index] == 0) {
            _packedOwnerships[index] = _packedOwnershipOf(index);
        }
    }

    /**
     * Returns the packed ownership data of `tokenId`.
     */
    function _packedOwnershipOf(uint256 tokenId) private view returns (uint256) {
        uint256 curr = tokenId;

        unchecked {
            if (_startTokenId() <= curr)
                if (curr < _currentIndex) {
                    uint256 packed = _packedOwnerships[curr];
                    // If not burned.
                    if (packed & _BITMASK_BURNED == 0) {
                        // Invariant:
                        // There will always be an initialized ownership slot
                        // (i.e. `ownership.addr != address(0) && ownership.burned == false`)
                        // before an unintialized ownership slot
                        // (i.e. `ownership.addr == address(0) && ownership.burned == false`)
                        // Hence, `curr` will not underflow.
                        //
                        // We can directly compare the packed value.
                        // If the address is zero, packed will be zero.
                        while (packed == 0) {
                            packed = _packedOwnerships[--curr];
                        }
                        return packed;
                    }
                }
        }
        revert OwnerQueryForNonexistentToken();
    }

    /**
     * @dev Returns the unpacked `TokenOwnership` struct from `packed`.
     */
    function _unpackedOwnership(uint256 packed) private pure returns (TokenOwnership memory ownership) {
        ownership.addr = address(uint160(packed));
        ownership.startTimestamp = uint64(packed >> _BITPOS_START_TIMESTAMP);
        ownership.burned = packed & _BITMASK_BURNED != 0;
        ownership.extraData = uint24(packed >> _BITPOS_EXTRA_DATA);
    }

    /**
     * @dev Packs ownership data into a single uint256.
     */
    function _packOwnershipData(address owner, uint256 flags) private view returns (uint256 result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // `owner | (block.timestamp << _BITPOS_START_TIMESTAMP) | flags`.
            result := or(owner, or(shl(_BITPOS_START_TIMESTAMP, timestamp()), flags))
        }
    }

    /**
     * @dev Returns the `nextInitialized` flag set if `quantity` equals 1.
     */
    function _nextInitializedFlag(uint256 quantity) private pure returns (uint256 result) {
        // For branchless setting of the `nextInitialized` flag.
        assembly {
            // `(quantity == 1) << _BITPOS_NEXT_INITIALIZED`.
            result := shl(_BITPOS_NEXT_INITIALIZED, eq(quantity, 1))
        }
    }

    // =============================================================
    //                      APPROVAL OPERATIONS
    // =============================================================

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);

        if (_msgSenderERC721A() != owner)
            if (!isApprovedForAll(owner, _msgSenderERC721A())) {
                revert ApprovalCallerNotOwnerNorApproved();
            }

        _tokenApprovals[tokenId].value = to;
        emit Approval(owner, to, tokenId);
    }

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (!_exists(tokenId)) revert ApprovalQueryForNonexistentToken();

        return _tokenApprovals[tokenId].value;
    }

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == _msgSenderERC721A()) revert ApproveToCaller();

        _operatorApprovals[_msgSenderERC721A()][operator] = approved;
        emit ApprovalForAll(_msgSenderERC721A(), operator, approved);
    }

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /**
     * @dev Returns whether `tokenId` exists.
     *
     * Tokens can be managed by their owner or approved accounts via {approve} or {setApprovalForAll}.
     *
     * Tokens start existing when they are minted. See {_mint}.
     */
    function _exists(uint256 tokenId) internal view virtual returns (bool) {
        return
            _startTokenId() <= tokenId &&
            tokenId < _currentIndex && // If within bounds,
            _packedOwnerships[tokenId] & _BITMASK_BURNED == 0; // and not burned.
    }

    /**
     * @dev Returns whether `msgSender` is equal to `approvedAddress` or `owner`.
     */
    function _isSenderApprovedOrOwner(
        address approvedAddress,
        address owner,
        address msgSender
    ) private pure returns (bool result) {
        assembly {
            // Mask `owner` to the lower 160 bits, in case the upper bits somehow aren't clean.
            owner := and(owner, _BITMASK_ADDRESS)
            // Mask `msgSender` to the lower 160 bits, in case the upper bits somehow aren't clean.
            msgSender := and(msgSender, _BITMASK_ADDRESS)
            // `msgSender == owner || msgSender == approvedAddress`.
            result := or(eq(msgSender, owner), eq(msgSender, approvedAddress))
        }
    }

    /**
     * @dev Returns the storage slot and value for the approved address of `tokenId`.
     */
    function _getApprovedSlotAndAddress(uint256 tokenId)
        private
        view
        returns (uint256 approvedAddressSlot, address approvedAddress)
    {
        TokenApprovalRef storage tokenApproval = _tokenApprovals[tokenId];
        // The following is equivalent to `approvedAddress = _tokenApprovals[tokenId]`.
        assembly {
            approvedAddressSlot := tokenApproval.slot
            approvedAddress := sload(approvedAddressSlot)
        }
    }

    // =============================================================
    //                      TRANSFER OPERATIONS
    // =============================================================

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        if (address(uint160(prevOwnershipPacked)) != from) revert TransferFromIncorrectOwner();

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        // The nested ifs save around 20+ gas over a compound boolean condition.
        if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
            if (!isApprovedForAll(from, _msgSenderERC721A())) revert TransferCallerNotOwnerNorApproved();

        if (to == address(0)) revert TransferToZeroAddress();

        _beforeTokenTransfers(from, to, tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // We can directly increment and decrement the balances.
            --_packedAddressData[from]; // Updates: `balance -= 1`.
            ++_packedAddressData[to]; // Updates: `balance += 1`.

            // Updates:
            // - `address` to the next owner.
            // - `startTimestamp` to the timestamp of transfering.
            // - `burned` to `false`.
            // - `nextInitialized` to `true`.
            _packedOwnerships[tokenId] = _packOwnershipData(
                to,
                _BITMASK_NEXT_INITIALIZED | _nextExtraData(from, to, prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (_packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != _currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        _packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, to, tokenId);
        _afterTokenTransfers(from, to, tokenId, 1);
    }

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, '');
    }

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        transferFrom(from, to, tokenId);
        if (to.code.length != 0)
            if (!_checkContractOnERC721Received(from, to, tokenId, _data)) {
                revert TransferToNonERC721ReceiverImplementer();
            }
    }

    /**
     * @dev Hook that is called before a set of serially-ordered token IDs
     * are about to be transferred. This includes minting.
     * And also called before burning one token.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Hook that is called after a set of serially-ordered token IDs
     * have been transferred. This includes minting.
     * And also called after one token has been burned.
     *
     * `startTokenId` - the first token ID to be transferred.
     * `quantity` - the amount to be transferred.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` has been
     * transferred to `to`.
     * - When `from` is zero, `tokenId` has been minted for `to`.
     * - When `to` is zero, `tokenId` has been burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual {}

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * `from` - Previous owner of the given token ID.
     * `to` - Target address that will receive the token.
     * `tokenId` - Token ID to be transferred.
     * `_data` - Optional data to send along with the call.
     *
     * Returns whether the call correctly returned the expected magic value.
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try ERC721A__IERC721Receiver(to).onERC721Received(_msgSenderERC721A(), from, tokenId, _data) returns (
            bytes4 retval
        ) {
            return retval == ERC721A__IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                revert TransferToNonERC721ReceiverImplementer();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }

    // =============================================================
    //                        MINT OPERATIONS
    // =============================================================

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = _currentIndex;
        if (quantity == 0) revert MintZeroQuantity();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // `balance` and `numberMinted` have a maximum limit of 2**64.
        // `tokenId` has a maximum limit of 2**256.
        unchecked {
            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            _packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            _packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            uint256 toMasked;
            uint256 end = startTokenId + quantity;

            // Use assembly to loop and emit the `Transfer` event for gas savings.
            assembly {
                // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
                toMasked := and(to, _BITMASK_ADDRESS)
                // Emit the `Transfer` event.
                log4(
                    0, // Start of data (0, since no data).
                    0, // End of data (0, since no data).
                    _TRANSFER_EVENT_SIGNATURE, // Signature.
                    0, // `address(0)`.
                    toMasked, // `to`.
                    startTokenId // `tokenId`.
                )

                for {
                    let tokenId := add(startTokenId, 1)
                } iszero(eq(tokenId, end)) {
                    tokenId := add(tokenId, 1)
                } {
                    // Emit the `Transfer` event. Similar to above.
                    log4(0, 0, _TRANSFER_EVENT_SIGNATURE, 0, toMasked, tokenId)
                }
            }
            if (toMasked == 0) revert MintToZeroAddress();

            _currentIndex = end;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * This function is intended for efficient minting only during contract creation.
     *
     * It emits only one {ConsecutiveTransfer} as defined in
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309),
     * instead of a sequence of {Transfer} event(s).
     *
     * Calling this function outside of contract creation WILL make your contract
     * non-compliant with the ERC721 standard.
     * For full ERC721 compliance, substituting ERC721 {Transfer} event(s) with the ERC2309
     * {ConsecutiveTransfer} event is only permissible during contract creation.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {ConsecutiveTransfer} event.
     */
    function _mintERC2309(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = _currentIndex;
        if (to == address(0)) revert MintToZeroAddress();
        if (quantity == 0) revert MintZeroQuantity();
        if (quantity > _MAX_MINT_ERC2309_QUANTITY_LIMIT) revert MintERC2309QuantityExceedsLimit();

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are unrealistic due to the above check for `quantity` to be below the limit.
        unchecked {
            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            _packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            _packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            emit ConsecutiveTransfer(startTokenId, startTokenId + quantity - 1, address(0), to);

            _currentIndex = startTokenId + quantity;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }

    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * See {_mint}.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        _mint(to, quantity);

        unchecked {
            if (to.code.length != 0) {
                uint256 end = _currentIndex;
                uint256 index = end - quantity;
                do {
                    if (!_checkContractOnERC721Received(address(0), to, index++, _data)) {
                        revert TransferToNonERC721ReceiverImplementer();
                    }
                } while (index < end);
                // Reentrancy protection.
                if (_currentIndex != end) revert();
            }
        }
    }

    /**
     * @dev Equivalent to `_safeMint(to, quantity, '')`.
     */
    function _safeMint(address to, uint256 quantity) internal virtual {
        _safeMint(to, quantity, '');
    }

    // =============================================================
    //                        BURN OPERATIONS
    // =============================================================

    /**
     * @dev Equivalent to `_burn(tokenId, false)`.
     */
    function _burn(uint256 tokenId) internal virtual {
        _burn(tokenId, false);
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId, bool approvalCheck) internal virtual {
        uint256 prevOwnershipPacked = _packedOwnershipOf(tokenId);

        address from = address(uint160(prevOwnershipPacked));

        (uint256 approvedAddressSlot, address approvedAddress) = _getApprovedSlotAndAddress(tokenId);

        if (approvalCheck) {
            // The nested ifs save around 20+ gas over a compound boolean condition.
            if (!_isSenderApprovedOrOwner(approvedAddress, from, _msgSenderERC721A()))
                if (!isApprovedForAll(from, _msgSenderERC721A())) revert TransferCallerNotOwnerNorApproved();
        }

        _beforeTokenTransfers(from, address(0), tokenId, 1);

        // Clear approvals from the previous owner.
        assembly {
            if approvedAddress {
                // This is equivalent to `delete _tokenApprovals[tokenId]`.
                sstore(approvedAddressSlot, 0)
            }
        }

        // Underflow of the sender's balance is impossible because we check for
        // ownership above and the recipient's balance can't realistically overflow.
        // Counter overflow is incredibly unrealistic as `tokenId` would have to be 2**256.
        unchecked {
            // Updates:
            // - `balance -= 1`.
            // - `numberBurned += 1`.
            //
            // We can directly decrement the balance, and increment the number burned.
            // This is equivalent to `packed -= 1; packed += 1 << _BITPOS_NUMBER_BURNED;`.
            _packedAddressData[from] += (1 << _BITPOS_NUMBER_BURNED) - 1;

            // Updates:
            // - `address` to the last owner.
            // - `startTimestamp` to the timestamp of burning.
            // - `burned` to `true`.
            // - `nextInitialized` to `true`.
            _packedOwnerships[tokenId] = _packOwnershipData(
                from,
                (_BITMASK_BURNED | _BITMASK_NEXT_INITIALIZED) | _nextExtraData(from, address(0), prevOwnershipPacked)
            );

            // If the next slot may not have been initialized (i.e. `nextInitialized == false`) .
            if (prevOwnershipPacked & _BITMASK_NEXT_INITIALIZED == 0) {
                uint256 nextTokenId = tokenId + 1;
                // If the next slot's address is zero and not burned (i.e. packed value is zero).
                if (_packedOwnerships[nextTokenId] == 0) {
                    // If the next slot is within bounds.
                    if (nextTokenId != _currentIndex) {
                        // Initialize the next slot to maintain correctness for `ownerOf(tokenId + 1)`.
                        _packedOwnerships[nextTokenId] = prevOwnershipPacked;
                    }
                }
            }
        }

        emit Transfer(from, address(0), tokenId);
        _afterTokenTransfers(from, address(0), tokenId, 1);

        // Overflow not possible, as _burnCounter cannot be exceed _currentIndex times.
        unchecked {
            _burnCounter++;
        }
    }

    // =============================================================
    //                     EXTRA DATA OPERATIONS
    // =============================================================

    /**
     * @dev Directly sets the extra data for the ownership data `index`.
     */
    function _setExtraDataAt(uint256 index, uint24 extraData) internal virtual {
        uint256 packed = _packedOwnerships[index];
        if (packed == 0) revert OwnershipNotInitializedForExtraData();
        uint256 extraDataCasted;
        // Cast `extraData` with assembly to avoid redundant masking.
        assembly {
            extraDataCasted := extraData
        }
        packed = (packed & _BITMASK_EXTRA_DATA_COMPLEMENT) | (extraDataCasted << _BITPOS_EXTRA_DATA);
        _packedOwnerships[index] = packed;
    }

    /**
     * @dev Called during each token transfer to set the 24bit `extraData` field.
     * Intended to be overridden by the cosumer contract.
     *
     * `previousExtraData` - the value of `extraData` before transfer.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, `from`'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, `tokenId` will be burned by `from`.
     * - `from` and `to` are never both zero.
     */
    function _extraData(
        address from,
        address to,
        uint24 previousExtraData
    ) internal view virtual returns (uint24) {}

    /**
     * @dev Returns the next extra data for the packed ownership data.
     * The returned result is shifted into position.
     */
    function _nextExtraData(
        address from,
        address to,
        uint256 prevOwnershipPacked
    ) private view returns (uint256) {
        uint24 extraData = uint24(prevOwnershipPacked >> _BITPOS_EXTRA_DATA);
        return uint256(_extraData(from, to, extraData)) << _BITPOS_EXTRA_DATA;
    }

    // =============================================================
    //                       OTHER OPERATIONS
    // =============================================================

    /**
     * @dev Returns the message sender (defaults to `msg.sender`).
     *
     * If you are writing GSN compatible contracts, you need to override this function.
     */
    function _msgSenderERC721A() internal view virtual returns (address) {
        return msg.sender;
    }

    /**
     * @dev Converts a uint256 to its ASCII string decimal representation.
     */
    function _toString(uint256 value) internal pure virtual returns (string memory str) {
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit),
            // but we allocate 0x80 bytes to keep the free memory pointer 32-byte word aliged.
            // We will need 1 32-byte word to store the length,
            // and 3 32-byte words to store a maximum of 78 digits. Total: 0x20 + 3 * 0x20 = 0x80.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, str)

            // Cache the end of the memory to calculate the length later.
            let end := str

            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            // prettier-ignore
            for { let temp := value } 1 {} {
                str := sub(str, 1)
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                // prettier-ignore
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

// SPDX-License-Identifier: MIT
// ERC721A Contracts v4.2.2
// Creator: Chiru Labs

pragma solidity ^0.8.4;

/**
 * @dev Interface of ERC721A.
 */
interface IERC721A {
    /**
     * The caller must own the token or be an approved operator.
     */
    error ApprovalCallerNotOwnerNorApproved();

    /**
     * The token does not exist.
     */
    error ApprovalQueryForNonexistentToken();

    /**
     * The caller cannot approve to their own address.
     */
    error ApproveToCaller();

    /**
     * Cannot query the balance for the zero address.
     */
    error BalanceQueryForZeroAddress();

    /**
     * Cannot mint to the zero address.
     */
    error MintToZeroAddress();

    /**
     * The quantity of tokens minted must be more than zero.
     */
    error MintZeroQuantity();

    /**
     * The token does not exist.
     */
    error OwnerQueryForNonexistentToken();

    /**
     * The caller must own the token or be an approved operator.
     */
    error TransferCallerNotOwnerNorApproved();

    /**
     * The token must be owned by `from`.
     */
    error TransferFromIncorrectOwner();

    /**
     * Cannot safely transfer to a contract that does not implement the
     * ERC721Receiver interface.
     */
    error TransferToNonERC721ReceiverImplementer();

    /**
     * Cannot transfer to the zero address.
     */
    error TransferToZeroAddress();

    /**
     * The token does not exist.
     */
    error URIQueryForNonexistentToken();

    /**
     * The `quantity` minted with ERC2309 exceeds the safety limit.
     */
    error MintERC2309QuantityExceedsLimit();

    /**
     * The `extraData` cannot be set on an unintialized ownership slot.
     */
    error OwnershipNotInitializedForExtraData();

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct TokenOwnership {
        // The address of the owner.
        address addr;
        // Stores the start time of ownership with minimal overhead for tokenomics.
        uint64 startTimestamp;
        // Whether the token has been burned.
        bool burned;
        // Arbitrary data similar to `startTimestamp` that can be set via {_extraData}.
        uint24 extraData;
    }

    // =============================================================
    //                         TOKEN COUNTERS
    // =============================================================

    /**
     * @dev Returns the total number of tokens in existence.
     * Burned tokens will reduce the count.
     * To get the total number of tokens minted, please see {_totalMinted}.
     */
    function totalSupply() external view returns (uint256);

    // =============================================================
    //                            IERC165
    // =============================================================

    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * [EIP section](https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified)
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    // =============================================================
    //                            IERC721
    // =============================================================

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables
     * (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in `owner`'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`,
     * checking first that contract recipients are aware of the ERC721 protocol
     * to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move
     * this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;

    /**
     * @dev Equivalent to `safeTransferFrom(from, to, tokenId, '')`.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom}
     * whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token
     * by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the
     * zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom}
     * for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // =============================================================
    //                        IERC721Metadata
    // =============================================================

    /**
     * @dev Returns the token collection name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId) external view returns (string memory);

    // =============================================================
    //                           IERC2309
    // =============================================================

    /**
     * @dev Emitted when tokens in `fromTokenId` to `toTokenId`
     * (inclusive) is transferred from `from` to `to`, as defined in the
     * [ERC2309](https://eips.ethereum.org/EIPS/eip-2309) standard.
     *
     * See {_mintERC2309} for more details.
     */
    event ConsecutiveTransfer(uint256 indexed fromTokenId, uint256 toTokenId, address indexed from, address indexed to);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../../ERC721/extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721ACollectionMetadataExtension.sol";
import "../extensions/ERC721APrefixedMetadataExtension.sol";
import "../extensions/ERC721AMinterExtension.sol";
import "../extensions/ERC721AOwnerMintExtension.sol";
import "../extensions/ERC721ATieringExtension.sol";
import "../extensions/ERC721ARoleBasedMintExtension.sol";
import "../extensions/ERC721ARoleBasedLockableExtension.sol";

contract ERC721ATieredSalesCollection is
    Ownable,
    ERC165Storage,
    WithdrawExtension,
    LicenseExtension,
    ERC721ACollectionMetadataExtension,
    ERC721APrefixedMetadataExtension,
    ERC721AOwnerMintExtension,
    ERC721ATieringExtension,
    ERC721ARoleBasedMintExtension,
    ERC721ARoleBasedLockableExtension,
    ERC721RoyaltyExtension,
    ERC2771ContextOwnable
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        string placeholderURI;
        string tokenURIPrefix;
        uint256 maxSupply;
        Tier[] tiers;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address proceedsRecipient;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721A(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);

        _transferOwnership(deployer);

        __WithdrawExtension_init(config.proceedsRecipient, WithdrawMode.ANYONE);
        __LicenseExtension_init(config.licenseVersion);
        __ERC721ACollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721APrefixedMetadataExtension_init(
            config.placeholderURI,
            config.tokenURIPrefix
        );
        __ERC721AMinterExtension_init(config.maxSupply);
        __ERC721AOwnerMintExtension_init();
        __ERC721ARoleBasedMintExtension_init(deployer);
        __ERC721ARoleBasedLockableExtension_init();
        __ERC721ATieringExtension_init(config.tiers);
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return ERC2771ContextOwnable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return ERC2771ContextOwnable._msgData();
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A, ERC721ALockableExtension) {
        ERC721ALockableExtension._beforeTokenTransfers(
            from,
            to,
            startTokenId,
            quantity
        );
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721ACollectionMetadataExtension,
            ERC721APrefixedMetadataExtension,
            ERC721AOwnerMintExtension,
            ERC721ARoleBasedMintExtension,
            ERC721RoyaltyExtension,
            ERC721ARoleBasedLockableExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.symbol();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721A, ERC721APrefixedMetadataExtension)
        returns (string memory)
    {
        return ERC721APrefixedMetadataExtension.tokenURI(_tokenId);
    }

    function setMaxSupply(uint256 newValue)
        public
        virtual
        override(ERC721AMinterExtension, ERC721ATieringExtension)
        onlyOwner
    {
        ERC721ATieringExtension.setMaxSupply(newValue);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IWithdrawExtension {
    enum WithdrawMode {
        OWNER,
        RECIPIENT,
        ANYONE,
        NOBODY
    }

    error WithdrawWrongRecipient();
    error WithdrawRecipientLocked();
    error WithdrawModeLocked();
    error WithdrawPowerRevoked();

    function setWithdrawRecipient(address _withdrawRecipient) external;

    function lockWithdrawRecipient() external;

    function revokeWithdrawPower() external;

    function setWithdrawMode(WithdrawMode _withdrawMode) external;

    function lockWithdrawMode() external;

    function withdraw(
        address[] calldata claimTokens,
        uint256[] calldata amounts
    ) external;
}

abstract contract WithdrawExtension is
    IWithdrawExtension,
    Initializable,
    Ownable,
    ERC165Storage
{
    // using Address for address;
    using Address for address payable;

    event Withdrawn(address[] claimTokens, uint256[] amounts);

    address public withdrawRecipient;
    bool public withdrawRecipientLocked;
    bool public withdrawPowerRevoked;
    WithdrawMode public withdrawMode;
    bool public withdrawModeLocked;

    /* INTERNAL */

    function __WithdrawExtension_init(
        address _withdrawRecipient,
        WithdrawMode _withdrawMode
    ) internal onlyInitializing {
        __WithdrawExtension_init_unchained(_withdrawRecipient, _withdrawMode);
    }

    function __WithdrawExtension_init_unchained(
        address _withdrawRecipient,
        WithdrawMode _withdrawMode
    ) internal onlyInitializing {
        _registerInterface(type(IWithdrawExtension).interfaceId);

        withdrawRecipient = _withdrawRecipient;
        withdrawMode = _withdrawMode;
    }

    /* ADMIN */

    function setWithdrawRecipient(address _withdrawRecipient)
        external
        onlyOwner
    {
        if (withdrawRecipientLocked) {
            revert WithdrawRecipientLocked();
        }

        withdrawRecipient = _withdrawRecipient;
    }

    function lockWithdrawRecipient() external onlyOwner {
        if (withdrawRecipientLocked) {
            revert WithdrawRecipientLocked();
        }

        withdrawRecipientLocked = true;
    }

    function setWithdrawMode(WithdrawMode _withdrawMode) external onlyOwner {
        if (withdrawModeLocked) {
            revert WithdrawModeLocked();
        }

        withdrawMode = _withdrawMode;
    }

    function lockWithdrawMode() external onlyOwner {
        if (withdrawModeLocked) {
            revert WithdrawModeLocked();
        }

        withdrawModeLocked = true;
    }

    /* PUBLIC */

    function withdraw(
        address[] calldata claimTokens,
        uint256[] calldata amounts
    ) external {
        /**
         * We are using msg.sender for smaller attack surface when evaluating
         * the sender of the function call. If in future we want to handle "withdraw"
         * functionality via meta transactions, we should consider using `_msgSender`
         */
        if (withdrawMode == WithdrawMode.NOBODY) {
            revert WithdrawPowerRevoked();
        } else if (withdrawMode == WithdrawMode.RECIPIENT) {
            if (withdrawRecipient != msg.sender) {
                revert WithdrawWrongRecipient();
            }
        } else if (withdrawMode == WithdrawMode.OWNER) {
            if (owner() != msg.sender) {
                revert WithdrawWrongRecipient();
            }
        }

        if (withdrawPowerRevoked) {
            revert WithdrawPowerRevoked();
        }

        for (uint256 i = 0; i < claimTokens.length; i++) {
            if (claimTokens[i] == address(0)) {
                payable(withdrawRecipient).sendValue(amounts[i]);
            } else {
                IERC20(claimTokens[i]).transfer(withdrawRecipient, amounts[i]);
            }
        }

        emit Withdrawn(claimTokens, amounts);
    }

    function revokeWithdrawPower() external onlyOwner {
        withdrawPowerRevoked = true;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Adopted from "@a16z/contracts/licenses/CantBeEvil.sol"
interface ICantBeEvil {
    function getLicenseURI() external view returns (string memory);

    function getLicenseName() external view returns (string memory);
}

interface ILicenseExtension {
    enum LicenseVersion {
        CBE_CC0,
        CBE_ECR,
        CBE_NECR,
        CBE_NECR_HS,
        CBE_PR,
        CBE_PR_HS,
        CUSTOM,
        UNLICENSED
    }

    error LicenseLocked();

    function setLicenseVersion(LicenseVersion licenseVersion) external;

    function lockLicenseVersion() external;
}

/**
 * @dev Extension to signal license for this NFT collection.
 */
abstract contract LicenseExtension is
    ILicenseExtension,
    ICantBeEvil,
    Initializable,
    Ownable,
    ERC165Storage
{
    using Strings for uint256;
    string internal constant A16Z_BASE_LICENSE_URI =
        "ar://_D9kN1WrNWbCq55BSAGRbTB4bS3v8QAPTYmBThSbX3A/";

    LicenseVersion public licenseVersion;
    string public customLicenseURI;
    string public customLicenseName;
    bool public licenseVersionLocked;

    function __LicenseExtension_init(LicenseVersion _licenseVersion)
        internal
        onlyInitializing
    {
        __LicenseExtension_init_unchained(_licenseVersion);
    }

    function __LicenseExtension_init_unchained(LicenseVersion _licenseVersion)
        internal
        onlyInitializing
    {
        _registerInterface(type(ILicenseExtension).interfaceId);
        _registerInterface(type(ICantBeEvil).interfaceId);

        licenseVersion = _licenseVersion;
    }

    /* ADMIN */

    function setCustomLicense(
        string calldata _customLicenseName,
        string calldata _customLicenseURI
    ) external onlyOwner {
        if (licenseVersionLocked) {
            revert LicenseLocked();
        }

        licenseVersion = LicenseVersion.CUSTOM;
        customLicenseName = _customLicenseName;
        customLicenseURI = _customLicenseURI;
    }

    function setLicenseVersion(LicenseVersion _licenseVersion)
        external
        override
        onlyOwner
    {
        if (licenseVersionLocked) {
            revert LicenseLocked();
        }

        licenseVersion = _licenseVersion;
    }

    function lockLicenseVersion() external override onlyOwner {
        licenseVersionLocked = true;
    }

    /* PUBLIC */

    function getLicenseURI() public view returns (string memory) {
        if (licenseVersion == LicenseVersion.CUSTOM) {
            return customLicenseURI;
        }
        if (licenseVersion == LicenseVersion.UNLICENSED) {
            return "";
        }

        return
            string.concat(
                A16Z_BASE_LICENSE_URI,
                uint256(licenseVersion).toString()
            );
    }

    function getLicenseName() public view returns (string memory) {
        if (licenseVersion == LicenseVersion.CUSTOM) {
            return customLicenseName;
        }
        if (licenseVersion == LicenseVersion.UNLICENSED) {
            return "";
        }

        if (LicenseVersion.CBE_CC0 == licenseVersion) return "CBE_CC0";
        if (LicenseVersion.CBE_ECR == licenseVersion) return "CBE_ECR";
        if (LicenseVersion.CBE_NECR == licenseVersion) return "CBE_NECR";
        if (LicenseVersion.CBE_NECR_HS == licenseVersion) return "CBE_NECR_HS";
        if (LicenseVersion.CBE_PR == licenseVersion) return "CBE_PR";
        else return "CBE_PR_HS";
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Context variant with ERC2771 support.
 */
abstract contract ERC2771ContextOwnable is Initializable, Context, Ownable {
    address public _trustedForwarder;

    function __ERC2771ContextOwnable_init(address trustedForwarder)
        internal
        onlyInitializing
    {
        __ERC2771ContextOwnable_init_unchained(trustedForwarder);
    }

    function __ERC2771ContextOwnable_init_unchained(address trustedForwarder)
        internal
        onlyInitializing
    {
        _trustedForwarder = trustedForwarder;
    }

    function setTrustedForwarder(address trustedForwarder) public onlyOwner {
        _trustedForwarder = trustedForwarder;
    }

    function isTrustedForwarder(address forwarder)
        public
        view
        virtual
        returns (bool)
    {
        return forwarder == _trustedForwarder;
    }

    function _msgSender()
        internal
        view
        virtual
        override
        returns (address sender)
    {
        if (isTrustedForwarder(msg.sender)) {
            // The assembly code is more direct than the Solidity version using `abi.decode`.
            assembly {
                sender := shr(96, calldataload(sub(calldatasize(), 20)))
            }
        } else {
            return super._msgSender();
        }
    }

    function _msgData()
        internal
        view
        virtual
        override
        returns (bytes calldata)
    {
        if (isTrustedForwarder(msg.sender)) {
            return msg.data[:msg.data.length - 20];
        } else {
            return super._msgData();
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@manifoldxyz/royalty-registry-solidity/contracts/overrides/IRoyaltyOverride.sol";
import "@manifoldxyz/royalty-registry-solidity/contracts/overrides/RoyaltyOverrideCore.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "../../../misc/rarible/IRoyalties.sol";
import "../../../misc/rarible/LibPart.sol";
import "../../../misc/rarible/LibRoyaltiesV2.sol";

interface IERC721RoyaltyExtension {
    function setTokenRoyalties(
        IEIP2981RoyaltyOverride.TokenRoyaltyConfig[] calldata royaltyConfigs
    ) external;

    function setDefaultRoyalty(
        IEIP2981RoyaltyOverride.TokenRoyalty calldata royalty
    ) external;

    function getRaribleV2Royalties(uint256 id)
        external
        view
        returns (LibPart.Part[] memory result);
}

/**
 * @dev Extension to signal configured royalty to famous marketplaces as well as ERC2981.
 *
 * This extension currently supports Standard ERC2981, Rarible.
 * Note that OpenSea is supported via Flair metadata feature.
 */
abstract contract ERC721RoyaltyExtension is
    IERC721RoyaltyExtension,
    IRoyalties,
    Initializable,
    Ownable,
    ERC165Storage,
    EIP2981RoyaltyOverrideCore
{
    function __ERC721RoyaltyExtension_init(
        address defaultRoyaltyReceiver,
        uint16 defaultRoyaltyBps
    ) internal onlyInitializing {
        __ERC721RoyaltyExtension_init_unchained(
            defaultRoyaltyReceiver,
            defaultRoyaltyBps
        );
    }

    function __ERC721RoyaltyExtension_init_unchained(
        address defaultRoyaltyReceiver,
        uint16 defaultRoyaltyBps
    ) internal onlyInitializing {
        _registerInterface(type(IERC721RoyaltyExtension).interfaceId);
        _registerInterface(type(IEIP2981).interfaceId);
        _registerInterface(type(IEIP2981RoyaltyOverride).interfaceId);
        _registerInterface(LibRoyaltiesV2._INTERFACE_ID_ROYALTIES);

        TokenRoyalty memory royalty = TokenRoyalty(
            defaultRoyaltyReceiver,
            defaultRoyaltyBps
        );

        _setDefaultRoyalty(royalty);
    }

    function setTokenRoyalties(TokenRoyaltyConfig[] calldata royaltyConfigs)
        external
        override(IEIP2981RoyaltyOverride, IERC721RoyaltyExtension)
        onlyOwner
    {
        _setTokenRoyalties(royaltyConfigs);
    }

    function setDefaultRoyalty(TokenRoyalty calldata royalty)
        external
        override(IEIP2981RoyaltyOverride, IERC721RoyaltyExtension)
        onlyOwner
    {
        _setDefaultRoyalty(royalty);
    }

    function getRaribleV2Royalties(uint256 id)
        external
        view
        override(IRoyalties, IERC721RoyaltyExtension)
        returns (LibPart.Part[] memory result)
    {
        result = new LibPart.Part[](1);

        result[0].account = payable(defaultRoyalty.recipient);
        result[0].value = defaultRoyalty.bps;

        id;
        // avoid unused param warning
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, EIP2981RoyaltyOverrideCore)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "erc721a/contracts/ERC721A.sol";

import {IERC721PrefixedMetadataExtension} from "../../ERC721/extensions/ERC721PrefixedMetadataExtension.sol";

/**
 * @dev Extension to allow configuring tokens metadata URI.
 *      In this extension tokens will have a shared token URI prefix,
 *      therefore on tokenURI() token's ID will be appended to the base URI.
 *      It also allows configuring a fallback "placeholder" URI when prefix is not set yet.
 */
abstract contract ERC721APrefixedMetadataExtension is
    IERC721PrefixedMetadataExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721A
{
    string internal _placeholderURI;
    string internal _tokenURIPrefix;
    string internal _tokenURISuffix;

    bool public tokenURIFrozen;

    function __ERC721APrefixedMetadataExtension_init(
        string memory placeholderURI_,
        string memory tokenURIPrefix_
    ) internal onlyInitializing {
        __ERC721APrefixedMetadataExtension_init_unchained(
            placeholderURI_,
            tokenURIPrefix_
        );
    }

    function __ERC721APrefixedMetadataExtension_init_unchained(
        string memory placeholderURI_,
        string memory tokenURIPrefix_
    ) internal onlyInitializing {
        _placeholderURI = placeholderURI_;
        _tokenURIPrefix = tokenURIPrefix_;
        _tokenURISuffix = ".json";

        _registerInterface(type(IERC721PrefixedMetadataExtension).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    /* ADMIN */

    function setPlaceholderURI(string memory newValue) external onlyOwner {
        _placeholderURI = newValue;
    }

    function setTokenURIPrefix(string memory newValue) external onlyOwner {
        require(!tokenURIFrozen, "FROZEN");
        _tokenURIPrefix = newValue;
    }

    function setTokenURISuffix(string memory newValue) external onlyOwner {
        require(!tokenURIFrozen, "FROZEN");
        _tokenURISuffix = newValue;
    }

    function freezeTokenURI() external onlyOwner {
        tokenURIFrozen = true;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721A)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function placeholderURI() public view returns (string memory) {
        return _placeholderURI;
    }

    function tokenURIPrefix() public view returns (string memory) {
        return _tokenURIPrefix;
    }

    function tokenURISuffix() public view returns (string memory) {
        return _tokenURISuffix;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721A, IERC721PrefixedMetadataExtension)
        returns (string memory)
    {
        return
            bytes(_tokenURIPrefix).length > 0
                ? string(
                    abi.encodePacked(
                        _tokenURIPrefix,
                        Strings.toString(_tokenId),
                        _tokenURISuffix
                    )
                )
                : _placeholderURI;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721OwnerMintExtension} from "../../ERC721/extensions/ERC721OwnerMintExtension.sol";

/**
 * @dev Extension to allow owner to mint directly without paying.
 */
abstract contract ERC721AOwnerMintExtension is
    IERC721OwnerMintExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AMinterExtension
{
    function __ERC721AOwnerMintExtension_init() internal onlyInitializing {
        __ERC721AOwnerMintExtension_init_unchained();
    }

    function __ERC721AOwnerMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OwnerMintExtension).interfaceId);
    }

    /* ADMIN */

    function mintByOwner(address to, uint256 count) external onlyOwner {
        _mintTo(to, count);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721TieringExtension} from "../../ERC721/extensions/ERC721TieringExtension.sol";

/**
 * @dev Extension to allow multiple tiers for minting,
 *      you can configure, different minting window, price, currency, max per wallet, and allowlist per tier.
 */
abstract contract ERC721ATieringExtension is
    IERC721TieringExtension,
    Initializable,
    Ownable,
    ERC721AMinterExtension,
    ReentrancyGuard
{
    mapping(uint256 => Tier) public tiers;

    uint256 public totalReserved;

    mapping(uint256 => uint256) public tierMints;

    mapping(uint256 => mapping(address => uint256)) internal walletMinted;

    uint256 public reservedMints;

    function __ERC721ATieringExtension_init(Tier[] memory _tiers)
        internal
        onlyInitializing
    {
        __ERC721ATieringExtension_init_unchained(_tiers);
    }

    function __ERC721ATieringExtension_init_unchained(Tier[] memory _tiers)
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721TieringExtension).interfaceId);

        for (uint256 i = 0; i < _tiers.length; i++) {
            tiers[i] = _tiers[i];
            totalReserved += _tiers[i].reserved;
        }
    }

    /* ADMIN */

    function configureTiering(uint256 tierId, Tier calldata tier)
        public
        onlyOwner
    {
        require(tier.maxAllocation >= tierMints[tierId], "LOWER_THAN_MINTED");

        if (tiers[tierId].reserved > 0) {
            require(tier.reserved >= tierMints[tierId], "LOW_RESERVE_AMOUNT");
        }

        if (tierMints[tierId] > 0) {
            require(
                tier.maxPerWallet >= tiers[tierId].maxPerWallet,
                "LOW_MAX_PER_WALLET"
            );
        }

        totalReserved -= tiers[tierId].reserved;
        tiers[tierId] = tier;
        totalReserved += tier.reserved;

        require(totalReserved <= maxSupply, "MAX_SUPPLY_EXCEEDED");
    }

    function configureTiering(
        uint256[] calldata _tierIds,
        Tier[] calldata _tiers
    ) public onlyOwner {
        for (uint256 i = 0; i < _tierIds.length; i++) {
            configureTiering(_tierIds[i], _tiers[i]);
        }
    }

    /* PUBLIC */

    function setMaxSupply(uint256 newValue)
        public
        virtual
        override(ERC721AMinterExtension)
        onlyOwner
    {
        ERC721AMinterExtension.setMaxSupply(newValue);
        require(
            newValue - totalSupply() >= totalReserved - reservedMints,
            "TOOLOW"
        );
    }

    function onTierAllowlist(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) public view returns (bool) {
        return
            MerkleProof.verify(
                proof,
                tiers[tierId].merkleRoot,
                _generateMerkleLeaf(minter, maxAllowance)
            );
    }

    function eligibleForTier(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) public view returns (uint256 maxMintable) {
        require(tiers[tierId].maxPerWallet > 0, "NOT_EXISTS");
        require(block.timestamp >= tiers[tierId].start, "NOT_STARTED");
        require(block.timestamp <= tiers[tierId].end, "ALREADY_ENDED");

        maxMintable = tiers[tierId].maxPerWallet - walletMinted[tierId][minter];

        if (tiers[tierId].merkleRoot != bytes32(0)) {
            require(
                walletMinted[tierId][minter] < maxAllowance,
                "MAXED_ALLOWANCE"
            );
            require(
                onTierAllowlist(tierId, minter, maxAllowance, proof),
                "NOT_ALLOWLISTED"
            );

            uint256 remainingAllowance = maxAllowance -
                walletMinted[tierId][minter];

            if (maxMintable > remainingAllowance) {
                maxMintable = remainingAllowance;
            }
        }
    }

    function mintByTier(
        uint256 tierId,
        uint256 count,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) external payable nonReentrant {
        address minter = _msgSender();

        uint256 maxMintable = eligibleForTier(
            tierId,
            minter,
            maxAllowance,
            proof
        );

        require(count <= maxMintable, "EXCEEDS_MAX");
        require(count <= remainingForTier(tierId), "EXCEEDS_ALLOCATION");
        require(
            count + tierMints[tierId] <= tiers[tierId].maxAllocation,
            "EXCEEDS_ALLOCATION"
        );

        if (tiers[tierId].currency == address(0)) {
            require(tiers[tierId].price * count <= msg.value, "LOW_AMOUNT");
        } else {
            IERC20(tiers[tierId].currency).transferFrom(
                minter,
                address(this),
                tiers[tierId].price * count
            );
        }

        walletMinted[tierId][minter] += count;
        tierMints[tierId] += count;

        if (tiers[tierId].reserved > 0) {
            reservedMints += count;
        }

        _mintTo(minter, count);
    }

    function remainingForTier(uint256 tierId)
        public
        view
        returns (uint256 tierRemaining)
    {
        // Substract all the remaining reserved spots from the total remaining supply...
        tierRemaining =
            (maxSupply - totalSupply()) -
            (totalReserved - reservedMints);

        // If this tier has reserved spots, add remaining spots back to result...
        if (tiers[tierId].reserved > 0) {
            tierRemaining += (tiers[tierId].reserved - tierMints[tierId]);
        }
    }

    function walletMintedByTier(uint256 tierId, address wallet)
        public
        view
        returns (uint256)
    {
        return walletMinted[tierId][wallet];
    }

    /* PRIVATE */

    function _generateMerkleLeaf(address account, uint256 maxAllowance)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, maxAllowance));
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721RoleBasedMintExtension} from "../../ERC721/extensions/ERC721RoleBasedMintExtension.sol";

/**
 * @dev Extension to allow holders of a OpenZepplin-based role to mint directly.
 */
abstract contract ERC721ARoleBasedMintExtension is
    IERC721RoleBasedMintExtension,
    ERC165Storage,
    ERC721AMinterExtension,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function __ERC721ARoleBasedMintExtension_init(address minter)
        internal
        onlyInitializing
    {
        __ERC721ARoleBasedMintExtension_init_unchained(minter);
    }

    function __ERC721ARoleBasedMintExtension_init_unchained(address minter)
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721RoleBasedMintExtension).interfaceId);

        _setupRole(MINTER_ROLE, minter);
    }

    /* ADMIN */

    function mintByRole(address to, uint256 count) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "NOT_MINTER_ROLE");

        _mintTo(to, count);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            AccessControl,
            ERC721ACollectionMetadataExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721ALockableExtension.sol";

interface IERC721ARoleBasedLockableExtension {
    function hasRoleBasedLockableExtension() external view returns (bool);
}

/**
 * @dev Extension to allow locking NFTs, for use-cases like staking, without leaving holders wallet, using roles.
 */
abstract contract ERC721ARoleBasedLockableExtension is
    IERC721ARoleBasedLockableExtension,
    ERC721ALockableExtension,
    AccessControl
{
    using BitMaps for BitMaps.BitMap;

    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    function __ERC721ARoleBasedLockableExtension_init()
        internal
        onlyInitializing
    {
        __ERC721ARoleBasedLockableExtension_init_unchained();
    }

    function __ERC721ARoleBasedLockableExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(
            type(IERC721ARoleBasedLockableExtension).interfaceId
        );
    }

    // ADMIN

    /**
     * Locks token(s) to effectively lock them, while keeping in the same wallet.
     * This mechanism prevents them from being transferred, yet still will show correct owner.
     */
    function lock(uint256 tokenId) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");
        _lock(tokenId);
    }

    function lock(uint256[] calldata tokenIds) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "STAKABLE_NOT_LOCKER_ROLE");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _lock(tokenIds[i]);
        }
    }

    /**
     * Unlocks locked token(s) to be able to transfer.
     */
    function unlock(uint256 tokenId) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");
        _unlock(tokenId);
    }

    function unlock(uint256[] calldata tokenIds) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "STAKABLE_NOT_LOCKER_ROLE");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _unlock(tokenIds[i]);
        }
    }

    // PUBLIC

    function hasRoleBasedLockableExtension()
        public
        view
        virtual
        returns (bool)
    {
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721ALockableExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Counters.sol)

pragma solidity ^0.8.0;

/**
 * @title Counters
 * @author Matt Condon (@shrugs)
 * @dev Provides counters that can only be incremented, decremented or reset. This can be used e.g. to track the number
 * of elements in a mapping, issuing ERC721 ids, or counting request ids.
 *
 * Include with `using Counters for Counters.Counter;`
 */
library Counters {
    struct Counter {
        // This variable should never be directly accessed by users of the library: interactions must be restricted to
        // the library's function. As of Solidity v0.5.2, this cannot be enforced, though there is a proposal to add
        // this feature: see https://github.com/ethereum/solidity/issues/4637
        uint256 _value; // default: 0
    }

    function current(Counter storage counter) internal view returns (uint256) {
        return counter._value;
    }

    function increment(Counter storage counter) internal {
        unchecked {
            counter._value += 1;
        }
    }

    function decrement(Counter storage counter) internal {
        uint256 value = counter._value;
        require(value > 0, "Counter: decrement overflow");
        unchecked {
            counter._value = value - 1;
        }
    }

    function reset(Counter storage counter) internal {
        counter._value = 0;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

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
        // On the first call to nonReentrant, _notEntered will be true
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;

        _;

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

pragma solidity 0.8.15;
pragma abicoder v2;

import "./LibPart.sol";

interface IRoyalties {
    function getRaribleV2Royalties(uint256 id)
        external
        view
        returns (LibPart.Part[] memory);
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

library LibPart {
    bytes32 public constant TYPE_HASH =
        keccak256("Part(address account,uint96 value)");

    struct Part {
        address payable account;
        uint96 value;
    }

    function hash(Part memory part) internal pure returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, part.account, part.value));
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

library LibRoyaltiesV2 {
    /*
     * bytes4(keccak256('getRaribleV2Royalties(uint256)')) == 0xcad96cca
     */
    bytes4 constant _INTERFACE_ID_ROYALTIES = 0xcad96cca;
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "./IRoyaltyOverride.sol";
import "../specs/IEIP2981.sol";

/**
 * Simple EIP2981 reference override implementation
 */
abstract contract EIP2981RoyaltyOverrideCore is IEIP2981, IEIP2981RoyaltyOverride, ERC165 {
    using EnumerableSet for EnumerableSet.UintSet;

    TokenRoyalty public defaultRoyalty;
    mapping(uint256 => TokenRoyalty) private _tokenRoyalties;
    EnumerableSet.UintSet private _tokensWithRoyalties;

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IEIP2981).interfaceId || interfaceId == type(IEIP2981RoyaltyOverride).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets token royalties. When you override this in the implementation contract
     * ensure that you access restrict it to the contract owner or admin
     */
    function _setTokenRoyalties(TokenRoyaltyConfig[] memory royaltyConfigs) internal {
        for (uint i = 0; i < royaltyConfigs.length; i++) {
            TokenRoyaltyConfig memory royaltyConfig = royaltyConfigs[i];
            require(royaltyConfig.bps < 10000, "Invalid bps");
            if (royaltyConfig.recipient == address(0)) {
                delete _tokenRoyalties[royaltyConfig.tokenId];
                _tokensWithRoyalties.remove(royaltyConfig.tokenId);
                emit TokenRoyaltyRemoved(royaltyConfig.tokenId);
            } else {
                _tokenRoyalties[royaltyConfig.tokenId] = TokenRoyalty(royaltyConfig.recipient, royaltyConfig.bps);
                _tokensWithRoyalties.add(royaltyConfig.tokenId);
                emit TokenRoyaltySet(royaltyConfig.tokenId, royaltyConfig.recipient, royaltyConfig.bps);
            }
        }
    }

    /**
     * @dev Sets default royalty. When you override this in the implementation contract
     * ensure that you access restrict it to the contract owner or admin
     */
    function _setDefaultRoyalty(TokenRoyalty memory royalty) internal {
        require(royalty.bps < 10000, "Invalid bps");
        defaultRoyalty = TokenRoyalty(royalty.recipient, royalty.bps);
        emit DefaultRoyaltySet(royalty.recipient, royalty.bps);
    }

    /**
     * @dev See {IEIP2981RoyaltyOverride-getTokenRoyaltiesCount}.
     */
    function getTokenRoyaltiesCount() external override view returns(uint256) {
        return _tokensWithRoyalties.length();
    }

    /**
     * @dev See {IEIP2981RoyaltyOverride-getTokenRoyaltyByIndex}.
     */
    function getTokenRoyaltyByIndex(uint256 index) external override view returns(TokenRoyaltyConfig memory) {
        uint256 tokenId = _tokensWithRoyalties.at(index);
        TokenRoyalty memory royalty = _tokenRoyalties[tokenId];
        return TokenRoyaltyConfig(tokenId, royalty.recipient, royalty.bps);
    }

    /**
     * @dev See {IEIP2981RoyaltyOverride-royaltyInfo}.
     */
    function royaltyInfo(uint256 tokenId, uint256 value) public override view returns (address, uint256) {
        if (_tokenRoyalties[tokenId].recipient != address(0)) {
            return (_tokenRoyalties[tokenId].recipient, value*_tokenRoyalties[tokenId].bps/10000);
        }
        if (defaultRoyalty.recipient != address(0) && defaultRoyalty.bps != 0) {
            return (defaultRoyalty.recipient, value*defaultRoyalty.bps/10000);
        }
        return (address(0), 0);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/**
 * Simple EIP2981 reference override implementation
 */
interface IEIP2981RoyaltyOverride is IERC165 {

    event TokenRoyaltyRemoved(uint256 tokenId);
    event TokenRoyaltySet(uint256 tokenId, address recipient, uint16 bps);
    event DefaultRoyaltySet(address recipient, uint16 bps);

    struct TokenRoyalty {
        address recipient;
        uint16 bps;
    }

    struct TokenRoyaltyConfig {
        uint256 tokenId;
        address recipient;
        uint16 bps;
    }

    /**
     * @dev Set per token royalties.  Passing a recipient of address(0) will delete any existing configuration
     */
    function setTokenRoyalties(TokenRoyaltyConfig[] calldata royalties) external;

    /**
     * @dev Get the number of token specific overrides.  Used to enumerate over all configurations
     */
    function getTokenRoyaltiesCount() external view returns(uint256);

    /**
     * @dev Get a token royalty configuration by index.  Use in conjunction with getTokenRoyaltiesCount to get all per token configurations
     */
    function getTokenRoyaltyByIndex(uint256 index) external view returns(TokenRoyaltyConfig memory);

    /**
     * @dev Set a default royalty configuration.  Will be used if no token specific configuration is set
     */
    function setDefaultRoyalty(TokenRoyalty calldata royalty) external;

}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/structs/EnumerableSet.sol)

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
 *  Trying to delete such a structure from storage will likely result in data corruption, rendering the structure unusable.
 *  See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 *  In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an array of EnumerableSet.
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
        return _values(set._inner);
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
     * @dev Returns the number of values on the set. O(1).
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

pragma solidity ^0.8.0;

/**
 * EIP-2981
 */
interface IEIP2981 {
    /**
     * bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
     *
     * => 0x2a55205a = 0x2a55205a
     */
    function royaltyInfo(uint256 tokenId, uint256 value) external view returns (address, uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721CollectionMetadataExtension.sol";

interface IERC721PrefixedMetadataExtension {
    function setPlaceholderURI(string memory newValue) external;

    function setTokenURIPrefix(string memory newValue) external;

    function setTokenURISuffix(string memory newValue) external;

    function placeholderURI() external view returns (string memory);

    function tokenURIPrefix() external view returns (string memory);

    function tokenURISuffix() external view returns (string memory);

    function tokenURI(uint256 _tokenId) external view returns (string memory);

    function freezeTokenURI() external;
}

/**
 * @dev Extension to allow configuring tokens metadata URI.
 *      In this extension tokens will have a shared token URI prefix,
 *      therefore on tokenURI() token's ID will be appended to the base URI.
 *      It also allows configuring a fallback "placeholder" URI when prefix is not set yet.
 */
abstract contract ERC721PrefixedMetadataExtension is
    IERC721PrefixedMetadataExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721
{
    string internal _placeholderURI;
    string internal _tokenURIPrefix;
    string internal _tokenURISuffix;

    bool public tokenURIFrozen;

    function __ERC721PrefixedMetadataExtension_init(
        string memory placeholderURI_,
        string memory tokenURIPrefix_
    ) internal onlyInitializing {
        __ERC721PrefixedMetadataExtension_init_unchained(
            placeholderURI_,
            tokenURIPrefix_
        );
    }

    function __ERC721PrefixedMetadataExtension_init_unchained(
        string memory placeholderURI_,
        string memory tokenURIPrefix_
    ) internal onlyInitializing {
        _placeholderURI = placeholderURI_;
        _tokenURIPrefix = tokenURIPrefix_;
        _tokenURISuffix = ".json";

        _registerInterface(type(IERC721PrefixedMetadataExtension).interfaceId);
        _registerInterface(type(IERC721Metadata).interfaceId);
    }

    /* ADMIN */

    function setPlaceholderURI(string memory newValue) external onlyOwner {
        _placeholderURI = newValue;
    }

    function setTokenURIPrefix(string memory newValue) external onlyOwner {
        require(!tokenURIFrozen, "FROZEN");
        _tokenURIPrefix = newValue;
    }

    function setTokenURISuffix(string memory newValue) external onlyOwner {
        require(!tokenURIFrozen, "FROZEN");
        _tokenURISuffix = newValue;
    }

    function freezeTokenURI() external onlyOwner {
        tokenURIFrozen = true;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function placeholderURI() public view returns (string memory) {
        return _placeholderURI;
    }

    function tokenURIPrefix() public view returns (string memory) {
        return _tokenURIPrefix;
    }

    function tokenURISuffix() public view returns (string memory) {
        return _tokenURISuffix;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, IERC721PrefixedMetadataExtension)
        returns (string memory)
    {
        return
            bytes(_tokenURIPrefix).length > 0
                ? string(
                    abi.encodePacked(
                        _tokenURIPrefix,
                        Strings.toString(_tokenId),
                        _tokenURISuffix
                    )
                )
                : _placeholderURI;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721OwnerMintExtension {
    function mintByOwner(address to, uint256 count) external;
}

/**
 * @dev Extension to allow owner to mint directly without paying.
 */
abstract contract ERC721OwnerMintExtension is
    IERC721OwnerMintExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AutoIdMinterExtension
{
    function __ERC721OwnerMintExtension_init() internal onlyInitializing {
        __ERC721OwnerMintExtension_init_unchained();
    }

    function __ERC721OwnerMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OwnerMintExtension).interfaceId);
    }

    /* ADMIN */

    function mintByOwner(address to, uint256 count) external onlyOwner {
        _mintTo(to, count);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721TieringExtension {
    struct Tier {
        uint256 start;
        uint256 end;
        address currency;
        uint256 price;
        uint256 maxPerWallet;
        bytes32 merkleRoot;
        uint256 reserved;
        uint256 maxAllocation;
    }

    function onTierAllowlist(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) external view returns (bool);

    function eligibleForTier(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) external view returns (uint256);

    function mintByTier(
        uint256 tierId,
        uint256 count,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) external payable;
}

/**
 * @dev Extension to allow multiple tiers for minting,
 *      you can configure, different minting window, price, currency, max per wallet, and allowlist per tier.
 */
abstract contract ERC721TieringExtension is
    IERC721TieringExtension,
    Initializable,
    Ownable,
    ERC721AutoIdMinterExtension,
    ReentrancyGuard
{
    mapping(uint256 => Tier) public tiers;

    uint256 public totalReserved;

    mapping(uint256 => uint256) public tierMints;

    mapping(uint256 => mapping(address => uint256)) public walletMinted;

    uint256 public reservedMints;

    function __ERC721TieringExtension_init(Tier[] memory _tiers)
        internal
        onlyInitializing
    {
        __ERC721TieringExtension_init_unchained(_tiers);
    }

    function __ERC721TieringExtension_init_unchained(Tier[] memory _tiers)
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721TieringExtension).interfaceId);

        for (uint256 i = 0; i < _tiers.length; i++) {
            tiers[i] = _tiers[i];
            totalReserved += _tiers[i].reserved;
        }
    }

    /* ADMIN */

    function configureTiering(uint256 tierId, Tier calldata tier)
        public
        onlyOwner
    {
        require(tier.maxAllocation >= tierMints[tierId], "LOWER_THAN_MINTED");

        if (tiers[tierId].reserved > 0) {
            require(tier.reserved >= tierMints[tierId], "LOW_RESERVE_AMOUNT");
        }

        if (tierMints[tierId] > 0) {
            require(
                tier.maxPerWallet >= tiers[tierId].maxPerWallet,
                "LOW_MAX_PER_WALLET"
            );
        }

        totalReserved -= tiers[tierId].reserved;
        tiers[tierId] = tier;
        totalReserved += tier.reserved;

        require(totalReserved <= maxSupply, "MAX_SUPPLY_EXCEEDED");
    }

    function configureTiering(
        uint256[] calldata _tierIds,
        Tier[] calldata _tiers
    ) public onlyOwner {
        for (uint256 i = 0; i < _tierIds.length; i++) {
            configureTiering(_tierIds[i], _tiers[i]);
        }
    }

    /* PUBLIC */

    function setMaxSupply(uint256 newValue)
        public
        virtual
        override(ERC721AutoIdMinterExtension)
        onlyOwner
    {
        ERC721AutoIdMinterExtension.setMaxSupply(newValue);
        require(
            newValue - totalSupply() >= totalReserved - reservedMints,
            "TOOLOW"
        );
    }

    function onTierAllowlist(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) public view returns (bool) {
        return
            MerkleProof.verify(
                proof,
                tiers[tierId].merkleRoot,
                _generateMerkleLeaf(minter, maxAllowance)
            );
    }

    function eligibleForTier(
        uint256 tierId,
        address minter,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) public view returns (uint256 maxMintable) {
        require(tiers[tierId].maxPerWallet > 0, "NOT_EXISTS");
        require(block.timestamp >= tiers[tierId].start, "NOT_STARTED");
        require(block.timestamp <= tiers[tierId].end, "ALREADY_ENDED");

        maxMintable = tiers[tierId].maxPerWallet - walletMinted[tierId][minter];

        if (tiers[tierId].merkleRoot != bytes32(0)) {
            require(
                walletMinted[tierId][minter] < maxAllowance,
                "MAXED_ALLOWANCE"
            );
            require(
                onTierAllowlist(tierId, minter, maxAllowance, proof),
                "NOT_ALLOWLISTED"
            );

            uint256 remainingAllowance = maxAllowance -
                walletMinted[tierId][minter];

            if (maxMintable > remainingAllowance) {
                maxMintable = remainingAllowance;
            }
        }
    }

    function mintByTier(
        uint256 tierId,
        uint256 count,
        uint256 maxAllowance,
        bytes32[] calldata proof
    ) external payable nonReentrant {
        address minter = _msgSender();

        uint256 maxMintable = eligibleForTier(
            tierId,
            minter,
            maxAllowance,
            proof
        );

        require(count <= maxMintable, "EXCEEDS_MAX");
        require(count <= remainingForTier(tierId), "EXCEEDS_ALLOCATION");
        require(
            count + tierMints[tierId] <= tiers[tierId].maxAllocation,
            "EXCEEDS_ALLOCATION"
        );

        if (tiers[tierId].currency == address(0)) {
            require(tiers[tierId].price * count <= msg.value, "LOW_AMOUNT");
        } else {
            IERC20(tiers[tierId].currency).transferFrom(
                minter,
                address(this),
                tiers[tierId].price * count
            );
        }

        walletMinted[tierId][minter] += count;
        tierMints[tierId] += count;

        if (tiers[tierId].reserved > 0) {
            reservedMints += count;
        }

        _mintTo(minter, count);
    }

    function remainingForTier(uint256 tierId)
        public
        view
        returns (uint256 tierRemaining)
    {
        // Substract all the remaining reserved spots from the total remaining supply...
        tierRemaining =
            (maxSupply - totalSupply()) -
            (totalReserved - reservedMints);

        // If this tier has reserved spots, add remaining spots back to result...
        if (tiers[tierId].reserved > 0) {
            tierRemaining += (tiers[tierId].reserved - tierMints[tierId]);
        }
    }

    function walletMintedByTier(uint256 tierId, address wallet)
        public
        view
        returns (uint256)
    {
        return walletMinted[tierId][wallet];
    }

    /* PRIVATE */

    function _generateMerkleLeaf(address account, uint256 maxAllowance)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account, maxAllowance));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The proofs can be generated using the JavaScript library
 * https://github.com/miguelmota/merkletreejs[merkletreejs].
 * Note: the hashing algorithm should be keccak256 and pair sorting should be enabled.
 *
 * See `test/utils/cryptography/MerkleProof.test.js` for some examples.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 leaf
    ) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be proved to be a part of a Merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and the sibling nodes in `proof`,
     * consuming from one or the other at each step according to the instructions given by
     * `proofFlags`.
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuild the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proof.length - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value for the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i] ? leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++] : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            return hashes[totalHashes - 1];
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721RoleBasedMintExtension {
    function mintByRole(address to, uint256 count) external;
}

/**
 * @dev Extension to allow holders of a OpenZepplin-based role to mint directly.
 */
abstract contract ERC721RoleBasedMintExtension is
    IERC721RoleBasedMintExtension,
    Initializable,
    ERC165Storage,
    ERC721AutoIdMinterExtension,
    AccessControl
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function __ERC721RoleBasedMintExtension_init(address minter)
        internal
        onlyInitializing
    {
        __ERC721RoleBasedMintExtension_init_unchained(minter);
    }

    function __ERC721RoleBasedMintExtension_init_unchained(address minter)
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721RoleBasedMintExtension).interfaceId);

        _setupRole(MINTER_ROLE, minter);
    }

    /* ADMIN */

    function mintByRole(address to, uint256 count) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "NOT_MINTER_ROLE");

        _mintTo(to, count);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            AccessControl,
            ERC721CollectionMetadataExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

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
abstract contract AccessControl is Context, IAccessControl, ERC165 {
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
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
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
                        Strings.toHexString(uint160(account), 20),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
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
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
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

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721AMinterExtension.sol";

interface IERC721ALockableExtension {
    function locked(uint256 tokenId) external view returns (bool);

    function lock(uint256 tokenId) external;

    function lock(uint256[] calldata tokenIds) external;

    function unlock(uint256 tokenId) external;

    function unlock(uint256[] calldata tokenIds) external;
}

/**
 * @dev Extension to allow locking NFTs, for use-cases like staking, without leaving holders wallet.
 */
abstract contract ERC721ALockableExtension is
    IERC721ALockableExtension,
    Initializable,
    ERC165Storage,
    ERC721AMinterExtension,
    ReentrancyGuard
{
    using BitMaps for BitMaps.BitMap;

    BitMaps.BitMap internal lockedTokens;

    function __ERC721ALockableExtension_init() internal onlyInitializing {
        __ERC721ALockableExtension_init_unchained();
    }

    function __ERC721ALockableExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721ALockableExtension).interfaceId);
    }

    // PUBLIC

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    /**
     * At this moment staking is only possible from a certain address (usually a smart contract).
     *
     * This is because in almost all cases you want another contract to perform custom logic on lock and unlock operations,
     * without allowing users to directly unlock their tokens and sell them, for example.
     */
    function _lock(uint256 tokenId) internal virtual {
        require(!lockedTokens.get(tokenId), "LOCKED");
        lockedTokens.set(tokenId);
    }

    function _unlock(uint256 tokenId) internal virtual {
        require(lockedTokens.get(tokenId), "NOT_LOCKED");
        lockedTokens.unset(tokenId);
    }

    /**
     * Returns if a token is locked or not.
     */
    function locked(uint256 tokenId) public view virtual returns (bool) {
        return lockedTokens.get(tokenId);
    }

    function filterUnlocked(uint256[] calldata ticketTokenIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory unlocked = new uint256[](ticketTokenIds.length);

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            if (!locked(ticketTokenIds[i])) {
                unlocked[i] = ticketTokenIds[i];
            }
        }

        return unlocked;
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A) {
        require(
            // We are not checking the quantity because it is only used during mint where users cannot stake/unstake.
            !lockedTokens.get(startTokenId),
            "LOCKED"
        );
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/structs/BitMaps.sol)
pragma solidity ^0.8.0;

/**
 * @dev Library for managing uint256 to bool mapping in a compact and efficient way, providing the keys are sequential.
 * Largelly inspired by Uniswap's https://github.com/Uniswap/merkle-distributor/blob/master/contracts/MerkleDistributor.sol[merkle-distributor].
 */
library BitMaps {
    struct BitMap {
        mapping(uint256 => uint256) _data;
    }

    /**
     * @dev Returns whether the bit at `index` is set.
     */
    function get(BitMap storage bitmap, uint256 index) internal view returns (bool) {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        return bitmap._data[bucket] & mask != 0;
    }

    /**
     * @dev Sets the bit at `index` to the boolean `value`.
     */
    function setTo(
        BitMap storage bitmap,
        uint256 index,
        bool value
    ) internal {
        if (value) {
            set(bitmap, index);
        } else {
            unset(bitmap, index);
        }
    }

    /**
     * @dev Sets the bit at `index`.
     */
    function set(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] |= mask;
    }

    /**
     * @dev Unsets the bit at `index`.
     */
    function unset(BitMap storage bitmap, uint256 index) internal {
        uint256 bucket = index >> 8;
        uint256 mask = 1 << (index & 0xff);
        bitmap._data[bucket] &= ~mask;
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC721/extensions/ERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";
import "./IERC721Enumerable.sol";

/**
 * @dev This implements an optional extension of {ERC721} defined in the EIP that adds
 * enumerability of all the token ids in the contract as well as all token ids owned by each
 * account.
 */
abstract contract ERC721Enumerable is ERC721, IERC721Enumerable {
    // Mapping from owner to list of owned token IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) private _ownedTokensIndex;

    // Array with all token ids, used for enumeration
    uint256[] private _allTokens;

    // Mapping from token id to position in the allTokens array
    mapping(uint256 => uint256) private _allTokensIndex;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Enumerable-tokenOfOwnerByIndex}.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721.balanceOf(owner), "ERC721Enumerable: owner index out of bounds");
        return _ownedTokens[owner][index];
    }

    /**
     * @dev See {IERC721Enumerable-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    /**
     * @dev See {IERC721Enumerable-tokenByIndex}.
     */
    function tokenByIndex(uint256 index) public view virtual override returns (uint256) {
        require(index < ERC721Enumerable.totalSupply(), "ERC721Enumerable: global index out of bounds");
        return _allTokens[index];
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     *
     * Calling conditions:
     *
     * - When `from` and `to` are both non-zero, ``from``'s `tokenId` will be
     * transferred to `to`.
     * - When `from` is zero, `tokenId` will be minted for `to`.
     * - When `to` is zero, ``from``'s `tokenId` will be burned.
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);

        if (from == address(0)) {
            _addTokenToAllTokensEnumeration(tokenId);
        } else if (from != to) {
            _removeTokenFromOwnerEnumeration(from, tokenId);
        }
        if (to == address(0)) {
            _removeTokenFromAllTokensEnumeration(tokenId);
        } else if (to != from) {
            _addTokenToOwnerEnumeration(to, tokenId);
        }
    }

    /**
     * @dev Private function to add a token to this extension's ownership-tracking data structures.
     * @param to address representing the new owner of the given token ID
     * @param tokenId uint256 ID of the token to be added to the tokens list of the given address
     */
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        uint256 length = ERC721.balanceOf(to);
        _ownedTokens[to][length] = tokenId;
        _ownedTokensIndex[tokenId] = length;
    }

    /**
     * @dev Private function to add a token to this extension's token tracking data structures.
     * @param tokenId uint256 ID of the token to be added to the tokens list
     */
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    /**
     * @dev Private function to remove a token from this extension's ownership-tracking data structures. Note that
     * while the token is not assigned a new owner, the `_ownedTokensIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a transfer operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedTokens array.
     * @param from address representing the previous owner of the given token ID
     * @param tokenId uint256 ID of the token to be removed from the tokens list of the given address
     */
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        // To prevent a gap in from's tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = ERC721.balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary
        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];

            _ownedTokens[from][tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
            _ownedTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    /**
     * @dev Private function to remove a token from this extension's token tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allTokens array.
     * @param tokenId uint256 ID of the token to be removed from the tokens list
     */
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        uint256 lastTokenId = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenId; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenId] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId];
        _allTokens.pop();
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/extensions/IERC721Enumerable.sol)

pragma solidity ^0.8.0;

import "../IERC721.sol";

/**
 * @title ERC-721 Non-Fungible Token Standard, optional enumeration extension
 * @dev See https://eips.ethereum.org/EIPS/eip-721
 */
interface IERC721Enumerable is IERC721 {
    /**
     * @dev Returns the total amount of tokens stored by the contract.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns a token ID owned by `owner` at a given `index` of its token list.
     * Use along with {balanceOf} to enumerate all of ``owner``'s tokens.
     */
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);

    /**
     * @dev Returns a token ID at a given `index` of all the tokens stored by the contract.
     * Use along with {totalSupply} to enumerate all tokens.
     */
    function tokenByIndex(uint256 index) external view returns (uint256);
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../common/WithdrawExtension.sol";
import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../../ERC721/extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721ACollectionMetadataExtension.sol";
import "../extensions/ERC721APrefixedMetadataExtension.sol";
import "../extensions/ERC721AMinterExtension.sol";
import "../extensions/ERC721AOwnerMintExtension.sol";
import "../extensions/ERC721APreSaleExtension.sol";
import "../extensions/ERC721APublicSaleExtension.sol";
import "../extensions/ERC721ARoleBasedMintExtension.sol";
import "../extensions/ERC721ARoleBasedLockableExtension.sol";

contract ERC721ASimpleSalesCollection is
    Initializable,
    Ownable,
    ERC165Storage,
    WithdrawExtension,
    LicenseExtension,
    ERC721ACollectionMetadataExtension,
    ERC721APrefixedMetadataExtension,
    ERC721AMinterExtension,
    ERC721AOwnerMintExtension,
    ERC721APreSaleExtension,
    ERC721APublicSaleExtension,
    ERC721ARoleBasedMintExtension,
    ERC721ARoleBasedLockableExtension,
    ERC721RoyaltyExtension,
    ERC2771ContextOwnable
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        string placeholderURI;
        string tokenURIPrefix;
        uint256 maxSupply;
        uint256 preSalePrice;
        uint256 preSaleMaxMintPerWallet;
        uint256 publicSalePrice;
        uint256 publicSaleMaxMintPerTx;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address proceedsRecipient;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721A(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);

        _transferOwnership(deployer);

        __WithdrawExtension_init(config.proceedsRecipient, WithdrawMode.ANYONE);
        __LicenseExtension_init(config.licenseVersion);
        __ERC721ACollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721APrefixedMetadataExtension_init(
            config.placeholderURI,
            config.tokenURIPrefix
        );
        __ERC721AMinterExtension_init(config.maxSupply);
        __ERC721AOwnerMintExtension_init();
        __ERC721ARoleBasedMintExtension_init(deployer);
        __ERC721ARoleBasedLockableExtension_init();
        __ERC721APreSaleExtension_init_unchained(
            config.preSalePrice,
            config.preSaleMaxMintPerWallet
        );
        __ERC721APublicSaleExtension_init(
            config.publicSalePrice,
            config.publicSaleMaxMintPerTx
        );
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity
    ) internal virtual override(ERC721A, ERC721ALockableExtension) {
        ERC721ALockableExtension._beforeTokenTransfers(
            from,
            to,
            startTokenId,
            quantity
        );
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721ACollectionMetadataExtension,
            ERC721APrefixedMetadataExtension,
            ERC721APreSaleExtension,
            ERC721APublicSaleExtension,
            ERC721AOwnerMintExtension,
            ERC721ARoleBasedMintExtension,
            ERC721ARoleBasedLockableExtension,
            ERC721RoyaltyExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.symbol();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721A, ERC721APrefixedMetadataExtension)
        returns (string memory)
    {
        return ERC721APrefixedMetadataExtension.tokenURI(_tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "erc721a/contracts/ERC721A.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721PreSaleExtension} from "../../ERC721/extensions/ERC721PreSaleExtension.sol";

/**
 * @dev Extension to provide pre-sale capabilities for certain collectors to mint for a specific price.
 */
abstract contract ERC721APreSaleExtension is
    IERC721PreSaleExtension,
    Initializable,
    ERC165Storage,
    ERC721AMinterExtension,
    ReentrancyGuard
{
    uint256 public preSalePrice;
    uint256 public preSaleMaxMintPerWallet;
    bytes32 public preSaleAllowlistMerkleRoot;
    bool public preSaleStatus;

    mapping(address => uint256) internal preSaleAllowlistClaimed;

    function __ERC721APreSaleExtension_init(
        uint256 _preSalePrice,
        uint256 _preSaleMaxMintPerWallet
    ) internal onlyInitializing {
        __ERC721APreSaleExtension_init_unchained(
            _preSalePrice,
            _preSaleMaxMintPerWallet
        );
    }

    function __ERC721APreSaleExtension_init_unchained(
        uint256 _preSalePrice,
        uint256 _preSaleMaxMintPerWallet
    ) internal onlyInitializing {
        _registerInterface(type(IERC721PreSaleExtension).interfaceId);

        preSalePrice = _preSalePrice;
        preSaleMaxMintPerWallet = _preSaleMaxMintPerWallet;
    }

    /* ADMIN */

    function setPreSalePrice(uint256 newValue) external onlyOwner {
        preSalePrice = newValue;
    }

    function setPreSaleMaxMintPerWallet(uint256 newValue) external onlyOwner {
        preSaleMaxMintPerWallet = newValue;
    }

    function setAllowlistMerkleRoot(bytes32 newRoot) external onlyOwner {
        preSaleAllowlistMerkleRoot = newRoot;
    }

    function togglePreSaleStatus(bool isActive) external onlyOwner {
        preSaleStatus = isActive;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function onPreSaleAllowList(address minter, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        return
            MerkleProof.verify(
                proof,
                preSaleAllowlistMerkleRoot,
                _generateMerkleLeaf(minter)
            );
    }

    function mintPreSale(uint256 count, bytes32[] calldata proof)
        external
        payable
        nonReentrant
    {
        require(preSaleStatus, "NOT_ACTIVE");

        address to = _msgSender();

        require(
            MerkleProof.verify(
                proof,
                preSaleAllowlistMerkleRoot,
                _generateMerkleLeaf(to)
            ),
            "WRONG_PROOF"
        );
        require(
            preSaleAllowlistClaimed[to] + count <= preSaleMaxMintPerWallet,
            "PRE_SALE_LIMIT"
        );
        require(preSalePrice * count <= msg.value, "INSUFFICIENT_AMOUNT");

        preSaleAllowlistClaimed[to] += count;

        _mintTo(to, count);
    }

    /* INTERNAL */

    function _generateMerkleLeaf(address account)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account));
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721PublicSaleExtension} from "../../ERC721/extensions/ERC721PublicSaleExtension.sol";

/**
 * @dev Extension to provide pre-sale and public-sale capabilities for collectors to mint for a specific price.
 */
abstract contract ERC721APublicSaleExtension is
    IERC721PublicSaleExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AMinterExtension,
    ReentrancyGuard
{
    uint256 public publicSalePrice;
    uint256 public publicSaleMaxMintPerTx;
    bool public publicSaleStatus;

    function __ERC721APublicSaleExtension_init(
        uint256 _publicSalePrice,
        uint256 _publicSaleMaxMintPerTx
    ) internal onlyInitializing {
        __ERC721APublicSaleExtension_init_unchained(
            _publicSalePrice,
            _publicSaleMaxMintPerTx
        );
    }

    function __ERC721APublicSaleExtension_init_unchained(
        uint256 _publicSalePrice,
        uint256 _publicSaleMaxMintPerTx
    ) internal onlyInitializing {
        _registerInterface(type(IERC721PublicSaleExtension).interfaceId);

        publicSalePrice = _publicSalePrice;
        publicSaleMaxMintPerTx = _publicSaleMaxMintPerTx;
    }

    /* ADMIN */

    function setPublicSalePrice(uint256 newValue) external onlyOwner {
        publicSalePrice = newValue;
    }

    function setPublicSaleMaxMintPerTx(uint256 newValue) external onlyOwner {
        publicSaleMaxMintPerTx = newValue;
    }

    function togglePublicSaleStatus(bool isActive) external onlyOwner {
        publicSaleStatus = isActive;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function mintPublicSale(address to, uint256 count)
        external
        payable
        nonReentrant
    {
        require(publicSaleStatus, "PUBLIC_SALE_NOT_ACTIVE");
        require(count <= publicSaleMaxMintPerTx, "PUBLIC_SALE_LIMIT");
        require(publicSalePrice * count <= msg.value, "INSUFFICIENT_AMOUNT");

        _mintTo(to, count);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721PreSaleExtension {
    function setPreSalePrice(uint256 newValue) external;

    function setPreSaleMaxMintPerWallet(uint256 newValue) external;

    function setAllowlistMerkleRoot(bytes32 newRoot) external;

    function togglePreSaleStatus(bool isActive) external;

    function onPreSaleAllowList(address minter, bytes32[] calldata proof)
        external
        view
        returns (bool);

    function mintPreSale(uint256 count, bytes32[] calldata proof)
        external
        payable;
}

/**
 * @dev Extension to provide pre-sale capabilities for certain collectors to mint for a specific price.
 */
abstract contract ERC721PreSaleExtension is
    IERC721PreSaleExtension,
    Initializable,
    ERC165Storage,
    ERC721AutoIdMinterExtension,
    ReentrancyGuard
{
    uint256 public preSalePrice;
    uint256 public preSaleMaxMintPerWallet;
    bytes32 public preSaleAllowlistMerkleRoot;
    bool public preSaleStatus;

    mapping(address => uint256) internal preSaleAllowlistClaimed;

    function __ERC721PreSaleExtension_init(
        uint256 _preSalePrice,
        uint256 _preSaleMaxMintPerWallet
    ) internal onlyInitializing {
        __ERC721PreSaleExtension_init_unchained(
            _preSalePrice,
            _preSaleMaxMintPerWallet
        );
    }

    function __ERC721PreSaleExtension_init_unchained(
        uint256 _preSalePrice,
        uint256 _preSaleMaxMintPerWallet
    ) internal onlyInitializing {
        _registerInterface(type(IERC721PreSaleExtension).interfaceId);

        preSalePrice = _preSalePrice;
        preSaleMaxMintPerWallet = _preSaleMaxMintPerWallet;
    }

    /* ADMIN */

    function setPreSalePrice(uint256 newValue) external onlyOwner {
        preSalePrice = newValue;
    }

    function setPreSaleMaxMintPerWallet(uint256 newValue) external onlyOwner {
        preSaleMaxMintPerWallet = newValue;
    }

    function setAllowlistMerkleRoot(bytes32 newRoot) external onlyOwner {
        preSaleAllowlistMerkleRoot = newRoot;
    }

    function togglePreSaleStatus(bool isActive) external onlyOwner {
        preSaleStatus = isActive;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function onPreSaleAllowList(address minter, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        return
            MerkleProof.verify(
                proof,
                preSaleAllowlistMerkleRoot,
                _generateMerkleLeaf(minter)
            );
    }

    function mintPreSale(uint256 count, bytes32[] calldata proof)
        external
        payable
        nonReentrant
    {
        require(preSaleStatus, "NOT_ACTIVE");

        address to = _msgSender();

        require(
            MerkleProof.verify(
                proof,
                preSaleAllowlistMerkleRoot,
                _generateMerkleLeaf(to)
            ),
            "WRONG_PROOF"
        );
        require(
            preSaleAllowlistClaimed[to] + count <= preSaleMaxMintPerWallet,
            "PRE_SALE_LIMIT"
        );
        require(preSalePrice * count <= msg.value, "INSUFFICIENT_AMOUNT");

        preSaleAllowlistClaimed[to] += count;

        _mintTo(to, count);
    }

    /* INTERNAL */

    function _generateMerkleLeaf(address account)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(account));
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721PublicSaleExtension {
    function setPublicSalePrice(uint256 newValue) external;

    function setPublicSaleMaxMintPerTx(uint256 newValue) external;

    function togglePublicSaleStatus(bool isActive) external;

    function mintPublicSale(address to, uint256 count) external payable;
}

/**
 * @dev Extension to provide pre-sale and public-sale capabilities for collectors to mint for a specific price.
 */
abstract contract ERC721PublicSaleExtension is
    IERC721PublicSaleExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AutoIdMinterExtension,
    ReentrancyGuard
{
    uint256 public publicSalePrice;
    uint256 public publicSaleMaxMintPerTx;
    bool public publicSaleStatus;

    function __ERC721PublicSaleExtension_init(
        uint256 _publicSalePrice,
        uint256 _publicSaleMaxMintPerTx
    ) internal onlyInitializing {
        __ERC721PublicSaleExtension_init_unchained(
            _publicSalePrice,
            _publicSaleMaxMintPerTx
        );
    }

    function __ERC721PublicSaleExtension_init_unchained(
        uint256 _publicSalePrice,
        uint256 _publicSaleMaxMintPerTx
    ) internal onlyInitializing {
        _registerInterface(type(IERC721PublicSaleExtension).interfaceId);

        publicSalePrice = _publicSalePrice;
        publicSaleMaxMintPerTx = _publicSaleMaxMintPerTx;
    }

    /* ADMIN */

    function setPublicSalePrice(uint256 newValue) external onlyOwner {
        publicSalePrice = newValue;
    }

    function setPublicSaleMaxMintPerTx(uint256 newValue) external onlyOwner {
        publicSaleMaxMintPerTx = newValue;
    }

    function togglePublicSaleStatus(bool isActive) external onlyOwner {
        publicSaleStatus = isActive;
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function mintPublicSale(address to, uint256 count)
        external
        payable
        nonReentrant
    {
        require(publicSaleStatus, "PUBLIC_SALE_NOT_ACTIVE");
        require(count <= publicSaleMaxMintPerTx, "PUBLIC_SALE_LIMIT");
        require(publicSalePrice * count <= msg.value, "INSUFFICIENT_AMOUNT");

        _mintTo(to, count);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC20/extensions/ERC20Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC20.sol";
import "../../../utils/Context.sol";

/**
 * @dev Extension of {ERC20} that allows token holders to destroy both their own
 * tokens and those that they have an allowance for, in a way that can be
 * recognized off-chain (via event analysis).
 */
abstract contract ERC20Burnable is Context, ERC20 {
    /**
     * @dev Destroys `amount` tokens from the caller.
     *
     * See {ERC20-_burn}.
     */
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, deducting from the caller's
     * allowance.
     *
     * See {ERC20-_burn} and {ERC20-allowance}.
     *
     * Requirements:
     *
     * - the caller must have allowance for ``accounts``'s tokens of at least
     * `amount`.
     */
    function burnFrom(address account, uint256 amount) public virtual {
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
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

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../extensions/ERC20RoleBasedLockingExtension.sol";

contract ERC20LockableToken is
    Initializable,
    ERC165Storage,
    AccessControl,
    ERC20,
    ERC20Burnable,
    Pausable,
    ERC20RoleBasedLockingExtension
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _name;
    string private _symbol;

    struct Config {
        string name;
        string symbol;
    }

    constructor(Config memory config) ERC20(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _name = config.name;
        _symbol = config.symbol;

        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(PAUSER_ROLE, deployer);
        _grantRole(MINTER_ROLE, deployer);

        __ERC20RoleBasedLockingExtension_init(deployer);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /* ADMIN */

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, AccessControl, ERC20RoleBasedLockingExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        virtual
        override(ERC20, ERC20RoleBasedLockingExtension)
        whenNotPaused
    {
        ERC20RoleBasedLockingExtension._beforeTokenTransfer(from, to, amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface ERC20RoleBasedLockingExtensionInterface {
    function lockForAll() external;

    function unlockForAll() external;

    function canTransfer(address) external view returns (bool);
}

/**
 * @dev Extension to allow locking transfers and only allow certain addresses do to transfers.
 */
abstract contract ERC20RoleBasedLockingExtension is
    Initializable,
    ERC165Storage,
    AccessControl,
    ERC20,
    ERC20RoleBasedLockingExtensionInterface
{
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    constructor() {}

    function __ERC20RoleBasedLockingExtension_init(address deployer)
        internal
        onlyInitializing
    {
        __ERC20RoleBasedLockingExtension_init_unchained(deployer);
    }

    function __ERC20RoleBasedLockingExtension_init_unchained(address deployer)
        internal
        onlyInitializing
    {
        _registerInterface(
            type(ERC20RoleBasedLockingExtensionInterface).interfaceId
        );

        _grantRole(TRANSFER_ROLE, deployer);
    }

    /* ADMIN */

    function lockForAll() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "NOT_ADMIN");

        _revokeRole(TRANSFER_ROLE, address(0));
    }

    function unlockForAll() external {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "NOT_ADMIN");

        _grantRole(TRANSFER_ROLE, address(0));
    }

    /* PUBLIC */

    function canTransfer(address operator)
        external
        view
        override
        returns (bool)
    {
        return hasRole(TRANSFER_ROLE, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, AccessControl)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(
            hasRole(TRANSFER_ROLE, address(0)) ||
                hasRole(TRANSFER_ROLE, _msgSender()),
            "TRANSFER_LOCKED"
        );

        super._beforeTokenTransfer(from, to, amount);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
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
    constructor() {
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
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../../ERC721/extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721AMinterExtension.sol";
import "../extensions/ERC721ACollectionMetadataExtension.sol";
import "../extensions/ERC721APerTokenMetadataExtension.sol";
import "../extensions/ERC721AOneOfOneMintExtension.sol";
import "../extensions/ERC721AOwnerMintExtension.sol";

contract ERC721AOneOfOneCollection is
    Initializable,
    Ownable,
    ERC165Storage,
    LicenseExtension,
    ERC721ACollectionMetadataExtension,
    ERC721AOwnerMintExtension,
    ERC721AOneOfOneMintExtension,
    ERC721RoyaltyExtension,
    ERC2771ContextOwnable
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        uint256 maxSupply;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721A(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);
        _setupRole(MINTER_ROLE, deployer);

        _transferOwnership(deployer);

        __ERC721ACollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721APerTokenMetadataExtension_init();
        __ERC721AOwnerMintExtension_init();
        __ERC721AOneOfOneMintExtension_init();
        __ERC721AMinterExtension_init(config.maxSupply);
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
        __LicenseExtension_init(config.licenseVersion);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721A, ERC721AOneOfOneMintExtension)
    {
        return ERC721AOneOfOneMintExtension._burn(tokenId);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721ACollectionMetadataExtension,
            ERC721AOwnerMintExtension,
            ERC721AOneOfOneMintExtension,
            ERC721RoyaltyExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        override(
            ERC721ACollectionMetadataExtension,
            ERC721AOneOfOneMintExtension
        )
        returns (string memory)
    {
        return ERC721AOneOfOneMintExtension.name();
    }

    function symbol()
        public
        view
        override(
            ERC721ACollectionMetadataExtension,
            ERC721AOneOfOneMintExtension
        )
        returns (string memory)
    {
        return ERC721AOneOfOneMintExtension.symbol();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721A, ERC721AOneOfOneMintExtension)
        returns (string memory)
    {
        return ERC721AOneOfOneMintExtension.tokenURI(_tokenId);
    }

    function getInfo()
        external
        view
        returns (
            uint256 _maxSupply,
            uint256 _totalSupply,
            uint256 _senderBalance
        )
    {
        uint256 balance = 0;

        if (_msgSender() != address(0)) {
            balance = this.balanceOf(_msgSender());
        }

        return (maxSupply, this.totalSupply(), balance);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "erc721a/contracts/ERC721A.sol";

import {IERC721PerTokenMetadataExtension} from "../../ERC721/extensions/ERC721PerTokenMetadataExtension.sol";

/**
 * @dev Extension to allow configuring collection and tokens metadata URI.
 *      In this extension each token will have a different independent token URI set by contract owner.
 *      To enable true self-custody for token owners, an admin can freeze URIs using a token ID pointer that can only be increased.
 */
abstract contract ERC721APerTokenMetadataExtension is
    IERC721PerTokenMetadataExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721A
{
    uint256 public lastFrozenTokenId;

    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    function __ERC721APerTokenMetadataExtension_init()
        internal
        onlyInitializing
    {
        __ERC721APerTokenMetadataExtension_init_unchained();
    }

    function __ERC721APerTokenMetadataExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721PerTokenMetadataExtension).interfaceId);
    }

    /* ADMIN */

    function freezeTokenURIs(uint256 _lastFrozenTokenId) external onlyOwner {
        require(_lastFrozenTokenId > lastFrozenTokenId, "CANNOT_UNFREEZE");
        lastFrozenTokenId = _lastFrozenTokenId;
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI)
        external
        onlyOwner
    {
        require(tokenId > lastFrozenTokenId, "FROZEN");
        _setTokenURI(tokenId, tokenURI);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721A)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI)
        internal
        virtual
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI set of nonexistent token"
        );
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";
import "./ERC721APerTokenMetadataExtension.sol";

import {IERC721OneOfOneMintExtension} from "../../ERC721/extensions/ERC721OneOfOneMintExtension.sol";

/**
 * @dev Extension to allow owner to mint 1-of-1 NFTs by providing dedicated metadata URI for each token.
 */
abstract contract ERC721AOneOfOneMintExtension is
    IERC721OneOfOneMintExtension,
    AccessControl,
    ERC721AMinterExtension,
    ERC721APerTokenMetadataExtension
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function __ERC721AOneOfOneMintExtension_init() internal onlyInitializing {
        __ERC721APerTokenMetadataExtension_init();
        __ERC721AOneOfOneMintExtension_init_unchained();
    }

    function __ERC721AOneOfOneMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OneOfOneMintExtension).interfaceId);
    }

    /* ADMIN */

    function mintWithTokenURIsByOwner(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external onlyOwner {
        uint256 startingTokenId = _nextTokenId();
        _mintTo(to, count);
        for (uint256 i = 0; i < count; i++) {
            _setTokenURI(startingTokenId + i, tokenURIs[i]);
        }
    }

    function mintWithTokenURIsByRole(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "NOT_MINTER_ROLE");

        uint256 startingTokenId = _nextTokenId();
        _mintTo(to, count);
        for (uint256 i = 0; i < count; i++) {
            _setTokenURI(startingTokenId + i, tokenURIs[i]);
        }
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            AccessControl,
            ERC721ACollectionMetadataExtension,
            ERC721APerTokenMetadataExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        virtual
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        virtual
        override(ERC721A, ERC721ACollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721ACollectionMetadataExtension.symbol();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(
            ERC721A,
            ERC721APerTokenMetadataExtension,
            IERC721OneOfOneMintExtension
        )
        returns (string memory)
    {
        return ERC721APerTokenMetadataExtension.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721A, ERC721APerTokenMetadataExtension)
    {
        return ERC721APerTokenMetadataExtension._burn(tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

interface IERC721PerTokenMetadataExtension {
    function freezeTokenURIs(uint256 _lastFrozenTokenId) external;

    function setTokenURI(uint256 tokenId, string memory tokenURI) external;
}

/**
 * @dev Extension to allow configuring collection and tokens metadata URI.
 *      In this extension each token will have a different independent token URI set by contract owner.
 *      To enable true self-custody for token owners, an admin can freeze URIs using a token ID pointer that can only be increased.
 */
abstract contract ERC721PerTokenMetadataExtension is
    IERC721PerTokenMetadataExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721URIStorage
{
    uint256 public lastFrozenTokenId;

    function __ERC721PerTokenMetadataExtension_init()
        internal
        onlyInitializing
    {
        __ERC721PerTokenMetadataExtension_init_unchained();
    }

    function __ERC721PerTokenMetadataExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721PerTokenMetadataExtension).interfaceId);
    }

    /* ADMIN */

    function freezeTokenURIs(uint256 _lastFrozenTokenId) external onlyOwner {
        require(_lastFrozenTokenId > lastFrozenTokenId, "CANNOT_UNFREEZE");
        lastFrozenTokenId = _lastFrozenTokenId;
    }

    function setTokenURI(uint256 tokenId, string memory tokenURI)
        external
        onlyOwner
    {
        require(tokenId > lastFrozenTokenId, "FROZEN");
        _setTokenURI(tokenId, tokenURI);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC721/extensions/ERC721URIStorage.sol)

pragma solidity ^0.8.0;

import "../ERC721.sol";

/**
 * @dev ERC721 token with storage based token URI management.
 */
abstract contract ERC721URIStorage is ERC721 {
    using Strings for uint256;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @dev See {ERC721-_burn}. This override additionally checks to see if a
     * token-specific URI was set for the token, and if so, it deletes the token URI from
     * the storage mapping.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";
import "./ERC721PerTokenMetadataExtension.sol";

interface IERC721OneOfOneMintExtension {
    function mintWithTokenURIsByOwner(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external;

    function mintWithTokenURIsByRole(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/**
 * @dev Extension to allow owner to mint 1-of-1 NFTs by providing dedicated metadata URI for each token.
 */
abstract contract ERC721OneOfOneMintExtension is
    IERC721OneOfOneMintExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    AccessControl,
    ERC721AutoIdMinterExtension,
    ERC721PerTokenMetadataExtension
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function __ERC721OneOfOneMintExtension_init() internal onlyInitializing {
        __ERC721OneOfOneMintExtension_init_unchained();
    }

    function __ERC721OneOfOneMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OneOfOneMintExtension).interfaceId);
    }

    /* ADMIN */

    function mintWithTokenURIsByOwner(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external onlyOwner {
        uint256 startingTokenId = _currentTokenId;
        _mintTo(to, count);
        for (uint256 i = 0; i < count; i++) {
            _setTokenURI(startingTokenId + i, tokenURIs[i]);
        }
    }

    function mintWithTokenURIsByRole(
        address to,
        uint256 count,
        string[] memory tokenURIs
    ) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "NOT_MINTER_ROLE");

        uint256 startingTokenId = _currentTokenId;
        _mintTo(to, count);
        for (uint256 i = 0; i < count; i++) {
            _setTokenURI(startingTokenId + i, tokenURIs[i]);
        }
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            AccessControl,
            ERC721CollectionMetadataExtension,
            ERC721PerTokenMetadataExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        virtual
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        virtual
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.symbol();
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721, ERC721URIStorage, IERC721OneOfOneMintExtension)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721URIStorage)
    {
        return ERC721URIStorage._burn(tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721ShareSplitExtension.sol";
import "../extensions/ERC721VestingReleaseExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721ShareVestingStream is
    Initializable,
    Ownable,
    ERC721VestingReleaseExtension,
    ERC721ShareSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    string public constant name = "ERC721 Share Vesting Stream";

    string public constant version = "0.1";

    struct Config {
        // Core
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Vesting release extension
        uint64 startTimestamp;
        uint64 durationSeconds;
        // Share split extension
        uint256[] tokenIds;
        uint256[] shares;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721VestingReleaseExtension_init(
            config.startTimestamp,
            config.durationSeconds
        );
        __ERC721ShareSplitExtension_init(config.tokenIds, config.shares);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal override(ERC721MultiTokenStream, ERC721LockableClaimExtension) {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721ShareSplitExtension {
    function hasERC721ShareSplitExtension() external view returns (bool);

    function setSharesForTokens(
        uint256[] memory _tokenIds,
        uint256[] memory _shares
    ) external;

    function getSharesByTokens(uint256[] calldata _tokenIds)
        external
        view
        returns (uint256[] memory);
}

abstract contract ERC721ShareSplitExtension is
    IERC721ShareSplitExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    event SharesUpdated(uint256 tokenId, uint256 prevShares, uint256 newShares);

    // Sum of all the share units ever configured
    uint256 public totalShares;

    // Map of ticket token ID -> share of the stream
    mapping(uint256 => uint256) public shares;

    /* INTERNAL */

    function __ERC721ShareSplitExtension_init(
        uint256[] memory _tokenIds,
        uint256[] memory _shares
    ) internal onlyInitializing {
        __ERC721ShareSplitExtension_init_unchained(_tokenIds, _shares);
    }

    function __ERC721ShareSplitExtension_init_unchained(
        uint256[] memory _tokenIds,
        uint256[] memory _shares
    ) internal onlyInitializing {
        require(_shares.length == _tokenIds.length, "ARGS_MISMATCH");
        _updateShares(_tokenIds, _shares);

        _registerInterface(type(IERC721ShareSplitExtension).interfaceId);
    }

    function setSharesForTokens(
        uint256[] memory _tokenIds,
        uint256[] memory _shares
    ) public onlyOwner {
        require(_shares.length == _tokenIds.length, "ARGS_MISMATCH");
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");

        _updateShares(_tokenIds, _shares);
    }

    /* PUBLIC */

    function hasERC721ShareSplitExtension() external pure returns (bool) {
        return true;
    }

    function getSharesByTokens(uint256[] calldata _tokenIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory _shares = new uint256[](_tokenIds.length);

        for (uint256 i = 0; i < _shares.length; i++) {
            _shares[i] = shares[_tokenIds[i]];
        }

        return _shares;
    }

    function _totalTokenReleasedAmount(
        uint256 totalReleasedAmount_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal view override returns (uint256) {
        claimToken_;

        return (totalReleasedAmount_ * shares[ticketTokenId_]) / totalShares;
    }

    /* INTERNAL */

    function _updateShares(uint256[] memory _tokenIds, uint256[] memory _shares)
        private
    {
        for (uint256 i = 0; i < _shares.length; i++) {
            _updateShares(_tokenIds[i], _shares[i]);
        }
    }

    function _updateShares(uint256 tokenId, uint256 newShares) private {
        uint256 prevShares = shares[tokenId];

        shares[tokenId] = newShares;
        totalShares = totalShares + newShares - prevShares;

        require(totalShares >= 0, "NEGATIVE_SHARES");

        emit SharesUpdated(tokenId, prevShares, newShares);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721VestingReleaseExtension {
    function hasERC721VestingReleaseExtension() external view returns (bool);

    function setVestingStartTimestamp(uint64 newValue) external;

    function setVestingDurationSeconds(uint64 newValue) external;
}

abstract contract ERC721VestingReleaseExtension is
    IERC721VestingReleaseExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    // Start of the vesting schedule
    uint64 public vestingStartTimestamp;

    // Duration of the vesting schedule
    uint64 public vestingDurationSeconds;

    /* INTERNAL */

    function __ERC721VestingReleaseExtension_init(
        uint64 _vestingStartTimestamp,
        uint64 _vestingDurationSeconds
    ) internal onlyInitializing {
        __ERC721VestingReleaseExtension_init_unchained(
            _vestingStartTimestamp,
            _vestingDurationSeconds
        );
    }

    function __ERC721VestingReleaseExtension_init_unchained(
        uint64 _vestingStartTimestamp,
        uint64 _vestingDurationSeconds
    ) internal onlyInitializing {
        vestingStartTimestamp = _vestingStartTimestamp;
        vestingDurationSeconds = _vestingDurationSeconds;

        _registerInterface(type(IERC721VestingReleaseExtension).interfaceId);
    }

    /* ADMIN */

    function setVestingStartTimestamp(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        vestingStartTimestamp = newValue;
    }

    function setVestingDurationSeconds(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        vestingDurationSeconds = newValue;
    }

    /* PUBLIC */

    function hasERC721VestingReleaseExtension() external pure returns (bool) {
        return true;
    }

    /* INTERNAL */

    function _totalStreamReleasedAmount(
        uint256 _streamTotalSupply,
        uint256 _ticketTokenId,
        address _claimToken
    ) internal view override returns (uint256) {
        _ticketTokenId;
        _claimToken;

        if (block.timestamp < vestingStartTimestamp) {
            return 0;
        } else if (
            block.timestamp > vestingStartTimestamp + vestingDurationSeconds
        ) {
            return _streamTotalSupply;
        } else {
            return
                (_streamTotalSupply *
                    (block.timestamp - vestingStartTimestamp)) /
                vestingDurationSeconds;
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721LockableClaimExtension {
    function hasERC721LockableClaimExtension() external view returns (bool);

    function setClaimLockedUntil(uint64 newValue) external;
}

abstract contract ERC721LockableClaimExtension is
    IERC721LockableClaimExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    // Claiming is only possible after this time (unix timestamp)
    uint64 public claimLockedUntil;

    /* INTERNAL */

    function __ERC721LockableClaimExtension_init(uint64 _claimLockedUntil)
        internal
        onlyInitializing
    {
        __ERC721LockableClaimExtension_init_unchained(_claimLockedUntil);
    }

    function __ERC721LockableClaimExtension_init_unchained(
        uint64 _claimLockedUntil
    ) internal onlyInitializing {
        claimLockedUntil = _claimLockedUntil;

        _registerInterface(type(IERC721LockableClaimExtension).interfaceId);
    }

    /* ADMIN */

    function setClaimLockedUntil(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        claimLockedUntil = newValue;
    }

    /* PUBLIC */

    function hasERC721LockableClaimExtension() external pure returns (bool) {
        return true;
    }

    /* INTERNAL */

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal virtual override {
        ticketTokenId_;
        claimToken_;
        beneficiary_;

        require(claimLockedUntil < block.timestamp, "CLAIM_LOCKED");
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IERC721MultiTokenStream {
    // Claim native currency for a single ticket token
    function claim(uint256 ticketTokenId) external;

    // Claim an erc20 claim token for a single ticket token
    function claim(uint256 ticketTokenId, address claimToken) external;

    // Claim native currency for multiple ticket tokens (only if all owned by sender)
    function claim(uint256[] calldata ticketTokenIds) external;

    // Claim native or erc20 tokens for multiple ticket tokens (only if all owned by `owner`)
    function claim(
        uint256[] calldata ticketTokenIds,
        address claimToken,
        address owner
    ) external;

    // Total native currency ever supplied to this stream
    function streamTotalSupply() external view returns (uint256);

    // Total erc20 token ever supplied to this stream by claim token address
    function streamTotalSupply(address claimToken)
        external
        view
        returns (uint256);

    // Total native currency ever claimed from this stream
    function streamTotalClaimed() external view returns (uint256);

    // Total erc20 token ever claimed from this stream by claim token address
    function streamTotalClaimed(address claimToken)
        external
        view
        returns (uint256);

    // Total native currency ever claimed for a single ticket token
    function streamTotalClaimed(uint256 ticketTokenId)
        external
        view
        returns (uint256);

    // Total native currency ever claimed for multiple token IDs
    function streamTotalClaimed(uint256[] calldata ticketTokenIds)
        external
        view
        returns (uint256);

    // Total erc20 token ever claimed for multiple token IDs
    function streamTotalClaimed(
        uint256[] calldata ticketTokenIds,
        address claimToken
    ) external view returns (uint256);

    // Calculate currently claimable amount for a specific ticket token ID and a specific claim token address
    // Pass 0x0000000000000000000000000000000000000000 as claim token to represent native currency
    function streamClaimableAmount(uint256 ticketTokenId, address claimToken)
        external
        view
        returns (uint256 claimableAmount);
}

abstract contract ERC721MultiTokenStream is
    IERC721MultiTokenStream,
    IERC721Receiver,
    Initializable,
    Ownable,
    ERC165Storage,
    ReentrancyGuard
{
    using Address for address;
    using Address for address payable;

    struct Entitlement {
        uint256 totalClaimed;
        uint256 lastClaimedAt;
    }

    // Config
    address public ticketToken;

    // Locks changing the config until this timestamp is reached
    uint64 public lockedUntilTimestamp;

    // Map of ticket token ID -> claim token address -> entitlement
    mapping(uint256 => mapping(address => Entitlement)) public entitlements;

    // Map of claim token address -> Total amount claimed by all holders
    mapping(address => uint256) internal _streamTotalClaimed;

    /* EVENTS */

    event Claim(
        address operator,
        address beneficiary,
        uint256 ticketTokenId,
        address claimToken,
        uint256 releasedAmount
    );

    event ClaimMany(
        address operator,
        address beneficiary,
        uint256[] ticketTokenIds,
        address claimToken,
        uint256 releasedAmount
    );

    function __ERC721MultiTokenStream_init(
        address _ticketToken,
        uint64 _lockedUntilTimestamp
    ) internal onlyInitializing {
        __ERC721MultiTokenStream_init_unchained(
            _ticketToken,
            _lockedUntilTimestamp
        );
    }

    function __ERC721MultiTokenStream_init_unchained(
        address _ticketToken,
        uint64 _lockedUntilTimestamp
    ) internal onlyInitializing {
        ticketToken = _ticketToken;
        lockedUntilTimestamp = _lockedUntilTimestamp;

        _registerInterface(type(IERC721MultiTokenStream).interfaceId);
    }

    /* ADMIN */

    function lockUntil(uint64 newValue) public onlyOwner {
        require(newValue > lockedUntilTimestamp, "CANNOT_REWIND");
        lockedUntilTimestamp = newValue;
    }

    /* PUBLIC */

    receive() external payable {
        require(msg.value > 0);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function claim(uint256 ticketTokenId) public {
        claim(ticketTokenId, address(0));
    }

    function claim(uint256 ticketTokenId, address claimToken)
        public
        nonReentrant
    {
        /* CHECKS */
        address beneficiary = _msgSender();
        _beforeClaim(ticketTokenId, claimToken, beneficiary);

        uint256 claimable = streamClaimableAmount(ticketTokenId, claimToken);
        require(claimable > 0, "NOTHING_TO_CLAIM");

        /* EFFECTS */

        entitlements[ticketTokenId][claimToken].totalClaimed += claimable;
        entitlements[ticketTokenId][claimToken].lastClaimedAt = block.timestamp;

        _streamTotalClaimed[claimToken] += claimable;

        /* INTERACTIONS */

        if (claimToken == address(0)) {
            payable(address(beneficiary)).sendValue(claimable);
        } else {
            IERC20(claimToken).transfer(beneficiary, claimable);
        }

        /* LOGS */

        emit Claim(
            _msgSender(),
            beneficiary,
            ticketTokenId,
            claimToken,
            claimable
        );
    }

    function claim(uint256[] calldata ticketTokenIds) public {
        claim(ticketTokenIds, address(0), _msgSender());
    }

    function claim(
        uint256[] calldata ticketTokenIds,
        address claimToken,
        address beneficiary
    ) public nonReentrant {
        uint256 totalClaimable;

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            _beforeClaim(ticketTokenIds[i], claimToken, beneficiary);

            /* EFFECTS */
            uint256 claimable = streamClaimableAmount(
                ticketTokenIds[i],
                claimToken
            );

            if (claimable > 0) {
                entitlements[ticketTokenIds[i]][claimToken]
                    .totalClaimed += claimable;
                entitlements[ticketTokenIds[i]][claimToken]
                    .lastClaimedAt = block.timestamp;

                totalClaimable += claimable;
            }
        }

        _streamTotalClaimed[claimToken] += totalClaimable;

        /* INTERACTIONS */

        if (claimToken == address(0)) {
            payable(address(beneficiary)).sendValue(totalClaimable);
        } else {
            IERC20(claimToken).transfer(beneficiary, totalClaimable);
        }

        /* LOGS */

        emit ClaimMany(
            _msgSender(),
            beneficiary,
            ticketTokenIds,
            claimToken,
            totalClaimable
        );
    }

    /* READ ONLY */

    function streamTotalSupply() public view returns (uint256) {
        return streamTotalSupply(address(0));
    }

    function streamTotalSupply(address claimToken)
        public
        view
        returns (uint256)
    {
        if (claimToken == address(0)) {
            return _streamTotalClaimed[claimToken] + address(this).balance;
        }

        return
            _streamTotalClaimed[claimToken] +
            IERC20(claimToken).balanceOf(address(this));
    }

    function streamTotalClaimed() public view returns (uint256) {
        return _streamTotalClaimed[address(0)];
    }

    function streamTotalClaimed(address claimToken)
        public
        view
        returns (uint256)
    {
        return _streamTotalClaimed[claimToken];
    }

    function streamTotalClaimed(uint256 ticketTokenId)
        public
        view
        returns (uint256)
    {
        return entitlements[ticketTokenId][address(0)].totalClaimed;
    }

    function streamTotalClaimed(uint256 ticketTokenId, address claimToken)
        public
        view
        returns (uint256)
    {
        return entitlements[ticketTokenId][claimToken].totalClaimed;
    }

    function streamTotalClaimed(uint256[] calldata ticketTokenIds)
        public
        view
        returns (uint256)
    {
        return streamTotalClaimed(ticketTokenIds, address(0));
    }

    function streamTotalClaimed(
        uint256[] calldata ticketTokenIds,
        address claimToken
    ) public view returns (uint256) {
        uint256 claimed = 0;

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            claimed += entitlements[ticketTokenIds[i]][claimToken].totalClaimed;
        }

        return claimed;
    }

    function streamClaimableAmount(
        uint256[] calldata ticketTokenIds,
        address claimToken
    ) public view returns (uint256) {
        uint256 claimable = 0;

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            claimable += streamClaimableAmount(ticketTokenIds[i], claimToken);
        }

        return claimable;
    }

    function streamClaimableAmount(uint256 ticketTokenId)
        public
        view
        returns (uint256)
    {
        return streamClaimableAmount(ticketTokenId, address(0));
    }

    function streamClaimableAmount(uint256 ticketTokenId, address claimToken)
        public
        view
        virtual
        returns (uint256)
    {
        uint256 totalReleased = _totalTokenReleasedAmount(
            _totalStreamReleasedAmount(
                streamTotalSupply(claimToken),
                ticketTokenId,
                claimToken
            ),
            ticketTokenId,
            claimToken
        );

        return
            totalReleased -
            entitlements[ticketTokenId][claimToken].totalClaimed;
    }

    function _totalStreamReleasedAmount(
        uint256 streamTotalSupply_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal view virtual returns (uint256);

    function _totalTokenReleasedAmount(
        uint256 totalReleasedAmount_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal view virtual returns (uint256);

    /* INTERNAL */

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal virtual {
        require(
            IERC721(ticketToken).ownerOf(ticketTokenId_) == beneficiary_,
            "NOT_NFT_OWNER"
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721InstantReleaseExtension.sol";
import "../extensions/ERC721ShareSplitExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721ShareInstantStream is
    Initializable,
    Ownable,
    ERC721InstantReleaseExtension,
    ERC721ShareSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    string public constant name = "ERC721 Share Instant Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Share split extension
        uint256[] tokenIds;
        uint256[] shares;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721InstantReleaseExtension_init();
        __ERC721ShareSplitExtension_init(config.tokenIds, config.shares);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal override(ERC721MultiTokenStream, ERC721LockableClaimExtension) {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721InstantReleaseExtension {
    function hasERC721InstantReleaseExtension() external view returns (bool);
}

abstract contract ERC721InstantReleaseExtension is
    IERC721InstantReleaseExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    /* INIT */

    function __ERC721InstantReleaseExtension_init() internal onlyInitializing {
        __ERC721InstantReleaseExtension_init_unchained();
    }

    function __ERC721InstantReleaseExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721InstantReleaseExtension).interfaceId);
    }

    /* PUBLIC */

    function hasERC721InstantReleaseExtension() external pure returns (bool) {
        return true;
    }

    /* INTERNAL */

    function _totalStreamReleasedAmount(
        uint256 streamTotalSupply_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal pure override returns (uint256) {
        ticketTokenId_;
        claimToken_;

        return streamTotalSupply_;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721EmissionReleaseExtension.sol";
import "../extensions/ERC721ShareSplitExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721ShareEmissionStream is
    Initializable,
    Ownable,
    ERC721EmissionReleaseExtension,
    ERC721ShareSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    using Address for address;
    using Address for address payable;

    string public constant name = "ERC721 Share Emission Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Emission release extension
        uint256 emissionRate;
        uint64 emissionTimeUnit;
        uint64 emissionStart;
        uint64 emissionEnd;
        // Share split extension
        uint256[] tokenIds;
        uint256[] shares;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721EmissionReleaseExtension_init(
            config.emissionRate,
            config.emissionTimeUnit,
            config.emissionStart,
            config.emissionEnd
        );
        __ERC721ShareSplitExtension_init(config.tokenIds, config.shares);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function rateByToken(uint256[] calldata tokenIds)
        public
        view
        virtual
        override
        returns (uint256 totalRate)
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            totalRate += emissionRate / shares[tokenIds[i]];
        }

        return totalRate;
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    )
        internal
        override(
            ERC721MultiTokenStream,
            ERC721LockableClaimExtension,
            ERC721EmissionReleaseExtension
        )
    {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721EmissionReleaseExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721EmissionReleaseExtension {
    function hasERC721EmissionReleaseExtension() external view returns (bool);

    function setEmissionRate(uint256 newValue) external;

    function setEmissionTimeUnit(uint64 newValue) external;

    function setEmissionStart(uint64 newValue) external;

    function setEmissionEnd(uint64 newValue) external;

    function releasedAmountUntil(uint64 calcUntil)
        external
        view
        returns (uint256);

    function emissionAmountUntil(uint64 calcUntil)
        external
        view
        returns (uint256);

    function rateByToken(uint256[] calldata tokenIds)
        external
        view
        returns (uint256);
}

/**
 * @author Flair (https://flair.finance)
 */
abstract contract ERC721EmissionReleaseExtension is
    IERC721EmissionReleaseExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    // Number of tokens released every `emissionTimeUnit`
    uint256 public emissionRate;

    // Time unit to release tokens, users can only claim once every `emissionTimeUnit`
    uint64 public emissionTimeUnit;

    // When emission and calculating tokens starts
    uint64 public emissionStart;

    // When to stop calculating the tokens released
    uint64 public emissionEnd;

    /* INIT */

    function __ERC721EmissionReleaseExtension_init(
        uint256 _emissionRate,
        uint64 _emissionTimeUnit,
        uint64 _emissionStart,
        uint64 _emissionEnd
    ) internal onlyInitializing {
        __ERC721EmissionReleaseExtension_init_unchained(
            _emissionRate,
            _emissionTimeUnit,
            _emissionStart,
            _emissionEnd
        );
    }

    function __ERC721EmissionReleaseExtension_init_unchained(
        uint256 _emissionRate,
        uint64 _emissionTimeUnit,
        uint64 _emissionStart,
        uint64 _emissionEnd
    ) internal onlyInitializing {
        emissionRate = _emissionRate;
        emissionTimeUnit = _emissionTimeUnit;
        emissionStart = _emissionStart;
        emissionEnd = _emissionEnd;

        _registerInterface(type(IERC721EmissionReleaseExtension).interfaceId);
    }

    /* ADMIN */

    function setEmissionRate(uint256 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        emissionRate = newValue;
    }

    function setEmissionTimeUnit(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        emissionTimeUnit = newValue;
    }

    function setEmissionStart(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        emissionStart = newValue;
    }

    function setEmissionEnd(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        emissionEnd = newValue;
    }

    /* PUBLIC */

    function hasERC721EmissionReleaseExtension() external pure returns (bool) {
        return true;
    }

    function releasedAmountUntil(uint64 calcUntil)
        public
        view
        virtual
        returns (uint256)
    {
        return
            emissionRate *
            // Intentionally rounded down:
            ((calcUntil - emissionStart) / emissionTimeUnit);
    }

    function emissionAmountUntil(uint64 calcUntil)
        public
        view
        virtual
        returns (uint256)
    {
        return ((calcUntil - emissionStart) * emissionRate) / emissionTimeUnit;
    }

    function rateByToken(uint256[] calldata tokenIds)
        public
        view
        virtual
        returns (uint256);

    /* INTERNAL */

    function _totalStreamReleasedAmount(
        uint256 streamTotalSupply_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal view virtual override returns (uint256) {
        streamTotalSupply_;
        ticketTokenId_;
        claimToken_;

        if (block.timestamp < emissionStart) {
            return 0;
        } else if (emissionEnd > 0 && block.timestamp > emissionEnd) {
            return releasedAmountUntil(emissionEnd);
        } else {
            return releasedAmountUntil(uint64(block.timestamp));
        }
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal virtual override {
        beneficiary_;

        require(emissionStart < block.timestamp, "NOT_STARTED");

        require(
            entitlements[ticketTokenId_][claimToken_].lastClaimedAt <
                block.timestamp - emissionTimeUnit,
            "TOO_EARLY"
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721EmissionReleaseExtension.sol";
import "../extensions/ERC721EqualSplitExtension.sol";
import "../extensions/ERC721LockedStakingExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

/**
 * @author Flair (https://flair.finance)
 */
contract ERC721LockedStakingEmissionStream is
    Initializable,
    Ownable,
    ERC721EmissionReleaseExtension,
    ERC721EqualSplitExtension,
    ERC721LockedStakingExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    using Address for address;
    using Address for address payable;

    string public constant name = "ERC721 Locked Staking Emission Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Locked staking extension
        uint64 minStakingDuration; // in seconds. Minimum time the NFT must stay locked before unstaking.
        uint64 maxStakingTotalDurations; // in seconds. Maximum sum total of all durations staking that will be counted (across all stake/unstakes for each token).
        // Emission release extension
        uint256 emissionRate;
        uint64 emissionTimeUnit;
        uint64 emissionStart;
        uint64 emissionEnd;
        // Equal split extension
        uint256 totalTickets;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721LockedStakingExtension_init(
            config.minStakingDuration,
            config.maxStakingTotalDurations
        );
        __ERC721EmissionReleaseExtension_init(
            config.emissionRate,
            config.emissionTimeUnit,
            config.emissionStart,
            config.emissionEnd
        );
        __ERC721EqualSplitExtension_init(config.totalTickets);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _totalStreamReleasedAmount(
        uint256 streamTotalSupply_,
        uint256 ticketTokenId_,
        address claimToken_
    )
        internal
        view
        virtual
        override(ERC721MultiTokenStream, ERC721EmissionReleaseExtension)
        returns (uint256)
    {
        // Removing the logic from emission extension because it is irrevelant when staking.
        return 0;
    }

    function _totalTokenReleasedAmount(
        uint256 totalReleasedAmount_,
        uint256 ticketTokenId_,
        address claimToken_
    )
        internal
        view
        virtual
        override(ERC721MultiTokenStream, ERC721EqualSplitExtension)
        returns (uint256)
    {
        totalReleasedAmount_;
        ticketTokenId_;
        claimToken_;

        // Get the rate per token to calculate based on stake duration
        return
            (emissionRate / totalTickets) *
            // Intentionally rounded down
            (totalStakedDuration(ticketTokenId_) / emissionTimeUnit);
    }

    function _stakingTimeLimit()
        internal
        view
        virtual
        override
        returns (uint64)
    {
        if (emissionEnd > 0) {
            return emissionEnd;
        }

        return super._stakingTimeLimit();
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    )
        internal
        override(
            ERC721MultiTokenStream,
            ERC721EmissionReleaseExtension,
            ERC721LockableClaimExtension
        )
    {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721EmissionReleaseExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }

    /* PUBLIC */

    function stake(uint256 tokenId) public override nonReentrant {
        require(uint64(block.timestamp) >= emissionStart, "NOT_STARTED_YET");

        super.stake(tokenId);
    }

    function stake(uint256[] calldata tokenIds) public override nonReentrant {
        require(uint64(block.timestamp) >= emissionStart, "NOT_STARTED_YET");

        super.stake(tokenIds);
    }

    function unstake(uint256 tokenId) public override nonReentrant {
        super.unstake(tokenId);
    }

    function unstake(uint256[] calldata tokenIds) public override nonReentrant {
        super.unstake(tokenIds);
    }

    function rateByToken(uint256[] calldata tokenIds)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 staked;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (lastStakingTime[tokenIds[i]] > 0) {
                staked++;
            }
        }

        return (emissionRate * staked) / totalTickets;
    }

    function rewardAmountByToken(uint256 ticketTokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return
            ((emissionRate * totalStakedDuration(ticketTokenId)) /
                totalTickets) / emissionTimeUnit;
    }

    function rewardAmountByToken(uint256[] calldata ticketTokenIds)
        public
        view
        virtual
        returns (uint256 total)
    {
        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            total += rewardAmountByToken(ticketTokenIds[i]);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

interface IERC721EqualSplitExtension {
    function hasERC721EqualSplitExtension() external view returns (bool);

    function setTotalTickets(uint256 newValue) external;
}

abstract contract ERC721EqualSplitExtension is
    IERC721EqualSplitExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    // Total number of ERC721 tokens to calculate their equal split share
    uint256 public totalTickets;

    /* INTERNAL */

    function __ERC721EqualSplitExtension_init(uint256 _totalTickets)
        internal
        onlyInitializing
    {
        __ERC721EqualSplitExtension_init_unchained(_totalTickets);
    }

    function __ERC721EqualSplitExtension_init_unchained(uint256 _totalTickets)
        internal
        onlyInitializing
    {
        totalTickets = _totalTickets;

        _registerInterface(type(IERC721EqualSplitExtension).interfaceId);
    }

    /* ADMIN */

    function setTotalTickets(uint256 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        totalTickets = newValue;
    }

    /* PUBLIC */

    function hasERC721EqualSplitExtension() external pure returns (bool) {
        return true;
    }

    /* INTERNAL */

    function _totalTokenReleasedAmount(
        uint256 totalReleasedAmount_,
        uint256 ticketTokenId_,
        address claimToken_
    ) internal view virtual override returns (uint256) {
        ticketTokenId_;
        claimToken_;

        return totalReleasedAmount_ / totalTickets;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IERC721LockableExtension} from "../../../collections/ERC721/extensions/ERC721LockableExtension.sol";

import "./ERC721StakingExtension.sol";

/**
 * @author Flair (https://flair.finance)
 */
interface IERC721LockedStakingExtension {
    function hasERC721LockedStakingExtension() external view returns (bool);
}

/**
 * @author Flair (https://flair.finance)
 */
abstract contract ERC721LockedStakingExtension is
    IERC721LockedStakingExtension,
    ERC721StakingExtension
{
    /* INIT */

    function __ERC721LockedStakingExtension_init(
        uint64 _minStakingDuration,
        uint64 _maxStakingTotalDurations
    ) internal onlyInitializing {
        __ERC721LockedStakingExtension_init_unchained();
        __ERC721StakingExtension_init_unchained(
            _minStakingDuration,
            _maxStakingTotalDurations
        );
    }

    function __ERC721LockedStakingExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721LockedStakingExtension).interfaceId);
    }

    /* PUBLIC */

    function hasERC721LockedStakingExtension() external pure returns (bool) {
        return true;
    }

    function stake(uint256 tokenId) public virtual override {
        ERC721StakingExtension.stake(tokenId);
        IERC721LockableExtension(ticketToken).lock(tokenId);
    }

    function stake(uint256[] calldata tokenIds) public virtual override {
        ERC721StakingExtension.stake(tokenIds);
        IERC721LockableExtension(ticketToken).lock(tokenIds);
    }

    function unstake(uint256 tokenId) public virtual override {
        ERC721StakingExtension.unstake(tokenId);
        IERC721LockableExtension(ticketToken).unlock(tokenId);
    }

    function unstake(uint256[] calldata tokenIds) public virtual override {
        ERC721StakingExtension.unstake(tokenIds);
        IERC721LockableExtension(ticketToken).unlock(tokenIds);
    }

    function _stake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual override {
        require(
            operator == IERC721(ticketToken).ownerOf(tokenId),
            "NOT_TOKEN_OWNER"
        );
        ERC721StakingExtension._stake(operator, currentTime, tokenId);
    }

    function _unstake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual override {
        require(
            operator == IERC721(ticketToken).ownerOf(tokenId),
            "NOT_TOKEN_OWNER"
        );
        ERC721StakingExtension._unstake(operator, currentTime, tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721LockableExtension {
    function locked(uint256 tokenId) external view returns (bool);

    function lock(uint256 tokenId) external;

    function lock(uint256[] calldata tokenIds) external;

    function unlock(uint256 tokenId) external;

    function unlock(uint256[] calldata tokenIds) external;
}

/**
 * @dev Extension to allow locking NFTs, for use-cases like staking, without leaving holders wallet.
 */
abstract contract ERC721LockableExtension is
    IERC721LockableExtension,
    Initializable,
    ERC165Storage,
    ERC721AutoIdMinterExtension,
    ReentrancyGuard
{
    using BitMaps for BitMaps.BitMap;

    BitMaps.BitMap internal lockedTokens;

    function __ERC721LockableExtension_init() internal onlyInitializing {
        __ERC721LockableExtension_init_unchained();
    }

    function __ERC721LockableExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721LockableExtension).interfaceId);
    }

    // PUBLIC

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    /**
     * Returns if a token is locked or not.
     */
    function locked(uint256 tokenId) public view virtual returns (bool) {
        return lockedTokens.get(tokenId);
    }

    function filterUnlocked(uint256[] calldata ticketTokenIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory unlocked = new uint256[](ticketTokenIds.length);

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            if (!locked(ticketTokenIds[i])) {
                unlocked[i] = ticketTokenIds[i];
            }
        }

        return unlocked;
    }

    /* INTERNAL */

    /**
     * At this moment staking is only possible from a certain address (usually a smart contract).
     *
     * This is because in almost all cases you want another contract to perform custom logic on lock and unlock operations,
     * without allowing users to directly unlock their tokens and sell them, for example.
     */
    function _lock(uint256 tokenId) internal virtual {
        require(!lockedTokens.get(tokenId), "LOCKED");
        lockedTokens.set(tokenId);
    }

    function _unlock(uint256 tokenId) internal virtual {
        require(lockedTokens.get(tokenId), "NOT_LOCKED");
        lockedTokens.unset(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        require(!lockedTokens.get(tokenId), "LOCKED");
        super._beforeTokenTransfer(from, to, tokenId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../base/ERC721MultiTokenStream.sol";

/**
 * @author Flair (https://flair.finance)
 */
interface IERC721StakingExtension {
    function hasERC721StakingExtension() external view returns (bool);

    function stake(uint256 tokenId) external;

    function stake(uint256[] calldata tokenIds) external;
}

/**
 * @author Flair (https://flair.finance)
 */
abstract contract ERC721StakingExtension is
    IERC721StakingExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721MultiTokenStream
{
    // Minimum seconds that token must be staked before unstaking.
    uint64 public minStakingDuration;

    // Maximum sum total of all durations staking that will be counted (across all stake/unstakes for each token). Staked durations beyond this number is ignored.
    uint64 public maxStakingTotalDurations;

    // Map of token ID to the time of last staking
    mapping(uint256 => uint64) public lastStakingTime;

    // Map of token ID to the sum total of all previous staked durations
    mapping(uint256 => uint64) public savedStakedDurations;

    /* INIT */

    function __ERC721StakingExtension_init(
        uint64 _minStakingDuration,
        uint64 _maxStakingTotalDurations
    ) internal onlyInitializing {
        __ERC721StakingExtension_init_unchained(
            _minStakingDuration,
            _maxStakingTotalDurations
        );
    }

    function __ERC721StakingExtension_init_unchained(
        uint64 _minStakingDuration,
        uint64 _maxStakingTotalDurations
    ) internal onlyInitializing {
        minStakingDuration = _minStakingDuration;
        maxStakingTotalDurations = _maxStakingTotalDurations;

        _registerInterface(type(IERC721StakingExtension).interfaceId);
    }

    /* ADMIN */

    function setMinStakingDuration(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        minStakingDuration = newValue;
    }

    function setMaxStakingTotalDurations(uint64 newValue) public onlyOwner {
        require(lockedUntilTimestamp < block.timestamp, "CONFIG_LOCKED");
        maxStakingTotalDurations = newValue;
    }

    /* PUBLIC */

    function hasERC721StakingExtension() external pure returns (bool) {
        return true;
    }

    function stake(uint256 tokenId) public virtual {
        _stake(_msgSender(), uint64(block.timestamp), tokenId);
    }

    function stake(uint256[] calldata tokenIds) public virtual {
        address operator = _msgSender();
        uint64 currentTime = uint64(block.timestamp);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _stake(operator, currentTime, tokenIds[i]);
        }
    }

    function unstake(uint256 tokenId) public virtual {
        _unstake(_msgSender(), uint64(block.timestamp), tokenId);
    }

    function unstake(uint256[] calldata tokenIds) public virtual {
        address operator = _msgSender();
        uint64 currentTime = uint64(block.timestamp);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _unstake(operator, currentTime, tokenIds[i]);
        }
    }

    function totalStakedDuration(uint256[] calldata ticketTokenIds)
        public
        view
        virtual
        returns (uint64)
    {
        uint64 totalDurations = 0;

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            totalDurations += totalStakedDuration(ticketTokenIds[i]);
        }

        return totalDurations;
    }

    function totalStakedDuration(uint256 ticketTokenId)
        public
        view
        virtual
        returns (uint64)
    {
        uint64 total = savedStakedDurations[ticketTokenId];

        if (lastStakingTime[ticketTokenId] > 0) {
            uint64 targetTime = _stakingTimeLimit();

            if (targetTime > block.timestamp) {
                targetTime = uint64(block.timestamp);
            }

            if (lastStakingTime[ticketTokenId] > 0) {
                if (targetTime > lastStakingTime[ticketTokenId]) {
                    total += (targetTime - lastStakingTime[ticketTokenId]);
                }
            }
        }

        if (total > maxStakingTotalDurations) {
            total = maxStakingTotalDurations;
        }

        return total;
    }

    function unlockingTime(uint256 ticketTokenId)
        public
        view
        returns (uint256)
    {
        return
            lastStakingTime[ticketTokenId] > 0
                ? lastStakingTime[ticketTokenId] + minStakingDuration
                : 0;
    }

    function unlockingTime(uint256[] calldata ticketTokenIds)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory unlockedAt = new uint256[](ticketTokenIds.length);

        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            unlockedAt[i] = unlockingTime(ticketTokenIds[i]);
        }

        return unlockedAt;
    }

    /* INTERNAL */

    function _stakingTimeLimit() internal view virtual returns (uint64) {
        return 18_446_744_073_709_551_615; // max(uint64)
    }

    function _stake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual {
        require(
            totalStakedDuration(tokenId) < maxStakingTotalDurations,
            "MAX_DURATION_EXCEEDED"
        );

        lastStakingTime[tokenId] = currentTime;
    }

    function _unstake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual {
        operator;

        require(lastStakingTime[tokenId] > 0, "NOT_STAKED");

        require(
            currentTime >= lastStakingTime[tokenId] + minStakingDuration,
            "NOT_STAKED_LONG_ENOUGH"
        );

        savedStakedDurations[tokenId] = totalStakedDuration(tokenId);

        lastStakingTime[tokenId] = 0;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721VestingReleaseExtension.sol";
import "../extensions/ERC721EqualSplitExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721EqualVestingStream is
    Initializable,
    Ownable,
    ERC721VestingReleaseExtension,
    ERC721EqualSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    using Address for address;
    using Address for address payable;

    string public constant name = "ERC721 Equal Vesting Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Vesting release extension
        uint64 startTimestamp;
        uint64 durationSeconds;
        // Equal split extension
        uint256 totalTickets;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721VestingReleaseExtension_init(
            config.startTimestamp,
            config.durationSeconds
        );
        __ERC721EqualSplitExtension_init(config.totalTickets);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal override(ERC721MultiTokenStream, ERC721LockableClaimExtension) {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721InstantReleaseExtension.sol";
import "../extensions/ERC721EqualSplitExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721EqualInstantStream is
    Initializable,
    Ownable,
    ERC721InstantReleaseExtension,
    ERC721EqualSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    string public constant name = "ERC721 Equal Instant Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Equal split extension
        uint256 totalTickets;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721EqualSplitExtension_init(config.totalTickets);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal override(ERC721MultiTokenStream, ERC721LockableClaimExtension) {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721EmissionReleaseExtension.sol";
import "../extensions/ERC721EqualSplitExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

contract ERC721EqualEmissionStream is
    Initializable,
    Ownable,
    ERC721EmissionReleaseExtension,
    ERC721EqualSplitExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    using Address for address;
    using Address for address payable;

    string public constant name = "ERC721 Equal Emission Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Equal split extension
        uint256 totalTickets;
        // Emission release extension
        uint256 emissionRate;
        uint64 emissionTimeUnit;
        uint64 emissionStart;
        uint64 emissionEnd;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721EmissionReleaseExtension_init(
            config.emissionRate,
            config.emissionTimeUnit,
            config.emissionStart,
            config.emissionEnd
        );
        __ERC721EqualSplitExtension_init(config.totalTickets);
    }

    function rateByToken(uint256[] calldata tokenIds)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return ((emissionRate * tokenIds.length) / totalTickets);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    )
        internal
        override(
            ERC721MultiTokenStream,
            ERC721EmissionReleaseExtension,
            ERC721LockableClaimExtension
        )
    {
        ERC721MultiTokenStream._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721EmissionReleaseExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../extensions/ERC721EmissionReleaseExtension.sol";
import "../extensions/ERC721EqualSplitExtension.sol";
import "../extensions/ERC721CustodialStakingExtension.sol";
import "../extensions/ERC721LockableClaimExtension.sol";

/**
 * @author Flair (https://flair.finance)
 */
contract ERC721CustodialStakingEmissionStream is
    Initializable,
    Ownable,
    ERC721EmissionReleaseExtension,
    ERC721EqualSplitExtension,
    ERC721CustodialStakingExtension,
    ERC721LockableClaimExtension,
    WithdrawExtension
{
    using Address for address;
    using Address for address payable;

    string public constant name = "ERC721 Custodial Staking Emission Stream";

    string public constant version = "0.1";

    struct Config {
        // Base
        address ticketToken;
        uint64 lockedUntilTimestamp;
        // Locked staking extension
        uint64 minStakingDuration; // in seconds. Minimum time the NFT must stay locked before unstaking.
        uint64 maxStakingTotalDurations; // in seconds. Maximum sum total of all durations staking that will be counted (across all stake/unstakes for each token).
        // Emission release extension
        uint256 emissionRate;
        uint64 emissionTimeUnit;
        uint64 emissionStart;
        uint64 emissionEnd;
        // Equal split extension
        uint256 totalTickets;
        // Lockable claim extension
        uint64 claimLockedUntil;
    }

    /* INTERNAL */

    constructor(Config memory config) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _transferOwnership(deployer);

        __WithdrawExtension_init(deployer, WithdrawMode.OWNER);
        __ERC721MultiTokenStream_init(
            config.ticketToken,
            config.lockedUntilTimestamp
        );
        __ERC721CustodialStakingExtension_init(
            config.minStakingDuration,
            config.maxStakingTotalDurations
        );
        __ERC721EmissionReleaseExtension_init(
            config.emissionRate,
            config.emissionTimeUnit,
            config.emissionStart,
            config.emissionEnd
        );
        __ERC721EqualSplitExtension_init(config.totalTickets);
        __ERC721LockableClaimExtension_init(config.claimLockedUntil);
    }

    function _totalStreamReleasedAmount(
        uint256 streamTotalSupply_,
        uint256 ticketTokenId_,
        address claimToken_
    )
        internal
        view
        virtual
        override(ERC721MultiTokenStream, ERC721EmissionReleaseExtension)
        returns (uint256)
    {
        // Removing the logic from emission extension because it is irrevelant when staking.
        return 0;
    }

    function _totalTokenReleasedAmount(
        uint256 totalReleasedAmount_,
        uint256 ticketTokenId_,
        address claimToken_
    )
        internal
        view
        virtual
        override(ERC721MultiTokenStream, ERC721EqualSplitExtension)
        returns (uint256)
    {
        totalReleasedAmount_;
        ticketTokenId_;
        claimToken_;

        // Get the rate per token to calculate based on stake duration
        return
            (emissionRate / totalTickets) *
            // Intentionally rounded down
            (totalStakedDuration(ticketTokenId_) / emissionTimeUnit);
    }

    function _stakingTimeLimit()
        internal
        view
        virtual
        override
        returns (uint64)
    {
        if (emissionEnd > 0) {
            return emissionEnd;
        }

        return super._stakingTimeLimit();
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    )
        internal
        override(
            ERC721MultiTokenStream,
            ERC721CustodialStakingExtension,
            ERC721EmissionReleaseExtension,
            ERC721LockableClaimExtension
        )
    {
        // Intentionally skipping ERC721MultiTokenStream because we need to check ownership based on current status of custody.
        ERC721CustodialStakingExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721LockableClaimExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
        ERC721EmissionReleaseExtension._beforeClaim(
            ticketTokenId_,
            claimToken_,
            beneficiary_
        );
    }

    /* PUBLIC */

    function stake(uint256 tokenId) public override nonReentrant {
        require(uint64(block.timestamp) >= emissionStart, "NOT_STARTED_YET");

        super.stake(tokenId);
    }

    function stake(uint256[] calldata tokenIds) public override nonReentrant {
        require(uint64(block.timestamp) >= emissionStart, "NOT_STARTED_YET");

        super.stake(tokenIds);
    }

    function unstake(uint256 tokenId) public override nonReentrant {
        super.unstake(tokenId);
    }

    function unstake(uint256[] calldata tokenIds) public override nonReentrant {
        super.unstake(tokenIds);
    }

    function rateByToken(uint256[] calldata tokenIds)
        public
        view
        virtual
        override
        returns (uint256)
    {
        uint256 staked;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (lastStakingTime[tokenIds[i]] > 0) {
                staked++;
            }
        }

        return (emissionRate * staked) / totalTickets;
    }

    function rewardAmountByToken(uint256 ticketTokenId)
        public
        view
        virtual
        returns (uint256)
    {
        return
            ((emissionRate * totalStakedDuration(ticketTokenId)) /
                totalTickets) / emissionTimeUnit;
    }

    function rewardAmountByToken(uint256[] calldata ticketTokenIds)
        public
        view
        virtual
        returns (uint256 total)
    {
        for (uint256 i = 0; i < ticketTokenIds.length; i++) {
            total += rewardAmountByToken(ticketTokenIds[i]);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IERC721LockableExtension} from "../../../collections/ERC721/extensions/ERC721LockableExtension.sol";

import "./ERC721StakingExtension.sol";

/**
 * @author Flair (https://flair.finance)
 */
interface IERC721CustodialStakingExtension {
    function hasERC721CustodialStakingExtension() external view returns (bool);

    function tokensInCustody(
        address staker,
        uint256 startTokenId,
        uint256 endTokenId
    ) external view returns (bool[] memory);
}

/**
 * @author Flair (https://flair.finance)
 */
abstract contract ERC721CustodialStakingExtension is
    IERC721CustodialStakingExtension,
    ERC721StakingExtension
{
    mapping(uint256 => address) public stakers;

    /* INIT */

    function __ERC721CustodialStakingExtension_init(
        uint64 _minStakingDuration,
        uint64 _maxStakingTotalDurations
    ) internal onlyInitializing {
        __ERC721CustodialStakingExtension_init_unchained();
        __ERC721StakingExtension_init_unchained(
            _minStakingDuration,
            _maxStakingTotalDurations
        );
    }

    function __ERC721CustodialStakingExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721CustodialStakingExtension).interfaceId);
    }

    /* PUBLIC */

    function hasERC721CustodialStakingExtension() external pure returns (bool) {
        return true;
    }

    function tokensInCustody(
        address staker,
        uint256 startTokenId,
        uint256 endTokenId
    ) external view returns (bool[] memory tokens) {
        tokens = new bool[](endTokenId - startTokenId + 1);

        for (uint256 i = startTokenId; i <= endTokenId; i++) {
            if (stakers[i] == staker) {
                tokens[i - startTokenId] = true;
            }
        }

        return tokens;
    }

    /* INTERNAL */

    function _stake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual override {
        stakers[tokenId] = operator;
        super._stake(operator, currentTime, tokenId);
        IERC721(ticketToken).transferFrom(operator, address(this), tokenId);
    }

    function _unstake(
        address operator,
        uint64 currentTime,
        uint256 tokenId
    ) internal virtual override {
        require(stakers[tokenId] == operator, "NOT_STAKER");
        delete stakers[tokenId];

        super._unstake(operator, currentTime, tokenId);
        IERC721(ticketToken).transferFrom(address(this), operator, tokenId);
    }

    function _beforeClaim(
        uint256 ticketTokenId_,
        address claimToken_,
        address beneficiary_
    ) internal virtual override {
        claimToken_;

        if (stakers[ticketTokenId_] == address(0)) {
            require(
                IERC721(ticketToken).ownerOf(ticketTokenId_) == beneficiary_,
                "NOT_NFT_OWNER"
            );
        } else {
            require(beneficiary_ == stakers[ticketTokenId_], "NOT_STAKER");
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity ^0.8.15;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./ERC721LockableExtension.sol";

interface IERC721RoleBasedLockableExtension {
    function hasRoleBasedLockableExtension() external view returns (bool);
}

/**
 * @dev Extension to allow locking NFTs, for use-cases like staking, without leaving holders wallet, using roles.
 */
abstract contract ERC721RoleBasedLockableExtension is
    IERC721RoleBasedLockableExtension,
    ERC721LockableExtension,
    AccessControl
{
    using BitMaps for BitMaps.BitMap;

    bytes32 public constant LOCKER_ROLE = keccak256("LOCKER_ROLE");

    function __ERC721RoleBasedLockableExtension_init()
        internal
        onlyInitializing
    {
        __ERC721RoleBasedLockableExtension_init_unchained();
    }

    function __ERC721RoleBasedLockableExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721RoleBasedLockableExtension).interfaceId);
    }

    // ADMIN

    /**
     * Locks token(s) to effectively lock them, while keeping in the same wallet.
     * This mechanism prevents them from being transferred, yet still will show correct owner.
     */
    function lock(uint256 tokenId) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");
        _lock(tokenId);
    }

    function lock(uint256[] calldata tokenIds) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _lock(tokenIds[i]);
        }
    }

    /**
     * Unlocks locked token(s) to be able to transfer.
     */
    function unlock(uint256 tokenId) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");
        _unlock(tokenId);
    }

    function unlock(uint256[] calldata tokenIds) public virtual nonReentrant {
        require(hasRole(LOCKER_ROLE, msg.sender), "NOT_LOCKER_ROLE");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _unlock(tokenIds[i]);
        }
    }

    // PUBLIC

    function hasRoleBasedLockableExtension()
        public
        view
        virtual
        returns (bool)
    {
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721LockableExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../extensions/ERC721CollectionMetadataExtension.sol";
import "../extensions/ERC721PrefixedMetadataExtension.sol";
import "../extensions/ERC721AutoIdMinterExtension.sol";
import "../extensions/ERC721OwnerMintExtension.sol";
import "../extensions/ERC721TieringExtension.sol";
import "../extensions/ERC721RoleBasedMintExtension.sol";
import "../extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721RoleBasedLockableExtension.sol";

contract ERC721TieredSalesCollection is
    Ownable,
    ERC165Storage,
    WithdrawExtension,
    LicenseExtension,
    ERC721PrefixedMetadataExtension,
    ERC721OwnerMintExtension,
    ERC721TieringExtension,
    ERC721RoleBasedMintExtension,
    ERC721RoleBasedLockableExtension,
    ERC721RoyaltyExtension,
    ERC2771ContextOwnable
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        string placeholderURI;
        string tokenURIPrefix;
        uint256 maxSupply;
        Tier[] tiers;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address proceedsRecipient;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);

        _transferOwnership(deployer);

        __WithdrawExtension_init(config.proceedsRecipient, WithdrawMode.ANYONE);
        __LicenseExtension_init(config.licenseVersion);
        __ERC721CollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721PrefixedMetadataExtension_init(
            config.placeholderURI,
            config.tokenURIPrefix
        );
        __ERC721AutoIdMinterExtension_init(config.maxSupply);
        __ERC721OwnerMintExtension_init();
        __ERC721RoleBasedMintExtension_init(deployer);
        __ERC721RoleBasedLockableExtension_init();
        __ERC721TieringExtension_init(config.tiers);
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return ERC2771ContextOwnable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return ERC2771ContextOwnable._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721LockableExtension) {
        return ERC721LockableExtension._beforeTokenTransfer(from, to, tokenId);
    }

    /* PUBLIC */

    function name()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.symbol();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721CollectionMetadataExtension,
            ERC721PrefixedMetadataExtension,
            ERC721OwnerMintExtension,
            ERC721RoleBasedMintExtension,
            ERC721RoyaltyExtension,
            ERC721RoleBasedLockableExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, ERC721PrefixedMetadataExtension)
        returns (string memory)
    {
        return ERC721PrefixedMetadataExtension.tokenURI(_tokenId);
    }

    function setMaxSupply(uint256 newValue)
        public
        virtual
        override(ERC721AutoIdMinterExtension, ERC721TieringExtension)
        onlyOwner
    {
        ERC721TieringExtension.setMaxSupply(newValue);
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.3) (utils/cryptography/ECDSA.sol)

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
        InvalidSignatureV
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
        } else if (error == RecoverError.InvalidSignatureV) {
            revert("ECDSA: invalid signature 'v' value");
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
    function tryRecover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address, RecoverError) {
        bytes32 s = vs & bytes32(0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        uint8 v = uint8((uint256(vs) >> 255) + 27);
        return tryRecover(hash, v, r, s);
    }

    /**
     * @dev Overload of {ECDSA-recover} that receives the `r and `vs` short-signature fields separately.
     *
     * _Available since v4.2._
     */
    function recover(
        bytes32 hash,
        bytes32 r,
        bytes32 vs
    ) internal pure returns (address) {
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
    function tryRecover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address, RecoverError) {
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
        if (v != 27 && v != 28) {
            return (address(0), RecoverError.InvalidSignatureV);
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
    function recover(
        bytes32 hash,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal pure returns (address) {
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
    function toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        // 32 is the length in bytes of hash,
        // enforced by the type signature above
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
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
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/cryptography/draft-EIP712.sol)

pragma solidity ^0.8.0;

import "./ECDSA.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding specified in the EIP is very generic, and such a generic implementation in Solidity is not feasible,
 * thus this contract does not implement the encoding itself. Protocols need to implement the type-specific encoding
 * they need in their contracts using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 * _Available since v3.4._
 */
abstract contract EIP712 {
    /* solhint-disable var-name-mixedcase */
    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;
    address private immutable _CACHED_THIS;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;
    bytes32 private immutable _TYPE_HASH;

    /* solhint-enable var-name-mixedcase */

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     *
     * NOTE: These parameters cannot be changed except through a xref:learn::upgrading-smart-contracts.adoc[smart
     * contract upgrade].
     */
    constructor(string memory name, string memory version) {
        bytes32 hashedName = keccak256(bytes(name));
        bytes32 hashedVersion = keccak256(bytes(version));
        bytes32 typeHash = keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(typeHash, hashedName, hashedVersion);
        _CACHED_THIS = address(this);
        _TYPE_HASH = typeHash;
    }

    /**
     * @dev Returns the domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _CACHED_THIS && block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function _buildDomainSeparator(
        bytes32 typeHash,
        bytes32 nameHash,
        bytes32 versionHash
    ) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, nameHash, versionHash, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view virtual returns (bytes32) {
        return ECDSA.toTypedDataHash(_domainSeparatorV4(), structHash);
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Context.sol";

abstract contract NativeMetaTransaction is Context, EIP712 {
    using SafeMath for uint256;

    bytes32 private constant META_TRANSACTION_TYPEHASH =
        keccak256(
            bytes(
                "MetaTransaction(uint256 nonce,address from,bytes functionSignature)"
            )
        );

    event MetaTransactionExecuted(
        address userAddress,
        address payable relayerAddress,
        bytes functionSignature
    );

    mapping(address => uint256) nonces;

    /*
     * Meta transaction structure.
     * No point of including value field here as if user is doing value transfer then he has the funds to pay for gas
     * He should call the desired function directly in that case.
     */
    struct MetaTransaction {
        uint256 nonce;
        address from;
        bytes functionSignature;
    }

    function _msgSender() internal view override returns (address sender) {
        if (msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(
                    mload(add(array, index)),
                    0xffffffffffffffffffffffffffffffffffffffff
                )
            }
        } else {
            sender = msg.sender;
        }

        return sender;
    }

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) public payable returns (bytes memory) {
        MetaTransaction memory metaTx = MetaTransaction({
            nonce: nonces[userAddress],
            from: userAddress,
            functionSignature: functionSignature
        });

        require(
            verify(userAddress, metaTx, sigR, sigS, sigV),
            "Signer and signature do not match"
        );

        // increase nonce for user (to avoid re-use)
        nonces[userAddress] = nonces[userAddress].add(1);

        emit MetaTransactionExecuted(
            userAddress,
            payable(msg.sender),
            functionSignature
        );

        // Append userAddress and relayer address at the end to extract it from calling context
        (bool success, bytes memory returnData) = address(this).call(
            abi.encodePacked(functionSignature, userAddress)
        );

        require(success, "Function call not successful");

        return returnData;
    }

    function hashMetaTransaction(MetaTransaction memory metaTx)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encode(
                    META_TRANSACTION_TYPEHASH,
                    metaTx.nonce,
                    metaTx.from,
                    keccak256(metaTx.functionSignature)
                )
            );
    }

    function getNonce(address user) public view returns (uint256 nonce) {
        nonce = nonces[user];
    }

    function verify(
        address signer,
        MetaTransaction memory metaTx,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) internal view returns (bool) {
        require(signer != address(0), "NativeMetaTransaction: INVALID_SIGNER");
        return
            signer ==
            ecrecover(
                _hashTypedDataV4(hashMetaTransaction(metaTx)),
                sigV,
                sigR,
                sigS
            );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UnorderedForwarder is EIP712, ReentrancyGuard {
    using ECDSA for bytes32;

    struct MetaTransaction {
        address from;
        address to;
        uint256 value;
        uint256 minGasPrice;
        uint256 maxGasPrice;
        uint256 expiresAt;
        uint256 nonce;
        bytes data;
    }

    bytes32 private constant _TYPEHASH =
        keccak256(
            "MetaTransaction(address from,address to,uint256 value,uint256 minGasPrice,uint256 maxGasPrice,uint256 expiresAt,uint256 nonce,bytes data)"
        );

    mapping(bytes32 => uint256) mtxHashToExecutedBlockNumber;

    constructor() EIP712("UnorderedForwarder", "0.0.1") {}

    /// @dev Refunds up to `msg.value` leftover ETH at the end of the call.
    modifier refundsAttachedEth() {
        _;
        uint256 remainingBalance = msg.value > address(this).balance
            ? address(this).balance
            : msg.value;
        if (remainingBalance > 0) {
            payable(msg.sender).transfer(remainingBalance);
        }
    }

    /// @dev Ensures that the ETH balance of `this` does not go below the
    ///      initial ETH balance before the call (excluding ETH attached to the call).
    modifier doesNotReduceEthBalance() {
        uint256 initialBalance = address(this).balance - msg.value;
        _;
        require(initialBalance <= address(this).balance, "FWD_ETH_LEAK");
    }

    function verify(MetaTransaction calldata mtx, bytes calldata signature)
        public
        view
        returns (bytes32 mtxHash)
    {
        mtxHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    _TYPEHASH,
                    mtx.from,
                    mtx.to,
                    mtx.value,
                    mtx.minGasPrice,
                    mtx.maxGasPrice,
                    mtx.expiresAt,
                    mtx.nonce,
                    keccak256(mtx.data)
                )
            )
        );

        // Must not be expired.
        require(mtx.expiresAt > block.timestamp, "FWD_EXPIRED");

        // Must be signed by the signer.
        require(
            mtxHash.recover(signature) == mtx.from,
            "FWD_INVALID_SIGNATURE"
        );

        // Transaction must not have been already executed.
        require(mtxHashToExecutedBlockNumber[mtxHash] == 0, "FWD_REPLAYED");

        return mtxHash;
    }

    function execute(MetaTransaction calldata mtx, bytes calldata signature)
        public
        payable
        nonReentrant
        doesNotReduceEthBalance
        refundsAttachedEth
        returns (bytes memory)
    {
        return _execute(mtx, signature);
    }

    function batchExecute(
        MetaTransaction[] calldata mtxs,
        bytes[] calldata signatures
    )
        public
        payable
        nonReentrant
        doesNotReduceEthBalance
        refundsAttachedEth
        returns (bytes[] memory returnResults)
    {
        require(mtxs.length == signatures.length, "FWD_MISMATCH_SIGNATURES");

        returnResults = new bytes[](mtxs.length);

        for (uint256 i = 0; i < mtxs.length; ++i) {
            returnResults[i] = _execute(mtxs[i], signatures[i]);
        }
    }

    function _execute(MetaTransaction calldata mtx, bytes calldata signature)
        internal
        returns (bytes memory)
    {
        // Must have a valid gas price.
        require(
            mtx.minGasPrice <= tx.gasprice && tx.gasprice <= mtx.maxGasPrice,
            "FWD_INVALID_GAS"
        );

        // Must have enough ETH.
        require(mtx.value <= address(this).balance, "FWD_INVALID_VALUE");

        bytes32 mtxHash = verify(mtx, signature);

        mtxHashToExecutedBlockNumber[mtxHash] = block.number;

        (bool success, bytes memory returndata) = mtx.to.call{value: mtx.value}(
            abi.encodePacked(mtx.data, mtx.from)
        );

        if (!success) {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert("FWD_CALL_FAILED");
            }
        }

        return returndata;
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../../common/WithdrawExtension.sol";
import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../extensions/ERC721CollectionMetadataExtension.sol";
import "../extensions/ERC721PrefixedMetadataExtension.sol";
import "../extensions/ERC721AutoIdMinterExtension.sol";
import "../extensions/ERC721OwnerMintExtension.sol";
import "../extensions/ERC721PreSaleExtension.sol";
import "../extensions/ERC721PublicSaleExtension.sol";
import "../extensions/ERC721RoleBasedMintExtension.sol";
import "../extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721RoleBasedLockableExtension.sol";
import "../extensions/ERC721BulkifyExtension.sol";

contract ERC721SimpleSalesCollection is
    Initializable,
    Ownable,
    ERC165Storage,
    WithdrawExtension,
    LicenseExtension,
    ERC721PrefixedMetadataExtension,
    ERC721OwnerMintExtension,
    ERC721PreSaleExtension,
    ERC721PublicSaleExtension,
    ERC721RoleBasedMintExtension,
    ERC721RoleBasedLockableExtension,
    ERC721RoyaltyExtension,
    ERC2771ContextOwnable,
    ERC721BulkifyExtension
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        string placeholderURI;
        string tokenURIPrefix;
        uint256 maxSupply;
        uint256 preSalePrice;
        uint256 preSaleMaxMintPerWallet;
        uint256 publicSalePrice;
        uint256 publicSaleMaxMintPerTx;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address proceedsRecipient;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);

        _transferOwnership(deployer);

        __WithdrawExtension_init(config.proceedsRecipient, WithdrawMode.ANYONE);
        __LicenseExtension_init(config.licenseVersion);
        __ERC721CollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721PrefixedMetadataExtension_init(
            config.placeholderURI,
            config.tokenURIPrefix
        );
        __ERC721AutoIdMinterExtension_init(config.maxSupply);
        __ERC721OwnerMintExtension_init();
        __ERC721RoleBasedMintExtension_init(deployer);
        __ERC721RoleBasedLockableExtension_init();
        __ERC721PreSaleExtension_init_unchained(
            config.preSalePrice,
            config.preSaleMaxMintPerWallet
        );
        __ERC721PublicSaleExtension_init(
            config.publicSalePrice,
            config.publicSaleMaxMintPerTx
        );
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
        __ERC721BulkifyExtension_init();
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721LockableExtension) {
        return ERC721LockableExtension._beforeTokenTransfer(from, to, tokenId);
    }

    /* PUBLIC */

    function name()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.symbol();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721PrefixedMetadataExtension,
            ERC721PreSaleExtension,
            ERC721PublicSaleExtension,
            ERC721OwnerMintExtension,
            ERC721RoleBasedMintExtension,
            ERC721RoyaltyExtension,
            ERC721RoleBasedLockableExtension,
            ERC721BulkifyExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, ERC721PrefixedMetadataExtension)
        returns (string memory)
    {
        return ERC721PrefixedMetadataExtension.tokenURI(_tokenId);
    }

    function getInfo()
        external
        view
        returns (
            uint256 _maxSupply,
            uint256 _totalSupply,
            uint256 _senderBalance,
            uint256 _preSalePrice,
            uint256 _preSaleMaxMintPerWallet,
            uint256 _preSaleAlreadyClaimed,
            bool _preSaleActive,
            uint256 _publicSalePrice,
            uint256 _publicSaleMaxMintPerTx,
            bool _publicSaleActive
        )
    {
        uint256 balance = 0;

        if (_msgSender() != address(0)) {
            balance = this.balanceOf(_msgSender());
        }

        return (
            maxSupply,
            this.totalSupply(),
            balance,
            preSalePrice,
            preSaleMaxMintPerWallet,
            preSaleAllowlistClaimed[_msgSender()],
            preSaleStatus,
            publicSalePrice,
            publicSaleMaxMintPerTx,
            publicSaleStatus
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IERC721BulkifyExtension {
    function transferFromBulk(
        address from,
        address to,
        uint256[] memory tokenIds
    ) external;

    function transferFromBulk(
        address[] memory from,
        address[] memory to,
        uint256[] memory tokenIds
    ) external;
}

/**
 * @dev Extension to add bulk operations to a standard ERC721 contract.
 */
abstract contract ERC721BulkifyExtension is
    IERC721BulkifyExtension,
    Initializable,
    ERC165Storage
{
    function __ERC721BulkifyExtension_init() internal onlyInitializing {
        __ERC721BulkifyExtension_init_unchained();
    }

    function __ERC721BulkifyExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721BulkifyExtension).interfaceId);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    /**
     * Useful for when user wants to return tokens to get a refund,
     * or when they want to transfer lots of tokens by paying gas fee only once.
     */
    function transferFromBulk(
        address from,
        address to,
        uint256[] memory tokenIds
    ) public virtual {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(address(this)).transferFrom(from, to, tokenIds[i]);
        }
    }

    /**
     * Useful for transferring multiple tokens from/to multiple addresses.
     */
    function transferFromBulk(
        address[] memory from,
        address[] memory to,
        uint256[] memory tokenIds
    ) public virtual {
        require(from.length == to.length, "FROM_TO_LENGTH_MISMATCH");
        require(from.length == tokenIds.length, "FROM_TOKEN_LENGTH_MISMATCH");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            IERC721(address(this)).transferFrom(from[i], to[i], tokenIds[i]);
        }
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import "../../../common/LicenseExtension.sol";
import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../extensions/ERC721CollectionMetadataExtension.sol";
import "../extensions/ERC721PrefixedMetadataExtension.sol";
import "../extensions/ERC721AutoIdMinterExtension.sol";
import "../extensions/ERC721OwnerMintExtension.sol";
import "../extensions/ERC721OwnerManagedExtension.sol";
import "../extensions/ERC721RoyaltyExtension.sol";
import "../extensions/ERC721BulkifyExtension.sol";

contract ERC721ManagedPrefixedCollection is
    Initializable,
    Ownable,
    ERC165Storage,
    LicenseExtension,
    ERC2771ContextOwnable,
    ERC721CollectionMetadataExtension,
    ERC721PrefixedMetadataExtension,
    ERC721AutoIdMinterExtension,
    ERC721OwnerMintExtension,
    ERC721OwnerManagedExtension,
    ERC721RoyaltyExtension,
    ERC721BulkifyExtension
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        string placeholderURI;
        string tokenURIPrefix;
        address[] initialHolders;
        uint256[] initialAmounts;
        uint256 maxSupply;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        require(
            config.initialHolders.length == config.initialAmounts.length,
            "ERC721/INVALID_INITIAL_ARGS"
        );

        _transferOwnership(deployer);

        __LicenseExtension_init(config.licenseVersion);
        __ERC721CollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721PrefixedMetadataExtension_init(
            config.placeholderURI,
            config.tokenURIPrefix
        );
        __ERC721AutoIdMinterExtension_init(config.maxSupply);
        __ERC721OwnerMintExtension_init();
        __ERC721OwnerManagedExtension_init();
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
        __ERC721BulkifyExtension_init();

        maxSupply = config.maxSupply;

        for (uint256 i = 0; i < config.initialHolders.length; i++) {
            _mintTo(config.initialHolders[i], config.initialAmounts[i]);
        }
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    /* PUBLIC */

    function name()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(ERC721, ERC721CollectionMetadataExtension)
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.symbol();
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721, ERC721OwnerManagedExtension)
        returns (bool)
    {
        return ERC721OwnerManagedExtension.isApprovedForAll(owner, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721CollectionMetadataExtension,
            ERC721OwnerMintExtension,
            ERC721OwnerManagedExtension,
            ERC721PrefixedMetadataExtension,
            ERC721RoyaltyExtension,
            ERC721BulkifyExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, ERC721PrefixedMetadataExtension)
        returns (string memory)
    {
        return ERC721PrefixedMetadataExtension.tokenURI(_tokenId);
    }

    function getInfo()
        external
        view
        returns (
            uint256 _maxSupply,
            uint256 _totalSupply,
            uint256 _senderBalance
        )
    {
        uint256 balance = 0;

        if (_msgSender() != address(0)) {
            balance = this.balanceOf(_msgSender());
        }

        return (maxSupply, this.totalSupply(), balance);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721OwnerManagedExtension {
    function revokeManagementPower() external;
}

/**
 * @dev Extension to allow owner to transfer tokens on behalf of owners. Only useful for certain use-cases.
 */
abstract contract ERC721OwnerManagedExtension is
    IERC721OwnerManagedExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AutoIdMinterExtension
{
    bool public managementPowerRevoked;

    function __ERC721OwnerManagedExtension_init() internal onlyInitializing {
        __ERC721OwnerManagedExtension_init_unchained();
    }

    function __ERC721OwnerManagedExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OwnerManagedExtension).interfaceId);
    }

    /* ADMIN */

    function revokeManagementPower() external onlyOwner {
        managementPowerRevoked = true;
    }

    /* PUBLIC */

    /**
     * Override isApprovedForAll to allow owner to transfer tokens.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        if (!managementPowerRevoked) {
            if (operator == super.owner()) {
                return true;
            }
        }

        return super.isApprovedForAll(owner, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721OwnerManagedExtension} from "../../ERC721/extensions/ERC721OwnerManagedExtension.sol";

/**
 * @dev Extension to allow owner to transfer tokens on behalf of owners. Only useful for certain use-cases.
 */
abstract contract ERC721AOwnerManagedExtension is
    IERC721OwnerManagedExtension,
    Initializable,
    Ownable,
    ERC165Storage,
    ERC721AMinterExtension
{
    bool public managementPowerRevoked;

    function __ERC721AOwnerManagedExtension_init() internal onlyInitializing {
        __ERC721AOwnerManagedExtension_init_unchained();
    }

    function __ERC721AOwnerManagedExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721OwnerManagedExtension).interfaceId);
    }

    /* ADMIN */

    function revokeManagementPower() external onlyOwner {
        managementPowerRevoked = true;
    }

    /* PUBLIC */

    /**
     * Override isApprovedForAll to allow owner to transfer tokens.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(ERC721A)
        returns (bool)
    {
        if (!managementPowerRevoked) {
            if (operator == super.owner()) {
                return true;
            }
        }

        return super.isApprovedForAll(owner, operator);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "../../../common/meta-transactions/ERC2771ContextOwnable.sol";
import "../../../common/LicenseExtension.sol";
import "../extensions/ERC721CollectionMetadataExtension.sol";
import "../extensions/ERC721PerTokenMetadataExtension.sol";
import "../extensions/ERC721OneOfOneMintExtension.sol";
import "../extensions/ERC721AutoIdMinterExtension.sol";
import "../extensions/ERC721OwnerMintExtension.sol";
import "../extensions/ERC721RoyaltyExtension.sol";

contract ERC721OneOfOneCollection is
    Initializable,
    Ownable,
    ERC165Storage,
    LicenseExtension,
    ERC721PerTokenMetadataExtension,
    ERC721OwnerMintExtension,
    ERC721RoyaltyExtension,
    ERC721OneOfOneMintExtension,
    ERC2771ContextOwnable
{
    struct Config {
        string name;
        string symbol;
        string contractURI;
        uint256 maxSupply;
        address defaultRoyaltyAddress;
        uint16 defaultRoyaltyBps;
        address trustedForwarder;
        LicenseVersion licenseVersion;
    }

    constructor(Config memory config) ERC721(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _setupRole(DEFAULT_ADMIN_ROLE, deployer);
        _setupRole(MINTER_ROLE, deployer);

        _transferOwnership(deployer);

        __LicenseExtension_init(config.licenseVersion);
        __ERC721CollectionMetadataExtension_init(
            config.name,
            config.symbol,
            config.contractURI
        );
        __ERC721PerTokenMetadataExtension_init();
        __ERC721OwnerMintExtension_init();
        __ERC721OneOfOneMintExtension_init();
        __ERC721AutoIdMinterExtension_init(config.maxSupply);
        __ERC721RoyaltyExtension_init(
            config.defaultRoyaltyAddress,
            config.defaultRoyaltyBps
        );
        __ERC2771ContextOwnable_init(config.trustedForwarder);
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721, ERC721OneOfOneMintExtension, ERC721URIStorage)
    {
        return ERC721OneOfOneMintExtension._burn(tokenId);
    }

    function _msgSender()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (address sender)
    {
        return super._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ERC2771ContextOwnable, Context)
        returns (bytes calldata)
    {
        return super._msgData();
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(
            ERC165Storage,
            ERC721OwnerMintExtension,
            ERC721OneOfOneMintExtension,
            ERC721PerTokenMetadataExtension,
            ERC721RoyaltyExtension,
            LicenseExtension
        )
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function name()
        public
        view
        override(
            ERC721,
            ERC721OneOfOneMintExtension,
            ERC721CollectionMetadataExtension
        )
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.name();
    }

    function symbol()
        public
        view
        override(
            ERC721,
            ERC721OneOfOneMintExtension,
            ERC721CollectionMetadataExtension
        )
        returns (string memory)
    {
        return ERC721CollectionMetadataExtension.symbol();
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        virtual
        override(ERC721, ERC721OneOfOneMintExtension, ERC721URIStorage)
        returns (string memory)
    {
        return ERC721OneOfOneMintExtension.tokenURI(_tokenId);
    }

    function getInfo()
        external
        view
        returns (
            uint256 _maxSupply,
            uint256 _totalSupply,
            uint256 _senderBalance
        )
    {
        uint256 balance = 0;

        if (_msgSender() != address(0)) {
            balance = this.balanceOf(_msgSender());
        }

        return (maxSupply, this.totalSupply(), balance);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ERC20BasicToken is
    Initializable,
    ERC20,
    ERC20Burnable,
    Pausable,
    AccessControl
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _name;
    string private _symbol;

    struct Config {
        string name;
        string symbol;
    }

    constructor(Config memory config) ERC20(config.name, config.symbol) {
        initialize(config, msg.sender);
    }

    function initialize(Config memory config, address deployer)
        public
        initializer
    {
        _name = config.name;
        _symbol = config.symbol;

        _grantRole(DEFAULT_ADMIN_ROLE, deployer);
        _grantRole(PAUSER_ROLE, deployer);
        _grantRole(MINTER_ROLE, deployer);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../common/WithdrawExtension.sol";
import "./Clones.sol";
import "./MinimalProxy.sol";

contract FlairFactoryNewable is Initializable, Ownable, WithdrawExtension {
    event ProxyCreated(address indexed deployer, address indexed proxyAddress);

    constructor() {
        initialize();
    }

    function initialize() public initializer {
        __WithdrawExtension_init(_msgSender(), WithdrawMode.OWNER);
    }

    function cloneDeterministicSimple(
        address implementation,
        bytes32 salt,
        bytes calldata data
    ) external payable returns (address deployedProxy) {
        MinimalProxy p = new MinimalProxy{salt: salt}(implementation);
        deployedProxy = address(p);

        if (data.length > 0) {
            (bool success, bytes memory returndata) = deployedProxy.call(data);

            if (!success) {
                // Look for revert reason and bubble it up if present
                if (returndata.length > 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly
                    assembly {
                        let returndata_size := mload(returndata)
                        revert(add(32, returndata), returndata_size)
                    }
                } else {
                    revert("FAILED_TO_CLONE");
                }
            }
        }

        emit ProxyCreated(msg.sender, address(deployedProxy));
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

library Clones {
    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create opcode, which should never revert.
     */
    function clone(address implementation) internal returns (address instance) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create(0, ptr, 0x37)
        }
        require(instance != address(0), "ERC1167: create failed");
    }

    /**
     * @dev Deploys and returns the address of a clone that mimics the behaviour of `implementation`.
     *
     * This function uses the create2 opcode and a `salt` to deterministically deploy
     * the clone. Using the same `implementation` and `salt` multiple time will revert, since
     * the clones cannot be deployed twice at the same address.
     */
    function cloneDeterministic(address implementation, bytes32 salt)
        internal
        returns (address instance)
    {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create2(0, ptr, 0x37, salt)
        }
        require(instance != address(0), "ERC1167: create2 failed");
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(
        address implementation,
        bytes32 salt,
        address deployer
    ) internal pure returns (address predicted) {
        /// @solidity memory-safe-assembly
        assembly {
            let ptr := mload(0x40)
            mstore(
                ptr,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(ptr, 0x14), shl(0x60, implementation))
            mstore(
                add(ptr, 0x28),
                0x5af43d82803e903d91602b57fd5bf3ff00000000000000000000000000000000
            )
            mstore(add(ptr, 0x38), shl(0x60, deployer))
            mstore(add(ptr, 0x4c), salt)
            mstore(add(ptr, 0x6c), keccak256(ptr, 0x37))
            predicted := keccak256(add(ptr, 0x37), 0x55)
        }
    }

    /**
     * @dev Computes the address of a clone deployed using {Clones-cloneDeterministic}.
     */
    function predictDeterministicAddress(address implementation, bytes32 salt)
        internal
        view
        returns (address predicted)
    {
        return predictDeterministicAddress(implementation, salt, address(this));
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/Proxy.sol";
import "@openzeppelin/contracts/utils/StorageSlot.sol";

contract MinimalProxy is Proxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    constructor(address _impl) payable {
        StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value = _impl;
    }

    function _implementation() internal view override returns (address) {
        return StorageSlot.getAddressSlot(_IMPLEMENTATION_SLOT).value;
    }
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
library StorageSlot {
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
// OpenZeppelin Contracts (last updated v4.6.0) (proxy/Proxy.sol)

pragma solidity ^0.8.0;

/**
 * @dev This abstract contract provides a fallback function that delegates all calls to another contract using the EVM
 * instruction `delegatecall`. We refer to the second contract as the _implementation_ behind the proxy, and it has to
 * be specified by overriding the virtual {_implementation} function.
 *
 * Additionally, delegation to the implementation can be triggered manually through the {_fallback} function, or to a
 * different contract through the {_delegate} function.
 *
 * The success and return data of the delegated call will be returned back to the caller of the proxy.
 */
abstract contract Proxy {
    /**
     * @dev Delegates the current call to `implementation`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _delegate(address implementation) internal virtual {
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

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
        }
    }

    /**
     * @dev This is a virtual function that should be overridden so it returns the address to which the fallback function
     * and {_fallback} should delegate.
     */
    function _implementation() internal view virtual returns (address);

    /**
     * @dev Delegates the current call to the address returned by `_implementation()`.
     *
     * This function does not return to its internal call site, it will return directly to the external caller.
     */
    function _fallback() internal virtual {
        _beforeFallback();
        _delegate(_implementation());
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if no other
     * function in the contract matches the call data.
     */
    fallback() external payable virtual {
        _fallback();
    }

    /**
     * @dev Fallback function that delegates calls to the address returned by `_implementation()`. Will run if call data
     * is empty.
     */
    receive() external payable virtual {
        _fallback();
    }

    /**
     * @dev Hook that is called before falling back to the implementation. Can happen as part of a manual `_fallback`
     * call, or as part of the Solidity `fallback` or `receive` functions.
     *
     * If overridden should call `super._beforeFallback()`.
     */
    function _beforeFallback() internal virtual {}
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../common/WithdrawExtension.sol";
import "./Clones.sol";

contract FlairFactory is Initializable, Ownable, WithdrawExtension {
    event ProxyCreated(address indexed deployer, address indexed proxyAddress);

    constructor() {
        initialize();
    }

    function initialize() public initializer {
        __WithdrawExtension_init(_msgSender(), WithdrawMode.OWNER);
    }

    function cloneDeterministicSimple(
        address implementation,
        bytes32 salt,
        bytes calldata data
    ) external payable returns (address deployedProxy) {
        bytes32 _salt = keccak256(abi.encodePacked(msg.sender, salt));
        deployedProxy = Clones.cloneDeterministic(implementation, _salt);

        if (data.length > 0) {
            (bool success, bytes memory returndata) = deployedProxy.call(data);

            if (!success) {
                // Look for revert reason and bubble it up if present
                if (returndata.length > 0) {
                    // The easiest way to bubble the revert reason is using memory via assembly
                    assembly {
                        let returndata_size := mload(returndata)
                        revert(add(32, returndata), returndata_size)
                    }
                } else {
                    revert("FAILED_TO_CLONE");
                }
            }
        }

        emit ProxyCreated(msg.sender, deployedProxy);
    }

    function predictDeterministicSimple(address implementation, bytes32 salt)
        external
        view
        returns (address deployedProxy)
    {
        bytes32 _salt = keccak256(abi.encodePacked(msg.sender, salt));
        deployedProxy = Clones.predictDeterministicAddress(
            implementation,
            _salt
        );
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AMinterExtension.sol";

import {IERC721FreeMintExtension} from "../../ERC721/extensions/ERC721FreeMintExtension.sol";

/**
 * @dev Extension to allow anyone to mint directly without paying.
 */
abstract contract ERC721AFreeMintExtension is
    IERC721FreeMintExtension,
    Initializable,
    ERC165Storage,
    ERC721AMinterExtension
{
    function __ERC721AFreeMintExtension_init() internal onlyInitializing {
        __ERC721AFreeMintExtension_init_unchained();
    }

    function __ERC721AFreeMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721FreeMintExtension).interfaceId);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721ACollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function mintFree(address to, uint256 count) external {
        _mintTo(to, count);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";

import "./ERC721AutoIdMinterExtension.sol";

interface IERC721FreeMintExtension {
    function mintFree(address to, uint256 count) external;
}

/**
 * @dev Extension to allow anyone to mint directly without paying.
 */
abstract contract ERC721FreeMintExtension is
    IERC721FreeMintExtension,
    Initializable,
    ERC165Storage,
    ERC721AutoIdMinterExtension
{
    function __ERC721FreeMintExtension_init() internal onlyInitializing {
        __ERC721FreeMintExtension_init_unchained();
    }

    function __ERC721FreeMintExtension_init_unchained()
        internal
        onlyInitializing
    {
        _registerInterface(type(IERC721FreeMintExtension).interfaceId);
    }

    /* PUBLIC */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165Storage, ERC721CollectionMetadataExtension)
        returns (bool)
    {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function mintFree(address to, uint256 count) external {
        _mintTo(to, count);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20("FlairTest", "FTS") {
    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// SPDX-License-Identifier: AGPL-3.0

pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TestERC721 is ERC721("FlairTest", "FTS"), ERC721Enumerable {
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        return super._beforeTokenTransfer(from, to, tokenId);
    }

    function mintExact(address to, uint256 tokenId) public returns (bool) {
        _mint(to, tokenId);
        return true;
    }

    function mintBulk(address to, uint256 total) public returns (bool) {
        for (uint256 i = 0; i < total; i++) {
            _mint(to, totalSupply());
        }
        return true;
    }
}

// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}