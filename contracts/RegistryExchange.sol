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
import "./ERC20.sol";


contract RegistryExchange {
    struct OfferInput {
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
    struct BidInput {
        uint tokenId;
        uint208 price;
        uint48 expiry;
    }
    struct Bid {
        uint208 price;
        uint48 expiry;
    }
    struct SaleData {
        address bidder;
        uint tokenId;
        uint price;
    }

    RegistryInterface public immutable registry;
    ERC20 public immutable weth;
    mapping(address => mapping(uint => Offer)) offers;
    mapping(address => mapping(uint => Bid)) bids;

    event Offered(address indexed account, OfferInput[] offers, uint timestamp);
    event BidRegistered(address indexed account, BidInput[] bids, uint timestamp);
    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);
    event Purchased(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event Sold(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);

    error IncorrectOwner(uint tokenId, address currentOwner);
    error OfferExpired(uint tokenId, uint expiry);
    error BidExpired(uint tokenId, uint expiry);
    error InvalidOffer(uint tokenId, address owner);
    error InvalidBid(uint tokenId, address bidder);
    error PriceMismatch(uint tokenId, uint offerPrice, uint purchasePrice);
    error InsufficientFunds(uint tokenId, uint required, uint available);
    error OnlyTokenOwnerCanTransfer();

    constructor(RegistryInterface _registry, ERC20 _weth) {
        registry = _registry;
        weth = _weth;
    }

    function offer(OfferInput[] memory offerInputs) public {
        for (uint i = 0; i < offerInputs.length; i = onePlus(i)) {
            OfferInput memory o = offerInputs[i];
            offers[msg.sender][o.tokenId] = Offer(o.price, o.expiry);
        }
        emit Offered(msg.sender, offerInputs, block.timestamp);
    }
    function purchase(PurchaseData[] calldata purchaseData) public payable {
        uint available = msg.value;
        for (uint i = 0; i < purchaseData.length; i = onePlus(i)) {
            PurchaseData memory p = purchaseData[i];
            address currentOwner = registry.ownerOf(p.tokenId);
            if (p.owner != currentOwner) {
                revert IncorrectOwner(p.tokenId, currentOwner);
            }
            Offer memory _offer = offers[p.owner][p.tokenId];
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
            delete offers[p.owner][p.tokenId];
            payable(p.owner).transfer(offerPrice);
            registry.transfer(msg.sender, p.tokenId);
            emit Purchased(p.owner, msg.sender, p.tokenId, offerPrice, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
    }

    function bid(BidInput[] memory bidInputs) public {
        for (uint i = 0; i < bidInputs.length; i = onePlus(i)) {
            BidInput memory b = bidInputs[i];
            bids[msg.sender][b.tokenId] = Bid(b.price, b.expiry);
        }
        emit BidRegistered(msg.sender, bidInputs, block.timestamp);
    }
    function sell(SaleData[] calldata saleData) public {
        for (uint i = 0; i < saleData.length; i = onePlus(i)) {
            SaleData memory s = saleData[i];
            address bidder = s.bidder;
            uint tokenId = s.tokenId;
            uint price = s.price;
            Bid memory _bid = bids[bidder][tokenId];
            if (_bid.expiry != 0 && _bid.expiry < block.timestamp) {
                revert BidExpired(s.tokenId, _bid.expiry);
            }
            if (_bid.price == 0) {
                revert InvalidBid(s.tokenId, bidder);
            }
            if (s.price != _bid.price) {
                revert PriceMismatch(s.tokenId, _bid.price, s.price);
            }
            uint wethBalance = weth.balanceOf(bidder);
            uint wethApproved = weth.allowance(bidder, address(this));
            uint available = wethBalance > wethApproved ? wethApproved : wethBalance;
            if (available < price) {
                revert InsufficientFunds(s.tokenId, price, available);
            }
            weth.transferFrom(bidder, msg.sender, price);
            delete bids[bidder][s.tokenId];
            registry.transfer(bidder, s.tokenId);
            emit Sold(msg.sender, bidder, s.tokenId, price, block.timestamp);
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
