// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

/**
 * @title PolyList
 * @dev Registry For Poly Account Authorised user.
 */

interface AccountInterface {
    function isAuth(address _user) external view returns (bool);
}

contract Variables {
    // PolyIndex Address.
    address public immutable polyIndex;

    constructor(address _polyIndex) {
        polyIndex = _polyIndex;
    }

    // Poly Account Count.
    uint64 public accounts;
    // Poly Account ID (Poly Account Address => Account ID).
    mapping(address => uint64) public accountID;
    // Poly Account Address (Poly Account ID => Poly Account Address).
    mapping(uint64 => address) public accountAddr;

    // User Link (User Address => UserLink(Account ID of First and Last And Count of Poly Accounts)).
    mapping(address => UserLink) public userLink;
    // Linked List of Users (User Address => Poly Account ID => UserList(Previous and next Account ID)).
    mapping(address => mapping(uint64 => UserList)) public userList;

    struct UserLink {
        uint64 first;
        uint64 last;
        uint64 count;
    }

    struct UserList {
        uint64 prev;
        uint64 next;
    }

    // Account Link (Poly Account ID => AccountLink).
    mapping(uint64 => AccountLink) public accountLink; // account => account linked list connection
    // Linked List of Accounts (Poly Account ID => Account Address => AccountList).
    mapping(uint64 => mapping(address => AccountList)) public accountList; // account => user address => list

    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }

    struct AccountList {
        address prev;
        address next;
    }
}

contract Configure is Variables {
    constructor(address _polyIndex) Variables(_polyIndex) {}

    /**
     * @dev Add Account to User Linked List.
     * @param _owner Account Owner.
     * @param _account Poly Account Address.
     */
    function addAccount(address _owner, uint64 _account) internal {
        if (userLink[_owner].last != 0) {
            userList[_owner][_account].prev = userLink[_owner].last;
            userList[_owner][userLink[_owner].last].next = _account;
        }
        if (userLink[_owner].first == 0) userLink[_owner].first = _account;
        userLink[_owner].last = _account;
        userLink[_owner].count = userLink[_owner].count + 1;
    }

    /**
     * @dev Remove Account from User Linked List.
     * @param _owner Account Owner/User.
     * @param _account Poly Account Address.
     */
    function removeAccount(address _owner, uint64 _account) internal {
        uint64 _prev = userList[_owner][_account].prev;
        uint64 _next = userList[_owner][_account].next;
        if (_prev != 0) userList[_owner][_prev].next = _next;
        if (_next != 0) userList[_owner][_next].prev = _prev;
        if (_prev == 0) userLink[_owner].first = _next;
        if (_next == 0) userLink[_owner].last = _prev;
        userLink[_owner].count = userLink[_owner].count - 1;
        delete userList[_owner][_account];
    }

    /**
     * @dev Add Owner to Account Linked List.
     * @param _owner Account Owner.
     * @param _account Poly Account Address.
     */
    function addUser(address _owner, uint64 _account) internal {
        if (accountLink[_account].last != address(0)) {
            accountList[_account][_owner].prev = accountLink[_account].last;
            accountList[_account][accountLink[_account].last].next = _owner;
        }
        if (accountLink[_account].first == address(0)) accountLink[_account].first = _owner;
        accountLink[_account].last = _owner;
        accountLink[_account].count = accountLink[_account].count + 1;
    }

    /**
     * @dev Remove Owner from Account Linked List.
     * @param _owner Account Owner.
     * @param _account Poly Account Address.
     */
    function removeUser(address _owner, uint64 _account) internal {
        address _prev = accountList[_account][_owner].prev;
        address _next = accountList[_account][_owner].next;
        if (_prev != address(0)) accountList[_account][_prev].next = _next;
        if (_next != address(0)) accountList[_account][_next].prev = _prev;
        if (_prev == address(0)) accountLink[_account].first = _next;
        if (_next == address(0)) accountLink[_account].last = _prev;
        accountLink[_account].count = accountLink[_account].count - 1;
        delete accountList[_account][_owner];
    }
}

contract PolyList is Configure {
    constructor(address _polyIndex) Configure(_polyIndex) {}

    /**
     * @dev Enable Auth for Poly Account.
     * @param _owner Owner Address.
     */
    function addAuth(address _owner) external {
        require(accountID[msg.sender] != 0, "not-account");
        require(AccountInterface(msg.sender).isAuth(_owner), "not-owner");
        addAccount(_owner, accountID[msg.sender]);
        addUser(_owner, accountID[msg.sender]);
    }

    /**
     * @dev Disable Auth for Poly Account.
     * @param _owner Owner Address.
     */
    function removeAuth(address _owner) external {
        require(accountID[msg.sender] != 0, "not-account");
        require(!AccountInterface(msg.sender).isAuth(_owner), "already-owner");
        removeAccount(_owner, accountID[msg.sender]);
        removeUser(_owner, accountID[msg.sender]);
    }

    /**
     * @dev Setup Initial configuration of Poly Account.
     * @param _account Poly Account Address.
     */
    function init(address _account) external {
        require(msg.sender == polyIndex, "not-index");
        accounts++;
        accountID[_account] = accounts;
        accountAddr[accounts] = _account;
    }
}