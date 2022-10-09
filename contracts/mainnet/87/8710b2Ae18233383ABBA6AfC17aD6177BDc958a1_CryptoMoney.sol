/**
 *Submitted for verification at Optimistic.Etherscan.io on 2022-10-09
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


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


error CryptoMoney__NotApproved();
error CryptoMoney__TransferFailed();
error CryptoMoney__CodeHashNotEmpty();
error CryptoMoney__FeeNotMet();
error CryptoMoney__InvalidCode();
error CryptoMoney__InvalidWord();
error CryptoMoney__NoFeesToWithdraw();

// @title A sample Crypto Money Contract
// @author Jason Chaskin, Sebastian Coronel, & Carlos Vera
// @notice This contract is for creating a sample Crypto Money Contract

contract CryptoMoney is Ownable {
    ///////////////////////
    // Storage Variables //
    ///////////////////////

    IERC20 private s_daiContract;
    uint256 private s_feeInWeiPerBill;
    uint256 private s_requestId;
    mapping(uint256 => Request) private s_requestIdToRequest;
    uint256 private s_nextBillId;
    Bill[] private s_bills;

    //////////////
    // Structs //
    //////////////

    struct Request {
        uint256 amountPerBill;
        uint256 billCount;
        bool isIssued;
        address requester;
    }

    struct Bill {
        uint256 id;
        uint256 value;
        bytes32 wordHash;
        bytes32 codeHash;
        bool isFunded;
        bool isRedeemed;
    }

    /////////////
    // Events //
    ////////////

    event NewRequest(
        uint256 indexed requestId,
        address indexed requester,
        uint256 amountPerBill,
        uint256 billCount
    );
    event BillIssued(uint256 indexed billId, uint256 value);
    event BillFunded(
        uint256 indexed billId,
        address indexed funder,
        uint256 value
    );
    event BillRedeemed(
        uint256 indexed billId,
        address indexed redeemer,
        uint256 value
    );

    constructor(uint256 feePerBill, address daiContractAddress) {
        s_feeInWeiPerBill = feePerBill;
        s_daiContract = IERC20(daiContractAddress);
        s_nextBillId = 1;
    }

    ///////////////
    // Functions //
    ///////////////

    // @notice Accepts payment for physical paper bills, creates a pending request object containing the amount per bills,
    // number of bills requested, is issued boolean set to false, and the address of the requester. Iterates request Id
    // @param amountPerBill The amount the requester requests each bill will be worth in DAI
    // @param billCount The total number of bills requested

    function requestBills(uint256 amountPerBill, uint256 billCount)
        external
        payable
    {
        if (s_feeInWeiPerBill * billCount > msg.value) {
            revert CryptoMoney__FeeNotMet();
        }
        s_requestIdToRequest[s_requestId] = Request(
            amountPerBill,
            billCount,
            false,
            msg.sender
        );
        emit NewRequest(s_requestId, msg.sender, amountPerBill, billCount);
        s_requestId++;
    }

    // @notice Issues new physical bills, bill objects are created containing the bill id, amount pulled from the request object,
    // a blank word hash (this gets updated by the funder when bill is funded), the keccak256 hash of a secret code, and
    // is funded and is redeemed are both set to false
    // @param requestId The request id is used to retrieve the request
    // @param codeHash Bills are created with the keccak256 hash of a secret code, this code is hidden on the paper money

    function issueBills(uint256 requestId, bytes[] calldata codeHash)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < codeHash.length; i++) {
            Request memory request = s_requestIdToRequest[requestId];
            s_bills.push(
                Bill(
                    s_nextBillId,
                    request.amountPerBill,
                    "",
                    bytes32(codeHash[i]),
                    false,
                    false
                )
            );
            emit BillIssued(s_nextBillId, request.amountPerBill);
            s_nextBillId++;
        }
        s_requestIdToRequest[requestId].isIssued = true;
    
    }

    // @notice The buyer of the paper bills funds them with DAI by scanning the QR code on the bill and calling this function.
    // Function makes sure that DAI is approved to be spent by the contract for the value stored in the bill object.
    // The buyer inputs a code, which is hashed on the frontend, this is the code hash that's inputted into the function.
    // In the bill object, the code hash is updated with inputted code hash and is funded is updated to true. DAI is transfered to this contract.
    // The buyer finally writes the code word on the physical bill
    // @param billId The bill Id id is used to retrieve the bill
    // @param amount The amount of DAI being funded
    // @param wodeHash bills are created with the keccak256 hash of a secret code, this code is hidden on the paper money

    function fund(
        uint256 billId,
        uint256 amount,
        bytes calldata wordHash
    ) external {
        Bill memory bill = s_bills[billId - 1];
        IERC20 daiContract = s_daiContract;
        if (daiContract.allowance(msg.sender, address(this)) < bill.value) {
            revert CryptoMoney__NotApproved();
        }
        s_bills[billId - 1].wordHash = bytes32(wordHash);
        s_bills[billId - 1].isFunded = true;
        daiContract.transferFrom(
            msg.sender,
            address(this),
            bill.value
        );
        emit BillFunded(billId - 1, msg.sender, amount);
    }

    // @notice The redeemer reveals the secret code which has been hidden on the paper bill and inputs it, the bill id, and the secret word which was pyhsically
    // written onto the bill into this function. It then checks to make sure both the hash of the word and code equal the hashes stored in the bill object
    // is redeemed is udpated on the bill object to be true and the DAI is transfered to the redeem address
    // @param billId The bill id that is attempted to be redeemed
    // @param code The secret code which was revealed on the physical bill
    // @param word the secret word which is written on the physical bill
    // @param redeem address is the address which receives the funds

    function redeem(
        uint256 billId,
        string memory code,
        string memory word,
        address redeemAddress
    ) external {
        Bill memory bill = s_bills[billId - 1];
        bytes32 testCodeHash = keccak256((abi.encodePacked(bill.codeHash)));
        bytes32 testCode = keccak256(abi.encodePacked(keccak256((abi.encodePacked(code)))));
        if (testCodeHash != testCode) {
                revert CryptoMoney__InvalidCode();
        }
        bytes32 testWordHash = keccak256((abi.encodePacked(bill.wordHash)));
        bytes32 testWord = keccak256(abi.encodePacked(keccak256((abi.encodePacked(word)))));
        if (testWordHash != testWord) {
                revert CryptoMoney__InvalidWord();
        }
        uint256 redeemValue = bill.value;
        s_bills[billId - 1].value = 0;
        s_bills[billId - 1].isRedeemed = true;
        s_daiContract.transfer(redeemAddress, redeemValue);
        emit BillRedeemed((billId - 1), redeemAddress, redeemValue);
    }

    function verifyWord(uint256 billId, string memory word) external view returns (bool) {    
        bytes32 testWordHash = keccak256((abi.encodePacked(s_bills[billId - 1].wordHash)));
        bytes32 testWord = keccak256(abi.encodePacked(keccak256((abi.encodePacked(word)))));
        if (testWordHash == testWord) {
            return true;
        } else {
            return false;
        }
    }

    function updateFee(uint256 updatedFee) external onlyOwner {
        s_feeInWeiPerBill = updatedFee;
    }

    function claimFees() external onlyOwner {
        if (address(this).balance == 0) {
            revert CryptoMoney__NoFeesToWithdraw();
        }
        (bool success, ) = payable(msg.sender).call{
            value: address(this).balance
        }("");
        if (!success) {
            revert CryptoMoney__TransferFailed();
        }
    }

    /////////////////////
    // View Functions //
    ////////////////////

    function getDaiContract() external view returns (IERC20) {
        return s_daiContract;
    }

    function getFeePerBill() external view returns (uint256) {
        return s_feeInWeiPerBill;
    }

    function getNextRequestId() external view returns (uint256) {
        return s_requestId;
    }

    function getOneRequest(uint256 requestId)
        external
        view
        returns (Request memory)
    {
        return s_requestIdToRequest[requestId];
    }

    function getNextBillId() external view returns (uint256) {
        return s_nextBillId;
    }

    function getOneBillFromBillId(uint256 billId)
        external
        view
        returns (Bill memory)
    {
        return s_bills[billId - 1];
    }
}