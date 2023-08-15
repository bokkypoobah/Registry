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

import "./Registry.sol";


contract RegistryExchange {
    RegistryInterface public immutable registry;

    constructor(RegistryInterface _registry) {
        registry = _registry;
    }
}
