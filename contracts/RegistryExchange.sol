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
// If you earn fees using your deployment of this code, or derivatives of this
// code, please send a proportionate amount to bokkypoobah.eth .
// Don't be stingy! Donations welcome!
//
// Enjoy. (c) BokkyPooBah / Bok Consulting Pty Ltd 2023
// ----------------------------------------------------------------------------

import "./Registry.sol";
import "./ERC20.sol";


/// @notice Ownership
contract Owned {
    address public owner;
    address public newOwner;

    event OwnershipTransferred(address indexed from, address indexed to);

    error NotOwner();

    modifier onlyOwner {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }
    function acceptOwnership() public {
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }
    function withdrawTokens(ERC20 token, uint tokens) public onlyOwner {
        if (address(token) == address(0)) {
            payable(owner).transfer((tokens == 0 ? address(this).balance : tokens));
        } else {
            token.transfer(owner, tokens == 0 ? token.balanceOf(address(this)) : tokens);
        }
    }
}


contract RegistryExchange is Owned {
    struct Order {
        uint208 price;
        uint48 expiry;
    }
    struct MakerData {
        uint tokenId;
        uint price;
        uint expiry;
    }
    struct TakerData {
        address account;
        uint tokenId;
        uint price;
    }

    uint public constant PRICE_MAX = 1_000_000 ether;
    uint public constant MAX_FEE = 10; // 10 basis points = 0.1%

    ERC20 public immutable weth;
    RegistryInterface public immutable registry;
    uint public fee = MAX_FEE;
    mapping(address => mapping(uint => Order)) public offers;
    mapping(address => mapping(uint => Order)) public bids;

    event FeeUpdated(uint indexed fee);
    event Offered(address indexed account, MakerData[] offers, uint timestamp);
    event Bid(address indexed account, MakerData[] bids, uint timestamp);
    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);
    event Purchased(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event Sold(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);

    error InvalidFee(uint fee, uint maxFee);
    error InvalidPrice(uint price, uint maxPrice);
    error IncorrectOwner(uint tokenId, address currentOwner);
    error OfferExpired(uint tokenId, uint expiry);
    error BidExpired(uint tokenId, uint expiry);
    error InvalidOffer(uint tokenId, address owner);
    error InvalidBid(uint tokenId, address bidder);
    error PriceMismatch(uint tokenId, uint offerPrice, uint purchasePrice);
    error TakerHasInsufficientEth(uint tokenId, uint required, uint available);
    error MakerHasInsufficientWeth(address bidder, uint tokenId, uint required, uint available);
    error OnlyTokenOwnerCanTransfer();

    constructor(ERC20 _weth, RegistryInterface _registry) {
        weth = _weth;
        registry = _registry;
    }
    function updateFee(uint _fee) public onlyOwner {
        if (_fee > MAX_FEE) {
            revert InvalidFee(_fee, MAX_FEE);
        }
        emit FeeUpdated(_fee);
        fee = _fee;
    }

    function offer(MakerData[] memory offerInputs) public {
        for (uint i = 0; i < offerInputs.length; i = onePlus(i)) {
            MakerData memory o = offerInputs[i];
            if (o.price > PRICE_MAX) {
                revert InvalidPrice(o.price, PRICE_MAX);
            }
            offers[msg.sender][o.tokenId] = Order(uint208(o.price), uint48(o.expiry));
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
            Order memory _offer = offers[p.account][p.tokenId];
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
                revert TakerHasInsufficientEth(p.tokenId, _offer.price, available);
            }
            available -= offerPrice;
            delete offers[p.account][p.tokenId];
            payable(p.account).transfer((offerPrice * (10_000 - fee)) / 10_000);
            registry.transfer(msg.sender, p.tokenId);
            emit Purchased(p.account, msg.sender, p.tokenId, p.price, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
    }

    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
    function bid(MakerData[] memory bidInputs) public {
        for (uint i = 0; i < bidInputs.length; i = onePlus(i)) {
            MakerData memory b = bidInputs[i];
            if (b.price > PRICE_MAX) {
                revert InvalidPrice(b.price, PRICE_MAX);
            }
            bids[msg.sender][b.tokenId] = Order(uint208(b.price), uint48(b.expiry));
        }
        emit Bid(msg.sender, bidInputs, block.timestamp);
    }
    function sell(TakerData[] calldata saleData) public {
        for (uint i = 0; i < saleData.length; i = onePlus(i)) {
            TakerData memory s = saleData[i];
            Order memory _bid = bids[s.account][s.tokenId];
            if (_bid.expiry != 0 && _bid.expiry < block.timestamp) {
                revert BidExpired(s.tokenId, _bid.expiry);
            }
            if (_bid.price == 0) {
                revert InvalidBid(s.tokenId, s.account);
            }
            if (s.price != _bid.price) {
                revert PriceMismatch(s.tokenId, _bid.price, s.price);
            }
            uint available = availableWeth(s.account);
            if (available < s.price) {
                revert MakerHasInsufficientWeth(s.account, s.tokenId, s.price, available);
            }
            weth.transferFrom(s.account, msg.sender, (s.price * (10_000 - fee)) / 10_000);
            weth.transferFrom(s.account, address(this), (s.price * fee) / 10_000);
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
