// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {HeapUtils} from "src/marketplace/HeapUtils.sol";

abstract contract Auction {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error Auction__AuctionEnded();
    error Auction__AuctionOngoing();
    error Auction__BidNotHighEnough();
    error Auction__AuctionNotFound();
    error Auction__RefundToBidderFailed();
    error Auction__MustBeSeller();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    HeapUtils.AuctionStruct[] internal auctionHeap; // Min-heap to store auctions by endTime
    mapping(uint256 listingItemId => uint256 auctionIdx) internal auctionIndex;
    mapping(uint256 => HeapUtils.AuctionStruct) public endedAuctions;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event AuctionStarted(uint256 indexed listingItemId, uint256 startPrice, uint256 endTime);
    event NewBidPlaced(uint256 indexed listingItemId, address indexed bidder, uint256 bidAmount);
    event AuctionEnded(uint256 indexed listingItemId, address indexed winner, uint256 winningBid);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Start an auction for a specific listing item
     * @param listingItemId The ID of the listing item to be auctioned
     * @param startPrice The starting price of the auction
     * @param duration The duration of the auction in seconds
     */
    function startAuction(uint256 listingItemId, uint256 startPrice, uint256 duration) external virtual {}

    /**
     * @notice End an auction for a specific listing item
     * @param listingItemId The ID of the listing item whose auction is to be ended
     */
    function endAuction(uint256 listingItemId) internal virtual {}

    /**
     * @notice Place a bid on an active auction
     * @param listingItemId The ID of the listing item being bid on
     */
    function placeBid(uint256 listingItemId) external payable virtual {}

    /**
     * @notice Withdraw a previously placed bid if the bidder has been outbid
     */
    function withdrawBid() external virtual {}
}
