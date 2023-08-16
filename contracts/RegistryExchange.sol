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
    struct MakerData {
        uint tokenId;
        uint208 price;
        uint48 expiry;
    }
    struct PriceExpiry {
        uint208 price;
        uint48 expiry;
    }
    struct TakerData {
        address account;
        uint tokenId;
        uint price;
    }

    RegistryInterface public immutable registry;
    ERC20 public immutable weth;
    mapping(address => mapping(uint => PriceExpiry)) offers;
    mapping(address => mapping(uint => PriceExpiry)) bids;

    event Offered(address indexed account, MakerData[] offers, uint timestamp);
    event BidRegistered(address indexed account, MakerData[] bids, uint timestamp);
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

    function offer(MakerData[] memory offerInputs) public {
        for (uint i = 0; i < offerInputs.length; i = onePlus(i)) {
            MakerData memory o = offerInputs[i];
            offers[msg.sender][o.tokenId] = PriceExpiry(o.price, o.expiry);
        }
        emit Offered(msg.sender, offerInputs, block.timestamp);
    }
    function purchase(TakerData[] calldata purchaseData) public payable {
        uint available = msg.value;
        for (uint i = 0; i < purchaseData.length; i = onePlus(i)) {
            TakerData memory p = purchaseData[i];
            address currentOwner = registry.ownerOf(p.tokenId);
            if (p.account != currentOwner) {
                revert IncorrectOwner(p.tokenId, currentOwner);
            }
            PriceExpiry memory _offer = offers[p.account][p.tokenId];
            if (_offer.expiry != 0 && _offer.expiry < block.timestamp) {
                revert OfferExpired(p.tokenId, _offer.expiry);
            }
            uint offerPrice = uint(_offer.price);
            if (_offer.price == 0) {
                revert InvalidOffer(p.tokenId, p.account);
            }
            if (offerPrice != p.price) {
                revert PriceMismatch(p.tokenId, _offer.price, p.price);
            }
            if (available < offerPrice) {
                revert InsufficientFunds(p.tokenId, _offer.price, available);
            }
            available -= offerPrice;
            delete offers[p.account][p.tokenId];
            payable(p.account).transfer(offerPrice);
            registry.transfer(msg.sender, p.tokenId);
            emit Purchased(p.account, msg.sender, p.tokenId, p.price, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
    }

    function bid(MakerData[] memory bidInputs) public {
        for (uint i = 0; i < bidInputs.length; i = onePlus(i)) {
            MakerData memory b = bidInputs[i];
            bids[msg.sender][b.tokenId] = PriceExpiry(b.price, b.expiry);
        }
        emit BidRegistered(msg.sender, bidInputs, block.timestamp);
    }
    function sell(TakerData[] calldata saleData) public {
        for (uint i = 0; i < saleData.length; i = onePlus(i)) {
            TakerData memory s = saleData[i];
            PriceExpiry memory _bid = bids[s.account][s.tokenId];
            if (_bid.expiry != 0 && _bid.expiry < block.timestamp) {
                revert BidExpired(s.tokenId, _bid.expiry);
            }
            if (_bid.price == 0) {
                revert InvalidBid(s.tokenId, s.account);
            }
            if (s.price != _bid.price) {
                revert PriceMismatch(s.tokenId, _bid.price, s.price);
            }
            uint wethBalance = weth.balanceOf(s.account);
            uint wethApproved = weth.allowance(s.account, address(this));
            uint available = wethBalance > wethApproved ? wethApproved : wethBalance;
            if (available < s.price) {
                revert InsufficientFunds(s.tokenId, s.price, available);
            }
            weth.transferFrom(s.account, msg.sender, s.price);
            delete bids[s.account][s.tokenId];
            registry.transfer(s.account, s.tokenId);
            emit Sold(msg.sender, s.account, s.tokenId, s.price, block.timestamp);
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
