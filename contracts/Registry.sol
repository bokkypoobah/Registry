pragma solidity ^0.8.21;

// ----------------------------------------------------------------------------
// Registry v0.8.9b-testing
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
    Registry immutable registry;

    constructor() {
        registry = Registry(msg.sender);
    }

    fallback (bytes calldata input) external returns (bytes memory output) {
        return registry.register(keccak256(abi.encodePacked(input)), msg.sender);
    }
}

contract Registry {

    RegistryReceiver public immutable registryReceiver;
    bytes32[] public hashes;
    mapping(bytes32 => address) public owners;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Registered(uint indexed tokenId, bytes32 indexed hash, address indexed owner, uint timestamp);
    event Transfer(address indexed from, address indexed to, uint indexed tokenId, uint timestamp);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, uint timestamp);

    error OnlyRegistryReceiverCanRegister();
    error AlreadyRegistered(bytes32 hash, address owner);
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
        if (owners[hash] != address(0)) {
            revert AlreadyRegistered(hash, owners[hash]);
        }
        owners[hash] = msgSender;
        emit Registered(hashes.length, hash, msgSender, block.timestamp);
        hashes.push(hash);
        output = bytes.concat(hash);
    }
    function ownerOf(uint tokenId) public view returns (address) {
        bytes32 hash = hashes[tokenId];
        return owners[hash];
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
        address owner = owners[hash];
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
        address from = owners[hash];
        owners[hash] = to;
        emit Transfer(from, to, tokenId, block.timestamp);
    }

    struct Data {
        bytes32 hash;
        address owner;
    }
    function onePlus(uint x) internal pure returns (uint) {
        unchecked { return 1 + x; }
    }
    function getData(uint count, uint offset) public view returns (Data[] memory results) {
        results = new Data[](count);
        for (uint i = 0; i < count && ((i + offset) < hashes.length); i = onePlus(i)) {
            bytes32 hash = hashes[i + offset];
            results[i] = Data(hash, owners[hash]);
        }
    }
}
