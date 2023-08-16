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

    RegistryInterface public immutable registry;
    mapping(address => mapping(uint => Offer)) offers;

    event Offered(address indexed owner, OfferData[] offers, uint timestamp);
    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);
    event Purchased(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);

    error IncorrectOwner(uint tokenId, address currentOwner);
    error OfferExpired(uint tokenId, uint expiry);
    error InvalidOffer(uint tokenId, address owner);
    error PriceMismatch(uint tokenId, uint offerPrice, uint purchasePrice);
    error InsufficientFunds(uint tokenId, uint required, uint available);
    error OnlyTokenOwnerCanTransfer();

    constructor(RegistryInterface _registry) {
        registry = _registry;
    }

    function offer(OfferData[] memory offerData) public {
        for (uint i = 0; i < offerData.length; i = onePlus(i)) {
            OfferData memory o = offerData[i];
            offers[msg.sender][o.tokenId] = Offer(o.price, o.expiry);
        }
        emit Offered(msg.sender, offerData, block.timestamp);
    }
    function purchase(PurchaseData[] calldata purchaseData) public payable {
        uint available = msg.value;
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
            if (available < offerPrice) {
                revert InsufficientFunds(p.tokenId, _offer.price, available);
            }
            available -= offerPrice;
            payable(p.owner).transfer(offerPrice);
            registry.transfer(msg.sender, p.tokenId);
            emit Purchased(p.owner, msg.sender, p.tokenId, offerPrice, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
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
}
