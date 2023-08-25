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

// type Account is address;
type BasisPoint is uint64; // 10 bps = 0.1%
type Counter is uint64;
type Fuse is uint64;
type Id is uint64;
type Unixtime is uint64;

Fuse constant FUSE_OWNER_CAN_UPDATE_DESCRIPTION = Fuse.wrap(0x01); // DESCRIPT DESCR
Fuse constant FUSE_OWNER_CAN_UPDATE_ROYALTIES = Fuse.wrap(0x02); // ROYALTIES ROYAL
Fuse constant FUSE_OWNER_CAN_BURN_USER_ITEM = Fuse.wrap(0x04); // OWNERBURN OBURN
Fuse constant FUSE_OWNER_CAN_MINT_ITEM = Fuse.wrap(0x08); // OWNERMINT OMINT
Fuse constant FUSE_MINTER_LIST_CAN_MINT_ITEM = Fuse.wrap(0x10); // MINTLIST MLIST
Fuse constant FUSE_ANY_USER_CAN_MINT_ITEM = Fuse.wrap(0x20); // ANY AUSER


interface ReceiverInterface {
    function registry() external view returns (RegistryInterface);
}

interface RegistryInterface {
    struct Royalty {
        address account;
        BasisPoint royalty;
    }
    struct Minter {
        address account;
        Counter count;
    }
    struct CollectionResult {
        string name;
        string description;
        address owner;
        ReceiverInterface receiver;
        Fuse fuses;
        Counter count;
        Unixtime created;
        Royalty[] royalties;
    }
    struct ItemResult {
        Id collectionId;
        bytes32 hash;
        address owner;
        Unixtime created;
    }

    function newCollection(string calldata name, string calldata description, Fuse fuse, Royalty[] memory royalties) external returns (Id _collectionId);
    function updateCollectionDescription(Id collectionId, string memory description) external;
    function updateCollectionRoyalties(Id collectionId, Royalty[] memory royalties) external;
    function updateCollectionMinters(Id collectionId, Minter[] calldata minterCounts) external;
    function burnCollectionToken(Id collectionId, Id tokenId) external;
    function burnFuses(Id collectionId, Fuse[] calldata fuse) external;

    function register(bytes32 hash, address msgSender) external returns (bytes memory output);

    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transfer(address to, Id tokenId) external;

    function collectionsCount() external view returns (uint);
    function itemsCount() external view returns (uint);
    function getReceiver(uint i) external view returns (ReceiverInterface receiver);
    function getCollectionId(Id tokenId) external view returns (Id collectionId);
    function getRoyalties(Id collectionId) external view returns (Royalty[] memory royalties);
    function ownerOf(Id tokenId) external view returns (address);
    function getCollections(uint count, uint offset) external view returns (CollectionResult[] memory results);
    function getItems(uint count, uint offset) external view returns (ItemResult[] memory results);

    /// @dev Collection `collectionid` description updated to `to` at `timestamp`
    event CollectionDescriptionUpdated(Id indexed collectionId, string description, Unixtime timestamp);
    /// @dev Collection `collectionid` royalties updated to `royalties` at `timestamp`
    event CollectionRoyaltiesUpdated(Id indexed collectionId, Royalty[] royalties, Unixtime timestamp);
    /// @dev Collection `collectionid` minters updated with `minters` at `timestamp`
    event CollectionMintersUpdated(Id indexed collectionId, Minter[] minterCounts, Unixtime timestamp);
    /// @dev Ownership of `collectionId` transferred from `from` to `to`
    event CollectionOwnershipTransferred(Id indexed collectionId, address indexed from, address indexed to, Unixtime timestamp);
    /// @dev New `hash` has been registered with `tokenId` under `collection` by `owner` at `timestamp`
    event Registered(Id indexed tokenId, Id indexed collectionId, bytes32 indexed hash, address owner, Unixtime timestamp);
    /// @dev `tokenId` has been transferred from `from` to `to` at `timestamp`
    event Transfer(address indexed from, address indexed to, Id indexed tokenId, Unixtime timestamp);
    /// @dev `owner` has `approved` for `operator` to manage all of its assets at `timestamp`
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, Unixtime timestamp);

    error MaxRoyaltyRecordsExceeded(uint maxRoyaltyRecords);
    error InvalidRoyalties();
    error InvalidCollectionName();
    error InvalidCollectionDescription();
    error InvalidFuses();
    error DuplicateCollectionName();
    error NotOwner();
    error Locked();
    error InvalidCollection();
    error AlreadyRegistered(bytes32 hash, address owner, Id tokenId, Unixtime created);
    error CannotApproveSelf();
    error InvalidTokenId();
    error NotOwnerNorApproved(address owner, Id tokenId);
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
    /// @return output Token Id, sequential from 0
    fallback(bytes calldata input) external returns (bytes memory output) {
        return _registry.register(keccak256(abi.encodePacked(input)), msg.sender);
    }
}


contract Utilities {
    uint private constant MAX_NAME_LENGTH = 64;
    uint private constant MAX_DESCRIPTION_LENGTH = 128;
    bytes1 private constant SPACE = 0x20;
    bytes1 private constant TILDE = 0x7e;

    /// @dev Is name valid? Length between 1 and `MAX_NAME_LENGTH`. Characters between SPACE and TILDE inclusive. No leading, trailing or repeating SPACEs
    /// @param str Name to check
    /// @return True if valid
    function _isValidName(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1 || b.length > MAX_NAME_LENGTH) {
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

    /// @dev Is description valid? Length between 0 and `MAX_DESCRIPTION_LENGTH`. No leading or trailing SPACEs
    /// @param str Description to check
    /// @return True if valid
    function _isValidDescription(string memory str) internal pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length > MAX_DESCRIPTION_LENGTH) {
            return false;
        }
        if (b[0] == SPACE || b[b.length-1] == SPACE) {
            return false;
        }
        return true;
    }
}


/// @title Registry of unique hashes of data assigned sequential tokenIds with transferable ownership
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Registry is RegistryInterface, Utilities {
    struct Collection {
        string name;
        string description;
        address owner;
        ReceiverInterface receiver;
        Fuse fuses;
        Id collectionId;
        Counter count;
        Unixtime created;
    }
    struct Data {
        address owner;
        Id collectionId;
        Id tokenId;
        Unixtime created;
    }

    uint private constant MAX_ROYALTY_RECORDS = 10;

    // Fuse private constant FUSE_OWNER_CAN_UPDATE_DESCRIPTION = Fuse.wrap(0x01);
    // Fuse private constant FUSE_OWNER_CAN_UPDATE_ROYALTIES = Fuse.wrap(0x02);
    // Fuse private constant FUSE_OWNER_CAN_BURN_USER_ITEM = Fuse.wrap(0x04);
    // Fuse private constant FUSE_OWNER_CAN_MINT_ITEM = Fuse.wrap(0x08);
    // Fuse private constant FUSE_MINTER_LIST_CAN_MINT_ITEM = Fuse.wrap(0x10);
    // Fuse private constant FUSE_ANY_USER_CAN_MINT_ITEM = Fuse.wrap(0x20);

    // Array of collection receivers
    ReceiverInterface[] public receivers;
    // collection receiver => [name, description, owner, ...]
    mapping(ReceiverInterface => Collection) collectionData;
    // collection name hash => true
    mapping(bytes32 => bool) collectionNameCheck;
    // TODO
    // collection id => Royalty[]
    mapping(Id => Royalty[]) private _royalties;
    // collection id => users => uint
    mapping(Id => mapping(address => uint)) collectionMinters;

    // Array of unique data hashes
    bytes32[] public hashes;
    // data hash => [owner, tokenId, created]
    mapping(bytes32 => Data) public data;
    // owner => operator => approved?
    mapping(address /* owner */ => mapping(address /* operator */ => bool /* approved */)) private _operatorApprovals;


    constructor() {
        _newCollection("", "", address(0), FUSE_ANY_USER_CAN_MINT_ITEM, new Royalty[](0));
    }

    function _newCollection(string memory name, string memory description, address owner, Fuse fuse, Royalty[] memory royalties) internal returns (Id _collectionId) {
        Receiver receiver = new Receiver();
        collectionData[receiver] = Collection(name, description, owner, receiver, fuse, Id.wrap(uint64(receivers.length)), Counter.wrap(0), Unixtime.wrap(uint64(block.timestamp)));
        receivers.push(receiver);
        _collectionId = Id.wrap(uint64(receivers.length - 1));
        if (royalties.length >= MAX_ROYALTY_RECORDS) {
            revert MaxRoyaltyRecordsExceeded(MAX_ROYALTY_RECORDS);
        }
        uint totalRoyalties;
        for (uint i = 0; i < royalties.length; i = onePlus(i)) {
            Royalty memory royalty = royalties[i];
            _royalties[_collectionId].push(Royalty(royalty.account, royalty.royalty));
            totalRoyalties += BasisPoint.unwrap(royalty.royalty);
        }
        if (totalRoyalties > 10_000) {
            revert InvalidRoyalties();
        }
        emit CollectionRoyaltiesUpdated(_collectionId, royalties, Unixtime.wrap(uint64(block.timestamp)));
    }

    function _isFuseSet(Fuse fuses, Fuse fuse) internal pure returns (bool) {
        return (Fuse.unwrap(fuses) & Fuse.unwrap(fuse)) == Fuse.unwrap(fuse);
    }
    function _isFuseBurnt(Fuse fuses, Fuse fuse) internal pure returns (bool) {
        return (Fuse.unwrap(fuses) & Fuse.unwrap(fuse)) != Fuse.unwrap(fuse);
    }
    // function _burnFuse(Fuse fuses, Fuse fuse) internal pure returns (bool) {
    //     return (Fuse.unwrap(fuses) & Fuse.unwrap(fuse)) == Fuse.unwrap(fuse);
    // }

    /// @dev Only {receiver} can register `hash` on behalf of `msgSender`
    /// @return _collectionId New collection id
    function newCollection(string calldata name, string calldata description, Fuse fuse, Royalty[] memory royalties) external returns (Id _collectionId) {
        if (!_isValidName(name)) {
            revert InvalidCollectionName();
        }
        if (!_isValidDescription(name)) {
            revert InvalidCollectionDescription();
        }
        // TODO
        // if ((lock & FUSE_USER_MINT_ITEM == FUSE_USER_MINT_ITEM) || (lock & FUSE_COLLECTION == FUSE_COLLECTION)) {
        //     revert InvalidFuses();
        // }
        bytes32 nameHash = keccak256(abi.encodePacked(name));
        if (collectionNameCheck[nameHash]) {
            revert DuplicateCollectionName();
        }
        collectionNameCheck[nameHash] = true;
        return _newCollection(name, description, address(msg.sender), fuse, royalties);
    }

    /// @dev Set description for {collectionId}. Can only be executed by collection owner
    /// @param collectionId Collection Id
    /// @param description Description
    function updateCollectionDescription(Id collectionId, string memory description) external {
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        if (!_isFuseSet(c.fuses, FUSE_OWNER_CAN_UPDATE_DESCRIPTION)) {
            revert Locked();
        }
        c.description = description;
        emit CollectionDescriptionUpdated(collectionId, description, Unixtime.wrap(uint64(block.timestamp)));
    }

    // TODO: Have a time delayed setting of Royalties
    /// @dev Set `royalties` for {collectionId}. Can only be executed by collection owner
    /// @param collectionId Collection Id
    /// @param royalties Royalties
    function updateCollectionRoyalties(Id collectionId, Royalty[] memory royalties) external {
        if (royalties.length >= MAX_ROYALTY_RECORDS) {
            revert MaxRoyaltyRecordsExceeded(MAX_ROYALTY_RECORDS);
        }
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        if (!_isFuseSet(c.fuses, FUSE_OWNER_CAN_UPDATE_ROYALTIES)) {
            revert Locked();
        }
        if (_royalties[collectionId].length > 0) {
            delete _royalties[collectionId];
        }
        for (uint i = 0; i < royalties.length; i = onePlus(i)) {
            Royalty memory royalty = royalties[i];
            _royalties[collectionId].push(Royalty(royalty.account, royalty.royalty));
        }
        emit CollectionRoyaltiesUpdated(collectionId, royalties, Unixtime.wrap(uint64(block.timestamp)));
    }


    /// @dev Update  `minterCounts` for `collectionId`. Can only be executed by collection owner
    /// @param collectionId Collection Id
    /// @param minterCounts Array of [[account, count]]
    function updateCollectionMinters(Id collectionId, Minter[] calldata minterCounts) external {
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        for (uint i = 0; i < minterCounts.length; i = onePlus(i)) {
            Minter memory mc = minterCounts[i];
            collectionMinters[c.collectionId][mc.account] = Counter.unwrap(mc.count);
        }
        emit CollectionMintersUpdated(collectionId, minterCounts, Unixtime.wrap(uint64(block.timestamp)));
    }


    // TODO: Wrong below
    /// @dev Lock {collectionId}. Can only be executed by collection owner
    function burnCollectionToken(Id collectionId, Id tokenId) external {
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        if (!_isFuseSet(c.fuses, FUSE_OWNER_CAN_BURN_USER_ITEM)) {
            revert Locked();
        }
        bytes32 hash = hashes[Id.unwrap(tokenId)];
        address from = data[hash].owner;
        if (Id.unwrap(collectionId) != Id.unwrap(data[hash].collectionId)) {
            revert NotOwner();
        }
        data[hash].owner = address(0x0);
        emit Transfer(from, address(0x0), tokenId, Unixtime.wrap(uint64(block.timestamp)));
    }


    /// @dev Burn fuses for {collectionId}. Can only be executed by collection owner
    function burnFuses(Id collectionId, Fuse[] calldata fuses) external {
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        // for (uint i = 0; i < inputs.length; i = onePlus(i)) {
        //     Fuse fuse = fuses[i];
        //     if (!_isFuseSet(c.fuses, fuse)) {
        //         revert Locked();
        //     }
        // }
        // TODO
        // if (c.lock == FUSE_COLLECTION) {
        //     revert Locked();
        // }
        // c.lock = uint64(lock);
    }


    function transferCollectionOwnership(Id collectionId, address newOwner) external {
        Collection storage c = collectionData[receivers[Id.unwrap(collectionId)]];
        if (c.owner != msg.sender) {
            revert NotOwner();
        }
        emit CollectionOwnershipTransferred(collectionId, c.owner, newOwner, Unixtime.wrap(uint64(block.timestamp)));
        c.owner = newOwner;
    }


    /// @dev Only {receiver} can register `hash` on behalf of `msgSender`
    /// @return output Token Id encoded as bytes
    function register(bytes32 hash, address msgSender) external returns (bytes memory output) {
        Collection storage c = collectionData[Receiver(msg.sender)];
        if (Unixtime.unwrap(c.created) == 0) {
            revert InvalidCollection();
        }
        if (Id.unwrap(c.collectionId) > 0) {
            hash = keccak256(abi.encodePacked(c.name, hash));
            // TODO
            // if ((c.lock & FUSE_USER_MINT_ITEM == FUSE_USER_MINT_ITEM) || (c.lock & FUSE_COLLECTION == FUSE_COLLECTION)) {
            //     revert Locked();
            // }
        }
        Data memory d = data[hash];
        bool burnt = false;
        if (d.owner != address(0)) {
            revert AlreadyRegistered(hash, d.owner, d.tokenId, d.created);
        } else if (Unixtime.unwrap(d.created) != 0) {
            burnt = true;
        }
        data[hash] = Data(msgSender, c.collectionId, Id.wrap(uint64(hashes.length)), Unixtime.wrap(uint64(block.timestamp)));
        emit Registered(Id.wrap(uint64(hashes.length)), c.collectionId, hash, msgSender, Unixtime.wrap(uint64(block.timestamp)));
        output = bytes.concat(bytes32(hashes.length));
        if (!burnt) {
            c.count = Counter.wrap(Counter.unwrap(c.count) + 1);
            hashes.push(hash);
        }
    }


    /// @dev Approve or remove `operator` to execute {transfer} on the caller's tokens
    function setApprovalForAll(address operator, bool approved) external {
        if (operator == msg.sender) {
            revert CannotApproveSelf();
        }
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved, Unixtime.wrap(uint64(block.timestamp)));
    }

    /// @dev Is `operator` allowed to manage all of the assets of `owner`?
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    /// @dev Is `spender` is allowed to manage `tokenId`?
    function _isApprovedOrOwner(address spender, Id tokenId) internal view returns (bool) {
        address owner = data[hashes[Id.unwrap(tokenId)]].owner;
        if (owner == address(0)) {
            revert InvalidTokenId();
        }
        return (spender == owner || isApprovedForAll(owner, spender));
    }

    /// @dev Transfer `tokenId` to `to`
    /// @param to New owner
    /// @param tokenId Token Id
    function transfer(address to, Id tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotOwnerNorApproved(msg.sender, tokenId);
        }
        bytes32 hash = hashes[Id.unwrap(tokenId)];
        address from = data[hash].owner;
        data[hash].owner = to;
        emit Transfer(from, to, tokenId, Unixtime.wrap(uint64(block.timestamp)));
    }


    /// @dev Number of collections
    function collectionsCount() external view returns (uint) {
        return receivers.length;
    }

    /// @dev Number of items
    function itemsCount() external view returns (uint) {
        return hashes.length;
    }

    /// @dev Receiver address
    function getReceiver(uint i) external view returns (ReceiverInterface) {
        return receivers[i];
    }

    /// @dev Returns the `collectionId` of `tokenId`
    /// @param tokenId Token Id
    /// @return collectionId Collection Id
    function getCollectionId(Id tokenId) external view returns (Id collectionId) {
        return data[hashes[Id.unwrap(tokenId)]].collectionId;
    }

    /// @dev Get royalties for `collectionId`
    /// @param collectionId Collection Id
    function getRoyalties(Id collectionId) external view returns (Royalty[] memory royalties) {
        return _royalties[collectionId];
    }

    /// @dev Returns the owner of `tokenId`
    /// @param tokenId Token Id
    /// @return owner Owner
    function ownerOf(Id tokenId) external view returns (address owner) {
        return data[hashes[Id.unwrap(tokenId)]].owner;
    }

    /// @dev Get `count` rows of data beginning at `offset`
    /// @param count Number of results
    /// @param offset Offset
    /// @return results
    function getCollections(uint count, uint offset) public view returns (CollectionResult[] memory results) {
        results = new CollectionResult[](count);
        for (uint i = 0; i < count && ((i + offset) < receivers.length); i = onePlus(i)) {
            ReceiverInterface receiver = receivers[i + offset];
            Collection memory c = collectionData[receiver];
            results[i] = CollectionResult(c.name, c.description, c.owner, receiver, c.fuses, c.count, c.created, _royalties[c.collectionId]);
        }
    }

    /// @dev Get `count` rows of data beginning at `offset`
    /// @param count Number of results
    /// @param offset Offset
    /// @return results [[hash, owner, created]]
    function getItems(uint count, uint offset) public view returns (ItemResult[] memory results) {
        results = new ItemResult[](count);
        for (uint i = 0; i < count && ((i + offset) < hashes.length); i = onePlus(i)) {
            bytes32 hash = hashes[i + offset];
            Data memory d = data[hash];
            results[i] = ItemResult(d.collectionId, hash, d.owner, d.created);
        }
    }
}
