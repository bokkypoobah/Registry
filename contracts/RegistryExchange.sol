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

    event BulkTransferred(address to, uint[] tokenIds, uint timestamp);

    error OnlyTokenOwnerCanTransfer();


    constructor(RegistryInterface _registry) {
        registry = _registry;
    }

    function bulkTransfer(address to, uint[] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; i = onePlus(i)) {
            if (msg.sender != registry.ownerOf(tokenIds[i])) {
                revert OnlyTokenOwnerCanTransfer();
            }
            registry.transfer(to, tokenIds[i]);
        }
        emit BulkTransferred(to, tokenIds, block.timestamp);
    }

    struct OfferData {
        uint tokenId;
        uint208 price;
        uint48 expiry;
    }

    // mapping(address => mapping(uint => ) )

    function offerForSale(OfferData[] memory offerData) public {

    }
}
