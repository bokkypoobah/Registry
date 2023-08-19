pragma solidity ^0.8.19;

// ----------------------------------------------------------------------------
// Registry v0.8.9d-testing
//
// Deployed to Sepolia
// - Registry
// - RegistryReceiver
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

interface RegistryReceiverInterface {
    function registry() external view returns (RegistryInterface);
}

interface RegistryInterface {
    struct Result {
        bytes32 hash;
        address owner;
        uint created;
    }
    function registryReceiver() external view returns (RegistryReceiverInterface);
    function register(bytes32 hash, address msgSender) external returns (bytes memory output);
    function ownerOf(uint tokenId) external view returns (address);
    function length() external view returns (uint);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transfer(address to, uint tokenId) external;
    function getData(uint count, uint offset) external view returns (Result[] memory results);
}

function onePlus(uint x) pure returns (uint) {
    unchecked { return 1 + x; }
}


/// @title RegistryReceiver
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract RegistryReceiver is RegistryReceiverInterface {
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


/// @title Registry of hashes of data with sequential tokenIds with transferable ownership
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Registry is RegistryInterface {
    struct Data {
        address owner;
        uint56 tokenId;
        uint40 created;
    }

    RegistryReceiver private immutable _registryReceiver;
    // Array of unique data hashes
    bytes32[] public hashes;
    // data hash => [owner, tokenId, created]
    mapping(bytes32 => Data) public data;
    // owner => operator => approved?
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    /// @dev New `hash` has been registered with `tokenId` by `owner` at `timestamp`
    event Registered(uint indexed tokenId, bytes32 indexed hash, address indexed owner, uint timestamp);
    /// @dev `tokenId` has been transferred from `from` to `to` at `timestamp`
    event Transfer(address indexed from, address indexed to, uint indexed tokenId, uint timestamp);
    /// @dev `owner` has `approved` for `operator` to manage all of its assets at `timestamp`
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, uint timestamp);

    error OnlyRegistryReceiverCanRegister();
    error AlreadyRegistered(bytes32 hash, address owner, uint tokenId, uint created);
    error CannotApproveSelf();
    error InvalidTokenId();
    error NotOwnerNorApproved(address owner, uint tokenId);

    constructor() {
        _registryReceiver = new RegistryReceiver();
    }

    /// @dev RegistryReceiver address
    function registryReceiver() external view returns (RegistryReceiverInterface) {
        return _registryReceiver;
    }

    /// @dev Only {registryReceiver} can register `hash` on behalf of `msgSender`
    /// @return output Token Id encoded as bytes
    function register(bytes32 hash, address msgSender) external returns (bytes memory output) {
        if (msg.sender != address(_registryReceiver)) {
            revert OnlyRegistryReceiverCanRegister();
        }
        Data memory d = data[hash];
        bool burnt = false;
        if (d.owner != address(0)) {
            revert AlreadyRegistered(hash, d.owner, d.tokenId, d.created);
        } else if (d.created != 0) {
            burnt = true;
        }
        data[hash] = Data(msgSender, uint56(hashes.length), uint40(block.timestamp));
        emit Registered(hashes.length, hash, msgSender, block.timestamp);
        output = bytes.concat(bytes32(hashes.length));
        if (!burnt) {
            hashes.push(hash);            
        }
    }

    /// @dev Returns the owner of `tokenId`
    function ownerOf(uint tokenId) external view returns (address) {
        return data[hashes[tokenId]].owner;
    }

    /// @dev Number of items
    function length() external view returns (uint) {
        return hashes.length;
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

    /// @dev Get `count` rows of data beginning at `offset`
    /// @param count Number of results
    /// @param offset Offset
    /// @return results [[hash, owner, created]]
    function getData(uint count, uint offset) public view returns (Result[] memory results) {
        results = new Result[](count);
        for (uint i = 0; i < count && ((i + offset) < hashes.length); i = onePlus(i)) {
            bytes32 hash = hashes[i + offset];
            Data memory d = data[hash];
            results[i] = Result(hash, d.owner, uint(d.created));
        }
    }
}
