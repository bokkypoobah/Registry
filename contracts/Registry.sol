pragma solidity ^0.8.21;

// ----------------------------------------------------------------------------
// Registry v 0.8.8-testing
//
// Deployed to Sepolia
//
// https://github.com/bokkypoobah/Registry
//
// SPDX-License-Identifier: MIT
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

contract RegistryReceiver {
    Registry registry;

    constructor(Registry _registry) {
        registry = _registry;
    }

    fallback (bytes calldata input) external returns (bytes memory output) {
        return registry.register(input, msg.sender);
    }
}

contract Registry {

    RegistryReceiver public registryReceiver;
    bytes32[] public hashes;
    mapping(bytes32 => address) public ownerOf;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Registered(bytes32 hash, uint index, address owner, uint timestamp);
    event Transfer(address indexed from, address indexed to, bytes32 indexed hash, uint timestamp);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved, uint timestamp);

    error OnlyRegistryReceiverCanRegister();
    error AlreadyRegistered(bytes32 hash, address owner);

    constructor() {
        registryReceiver = new RegistryReceiver(this);
    }

    function register(bytes calldata input, address msgSender) public returns (bytes memory output) {
        if (msg.sender != address(registryReceiver)) {
            revert OnlyRegistryReceiverCanRegister();
        }
        bytes32 hash = keccak256(abi.encodePacked(input));
        address owner = ownerOf[hash];
        if (owner != address(0)) {
            revert AlreadyRegistered(hash, owner);
        }
        ownerOf[hash] = msgSender;
        emit Registered(hash, hashes.length, msg.sender, block.timestamp);
        hashes.push(hash);
        output = bytes.concat(hash);
    }
    function hashesLength() public view returns (uint) {
        return hashes.length;
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "Cannot approve self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved, block.timestamp);
    }
    function isApprovedForAll(address owner, address operator) public view returns (bool) {
        return _operatorApprovals[owner][operator];
    }
    function _isApprovedOrOwner(address spender, bytes32 hash) internal view returns (bool) {
        address owner = ownerOf[hash];
        require(owner != address(0), "Nonexistent hash");
        return (spender == owner || isApprovedForAll(owner, spender));
    }
    function transfer(address to, bytes32 hash) public {
        require(_isApprovedOrOwner(msg.sender, hash), "Not owner nor approved");
        address from = ownerOf[hash];
        ownerOf[hash] = to;
        emit Transfer(from, to, hash, block.timestamp);
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
            results[i] = Data(hash, ownerOf[hash]);
        }
    }
}
