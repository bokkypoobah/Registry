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
    struct Record {
        uint208 price;
        uint48 expiry;
    }
    struct Order {
        uint tokenId;
        uint price;
        uint expiry;
    }
    struct Trade {
        address account;
        uint tokenId;
        uint price;
    }

    uint public constant PRICE_MAX = 1_000_000 ether;
    uint public constant MAX_FEE = 10; // 10 basis points = 0.1%

    ERC20 public immutable weth;
    RegistryInterface public immutable registry;
    uint public fee = MAX_FEE;
    mapping(address => mapping(uint => Record)) public offers;
    mapping(address => mapping(uint => Record)) public bids;

    event Offer(address indexed account, Order[] offers, uint timestamp);
    event Bid(address indexed account, Order[] bids, uint timestamp);
    event Bought(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event Sold(address indexed from, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    event BulkTransferred(address indexed to, uint[] tokenIds, uint timestamp);
    event FeeUpdated(uint indexed fee);

    error InvalidPrice(uint price, uint maxPrice);
    error IncorrectOwner(uint tokenId, address tokenOwner, address orderOwner);
    error OrderExpired(uint tokenId, uint expiry);
    error InvalidOrder(uint tokenId, address account);
    error CannotSelfTrade(uint tokenId);
    error PriceMismatch(uint tokenId, uint orderPrice, uint purchasePrice);
    error TakerHasInsufficientEth(uint tokenId, uint required, uint available);
    error MakerHasInsufficientWeth(address bidder, uint tokenId, uint required, uint available);
    error InvalidFee(uint fee, uint maxFee);
    error OnlyTokenOwnerCanTransfer();

    constructor(ERC20 _weth, RegistryInterface _registry) {
        weth = _weth;
        registry = _registry;
    }

    function offer(Order[] memory orders) public {
        for (uint i = 0; i < orders.length; i = onePlus(i)) {
            Order memory o = orders[i];
            if (o.price > PRICE_MAX) {
                revert InvalidPrice(o.price, PRICE_MAX);
            }
            offers[msg.sender][o.tokenId] = Record(uint208(o.price), uint48(o.expiry));
        }
        emit Offer(msg.sender, orders, block.timestamp);
    }
    function bid(Order[] memory orders) public {
        for (uint i = 0; i < orders.length; i = onePlus(i)) {
            Order memory o = orders[i];
            if (o.price > PRICE_MAX) {
                revert InvalidPrice(o.price, PRICE_MAX);
            }
            bids[msg.sender][o.tokenId] = Record(uint208(o.price), uint48(o.expiry));
        }
        emit Bid(msg.sender, orders, block.timestamp);
    }
    function buy(Trade[] calldata trades, address uiFeeAccount) public payable reentrancyGuard {
        uint available = msg.value;
        for (uint i = 0; i < trades.length; i = onePlus(i)) {
            Trade memory t = trades[i];
            if (t.account == msg.sender) {
                revert CannotSelfTrade(t.tokenId);
            }
            address tokenOwner = registry.ownerOf(t.tokenId);
            if (t.account != tokenOwner) {
                revert IncorrectOwner(t.tokenId, tokenOwner, t.account);
            }
            Record memory order = offers[t.account][t.tokenId];
            if (order.expiry == 0) {
                revert InvalidOrder(t.tokenId, t.account);
            } else if (order.expiry < block.timestamp) {
                revert OrderExpired(t.tokenId, order.expiry);
            }
            uint orderPrice = uint(order.price);
            if (orderPrice != t.price) {
                revert PriceMismatch(t.tokenId, orderPrice, t.price);
            }
            if (available < orderPrice) {
                revert TakerHasInsufficientEth(t.tokenId, orderPrice, available);
            }
            available -= orderPrice;
            delete offers[t.account][t.tokenId];
            payable(t.account).transfer((orderPrice * (10_000 - fee)) / 10_000);
            if (uiFeeAccount != address(0)) {
                payable(uiFeeAccount).transfer((orderPrice * fee) / 20_000);
            }
            registry.transfer(msg.sender, t.tokenId);
            emit Bought(t.account, msg.sender, t.tokenId, orderPrice, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
    }
    function sell(Trade[] calldata trades, address uiFeeAccount) public {
        for (uint i = 0; i < trades.length; i = onePlus(i)) {
            Trade memory t = trades[i];
            if (t.account == msg.sender) {
                revert CannotSelfTrade(t.tokenId);
            }
            Record memory order = bids[t.account][t.tokenId];
            if (order.expiry == 0) {
                revert InvalidOrder(t.tokenId, t.account);
            } else if (order.expiry < block.timestamp) {
                revert OrderExpired(t.tokenId, order.expiry);
            }
            uint orderPrice = uint(order.price);
            if (orderPrice != t.price) {
                revert PriceMismatch(t.tokenId, orderPrice, t.price);
            }
            uint available = availableWeth(t.account);
            if (available < orderPrice) {
                revert MakerHasInsufficientWeth(t.account, t.tokenId, orderPrice, available);
            }
            delete bids[t.account][t.tokenId];
            weth.transferFrom(t.account, msg.sender, (orderPrice * (10_000 - fee)) / 10_000);
            if (uiFeeAccount != address(0)) {
                weth.transferFrom(t.account, uiFeeAccount, (orderPrice * fee) / 20_000);
                weth.transferFrom(t.account, address(this), (orderPrice * fee) / 20_000);
            } else {
                weth.transferFrom(t.account, address(this), (orderPrice * fee) / 10_000);
            }
            registry.transfer(t.account, t.tokenId);
            emit Sold(msg.sender, t.account, t.tokenId, orderPrice, block.timestamp);
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
    function updateFee(uint _fee) public onlyOwner {
        if (_fee > MAX_FEE) {
            revert InvalidFee(_fee, MAX_FEE);
        }
        emit FeeUpdated(_fee);
        fee = _fee;
    }

    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
}
