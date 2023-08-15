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
    struct Offer {
        uint208 price;
        uint48 expiry;
    }
    struct PurchaseData {
        address owner;
        uint tokenId;
        uint price;
    }

    mapping(address => mapping(uint => Offer)) offers;

    event Offered(address msgSender, OfferData[] offers, uint timestamp);

    error IncorrectOwner(uint tokenId, address currentOwner);
    error OfferExpired(uint expiry);

    function offer(OfferData[] memory offerData) public {
        for (uint i = 0; i < offerData.length; i = onePlus(i)) {
            OfferData memory o = offerData[i];
            offers[msg.sender][o.tokenId] = Offer(o.price, o.expiry);
        }
        emit Offered(msg.sender, offerData, block.timestamp);
    }
    function purchase(PurchaseData[] calldata purchaseData) public payable {
        for (uint i = 0; i < purchaseData.length; i = onePlus(i)) {
            PurchaseData memory p = purchaseData[i];
            address currentOwner = registry.ownerOf(p.tokenId);
            if (p.owner != currentOwner) {
                revert IncorrectOwner(p.tokenId, currentOwner);
            }
            Offer storage _offer = offers[p.owner][p.tokenId];
            // if ()
        }
    }


}
