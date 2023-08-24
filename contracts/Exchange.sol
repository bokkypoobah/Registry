pragma solidity ^0.8.19;

// ----------------------------------------------------------------------------
// Exchange v0.8.8-testing
//
// Deployed to Sepolia
// - Exchange
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

type Price is uint96;

/// @notice Ownership
contract Owned {
    address public owner;
    address public newOwner;

    /// @dev Ownership transferred from `from` to `to`
    event OwnershipTransferred(address indexed from, address indexed to, Unixtime timestamp);

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
        emit OwnershipTransferred(owner, newOwner, Unixtime.wrap(uint64(block.timestamp)));
        owner = newOwner;
        newOwner = address(0);
    }
}


/// @title Exchange
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Exchange is Owned {

    enum Action { Offer, Bid, Buy, Sell, CollectionOffer, CollectionBid, CollectionBuy, CollectionSell }

    struct Input {
        Action action;
        address counterparty; // ? Required for Buy And Sell
        uint64 id; // collectionId for CollectionOffer and CollectionBid, tokenId otherwise
        Price price;
        uint64 count;
        Unixtime expiry; // ? Required for Offer and Bid
    }
    struct Record {
        Price price;
        uint64 count;
        Unixtime expiry;
    }

    /// @dev Maximum price in orders
    Price private constant MAX_ORDER_PRICE = Price.wrap(uint96(1_000_000 ether));
    /// @dev Maximum count in orders
    uint private constant MAX_ORDER_COUNT = 100_000;
    /// @dev Maximum fee in basis points (10 bps = 0.1%)
    BasisPoint private constant MAX_FEE = BasisPoint.wrap(10);

    // WETH
    ERC20 public immutable weth;
    // Registry
    RegistryInterface public immutable registry;
    // Fee account
    address public feeAccount;
    // Fee in basis points (10 bps = 0.1%)
    BasisPoint public fee = MAX_FEE;
    // maker => tokenId => [price, expiry]
    mapping(address => mapping(uint => mapping(Action => Record))) public orders;

    /// @dev Order added by `account` to `action` `id` at `price` before expiry, at `timestamp`
    event Order(address indexed account, Action action, uint indexed id, Price indexed price, uint count, Unixtime expiry, Unixtime timestamp);
    /// @dev Order updated for `account` to `action` `id` at `price` before expiry, at `timestamp`
    event OrderUpdated(address indexed account, Action action, uint indexed id, Price indexed price, uint count, Unixtime expiry, Unixtime timestamp);
    /// @dev Order deleted for `account` to `action` `id` at `price` before expiry, at `timestamp`
    event OrderDeleted(address indexed account, Action action, uint indexed id, Price indexed price, Unixtime timestamp);
    /// @dev `account` trade with `counterparty` `action` `tokenId` at `price`, at `timestamp`
    event Trade(address indexed account, address indexed counterparty, Action action, uint indexed tokenId, uint collectionId, uint price, Unixtime timestamp);
    /// @dev `tokenIds` bulk transferred from `from` to `to`, at `timestamp`
    event BulkTransferred(address indexed from, address indexed to, uint[] tokenIds, Unixtime timestamp);
    /// @dev Fee account updated from `oldFeeAccount` to `newFeeAccount`, at `timestamp`
    event FeeAccountUpdated(address indexed oldFeeAccount, address indexed newFeeAccount, Unixtime timestamp);
    /// @dev Fee in basis points updated from `oldFee` to `newFee`, at `timestamp`
    event FeeUpdated(BasisPoint indexed oldFee, BasisPoint indexed newFee, Unixtime timestamp);

    error InvalidOrderCount(uint index, uint count, uint maxCount);
    error InvalidOrderPrice(uint index, Price price, Price maxPrice);
    error SellerDoesNotOwnToken(uint tokenId, address tokenOwner, address orderOwner);
    error OrderExpired(uint tokenId, Unixtime expiry);
    error OrderInvalid(uint tokenId, address account);
    error CannotSelfTrade(uint tokenId);
    error PriceMismatch(uint tokenId, Price orderPrice, Price tradePrice);
    error TakerHasInsufficientEth(uint tokenId, uint required, uint available);
    error MakerHasInsufficientWeth(address bidder, uint tokenId, uint required, uint available);
    error BuyerHasInsufficientWeth(address buyer, uint tokenId, uint required, uint available);
    error InvalidFeeAccount();
    error InvalidFee(BasisPoint fee, BasisPoint maxFee);
    error OnlyTokenOwnerCanTransfer();

    constructor(ERC20 _weth, RegistryInterface _registry) {
        weth = _weth;
        registry = _registry;
        feeAccount = msg.sender;
    }

    /// @dev Execute Offer, Bid, Buy and Sell orders
    /// @param inputs [[action, account, tokenId, price, count, expiry]]
    /// @param uiFeeAccount Fee account that will receive half of the fees if non-null
    function execute(Input[] calldata inputs, address uiFeeAccount) public {
        for (uint i = 0; i < inputs.length; i = onePlus(i)) {
            Input memory input = inputs[i];
            Action baseAction = (uint(input.action) <= uint(Action.Sell)) ? input.action : Action(uint(input.action) - 4);
            // Offer, Bid, CollectionOffer & CollectionBid
            if (baseAction == Action.Offer || baseAction == Action.Bid) {
                if (Price.unwrap(input.price) > Price.unwrap(MAX_ORDER_PRICE)) {
                    revert InvalidOrderPrice(i, input.price, MAX_ORDER_PRICE);
                }
                if (input.action == Action.Offer || input.action == Action.Bid) {
                    if (input.count != 1) {
                        revert InvalidOrderCount(i, input.count, 1);
                    }
                } else {
                    if (input.count == 0 || input.count > MAX_ORDER_COUNT) {
                        revert InvalidOrderCount(i, input.count, MAX_ORDER_COUNT);
                    }
                }
                orders[msg.sender][input.id][input.action] = Record(input.price, uint64(input.count), input.expiry);
                emit Order(msg.sender, input.action, input.id, input.price, input.count, input.expiry, Unixtime.wrap(uint64(block.timestamp)));
            // Buy, Sell, CollectionBuy, CollectionSell
            } else {
                if (msg.sender == input.counterparty) {
                    revert CannotSelfTrade(input.id);
                }
                uint collectionId = registry.getCollectionId(input.id);
                // Buy => Offer; Sell => Bid; CollectionBuy => CollectionOffer; CollectionSell => CollectionBid
                Action matchingOrderAction = Action(uint(input.action) - 2);
                uint matchingOrderId = (input.action == Action.Buy || input.action == Action.Sell) ? input.id : collectionId;
                Record storage order = orders[input.counterparty][matchingOrderId][matchingOrderAction];
                // TODO: Want to allow expiry to be zero. Use count as the indicator?
                if (Unixtime.unwrap(order.expiry) == 0) {
                    revert OrderInvalid(matchingOrderId, input.counterparty);
                } else if (Unixtime.unwrap(order.expiry) < block.timestamp) {
                    revert OrderExpired(matchingOrderId, order.expiry);
                }
                // Want to allow price to be 0
                uint orderPrice = Price.unwrap(order.price);
                if (orderPrice != Price.unwrap(input.price)) {
                    revert PriceMismatch(input.id, Price.wrap(uint96(orderPrice)), input.price);
                }
                (address buyer, address seller) = baseAction == Action.Buy ? (msg.sender, input.counterparty) : (input.counterparty, msg.sender);
                address tokenOwner = registry.ownerOf(input.id);
                if (seller != tokenOwner) {
                    revert SellerDoesNotOwnToken(input.id, tokenOwner, seller);
                }
                uint available = availableWeth(buyer);
                if (available < orderPrice) {
                    revert BuyerHasInsufficientWeth(buyer, input.id, orderPrice, available);
                }
                if (order.count > 1) {
                    order.count--;
                    emit OrderUpdated(input.counterparty, matchingOrderAction, matchingOrderId, Price.wrap(uint96(orderPrice)), order.count, order.expiry, Unixtime.wrap(uint64(block.timestamp)));
                } else {
                    delete orders[input.counterparty][matchingOrderId][matchingOrderAction];
                    emit OrderDeleted(input.counterparty, matchingOrderAction, matchingOrderId, Price.wrap(uint96(orderPrice)), Unixtime.wrap(uint64(block.timestamp)));
                }
                weth.transferFrom(buyer, seller, (orderPrice * (10_000 - BasisPoint.unwrap(fee))) / 10_000);
                if (uiFeeAccount != address(0)) {
                    weth.transferFrom(buyer, feeAccount, (orderPrice * BasisPoint.unwrap(fee)) / 20_000);
                    weth.transferFrom(buyer, uiFeeAccount, (orderPrice * BasisPoint.unwrap(fee)) / 20_000);
                } else {
                    weth.transferFrom(buyer, feeAccount, (orderPrice * BasisPoint.unwrap(fee)) / 10_000);
                }
                registry.transfer(buyer, input.id);
                emit Trade(msg.sender, input.counterparty, input.action, input.id, collectionId, orderPrice, Unixtime.wrap(uint64(block.timestamp)));
            }
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
        emit BulkTransferred(msg.sender, to, tokenIds, Unixtime.wrap(uint64(block.timestamp)));
    }

    /// @dev Update fee account to `newFeeAccount`. Only callable by {owner}
    /// @param newFeeAccount New fee account
    function updateFeeAccount(address newFeeAccount) public onlyOwner {
        if (newFeeAccount == address(0)) {
            revert InvalidFeeAccount();
        }
        emit FeeAccountUpdated(feeAccount, newFeeAccount, Unixtime.wrap(uint64(block.timestamp)));
        feeAccount = newFeeAccount;
    }

    /// @dev Update fee to `newFee`, with a limit of {MAX_FEE}. Only callable by {owner}
    /// @param newFee New fee
    function updateFee(BasisPoint newFee) public onlyOwner {
        if (BasisPoint.unwrap(newFee) > BasisPoint.unwrap(MAX_FEE)) {
            revert InvalidFee(newFee, MAX_FEE);
        }
        emit FeeUpdated(fee, newFee, Unixtime.wrap(uint64(block.timestamp)));
        fee = newFee;
    }

    /// @dev Minimum of WETH balance and spending allowance to this {Exchange} for `account`
    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
}
