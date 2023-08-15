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

interface RegistryReceiver {
    function registry() external view returns (Registry);
}

interface Registry {
    function registryReceiver() external view returns (RegistryReceiver);
}

contract RegistryExchange {
    Registry public immutable registry;

    constructor(Registry _registry) {
        registry = _registry;
    }
}
