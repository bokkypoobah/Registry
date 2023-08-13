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
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

contract RegistryReceiver {
    Registry public immutable registry;

    constructor() {
        registry = Registry(msg.sender);
    }

    fallback(bytes calldata input) external returns (bytes memory output) {
        return registry.register(keccak256(abi.encodePacked(input)), msg.sender);
    }
}


contract Registry {
    struct Data {
        address owner;
        uint56 tokenId;
        uint40 created;
    }
    struct Result {
        bytes32 hash;
        address owner;
        uint created;
    }

    RegistryReceiver public immutable registryReceiver;
    bytes32[] public hashes;
    mapping(bytes32 => Data) public data;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Registered(uint indexed tokenId, bytes32 indexed hash, address indexed owner, uint timestamp);
    event Transfer(address indexed from, address indexed to, uint indexed tokenId, uint timestamp);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, uint timestamp);

    error OnlyRegistryReceiverCanRegister();
    error AlreadyRegistered(bytes32 hash, address owner, uint tokenId, uint created);
    error CannotApproveSelf();
    error InvalidTokenId();
    error NotOwnerNorApproved();

    constructor() {
        registryReceiver = new RegistryReceiver();
    }

    function register(bytes32 hash, address msgSender) public returns (bytes memory output) {
        if (msg.sender != address(registryReceiver)) {
            revert OnlyRegistryReceiverCanRegister();
        }
        Data memory d = data[hash];
        if (d.owner != address(0)) {
            revert AlreadyRegistered(hash, d.owner, d.tokenId, d.created);
        }
        data[hash] = Data(msgSender, uint56(hashes.length), uint40(block.timestamp));
        emit Registered(hashes.length, hash, msgSender, block.timestamp);
        output = bytes.concat(bytes32(hashes.length));
        hashes.push(hash);
    }
    function ownerOf(uint tokenId) public view returns (address) {
        bytes32 hash = hashes[tokenId];
        return data[hash].owner;
    }
    function hashesLength() public view returns (uint) {
        return hashes.length;
    }

    function setApprovalForAll(address operator, bool approved) public {
        if (operator == msg.sender) {
            revert CannotApproveSelf();
        }
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved, block.timestamp);
    }
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    function _isApprovedOrOwner(address spender, uint tokenId) internal view returns (bool) {
        bytes32 hash = hashes[tokenId];
        address owner = data[hash].owner;
        if (owner == address(0)) {
            revert InvalidTokenId();
        }
        return (spender == owner || isApprovedForAll(owner, spender));
    }
    function transfer(address to, uint tokenId) public {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) {
            revert NotOwnerNorApproved();
        }
        bytes32 hash = hashes[tokenId];
        address from = data[hash].owner;
        data[hash].owner = to;
        emit Transfer(from, to, tokenId, block.timestamp);
    }

    function onePlus(uint x) internal pure returns (uint) {
        unchecked { return 1 + x; }
    }
    function getData(uint count, uint offset) public view returns (Result[] memory results) {
        results = new Result[](count);
        for (uint i = 0; i < count && ((i + offset) < hashes.length); i = onePlus(i)) {
            bytes32 hash = hashes[i + offset];
            Data memory d = data[hash];
            results[i] = Result(hash, d.owner, uint(d.created));
        }
    }
}
