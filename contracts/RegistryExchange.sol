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

    /// @dev Ownership transferred from `from` to `to`
    event OwnershipTransferred(address indexed from, address indexed to);

    error NotOwner();
    error NotNewOwner(address newOwner);

    /// @dev Only {owner} can execute functions with this modifier
    modifier onlyOwner {
        if (msg.sender != owner) {
            revert NotOwner();
        }
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @dev Assign {newOnwer} to a `_newOwner`. `_newOwner` will have to {acceptOwnership} to confirm transfer
    /// @param _newOwner New proposed owner
    function transferOwnership(address _newOwner) public onlyOwner {
        newOwner = _newOwner;
    }

    /// @dev Acceptance of ownership transfer by {newOwner}
    function acceptOwnership() public {
        if (msg.sender != newOwner) {
            revert NotNewOwner(newOwner);
        }
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }

    /// @dev Withdraw fees to `owner` account. Only callable by `owner`
    /// @param token ERC-20 token contract, or null for ETH
    /// @param tokens Token amount, or 0 for the full balance
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

    /// @dev Functions with this modifier cannot be re-entered
    modifier reentrancyGuard() {
        if (_executing == 1) {
            revert ReentrancyAttempted();
        }
        _executing = 1;
        _;
        _executing = 2;
    }
}


/// @title RegistryExchange
/// @author BokkyPooBah, Bok Consulting Pty Ltd
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

    /// @dev Maximum price in orders
    uint public constant PRICE_MAX = 1_000_000 ether;
    /// @dev Maximum fee in basis points (10 basis points = 0.1%)
    uint public constant MAX_FEE = 10;

    // WETH
    ERC20 public immutable weth;
    // Registry
    RegistryInterface public immutable registry;
    // Fee
    uint public fee = MAX_FEE;
    // maker => tokenId => [price, expiry]
    mapping(address => mapping(uint => Record)) public offers;
    // maker => tokenId => [price, expiry]
    mapping(address => mapping(uint => Record)) public bids;

    /// @dev `offers` from `account` to sell tokenIds, at `timestamp`
    event Offer(address indexed account, Order[] offers, uint timestamp);
    /// @dev `bids` from `account` to buy tokenIds, at `timestamp`
    event Bid(address indexed account, Order[] bids, uint timestamp);
    /// @dev `account` bought `tokenId` from `from`, at `timestamp`
    event Bought(address indexed account, address indexed from, uint indexed tokenId, uint price, uint timestamp);
    /// @dev `account` sold `tokenId` to `to`, at `timestamp`
    event Sold(address indexed account, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    /// @dev `tokenIds` bulk transferred from `from` to `to`, at `timestamp`
    event BulkTransferred(address indexed from, address indexed to, uint[] tokenIds, uint timestamp);
    /// @dev Fee in basis points updated from `oldFee` to `newFee`, at `timestamp`
    event FeeUpdated(uint indexed oldFee, uint indexed newFee, uint timestamp);

    error InvalidPrice(uint price, uint maxPrice);
    error IncorrectOwner(uint tokenId, address tokenOwner, address orderOwner);
    error OrderExpired(uint tokenId, uint expiry);
    error OrderInvalid(uint tokenId, address account);
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

    /// @dev Maker update `_offers` to sell tokens for ETH
    /// @param _offers [[tokenId, price, expiry]]
    function offer(Order[] memory _offers) public {
        for (uint i = 0; i < _offers.length; i = onePlus(i)) {
            Order memory o = _offers[i];
            if (o.price > PRICE_MAX) {
                revert InvalidPrice(o.price, PRICE_MAX);
            }
            offers[msg.sender][o.tokenId] = Record(uint208(o.price), uint48(o.expiry));
        }
        emit Offer(msg.sender, _offers, block.timestamp);
    }

    /// @dev Maker update `_bids` to buy tokens for WETH
    /// @param _bids [[tokenId, price, expiry]]
    function bid(Order[] memory _bids) public {
        for (uint i = 0; i < _bids.length; i = onePlus(i)) {
            Order memory o = _bids[i];
            if (o.price > PRICE_MAX) {
                revert InvalidPrice(o.price, PRICE_MAX);
            }
            bids[msg.sender][o.tokenId] = Record(uint208(o.price), uint48(o.expiry));
        }
        emit Bid(msg.sender, _bids, block.timestamp);
    }

    /// @dev Taker execute `trades` against {offers} to buy tokens for ETH. Executed {offers} are removed
    /// @param trades [[maker, tokenId, price]]
    /// @param uiFeeAccount Fee account that will receive half of the fees if non-null
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
                revert OrderInvalid(t.tokenId, t.account);
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
            emit Bought(msg.sender, t.account, t.tokenId, orderPrice, block.timestamp);
        }
        if (available > 0) {
            payable(msg.sender).transfer(available);
        }
    }

    /// @dev Taker execute `trades` against {bids} to sell tokens for WETH. Executed {bids} are removed
    /// @param trades [[maker, tokenId, price]]
    /// @param uiFeeAccount Fee account that will receive half of the fees if non-null
    function sell(Trade[] calldata trades, address uiFeeAccount) public {
        for (uint i = 0; i < trades.length; i = onePlus(i)) {
            Trade memory t = trades[i];
            if (t.account == msg.sender) {
                revert CannotSelfTrade(t.tokenId);
            }
            Record memory order = bids[t.account][t.tokenId];
            if (order.expiry == 0) {
                revert OrderInvalid(t.tokenId, t.account);
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

    /// @dev Transfer `tokenIds` to `to`. Requires owner to have executed setApprovalForAll(registryExchange, true)
    /// @param to New owner
    /// @param tokenIds Token Ids
    function bulkTransfer(address to, uint[] memory tokenIds) public {
        for (uint i = 0; i < tokenIds.length; i = onePlus(i)) {
            if (msg.sender != registry.ownerOf(tokenIds[i])) {
                revert OnlyTokenOwnerCanTransfer();
            }
            registry.transfer(to, tokenIds[i]);
        }
        emit BulkTransferred(msg.sender, to, tokenIds, block.timestamp);
    }

    /// @dev Update fee to `newFee`, with a limit of {MAX_FEE}. Only callable by {owner}
    /// @param newFee New fee
    function updateFee(uint newFee) public onlyOwner {
        if (newFee > MAX_FEE) {
            revert InvalidFee(newFee, MAX_FEE);
        }
        emit FeeUpdated(fee, newFee, block.timestamp);
        fee = newFee;
    }

    /// @dev Minimum of WETH balance and spending allowance to this {RegistryExchange} for `account`
    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
}
