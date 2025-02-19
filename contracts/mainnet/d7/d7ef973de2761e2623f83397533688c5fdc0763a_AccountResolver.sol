// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface AccountInterface {
    function isAuth(address user) external view returns (bool);
    function sheild() external view returns (bool);
    function version() external view returns (uint256);
}

interface ListInterface {
    struct UserLink {
        uint64 first;
        uint64 last;
        uint64 count;
    }

    struct UserList {
        uint64 prev;
        uint64 next;
    }

    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }

    struct AccountList {
        address prev;
        address next;
    }

    function accounts() external view returns (uint256);
    function accountID(address) external view returns (uint64);
    function accountAddr(uint64) external view returns (address);
    function userLink(address) external view returns (UserLink memory);
    function userList(address, uint64) external view returns (UserList memory);
    function accountLink(uint64) external view returns (AccountLink memory);
    function accountList(uint64, address) external view returns (AccountList memory);
}

interface IndexInterface {
    function master() external view returns (address);
    function list() external view returns (address);
    function connectors(uint256) external view returns (address);
    function account(uint256) external view returns (address);
    function check(uint256) external view returns (address);
    function versionCount() external view returns (uint256);
}

interface ConnectorsInterface {
    struct List {
        address prev;
        address next;
    }

    function chief(address) external view returns (bool);
    function connectors(address) external view returns (bool);
    function staticConnectors(address) external view returns (bool);

    function connectorArray(uint256) external view returns (address);
    function connectorLength() external view returns (uint256);
    function staticConnectorArray(uint256) external view returns (address);
    function staticConnectorLength() external view returns (uint256);
    function connectorCount() external view returns (uint256);

    function isConnector(address[] calldata _connectors) external view returns (bool isOk);
    function isStaticConnector(address[] calldata _connectors) external view returns (bool isOk);
}

interface ConnectorInterface {
    function name() external view returns (string memory);
}

interface GnosisFactoryInterface {
    function proxyRuntimeCode() external pure returns (bytes memory);
}

contract Helpers {
    address public index;
    address public list;
    IndexInterface indexContract;
    ListInterface listContract;

    GnosisFactoryInterface[] public gnosisFactoryContracts;

    function getContractCode(address _addr) public view returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
}

contract AccountResolver is Helpers {
    constructor(address _index) {
        index = _index;
        indexContract = IndexInterface(index);
        list = indexContract.list();
        listContract = ListInterface(list);
    }

    function getID(address account) public view returns (uint256 id) {
        return listContract.accountID(account);
    }

    function getAccount(uint64 id) public view returns (address account) {
        return listContract.accountAddr(uint64(id));
    }

    function getAuthorityIDs(address authority) public view returns (uint64[] memory) {
        ListInterface.UserLink memory userLink = listContract.userLink(authority);
        uint64[] memory IDs = new uint64[](userLink.count);
        uint64 id = userLink.first;
        for (uint256 i = 0; i < userLink.count; i++) {
            IDs[i] = id;
            ListInterface.UserList memory userList = listContract.userList(authority, id);
            id = userList.next;
        }
        return IDs;
    }

    function getAuthorityAccounts(address authority) public view returns (address[] memory) {
        uint64[] memory IDs = getAuthorityIDs(authority);
        address[] memory accounts = new address[](IDs.length);
        for (uint256 i = 0; i < IDs.length; i++) {
            accounts[i] = getAccount(IDs[i]);
        }
        return accounts;
    }

    function getIDAuthorities(uint256 id) public view returns (address[] memory) {
        ListInterface.AccountLink memory accountLink = listContract.accountLink(uint64(id));
        address[] memory authorities = new address[](accountLink.count);
        address authority = accountLink.first;
        for (uint256 i = 0; i < accountLink.count; i++) {
            authorities[i] = authority;
            ListInterface.AccountList memory accountList = listContract.accountList(uint64(id), authority);
            authority = accountList.next;
        }
        return authorities;
    }

    function getAccountAuthorities(address account) public view returns (address[] memory) {
        return getIDAuthorities(getID(account));
    }

    function getAccountVersions(address[] memory accounts) public view returns (uint256[] memory) {
        uint256[] memory versions = new uint[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            versions[i] = AccountInterface(accounts[i]).version();
        }
        return versions;
    }

    struct AuthorityData {
        uint64[] IDs;
        address[] accounts;
        uint256[] versions;
    }

    struct AccountData {
        uint256 ID;
        address account;
        uint256 version;
        address[] authorities;
    }

    function getAuthorityDetails(address authority) public view returns (AuthorityData memory) {
        address[] memory accounts = getAuthorityAccounts(authority);
        return AuthorityData(getAuthorityIDs(authority), accounts, getAccountVersions(accounts));
    }

    function getAccountIdDetails(uint256 id) public view returns (AccountData memory) {
        address account = getAccount(uint64(id));
        return AccountData(id, account, AccountInterface(account).version(), getIDAuthorities(id));
    }

    function getAccountDetails(address account) public view returns (AccountData memory) {
        uint256 id = getID(account);
        return AccountData(id, account, AccountInterface(account).version(), getIDAuthorities(id));
    }

    function isShield(address account) public view returns (bool shield) {
        shield = AccountInterface(account).sheild();
    }

    struct AuthType {
        address owner;
        uint256 authType;
    }

    function getAuthorityTypes(address[] memory authorities) public view returns (AuthType[] memory) {
        AuthType[] memory types = new AuthType[](authorities.length);
        for (uint256 i = 0; i < authorities.length; i++) {
            bytes memory _contractCode = getContractCode(authorities[i]);
            bool isSafe;
            for (uint256 k = 0; k < gnosisFactoryContracts.length; k++) {
                bytes memory multiSigCode = gnosisFactoryContracts[k].proxyRuntimeCode();
                if (keccak256(abi.encode(multiSigCode)) == keccak256(abi.encode(_contractCode))) {
                    isSafe = true;
                }
            }
            if (isSafe) {
                types[i] = AuthType({owner: authorities[i], authType: 1});
            } else {
                types[i] = AuthType({owner: authorities[i], authType: 0});
            }
        }
        return types;
    }

    function getAccountAuthoritiesTypes(address account) public view returns (AuthType[] memory) {
        return getAuthorityTypes(getAccountAuthorities(account));
    }
}