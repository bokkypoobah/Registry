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
}


/// @title Exchange
/// @author BokkyPooBah, Bok Consulting Pty Ltd
contract Exchange is Owned {

    enum Action { Offer, Bid, Buy, Sell, CollectionOffer, CollectionBid, CollectionBuy, CollectionSell }

    struct Input {
        Action action;
        address counterparty; // ? Required for Buy And Sell
        uint id; // collectionId for CollectionOffer and CollectionBid, tokenId otherwise
        uint price;
        uint count;
        uint expiry; // ? Required for Offer and Bid
    }
    struct Record {
        uint96 price;
        uint64 count;
        uint64 expiry;
    }

    /// @dev Maximum price in orders
    uint private constant MAX_PRICE = 1_000_000 ether;
    /// @dev Maximum count in orders
    uint private constant MAX_COUNT = 1000000;
    /// @dev Maximum fee in basis points (10 bps = 0.1%)
    uint private constant MAX_FEE = 10;

    // WETH
    ERC20 public immutable weth;
    // Registry
    RegistryInterface public immutable registry;
    // Fee account
    address public feeAccount;
    // Fee in basis points (10 bps = 0.1%)
    uint public fee = MAX_FEE;
    // maker => tokenId => [price, expiry]
    mapping(address => mapping(uint => mapping(Action => Record))) public orders;

    /// @dev Order by `account` to `action` `id` at `price` before expiry, at `timestamp`
    event Order(address indexed account, Action action, uint indexed id, uint indexed price, uint count, uint expiry, uint timestamp);
    /// @dev Order by `account` to `action` `id` at `price` before expiry, at `timestamp`
    event OrderUpdated(address indexed account, Action action, uint indexed id, uint indexed price, uint count, uint expiry, uint timestamp);
    /// @dev Order by `account` to `action` `id` at `price` before expiry, at `timestamp`
    event OrderDeleted(address indexed account, Action action, uint indexed id, uint indexed price, uint timestamp);
    /// @dev `account` trade with `counterparty` `action` `tokenId` at `price`, at `timestamp`
    event Trade(address indexed account, address indexed counterparty, Action action, uint indexed tokenId, uint collectionId, uint price, uint timestamp);
    /// @dev `tokenIds` bulk transferred from `from` to `to`, at `timestamp`
    event BulkTransferred(address indexed from, address indexed to, uint[] tokenIds, uint timestamp);
    /// @dev Fee account updated from `oldFeeAccount` to `newFeeAccount`, at `timestamp`
    event FeeAccountUpdated(address indexed oldFeeAccount, address indexed newFeeAccount, uint timestamp);
    /// @dev Fee in basis points updated from `oldFee` to `newFee`, at `timestamp`
    event FeeUpdated(uint indexed oldFee, uint indexed newFee, uint timestamp);

    error InvalidCount(uint index, uint count, uint maxCount);
    error InvalidPrice(uint index, uint price, uint maxPrice);
    error SellerDoesNotOwnToken(uint tokenId, address tokenOwner, address orderOwner);
    error OrderExpired(uint tokenId, uint expiry);
    error OrderInvalid(uint tokenId, address account);
    error CannotSelfTrade(uint tokenId);
    error PriceMismatch(uint tokenId, uint orderPrice, uint purchasePrice);
    error TakerHasInsufficientEth(uint tokenId, uint required, uint available);
    error MakerHasInsufficientWeth(address bidder, uint tokenId, uint required, uint available);
    error BuyerHasInsufficientWeth(address buyer, uint tokenId, uint required, uint available);
    error InvalidFeeAccount();
    error InvalidFee(uint fee, uint maxFee);
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
                if (input.price > MAX_PRICE) {
                    revert InvalidPrice(i, input.price, MAX_PRICE);
                }
                if (input.action == Action.Offer || input.action == Action.Bid) {
                    if (input.count != 1) {
                        revert InvalidCount(i, input.count, 1);
                    }
                } else {
                    if (input.count == 0 || input.count > MAX_COUNT) {
                        revert InvalidCount(i, input.count, MAX_COUNT);
                    }
                }
                orders[msg.sender][input.id][input.action] = Record(uint96(input.price), uint64(input.count), uint64(input.expiry));
                emit Order(msg.sender, input.action, input.id, input.price, input.count, input.expiry, block.timestamp);
            // Buy, Sell, CollectionBuy, CollectionSell
            } else {
                if (msg.sender == input.counterparty) {
                    revert CannotSelfTrade(input.id);
                }
                // Buy => Offer; Sell => Bid; CollectionBuy => CollectionOffer; CollectionSell => CollectionBid
                Action matchingAction = Action(uint(input.action) - 2);
                uint collectionId = registry.getCollectionId(input.id);
                uint matchingId = (input.action == Action.Buy || input.action == Action.Sell) ? input.id : collectionId;
                Record storage order = orders[input.counterparty][matchingId][matchingAction];
                if (order.expiry == 0) {
                    revert OrderInvalid(matchingId, input.counterparty);
                } else if (order.expiry < block.timestamp) {
                    revert OrderExpired(matchingId, order.expiry);
                }
                uint orderPrice = uint(order.price);
                if (orderPrice != input.price) {
                    revert PriceMismatch(input.id, orderPrice, input.price);
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
                    emit OrderUpdated(input.counterparty, matchingAction, matchingId, orderPrice, order.count, order.expiry, block.timestamp);
                } else {
                    delete orders[input.counterparty][matchingId][matchingAction];
                    emit OrderDeleted(input.counterparty, matchingAction, matchingId, orderPrice, block.timestamp);
                }
                weth.transferFrom(buyer, seller, (orderPrice * (10_000 - fee)) / 10_000);
                if (uiFeeAccount != address(0)) {
                    weth.transferFrom(buyer, feeAccount, (orderPrice * fee) / 20_000);
                    weth.transferFrom(buyer, uiFeeAccount, (orderPrice * fee) / 20_000);
                } else {
                    weth.transferFrom(buyer, feeAccount, (orderPrice * fee) / 10_000);
                }
                registry.transfer(buyer, input.id);
                emit Trade(msg.sender, input.counterparty, input.action, input.id, collectionId, orderPrice, block.timestamp);
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
        emit BulkTransferred(msg.sender, to, tokenIds, block.timestamp);
    }

    /// @dev Update fee account to `newFeeAccount`. Only callable by {owner}
    /// @param newFeeAccount New fee account
    function updateFeeAccount(address newFeeAccount) public onlyOwner {
        if (newFeeAccount == address(0)) {
            revert InvalidFeeAccount();
        }
        emit FeeAccountUpdated(feeAccount, newFeeAccount, block.timestamp);
        feeAccount = newFeeAccount;
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

    /// @dev Minimum of WETH balance and spending allowance to this {Exchange} for `account`
    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
}
