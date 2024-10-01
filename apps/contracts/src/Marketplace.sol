// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Marketplace Contract
 * @author Ricardo Rojas
 * @notice This contract allows users to list and purchase NFTs
 * @dev Inherits from ReentrancyGuard to prevent reentrancy attacks
 */
contract Marketplace is ReentrancyGuard {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Marketplace__InvalidPrice();
    error Marketplace__ListingItemDoesNotExist();
    error Marketplace__ListingItemAlreadySold();
    error Marketplace__NotEnoughEther();
    error Marketplace__PaymentToSellerFailed();
    error Marketplace__PaymentOfFeeFailed();
    error Marketplace__MustBeSeller();
    error Marketplace__MustBeBidder();
    error Marketplace__RefundToBidderFailed();
    error Marketplace__AuctionEnded();
    error Marketplace__AuctionOngoing();
    error Marketplace__BidNotHighEnough();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/
    struct ListingItem {
        uint256 listingItemId;
        IERC721 nft;
        uint256 tokenId;
        uint256 price;
        address payable seller;
        bool sold;
    }

    struct Offer {
        address bidder;
        uint256 offerAmount;
    }

    struct PriceHistory {
        uint256 price;
        uint256 timestamp;
    }

    struct Auction {
        uint256 startPrice;
        address payable highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool ended;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address payable private immutable i_feeAccount;
    uint256 private immutable i_feePercent;
    uint256 private listingItemCount;
    address private constant ZERO_ADDRESS = address(0);

    mapping(uint256 listingItemId => ListingItem listingItem) private listingItems;
    mapping(uint256 => Offer[]) public offers;
    mapping(uint256 => PriceHistory[]) public priceHistories;
    mapping(uint256 => Auction) public auctions;
    mapping(address => uint256) public pendingReturns;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event ListingItemCreated(
        uint256 listingItemId, address indexed nft, uint256 tokenId, uint256 price, address indexed seller
    );

    event ListingItemPurchased(
        uint256 listingItemId,
        address indexed nft,
        uint256 tokenId,
        uint256 price,
        address indexed seller,
        address indexed buyer
    );

    event ListingItemPriceUpdated(uint256 indexed listingItemId, uint256 newPrice, address indexed seller);
    event AuctionStarted(uint256 indexed listingItemId, uint256 startPrice, uint256 endTime);
    event NewBidPlaced(uint256 indexed listingItemId, address indexed bidder, uint256 bidAmount);
    event AuctionEnded(uint256 indexed listingItemId, address indexed winner, uint256 winningBid);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to initialize the marketplace with a fee percentage
     * @param feePercent The percentage fee taken by the marketplace
     */
    constructor(uint256 feePercent) {
        i_feeAccount = payable(msg.sender);
        i_feePercent = feePercent;
    }

    receive() external payable {}

    fallback() external payable {}

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to create a new listing item
     * @param nft The NFT
     * @param tokenId The token ID of the NFT
     * @param price The price of the listing item
     * @dev Transfers the NFT from the seller to the marketplace contract
     */
    function createListingItem(IERC721 nft, uint256 tokenId, uint256 price) external nonReentrant {
        if (price == 0) {
            revert Marketplace__InvalidPrice();
        }
        // Increment listingItemCount
        listingItemCount++;
        // Transfer the NFT from the seller to the marketplace contract
        nft.transferFrom(msg.sender, address(this), tokenId);
        // Add the new listing item to the listingItems mapping
        listingItems[listingItemCount] = ListingItem(listingItemCount, nft, tokenId, price, payable(msg.sender), false);
        // Add the price to the priceHistories mapping
        priceHistories[listingItemCount].push(PriceHistory({price: price, timestamp: block.timestamp}));
        // Emit the ListingItemCreated event
        emit ListingItemCreated(listingItemCount, address(nft), tokenId, price, msg.sender);
    }

    /**
     * @notice Function to purchase a listing item
     * @param listingItemId The unique ID of the listing item
     * @dev Transfers the NFT from the marketplace contract to the buyer
     */
    function purchaseListingItem(uint256 listingItemId) external payable nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];
        uint256 totalPrice = getTotalPrice(listingItemId);

        if (listingItem.sold) {
            revert Marketplace__ListingItemAlreadySold();
        }

        if (msg.value < totalPrice) {
            revert Marketplace__NotEnoughEther();
        }

        if (listingItemId == 0 || listingItemId > listingItemCount) {
            revert Marketplace__ListingItemDoesNotExist();
        }

        // Pay the seller
        (bool successSeller,) = listingItem.seller.call{value: listingItem.price}("");
        if (!successSeller) {
            revert Marketplace__PaymentToSellerFailed();
        }

        // Pay the marketplace fee
        uint256 feeAmount = totalPrice - listingItem.price;
        if (feeAmount > 0) {
            (bool successFee,) = i_feeAccount.call{value: feeAmount}("");
            if (!successFee) {
                revert Marketplace__PaymentOfFeeFailed();
            }
        }

        listingItem.sold = true;

        // Transfer the NFT to the buyer
        listingItem.nft.transferFrom(address(this), msg.sender, listingItem.tokenId);

        emit ListingItemPurchased(
            listingItemId,
            address(listingItem.nft),
            listingItem.tokenId,
            listingItem.price,
            listingItem.seller,
            msg.sender
        );
    }

    /**
     * @notice Function to update the price of a listing item
     * @param listingItemId The unique ID of the listing item
     * @param newPrice The new price for the listing item
     */
    function updateListingPrice(uint256 listingItemId, uint256 newPrice) external nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];

        // Ensure only the seller can update the price
        if (listingItem.seller != msg.sender) {
            revert Marketplace__MustBeSeller();
        }

        // Ensure the new price is valid
        if (newPrice == 0) {
            revert Marketplace__InvalidPrice();
        }

        // Update the price
        listingItem.price = newPrice;

        // Add the new price to the priceHistories mapping
        priceHistories[listingItemId].push(PriceHistory({price: newPrice, timestamp: block.timestamp}));

        // Emit an event to log the price update
        emit ListingItemPriceUpdated(listingItemId, newPrice, listingItem.seller);
    }

    /**
     * @notice Function to make an offer on a listing item
     * @param listingItemId The ID of the listing item
     * @param offerAmount The amount of the offer
     */
    function makeOffer(uint256 listingItemId, uint256 offerAmount) external payable nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];

        if (listingItem.sold) {
            revert Marketplace__ListingItemAlreadySold();
        }

        if (msg.value != offerAmount) {
            revert Marketplace__NotEnoughEther();
        }

        // Store the offer
        offers[listingItemId].push(Offer({bidder: msg.sender, offerAmount: offerAmount}));
    }

    /**
     * @notice Function to accept an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to accept
     */
    function acceptOffer(uint256 listingItemId, uint256 offerIndex) external nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];

        if (listingItem.seller != msg.sender) {
            revert Marketplace__MustBeSeller();
        }

        if (listingItem.sold) {
            revert Marketplace__ListingItemAlreadySold();
        }

        Offer memory offer = offers[listingItemId][offerIndex];
        uint256 offeredAmount = offer.offerAmount;
        uint256 feeAmount = (offeredAmount * i_feePercent) / 100; // Calculate the fee amount
        uint256 offeredAmountAfterFee = offeredAmount - feeAmount;
        // Pay the seller
        (bool successSeller,) = listingItem.seller.call{value: offeredAmountAfterFee}("");
        if (!successSeller) {
            revert Marketplace__PaymentToSellerFailed();
        }
        (bool successFee,) = i_feeAccount.call{value: feeAmount}("");
        if (!successFee) {
            revert Marketplace__PaymentOfFeeFailed();
        }

        // Transfer the NFT to the bidder
        listingItem.nft.transferFrom(address(this), offer.bidder, listingItem.tokenId);

        listingItem.sold = true;

        // Remove the offer
        delete offers[listingItemId][offerIndex];

        emit ListingItemPurchased(
            listingItemId,
            address(listingItem.nft),
            listingItem.tokenId,
            offeredAmountAfterFee,
            listingItem.seller,
            offer.bidder
        );
    }

    /**
     * @notice Function to reject an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to reject
     */
    function rejectOffer(uint256 listingItemId, uint256 offerIndex) external nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];

        if (listingItem.seller != msg.sender) {
            revert Marketplace__MustBeSeller();
        }

        Offer memory offer = offers[listingItemId][offerIndex];

        // Refund the bidder
        (bool successRefund,) = offer.bidder.call{value: offer.offerAmount}("");
        if (!successRefund) {
            revert Marketplace__RefundToBidderFailed();
        }

        // Remove the offer
        delete offers[listingItemId][offerIndex];
    }

    /**
     * @notice Function to retract an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to retract
     */
    function retractOffer(uint256 listingItemId, uint256 offerIndex) external nonReentrant {
        // Ensure the offer exists and is not already accepted
        Offer memory offer = offers[listingItemId][offerIndex];

        if (offer.bidder != msg.sender) {
            revert Marketplace__MustBeBidder();
        }

        // Refund the bidder
        (bool successRefund,) = offer.bidder.call{value: offer.offerAmount}("");
        if (!successRefund) {
            revert Marketplace__RefundToBidderFailed();
        }

        // Remove the offer
        delete offers[listingItemId][offerIndex];
    }

    /*//////////////////////////////////////////////////////////////
                           AUCTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Start an auction for a listing item
     * @param listingItemId The ID of the listing item
     * @param startPrice The starting price of the auction
     * @param duration The duration of the auction (in seconds)
     */
    function startAuction(uint256 listingItemId, uint256 startPrice, uint256 duration) external nonReentrant {
        ListingItem storage listingItem = listingItems[listingItemId];

        if (listingItem.seller != msg.sender) {
            revert Marketplace__MustBeSeller();
        }

        auctions[listingItemId] = Auction({
            startPrice: startPrice,
            highestBidder: payable(ZERO_ADDRESS),
            highestBid: 0,
            endTime: block.timestamp + duration,
            ended: false
        });

        emit AuctionStarted(listingItemId, startPrice, auctions[listingItemId].endTime);
    }

    /**
     * @notice End an auction and transfer the NFT to the highest bidder
     * @param listingItemId The ID of the listing item being auctioned
     */
    function endAuction(uint256 listingItemId) external nonReentrant {
        Auction storage auction = auctions[listingItemId];
        ListingItem storage listingItem = listingItems[listingItemId];

        if (block.timestamp < auction.endTime) {
            revert Marketplace__AuctionOngoing();
        }

        if (auction.ended) {
            revert Marketplace__AuctionEnded();
        }

        auction.ended = true;

        if (auction.highestBidder != ZERO_ADDRESS) {
            uint256 feeAmount = (auction.highestBid * i_feePercent) / 100;
            uint256 sellerProceeds = auction.highestBid - feeAmount;

            // Transfer proceeds to the seller
            (bool successSeller,) = listingItem.seller.call{value: sellerProceeds}("");
            if (!successSeller) {
                revert Marketplace__PaymentToSellerFailed();
            }

            // Transfer the marketplace fee
            (bool successFee,) = i_feeAccount.call{value: feeAmount}("");
            if (!successFee) {
                revert Marketplace__PaymentOfFeeFailed();
            }

            // Transfer the NFT to the highest bidder
            listingItem.nft.transferFrom(address(this), auction.highestBidder, listingItem.tokenId);

            listingItem.sold = true;

            emit AuctionEnded(listingItemId, auction.highestBidder, auction.highestBid);
        }
    }

    /**
     * @notice Place a bid on an active auction
     * @param listingItemId The ID of the listing item being auctioned
     */
    function placeBid(uint256 listingItemId) external payable nonReentrant {
        Auction storage auction = auctions[listingItemId];

        if (block.timestamp >= auction.endTime) {
            revert Marketplace__AuctionEnded();
        }

        uint256 currentBid = auction.highestBid;

        if (msg.value <= currentBid) {
            revert Marketplace__BidNotHighEnough();
        }

        // Refund the previous highest bidder
        if (auction.highestBidder != ZERO_ADDRESS) {
            pendingReturns[auction.highestBidder] += auction.highestBid;
        }

        // Update the auction with the new highest bid
        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender);

        emit NewBidPlaced(listingItemId, msg.sender, msg.value);
    }

    /**
     * @notice Withdraw a bidder's refundable amount if they have been outbid
     */
    function withdrawBid() external nonReentrant {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;

            (bool success,) = msg.sender.call{value: amount}("");
            if (!success) {
                revert Marketplace__RefundToBidderFailed();
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    EXTERNAL / PUBLIC VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to get the total price of a listing item including the marketplace fee
     * @param listingItemId The unique ID of the listing item
     * @return The total price including the marketplace fee
     */
    function getTotalPrice(uint256 listingItemId) public view returns (uint256) {
        return ((listingItems[listingItemId].price * (100 + i_feePercent)) / 100);
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to get the address of the fee account
     * @return The address of the fee account
     */
    function getFeeAccount() external view returns (address) {
        return i_feeAccount;
    }

    /**
     * @notice Function to get the fee percentage
     * @return The fee percentage
     */
    function getFeePercent() external view returns (uint256) {
        return i_feePercent;
    }

    /**
     * @notice Function to get the total number of listing items
     * @return The total number of listing items
     */
    function getListingItemCount() external view returns (uint256) {
        return listingItemCount;
    }

    /**
     * @notice Function to get a listing item by its ID
     * @param listingItemId The unique ID of the listing item
     * @return The ListingItem struct
     */
    function getListingItem(uint256 listingItemId) external view returns (ListingItem memory) {
        return listingItems[listingItemId];
    }

    /**
     * @notice Function to get the price history of a listing item
     * @param listingItemId The unique ID of the listing item
     * @return An array of PriceHistory structs containing price and timestamp
     */
    function getPriceHistory(uint256 listingItemId) external view returns (PriceHistory[] memory) {
        return priceHistories[listingItemId];
    }

    /**
     * @notice Function to get the offers for a listing item
     * @param listingItemId The unique ID of the listing item
     * @return An array of Offer structs containing bidder and offerAmount
     */
    function getOffers(uint256 listingItemId) external view returns (Offer[] memory) {
        return offers[listingItemId];
    }
}
