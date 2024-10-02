// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Marketplace Contract
 * @author Ricardo Rojas
 * @notice This contract allows users to list and purchase NFTs
 * @dev Inherits from ReentrancyGuard to prevent reentrancy attacks
 */
contract Marketplace is ReentrancyGuard, AutomationCompatibleInterface {
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
    error Marketplace__AuctionNotFound();

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
        uint256 listingItemId;
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

    Auction[] private auctionHeap; // Min-heap to store auctions by endTime

    mapping(uint256 listingItemId => ListingItem listingItem) private listingItems;
    mapping(uint256 => Offer[]) public offers;
    mapping(uint256 => PriceHistory[]) public priceHistories;
    mapping(address accountToRefund => uint256 amountToRefund) public pendingReturns;
    mapping(uint256 listingItemId => uint256 auctionIdx) public auctionIndex;

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
        Auction memory newAuction = Auction({
            listingItemId: listingItemId,
            startPrice: startPrice,
            highestBidder: payable(address(0)),
            highestBid: 0,
            endTime: block.timestamp + duration,
            ended: false
        });

        // Insert the auction into the min-heap
        auctionHeap.push(newAuction);
        // Update the auction index mapping
        uint256 index = auctionHeap.length - 1;
        auctionIndex[listingItemId] = index;
        // Heapify up to maintain the min-heap property
        _heapifyUp(index);

        emit AuctionStarted(listingItemId, startPrice, newAuction.endTime);
    }

    /**
     * @notice Chainlink Keeper's checkUpkeep function
     * @dev Only checks the first auction in the linked list (the soonest to expire)
     */
    function checkUpkeep(bytes calldata /* checkData */ )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (auctionHeap.length > 0) {
            Auction memory soonestAuction = auctionHeap[0];

            if (block.timestamp >= soonestAuction.endTime && !soonestAuction.ended) {
                upkeepNeeded = true;
                performData = abi.encode(soonestAuction.listingItemId);
            }
        }
    }

    /**
     * @notice Chainlink Keeper's performUpkeep function
     * @param performData The auction ID to end (encoded by checkUpkeep)
     */
    function performUpkeep(bytes calldata performData) external override nonReentrant {
        uint256 listingItemId = abi.decode(performData, (uint256));
        endAuction(listingItemId);
    }

    /**
     * @notice End an auction and transfer the NFT to the highest bidder
     * @param listingItemId The ID of the listing item being auctioned
     */
    function endAuction(uint256 listingItemId) internal nonReentrant {
        uint256 index = auctionIndex[listingItemId];
        if (index >= auctionHeap.length || auctionHeap[index].listingItemId != listingItemId) {
            revert Marketplace__AuctionNotFound();
        }
        Auction storage auction = auctionHeap[index];
        ListingItem storage listingItem = listingItems[listingItemId];

        if (block.timestamp < auction.endTime) {
            revert Marketplace__AuctionOngoing();
        }

        if (auction.ended) {
            revert Marketplace__AuctionEnded();
        }

        // Mark the auction as ended
        auction.ended = true;

        // Pop the auction from the heap
        _popAuction();

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

            emit ListingItemPurchased(
                listingItemId,
                address(listingItem.nft),
                listingItem.tokenId,
                sellerProceeds,
                listingItem.seller,
                auction.highestBidder
            );
            emit AuctionEnded(listingItemId, auction.highestBidder, auction.highestBid);
        }
    }

    /**
     * @notice Place a bid on an active auction
     * @param listingItemId The ID of the listing item being auctioned
     */
    function placeBid(uint256 listingItemId) external payable nonReentrant {
        // Find the auction by looking up the index in the heap
        uint256 index = auctionIndex[listingItemId];

        // Ensure the index is valid and within bounds
        if (index >= auctionHeap.length) {
            revert Marketplace__AuctionNotFound();
        }

        Auction storage auction = auctionHeap[index];

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

    /**
     * @notice Get the details of an auction by its listing item ID
     * @param listingItemId The ID of the auction to retrieve
     * @return The auction details
     */
    function getAuction(uint256 listingItemId) external view returns (Auction memory) {
        uint256 index = auctionIndex[listingItemId];
        if (index < auctionHeap.length) {
            return auctionHeap[index];
        }
        revert Marketplace__AuctionNotFound();
    }

    /**
     * @notice Get the auction with the soonest end time
     * @return The auction details
     */
    function getSoonestAuction() external view returns (Auction memory) {
        if (auctionHeap.length == 0) {
            revert Marketplace__AuctionNotFound();
        }
        return auctionHeap[0];
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

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////
                     MIN-HEAP OPERATIONS FOR AUCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Insert a new auction into the heap and maintain the min-heap property
     * @param index The index of the auction to heapify up
     */
    function _heapifyUp(uint256 index) internal {
        while (index > 0) {
            uint256 parentIndex = (index - 1) / 2;

            if (auctionHeap[parentIndex].endTime <= auctionHeap[index].endTime) {
                break;
            }

            // Swap with parent
            Auction memory temp = auctionHeap[parentIndex];
            auctionHeap[parentIndex] = auctionHeap[index];
            auctionHeap[index] = temp;

            // Update the auction index mapping
            auctionIndex[auctionHeap[parentIndex].listingItemId] = parentIndex;
            auctionIndex[auctionHeap[index].listingItemId] = index;

            index = parentIndex;
        }
    }

    /**
     * @notice Remove the root auction (soonest ending) and maintain the heap property
     */
    function _popAuction() internal {
        if (auctionHeap.length == 0) {
            revert Marketplace__AuctionNotFound();
        }

        // Delete the auction index
        delete auctionIndex[auctionHeap[0].listingItemId];

        // Move the last element to the root and pop the last element
        auctionHeap[0] = auctionHeap[auctionHeap.length - 1]; // Move the last element to the root
        auctionHeap.pop(); // Remove the last element

        // Heapify down the new root element to restore the heap property
        _heapifyDown(0);
    }

    /**
     * @notice Heapify down from the root to maintain the min-heap property
     * @param index The index of the auction to heapify down
     */
    function _heapifyDown(uint256 index) internal {
        uint256 length = auctionHeap.length;
        uint256 leftChild;
        uint256 rightChild;
        uint256 smallest = index;

        while (true) {
            leftChild = 2 * index + 1;
            rightChild = 2 * index + 2;

            // Find the smallest child
            if (leftChild < length && auctionHeap[leftChild].endTime < auctionHeap[smallest].endTime) {
                smallest = leftChild;
            }

            if (rightChild < length && auctionHeap[rightChild].endTime < auctionHeap[smallest].endTime) {
                smallest = rightChild;
            }

            // If the current node is already in the correct position, exit
            if (smallest == index) {
                break;
            }

            // Swap with the smallest child
            Auction memory temp = auctionHeap[index];
            auctionHeap[index] = auctionHeap[smallest];
            auctionHeap[smallest] = temp;

            // Update the index map
            auctionIndex[auctionHeap[index].listingItemId] = index;
            auctionIndex[auctionHeap[smallest].listingItemId] = smallest;

            index = smallest;
        }
    }
}
