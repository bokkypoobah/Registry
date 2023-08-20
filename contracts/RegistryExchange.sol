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

    enum Action { Offer, Bid, Buy, Sell }

    struct Input {
        Action action;
        address account; // Required for Buy And Sell
        uint tokenId;
        uint price;
        uint expiry; // Required for Offer and Bid
    }
    struct Record {
        uint192 price;
        uint64 expiry;
    }

    /// @dev Maximum price in orders
    uint public constant PRICE_MAX = 1_000_000 ether;
    /// @dev Maximum fee in basis points (10 bps = 0.1%)
    uint public constant MAX_FEE = 10;

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


    /// @dev `offers` from `account` to sell `tokenId` at `price`, at `timestamp`
    event Offer(address indexed account, uint indexed tokenId, uint indexed price, uint expiry, uint timestamp);
    /// @dev `bids` from `account` to buy `tokenId` at `price`, at `timestamp`
    event Bid(address indexed account, uint indexed tokenId, uint indexed price, uint expiry, uint timestamp);
    /// @dev `account` bought `tokenId` from `from`, at `timestamp`
    event Bought(address indexed account, address indexed from, uint indexed tokenId, uint price, uint timestamp);
    /// @dev `account` sold `tokenId` to `to`, at `timestamp`
    event Sold(address indexed account, address indexed to, uint indexed tokenId, uint price, uint timestamp);
    /// @dev `tokenIds` bulk transferred from `from` to `to`, at `timestamp`
    event BulkTransferred(address indexed from, address indexed to, uint[] tokenIds, uint timestamp);
    /// @dev Fee account updated from `oldFeeAccount` to `newFeeAccount`, at `timestamp`
    event FeeAccountUpdated(address indexed oldFeeAccount, address indexed newFeeAccount, uint timestamp);
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
    error InvalidFeeAccount();
    error InvalidFee(uint fee, uint maxFee);
    error OnlyTokenOwnerCanTransfer();

    constructor(ERC20 _weth, RegistryInterface _registry) {
        weth = _weth;
        registry = _registry;
        feeAccount = msg.sender;
    }

    /// @dev Execute Offer, Bid, Buy and Sell orders
    /// @param inputs [[action, account, tokenId, price, expiry]]
    /// @param uiFeeAccount Fee account that will receive half of the fees if non-null
    function execute(Input[] calldata inputs, address uiFeeAccount) public {
        for (uint i = 0; i < inputs.length; i = onePlus(i)) {
            Input memory input = inputs[i];
            if (input.action == Action.Offer || input.action == Action.Bid) {
                if (input.price > PRICE_MAX) {
                    revert InvalidPrice(input.price, PRICE_MAX);
                }
                orders[msg.sender][input.tokenId][input.action] = Record(uint192(input.price), uint64(input.expiry));
                if (input.action == Action.Offer) {
                    emit Offer(msg.sender, input.tokenId, input.price, input.expiry, block.timestamp);
                } else if (input.action == Action.Bid) {
                    emit Bid(msg.sender, input.tokenId, input.price, input.expiry, block.timestamp);
                }
            } else if (input.action == Action.Buy || input.action == Action.Sell) {
                if (input.account == msg.sender) {
                    revert CannotSelfTrade(input.tokenId);
                }
                address tokenOwner = registry.ownerOf(input.tokenId);
                if (input.account != tokenOwner) {
                    revert IncorrectOwner(input.tokenId, tokenOwner, input.account);
                }
                Action orderAction = input.action == Action.Buy ? Action.Offer : Action.Bid;
                Record memory order = orders[input.account][input.tokenId][orderAction];
                if (order.expiry == 0) {
                    revert OrderInvalid(input.tokenId, input.account);
                } else if (order.expiry < block.timestamp) {
                    revert OrderExpired(input.tokenId, order.expiry);
                }
                uint orderPrice = uint(order.price);
                if (orderPrice != input.price) {
                    revert PriceMismatch(input.tokenId, orderPrice, input.price);
                }
                if (input.action == Action.Buy) {
                    uint available = availableWeth(msg.sender);
                    if (available < orderPrice) {
                        revert TakerHasInsufficientEth(input.tokenId, orderPrice, available);
                    }
                    delete orders[input.account][input.tokenId][orderAction];
                    weth.transferFrom(msg.sender, input.account, (orderPrice * (10_000 - fee)) / 10_000);
                    if (uiFeeAccount != address(0)) {
                        weth.transferFrom(msg.sender, feeAccount, (orderPrice * fee) / 20_000);
                        weth.transferFrom(msg.sender, uiFeeAccount, (orderPrice * fee) / 20_000);
                    } else {
                        weth.transferFrom(msg.sender, feeAccount, (orderPrice * fee) / 10_000);
                    }
                    registry.transfer(msg.sender, input.tokenId);
                    emit Bought(msg.sender, input.account, input.tokenId, orderPrice, block.timestamp);
                } else if (input.action == Action.Sell) {
                    uint available = availableWeth(input.account);
                    if (available < orderPrice) {
                        revert MakerHasInsufficientWeth(input.account, input.tokenId, orderPrice, available);
                    }
                    delete orders[input.account][input.tokenId][orderAction];
                    weth.transferFrom(input.account, msg.sender, (orderPrice * (10_000 - fee)) / 10_000);
                    if (uiFeeAccount != address(0)) {
                        weth.transferFrom(input.account, feeAccount, (orderPrice * fee) / 20_000);
                        weth.transferFrom(input.account, uiFeeAccount, (orderPrice * fee) / 20_000);
                    } else {
                        weth.transferFrom(input.account, feeAccount, (orderPrice * fee) / 10_000);
                    }
                    registry.transfer(input.account, input.tokenId);
                    emit Sold(msg.sender, input.account, input.tokenId, orderPrice, block.timestamp);
                }
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

    /// @dev Minimum of WETH balance and spending allowance to this {RegistryExchange} for `account`
    function availableWeth(address account) internal view returns (uint tokens) {
        uint allowance = weth.allowance(account, address(this));
        uint balance = weth.balanceOf(account);
        tokens = allowance < balance ? allowance : balance;
    }
}
