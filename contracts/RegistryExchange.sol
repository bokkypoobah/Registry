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
    function withdraw(ERC20 token, uint tokens) public onlyOwner {
        if (address(token) == address(0)) {
            payable(owner).transfer((tokens == 0 ? address(this).balance : tokens));
        } else {
            token.transfer(owner, tokens == 0 ? token.balanceOf(address(this)) : tokens);
        }
    }
}


contract ReentrancyGuard {
    uint private _executing;

    error ReentrancyAttempted();

    modifier reentrancyGuard() {
        if (_executing == 1) {
            revert ReentrancyAttempted();
        }
        _executing = 1;
        _;
        _executing = 2;
    }
}


contract RegistryExchange is Owned, ReentrancyGuard {
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
    event Bought(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event Bid(address indexed account, MakerData[] bids, uint timestamp);
    event Sold(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);

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

    function offer(MakerData[] memory inputs) public {
        for (uint i = 0; i < inputs.length; i = onePlus(i)) {
            MakerData memory input = inputs[i];
            if (input.price > PRICE_MAX) {
                revert InvalidPrice(input.price, PRICE_MAX);
            }
            offers[msg.sender][input.tokenId] = Order(uint208(input.price), uint48(input.expiry));
        }
        emit Offered(msg.sender, inputs, block.timestamp);
    }
    function buy(TakerData[] calldata data) public payable reentrancyGuard {
        uint available = msg.value;
        for (uint i = 0; i < data.length; i = onePlus(i)) {
            TakerData memory d = data[i];
            address currentOwner = registry.ownerOf(d.tokenId);
            if (d.account != currentOwner) {
                revert IncorrectOwner(d.tokenId, currentOwner);
            }
            Order memory _offer = offers[d.account][d.tokenId];
            if (_offer.expiry != 0 && _offer.expiry < block.timestamp) {
                revert OfferExpired(d.tokenId, _offer.expiry);
            }
            uint offerPrice = uint(_offer.price);
            if (_offer.price == 0) {
                revert InvalidOffer(d.tokenId, d.account);
            }
            if (offerPrice != d.price) {
                revert PriceMismatch(d.tokenId, _offer.price, d.price);
            }
            if (available < offerPrice) {
                revert TakerHasInsufficientEth(d.tokenId, _offer.price, available);
            }
            available -= offerPrice;
            delete offers[d.account][d.tokenId];
            payable(d.account).transfer((offerPrice * (10_000 - fee)) / 10_000);
            registry.transfer(msg.sender, d.tokenId);
            emit Bought(d.account, msg.sender, d.tokenId, d.price, block.timestamp);
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
    function bid(MakerData[] memory inputs) public {
        for (uint i = 0; i < inputs.length; i = onePlus(i)) {
            MakerData memory input = inputs[i];
            if (input.price > PRICE_MAX) {
                revert InvalidPrice(input.price, PRICE_MAX);
            }
            bids[msg.sender][input.tokenId] = Order(uint208(input.price), uint48(input.expiry));
        }
        emit Bid(msg.sender, inputs, block.timestamp);
    }
    function sell(TakerData[] calldata data) public {
        for (uint i = 0; i < data.length; i = onePlus(i)) {
            TakerData memory d = data[i];
            Order memory _bid = bids[d.account][d.tokenId];
            if (_bid.expiry != 0 && _bid.expiry < block.timestamp) {
                revert BidExpired(d.tokenId, _bid.expiry);
            }
            if (_bid.price == 0) {
                revert InvalidBid(d.tokenId, d.account);
            }
            if (d.price != _bid.price) {
                revert PriceMismatch(d.tokenId, _bid.price, d.price);
            }
            uint available = availableWeth(d.account);
            if (available < d.price) {
                revert MakerHasInsufficientWeth(d.account, d.tokenId, d.price, available);
            }
            weth.transferFrom(d.account, msg.sender, (d.price * (10_000 - fee)) / 10_000);
            weth.transferFrom(d.account, address(this), (d.price * fee) / 10_000);
            delete bids[d.account][d.tokenId];
            registry.transfer(d.account, d.tokenId);
            emit Sold(msg.sender, d.account, d.tokenId, d.price, block.timestamp);
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
