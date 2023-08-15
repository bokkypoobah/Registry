pragma solidity ^0.8.19;

// ----------------------------------------------------------------------------
// RegistryExchange v0.8.8-testing
//
// Deployed to Sepolia
// - RegistryExchange
//
// https://github.com/bokkypoobah/Registry
//
// SPDX-License-Identifier: MIT
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

interface RegistryReceiverInterface {
    function registry() external view returns (RegistryInterface);
}

interface RegistryInterface {
    function registryReceiver() external view returns (RegistryReceiverInterface);
    // function register(bytes32 hash, address msgSender) public returns (bytes memory output) {
    // function ownerOf(uint tokenId) public view returns (address) {
    // function hashesLength() public view returns (uint) {
    // function setApprovalForAll(address operator, bool approved) public {
    // function isApprovedForAll(address owner, address operator) public view returns (bool) {
    // function _isApprovedOrOwner(address spender, uint tokenId) internal view returns (bool) {
    // function transfer(address to, uint tokenId) public {
    // function getData(uint count, uint offset) public view returns (Result[] memory results) {

}

contract RegistryExchange {
    RegistryInterface public immutable registry;

    constructor(RegistryInterface _registry) {
        registry = _registry;
    }
}
