pragma solidity ^0.8.21;

// ----------------------------------------------------------------------------
// Registry
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
    fallback (bytes calldata _input) external returns (bytes memory _output) {
        return registry.registerWithSender(_input, msg.sender);
    }
}

contract Registry {

    RegistryReceiver public registryReceiver;
    bytes32[] public dataIndex;
    mapping(bytes32 => address) public ownerOf;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    event Registered(bytes32 hash, uint index, address owner, uint timestamp);
    event Transfer(address indexed from, address indexed to, bytes32 indexed hash, uint timestamp);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);


    constructor() {
        registryReceiver = new RegistryReceiver(this);
    }

    function registerWithSender(bytes calldata _input, address msgSender) public returns (bytes memory _output) {
        if (msgSender != address(0)) {
            bytes32 hash = keccak256(abi.encodePacked(_input));
            address owner = ownerOf[hash];
            if (owner == address(0)) {
                ownerOf[hash] = msgSender;
                emit Registered(hash, dataIndex.length, msg.sender, block.timestamp);
                dataIndex.push(hash);
                _output = bytes.concat(hash);
            }
        }
    }
    function register(bytes calldata _input) public returns (bytes memory _output) {
        return registerWithSender(_input, msg.sender);
    }

    function setApprovalForAll(address operator, bool approved) public {
        require(operator != msg.sender, "Cannot approve self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
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
}
