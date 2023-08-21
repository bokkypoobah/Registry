pragma solidity ^0.8.19;

// ----------------------------------------------------------------------------
// Registry v0.8.9d-testing
//
// Deployed to Sepolia
// - Registry
// - Receiver
//
// https://github.com/bokkypoobah/Registry
//
// SPDX-License-Identifier: MIT
//
// If you earn fees using your deployment of this code, or derivatives of this
// code, please send a proportionate amount to bokkypoobah.eth .
// Don't be stingy! Donations welcome!
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

interface ReceiverInterface {
    function registry() external view returns (RegistryInterface);
}

interface RegistryInterface {
    struct CollectionResult {
        string name;
        string description;
        address owner;
        ReceiverInterface receiver;
        bool locked; // ? LOCK_NAME, LOCK_DESCRIPTION, LOCK_ADDITEMS, ??LOCK_REMOVEITEMS
        uint64 items;
        uint64 created;
    }
    struct Result {
        bytes32 hash;
        uint collectionId;
        address owner;
        uint created;
    }
    function getReceiver(uint i) external view returns (ReceiverInterface);
    function register(bytes32 hash, address msgSender) external returns (bytes memory output);
    function ownerOf(uint tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transfer(address to, uint tokenId) external;
    function itemsLength() external view returns (uint);
    function collectionsLength() external view returns (uint);
    function getData(uint count, uint offset) external view returns (Result[] memory results);
}

function onePlus(uint x) pure returns (uint) {
    unchecked { return 1 + x; }
}


/// @title Receiver
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Receiver is ReceiverInterface {
    RegistryInterface private immutable _registry;

    constructor() {
        _registry = Registry(msg.sender);
    }
    function registry() external view returns (RegistryInterface) {
        return _registry;
    }

    /// @dev Fallback function so tx.data = payload
    /// @param input tx.data payload
    /// @return output TokenId, sequential from 0
    fallback(bytes calldata input) external returns (bytes memory output) {
        return _registry.register(keccak256(abi.encodePacked(input)), msg.sender);
    }
}


contract Utilities {
    uint private constant MAXNAMELENGTH = 48;
    bytes1 private constant SPACE = 0x20;
    bytes1 private constant TILDE = 0x7e;

    /// @dev Is name valid? Length between 1 and `MAXNAMELENGTH`. Characters between SPACE and TILDE inclusive. No leading, trailing or repeating SPACEs
    /// @param str Name to check
    /// @return True if valid
    function isValidName(string memory str) public pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1 || b.length > MAXNAMELENGTH) {
            return false;
        }
        if (b[0] == SPACE || b[b.length-1] == SPACE) {
            return false;
        }
        bytes1 lastChar = b[0];
        for (uint i; i < b.length; i = onePlus(i)) {
            bytes1 char = b[i];
            if (char == SPACE && lastChar == SPACE) {
                return false;
            }
            if (!(char >= SPACE && char <= TILDE)) {
                return false;
            }
            lastChar = char;
        }
        return true;
    }
}


/// @title Registry of hashes of data with sequential tokenIds with transferable ownership
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Registry is RegistryInterface, Utilities {
    struct Collection {
        string name;
        string description;
        address owner;
        ReceiverInterface receiver;
        // string tokenUriPrefix;
        // string tokenUriPostfix;
        bool locked;
        uint64 collectionId;
        uint64 items;
        uint64 created;
    }
    struct Data {
        address owner;
        uint64 collectionId;
        uint64 tokenId;
        uint64 created;
    }

    // Array of collection receivers
    ReceiverInterface[] public receivers;
    // collection receiver => [name, description, owner, ...]
    mapping(ReceiverInterface => Collection) collectionData;
    // collection name hash => true
    mapping(bytes32 => bool) collectionNameCheck;

    // Array of unique data hashes
    bytes32[] public hashes;
    // data hash => [owner, tokenId, created]
    mapping(bytes32 => Data) public data;
    // owner => operator => approved?
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /// @dev New `hash` has been registered with `tokenId` under `collection` by `owner` at `timestamp`
    event Registered(uint indexed tokenId, bytes32 indexed hash, address indexed collection, address owner, uint timestamp);
    /// @dev `tokenId` has been transferred from `from` to `to` at `timestamp`
    event Transfer(address indexed from, address indexed to, uint indexed tokenId, uint timestamp);
    /// @dev `owner` has `approved` for `operator` to manage all of its assets at `timestamp`
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, uint timestamp);

    error InvalidCollectionName();
    error DuplicateCollectionName();
    error NotOwner();
    error Locked();
    error InvalidCollection();
    error AlreadyRegistered(bytes32 hash, address owner, uint tokenId, uint created);
    error CannotApproveSelf();
    error InvalidTokenId();
    error NotOwnerNorApproved(address owner, uint tokenId);

    constructor() {
        _newCollection("", "", false);
    }

    /// @dev Receiver address
    function getReceiver(uint i) external view returns (ReceiverInterface) {
        return receivers[i];
    }

    function _newCollection(string memory name, string memory description, bool locked) internal returns (uint) {
        Receiver receiver = new Receiver();
        collectionData[receiver] = Collection(name, description, address(msg.sender), receiver, locked, uint64(receivers.length), 0, uint64(block.timestamp));
        receivers.push(receiver);
        return receivers.length - 1;
    }

    /// @dev Only {receiver} can register `hash` on behalf of `msgSender`
    /// @return _collectionId New collection id
    function newCollection(string calldata name, string calldata description) external returns (uint /*_collectionId*/) {
        if (!isValidName(name)) {
            revert InvalidCollectionName();
        }
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (collectionNameCheck[nameHash]) {
            revert DuplicateCollectionName();
        }
        collectionNameCheck[nameHash] = true;
        return _newCollection(name, description, false);
    }

    /// @dev Lock {collectionId}. Can only be executed by collection owner
    function lockCollection(uint collectionId) external {
        // ReceiverInterface receiver = receivers[collectionId];
        Collection storage c = collectionData[receivers[collectionId]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        if (!c.locked) {
            revert Locked();
        }
        c.locked = true;
    }

    /// @dev Only {receiver} can register `hash` on behalf of `msgSender`
    /// @return output Token Id encoded as bytes
    function register(bytes32 hash, address msgSender) external returns (bytes memory output) {
        Collection storage c = collectionData[Receiver(msg.sender)];
        // ~ USD 1.00 to get here. Note cost ~ USD 0.80 to write 256 bits
        if (c.created == 0) {
            revert InvalidCollection();
        }
        if (c.collectionId > 0) {
            hash = keccak256(abi.encodePacked(c.name, hash));
        }
        Data memory d = data[hash];
        bool burnt = false;
        if (d.owner != address(0)) {
            revert AlreadyRegistered(hash, d.owner, d.tokenId, d.created);
        } else if (d.created != 0) {
            burnt = true;
        }
        // ~ USD 1.36 to get here
        c.items++;
        // ~USD 1.49 to get here
        data[hash] = Data(msgSender, c.collectionId, uint64(hashes.length), uint64(block.timestamp));
        // ~USD 3.21 to get here
        emit Registered(hashes.length, hash, msg.sender, msgSender, block.timestamp);
        // ~USD 3.34 to get here
        output = bytes.concat(bytes32(hashes.length));
        if (!burnt) {
            // 85,087 ~USD 3.36 to get here
            hashes.push(hash);
            // 126,349 ~USD 5.05 to get here; 109,471 ~USD 4.37 for second item
        }
    }

    /// @dev Returns the owner of `tokenId`
    function ownerOf(uint tokenId) external view returns (address) {
        return data[hashes[tokenId]].owner;
    }

    /// @dev Approve or remove `operator` to execute {transfer} on the caller's tokens
    function setApprovalForAll(address operator, bool approved) external {
        if (operator == msg.sender) {
            revert CannotApproveSelf();
        }
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved, block.timestamp);
    }

    /// @dev Is `operator` allowed to manage all of the assets of `owner`?
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /// @dev Is `spender` is allowed to manage `tokenId`?
    function _isApprovedOrOwner(address spender, uint tokenId) internal view returns (bool) {
        address owner = data[hashes[tokenId]].owner;
        if (owner == address(0)) {
            revert InvalidTokenId();
        }
        return (spender == owner || isApprovedForAll(owner, spender));
    }

    /// @dev Transfer `tokenId` to `to`
    /// @param to New owner
    /// @param tokenId Token Id
    function transfer(address to, uint tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotOwnerNorApproved(msg.sender, tokenId);
        }
        bytes32 hash = hashes[tokenId];
        address from = data[hash].owner;
        data[hash].owner = to;
        emit Transfer(from, to, tokenId, block.timestamp);
    }


    /// @dev Number of collections
    function collectionsLength() external view returns (uint) {
        return receivers.length;
    }

    /// @dev Number of items
    function itemsLength() external view returns (uint) {
        return hashes.length;
    }

    function getCollections(uint count, uint offset) public view returns (CollectionResult[] memory results) {
        results = new CollectionResult[](count);
        for (uint i = 0; i < count && ((i + offset) < receivers.length); i = onePlus(i)) {
            ReceiverInterface receiver = receivers[i + offset];
            Collection memory c = collectionData[receiver];
            results[i] = CollectionResult(c.name, c.description, c.owner, receiver, c.locked, c.items, c.created);
        }
    }


    /// @dev Get `count` rows of data beginning at `offset`
    /// @param count Number of results
    /// @param offset Offset
    /// @return results [[hash, owner, created]]
    function getData(uint count, uint offset) public view returns (Result[] memory results) {
        results = new Result[](count);
        for (uint i = 0; i < count && ((i + offset) < hashes.length); i = onePlus(i)) {
            bytes32 hash = hashes[i + offset];
            Data memory d = data[hash];
            results[i] = Result(hash, d.collectionId, d.owner, uint(d.created));
        }
    }
}
