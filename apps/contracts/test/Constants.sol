// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

abstract contract Constants {
    uint256 public constant FEE_PERCENT = 2;
    uint256 public constant LISTING_PRICE = 1 ether;
    uint256 public constant UPDATED_PRICE = 2 ether;
    uint256 public constant BID_AMOUNT = 1.5 ether;
    uint256 public constant AUCTION_DURATION_1_DAY = 1 days;
    uint256 public constant AUCTION_DURATION_2_DAYS = 2 days;
    uint256 public constant AUCTION_DURATION_3_DAYS = 3 days;
    uint256 public constant INVALID_LISTING_ID = 999;
    uint256 public constant INSUFFICIENT_ETHER = 0.5 ether;
    uint256 public constant TOTAL_PRICE_WITH_FEE = 1.02 ether;
    uint256 public constant BUYER_INITIAL_BALANCE = 2 ether;
    uint256 public constant OFFER_AMOUNT = 1 ether;
    uint256 public constant TIME_INCREMENT = 1;
    uint256 public constant LISTING_ITEM_ID_1 = 1;
    uint256 public constant LISTING_ITEM_ID_2 = 2;
    uint256 public constant LISTING_ITEM_ID_3 = 3;
    uint256 public constant OFFER_INDEX = 0;
    uint256 public constant ROOT_AUCTION_INDEX = 0;
}
