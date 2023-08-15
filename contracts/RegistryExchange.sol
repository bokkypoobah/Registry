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

    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);

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

    event Offered(address indexed owner, OfferData[] offers, uint timestamp);

    error IncorrectOwner(uint tokenId, address currentOwner);
    error OfferExpired(uint tokenId, uint expiry);
    error InvalidOffer(uint tokenId, address owner);
    error PriceMismatch(uint tokenId, uint offerPrice, uint purchasePrice);

    function offer(OfferData[] memory offerData) public {
        for (uint i = 0; i < offerData.length; i = onePlus(i)) {
            OfferData memory o = offerData[i];
            offers[msg.sender][o.tokenId] = Offer(o.price, o.expiry);
        }
        emit Offered(msg.sender, offerData, block.timestamp);
    }
    function purchase(PurchaseData[] calldata purchaseData /*, bool fillOrKill */) public payable {
        uint totalPaid = 0;
        for (uint i = 0; i < purchaseData.length; i = onePlus(i)) {
            PurchaseData memory p = purchaseData[i];
            address currentOwner = registry.ownerOf(p.tokenId);
            if (p.owner != currentOwner) {
                revert IncorrectOwner(p.tokenId, currentOwner);
            }
            Offer storage _offer = offers[p.owner][p.tokenId];
            if (_offer.expiry != 0 && _offer.expiry < block.timestamp) {
                revert OfferExpired(p.tokenId, _offer.expiry);
            }
            uint offerPrice = uint(_offer.price);
            if (_offer.price == 0) {
                revert InvalidOffer(p.tokenId, p.owner);
            }
            if (offerPrice != p.price) {
                revert PriceMismatch(p.tokenId, _offer.price, p.price);
            }

            // TODO: fill, or fillOrKill (revert if whole batch not completed)

            totalPaid += offerPrice;
            payable(p.owner).transfer(offerPrice);
            registry.transfer(msg.sender, p.tokenId);
        }
        // if (totalPaid < msg.value) {
        //     // Should not get here
        // }

        if (totalPaid > msg.value) {
            uint refund = msg.value - totalPaid;
            payable(msg.sender).transfer(refund);
        }
    }


}
