// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Marketplace} from "src/marketplace/Marketplace.sol";
import {HeapUtils} from "src/marketplace/HeapUtils.sol";
import {Auction} from "src/marketplace/Auction.sol";
import {DeployMarketplace} from "script/DeployMarketplace.s.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Constants} from "../Constants.sol";

contract MarketplaceTest is Test, Constants {
    Marketplace public marketplace;
    DeployMarketplace public deployer;
    MockERC721 public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public buyer2 = makeAddr("buyer2");

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier createListItem() {
        // Ensure the seller is performing both the approval and the listing creation
        vm.startPrank(seller);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), LISTING_ITEM_ID_1);
        // Create the listing
        marketplace.createListingItem(nft, LISTING_ITEM_ID_1, LISTING_PRICE);
        // Stop the prank (stop simulating the seller's actions)
        vm.stopPrank();
        _;
    }

    modifier createMultipleListItems() {
        // Ensure the seller is performing both the approval and the listing creation
        vm.startPrank(seller);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), LISTING_ITEM_ID_1);
        // Create the listing
        marketplace.createListingItem(nft, LISTING_ITEM_ID_1, LISTING_PRICE);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), LISTING_ITEM_ID_2);
        // Create the listing
        marketplace.createListingItem(nft, LISTING_ITEM_ID_2, LISTING_PRICE);
        // Minting a new NFT for the seller
        nft.mint(seller, LISTING_ITEM_ID_3);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), LISTING_ITEM_ID_3);
        // Create the listing
        marketplace.createListingItem(nft, LISTING_ITEM_ID_3, LISTING_PRICE);
        // Stop the prank (stop simulating the seller's actions)
        vm.stopPrank();
        _;
    }

    modifier startAuction() {
        // Ensure the seller is performing both the approval and the listing creation
        vm.startPrank(seller);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), LISTING_ITEM_ID_1);
        // Create the listing
        marketplace.createListingItem(nft, LISTING_ITEM_ID_1, LISTING_PRICE);
        // Start the auction
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        // Stop the prank (stop simulating the seller's actions)
        vm.stopPrank();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function setUp() public {
        // Deploy the mock ERC721 contract
        nft = new MockERC721(); // Deploy the MockERC721 token
        // Deploy the marketplace contract via the deployer script
        deployer = new DeployMarketplace();
        marketplace = deployer.run();
        // Mint an NFT to seller
        vm.startPrank(seller);
        nft.mint(seller, LISTING_ITEM_ID_1);
        nft.mint(seller, LISTING_ITEM_ID_2);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            MARKETPLACE CORE
    //////////////////////////////////////////////////////////////*/
    // Ensure contract is deployed with correct fee percentage and fee account
    function testMarketplaceInitialState() public view {
        assertEq(marketplace.getFeePercent(), FEE_PERCENT);
    }

    // Create a valid listing
    function testCreateListingItem() public createListItem {
        // Retrieve the ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(LISTING_ITEM_ID_1);

        // Assert the listing item is created
        assertEq(listingItem.listingItemId, LISTING_ITEM_ID_1);
        assertEq(address(listingItem.nft), address(nft));
        assertEq(listingItem.tokenId, LISTING_ITEM_ID_1);
        assertEq(listingItem.price, LISTING_PRICE);
        assertEq(listingItem.seller, seller);
        assertEq(listingItem.sold, false);
    }

    // Revert if the listing price is 0
    function testRevertInvalidListingPrice() public {
        vm.prank(seller);
        nft.approve(address(marketplace), LISTING_ITEM_ID_1);
        vm.expectRevert(Marketplace.Marketplace__InvalidPrice.selector);
        marketplace.createListingItem(nft, LISTING_ITEM_ID_1, 0); // Price cannot be zero
    }

    // Purchase a listing successfully
    function testPurchaseListingItem() public createListItem {
        // Buyer purchases the item
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE); // Give buyer some Ether
        marketplace.purchaseListingItem{value: TOTAL_PRICE_WITH_FEE}(LISTING_ITEM_ID_1); // Fee is 2%

        // Retrieve the ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(LISTING_ITEM_ID_1);

        // Assert the item is marked as sold
        assertEq(listingItem.sold, true);

        // Assert NFT ownership transferred to buyer
        assertEq(nft.ownerOf(LISTING_ITEM_ID_1), buyer);
    }

    // Revert if not enough Ether is sent
    function testRevertInsufficientEther() public createListItem {
        // Buyer tries to purchase the item with insufficient Ether
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE); // Give buyer some Ether
        vm.expectRevert(Marketplace.Marketplace__NotEnoughEther.selector);
        marketplace.purchaseListingItem{value: INSUFFICIENT_ETHER}(LISTING_ITEM_ID_1); // Not enough Ether
    }

    // Revert if trying to purchase a sold item
    function testRevertPurchaseAlreadySoldItem() public createListItem {
        // Buyer purchases the item
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE);
        marketplace.purchaseListingItem{value: TOTAL_PRICE_WITH_FEE}(LISTING_ITEM_ID_1);

        // Another buyer tries to purchase the same item, should revert
        vm.prank(buyer2); // Another buyer
        vm.deal(buyer2, BUYER_INITIAL_BALANCE);
        vm.expectRevert(Marketplace.Marketplace__ListingItemAlreadySold.selector);
        marketplace.purchaseListingItem{value: TOTAL_PRICE_WITH_FEE}(LISTING_ITEM_ID_1);
    }

    // Revert if listing item does not exist
    function testRevertListingDoesNotExist() public {
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE);
        vm.expectRevert(Marketplace.Marketplace__ListingItemDoesNotExist.selector);
        marketplace.purchaseListingItem{value: TOTAL_PRICE_WITH_FEE}(INVALID_LISTING_ID); // Invalid listing ID
    }

    // Check fee calculation
    function testFeeCalculation() public createListItem {
        // Assert the total price including the marketplace fee (1.02 ether for 2% fee)
        uint256 totalPrice = marketplace.getTotalPrice(LISTING_ITEM_ID_1);
        assertEq(totalPrice, TOTAL_PRICE_WITH_FEE);
    }

    // Update listing price successfully
    function testUpdateListingPrice() public createListItem {
        // Seller updates the price
        vm.startPrank(seller);
        marketplace.updateListingPrice(LISTING_ITEM_ID_1, UPDATED_PRICE);
        vm.stopPrank();

        // Retrieve the updated ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(LISTING_ITEM_ID_1);

        // Assert the price is updated
        assertEq(listingItem.price, UPDATED_PRICE);
    }

    // Revert if non-seller tries to update price
    function testRevertUpdatePriceByNonSeller() public createListItem {
        // Non-seller tries to update the price
        vm.prank(buyer);
        vm.expectRevert(Marketplace.Marketplace__MustBeSeller.selector);
        marketplace.updateListingPrice(LISTING_ITEM_ID_1, UPDATED_PRICE);
    }

    // Record price history on listing creation and update
    function testPriceHistory() public createListItem {
        // Retrieve the price history
        Marketplace.PriceHistory[] memory history = marketplace.getPriceHistory(LISTING_ITEM_ID_1);

        // Assert the initial price is recorded
        assertEq(history.length, 1);
        assertEq(history[0].price, LISTING_PRICE);

        // Update the price
        vm.startPrank(seller);
        marketplace.updateListingPrice(LISTING_ITEM_ID_1, UPDATED_PRICE);
        vm.stopPrank();

        // Retrieve the updated price history
        history = marketplace.getPriceHistory(LISTING_ITEM_ID_1);

        // Assert the new price is recorded
        assertEq(history.length, 2);
        assertEq(history[1].price, UPDATED_PRICE);
    }

    // Test updating listing price with invalid price
    function testRevertUpdateListingPriceInvalid() public createListItem {
        // Attempt to update the price to zero
        vm.startPrank(seller);
        vm.expectRevert(Marketplace.Marketplace__InvalidPrice.selector);
        marketplace.updateListingPrice(1, 0);
        vm.stopPrank();
    }

    // Revert on creating a listing with unapproved NFT
    function testRevertCreateListingWithoutApproval() public {
        vm.startPrank(seller);
        // Attempt to create a listing without approving the marketplace
        vm.expectRevert();
        marketplace.createListingItem(nft, LISTING_ITEM_ID_1, LISTING_PRICE);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                                 OFFERS
    //////////////////////////////////////////////////////////////*/
    // Make an offer successfully
    function testMakeOffer() public createListItem {
        vm.prank(buyer);
        vm.deal(buyer, OFFER_AMOUNT);
        marketplace.makeOffer{value: OFFER_AMOUNT}(LISTING_ITEM_ID_1, OFFER_AMOUNT);

        // Retrieve the offers
        Marketplace.OfferStruct[] memory offers = marketplace.getOffers(LISTING_ITEM_ID_1);

        // Assert the offer is recorded
        assertEq(offers.length, 1);
        assertEq(offers[OFFER_INDEX].bidder, buyer);
        assertEq(offers[OFFER_INDEX].offerAmount, OFFER_AMOUNT);
    }

    // Accept an offer successfully
    function testAcceptOffer() public createListItem {
        vm.prank(buyer);
        vm.deal(buyer, OFFER_AMOUNT);
        marketplace.makeOffer{value: OFFER_AMOUNT}(LISTING_ITEM_ID_1, OFFER_AMOUNT);

        vm.startPrank(seller);
        marketplace.acceptOffer(LISTING_ITEM_ID_1, OFFER_INDEX);
        vm.stopPrank();

        // Assert the item is marked as sold
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(LISTING_ITEM_ID_1);
        assertEq(listingItem.sold, true);
    }

    // Reject an offer successfully
    function testRejectOffer() public createListItem {
        vm.prank(buyer);
        vm.deal(buyer, OFFER_AMOUNT);
        marketplace.makeOffer{value: OFFER_AMOUNT}(LISTING_ITEM_ID_1, OFFER_AMOUNT);

        vm.startPrank(seller);
        marketplace.rejectOffer(LISTING_ITEM_ID_1, OFFER_INDEX);
        vm.stopPrank();

        // Retrieve the offers
        Marketplace.OfferStruct[] memory offers = marketplace.getOffers(LISTING_ITEM_ID_1);

        // Assert the offer is removed
        assertEq(offers.length, 0);
    }

    // Retract an offer successfully
    function testRetractOffer() public createListItem {
        vm.prank(buyer);
        vm.deal(buyer, OFFER_AMOUNT);
        marketplace.makeOffer{value: OFFER_AMOUNT}(LISTING_ITEM_ID_1, OFFER_AMOUNT);

        vm.prank(buyer);
        marketplace.retractOffer(LISTING_ITEM_ID_1, OFFER_INDEX);

        // Retrieve the offers
        Marketplace.OfferStruct[] memory offers = marketplace.getOffers(LISTING_ITEM_ID_1);

        // Assert the offer is removed
        assertEq(offers.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                                AUCTIONS
    //////////////////////////////////////////////////////////////*/
    // Start an auction successfully
    function testStartAuction() public createListItem {
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        vm.stopPrank();

        // Retrieve the auction details
        HeapUtils.AuctionStruct memory auction = marketplace.getOngoingAuction(LISTING_ITEM_ID_1);

        // Assert the auction is started
        assertEq(auction.listingItemId, LISTING_ITEM_ID_1);
        assertEq(auction.startPrice, LISTING_PRICE);
        assertEq(auction.ended, false);
    }

    // Place a bid successfully
    function testPlaceBid() public startAuction {
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE);
        marketplace.placeBid{value: BID_AMOUNT}(LISTING_ITEM_ID_1);

        // Retrieve the auction details
        HeapUtils.AuctionStruct memory auction = marketplace.getOngoingAuction(LISTING_ITEM_ID_1);

        // Assert the bid is recorded
        assertEq(auction.highestBid, BID_AMOUNT);
        assertEq(auction.highestBidder, buyer);
    }

    // End an auction successfully
    function testEndAuction() public startAuction {
        vm.startPrank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE);
        marketplace.placeBid{value: BID_AMOUNT}(LISTING_ITEM_ID_1);
        vm.stopPrank();
        // Fast forward time to end the auction
        vm.warp(block.timestamp + AUCTION_DURATION_1_DAY + TIME_INCREMENT);

        vm.prank(seller);
        marketplace.performUpkeep(abi.encode(LISTING_ITEM_ID_1));

        // Assert the auction is ended
        HeapUtils.AuctionStruct memory auction = marketplace.getEndedAuction(LISTING_ITEM_ID_1);

        assertEq(auction.ended, true);

        // Assert the item is marked as sold
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(LISTING_ITEM_ID_1);
        assertEq(listingItem.sold, true);
    }

    // Insert auctions and verify heap property
    function testInsertAuctionsAndVerifyHeap() public createMultipleListItems {
        vm.startPrank(seller);
        // Start multiple auctions with different end times
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_3_DAYS);
        marketplace.startAuction(LISTING_ITEM_ID_2, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        marketplace.startAuction(LISTING_ITEM_ID_3, LISTING_PRICE, AUCTION_DURATION_2_DAYS);
        vm.stopPrank();

        // Verify the auction with the earliest end time is at the root
        HeapUtils.AuctionStruct memory rootAuction = marketplace.getOngoingAuction(ROOT_AUCTION_INDEX);
        assertEq(rootAuction.listingItemId, LISTING_ITEM_ID_2); // Auction with 1 day end time should be at root
    }

    // Remove auction and verify heap property
    function testRemoveAuctionAndVerifyHeap() public createMultipleListItems {
        // Start multiple auctions
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_3_DAYS);
        marketplace.startAuction(LISTING_ITEM_ID_2, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        marketplace.startAuction(LISTING_ITEM_ID_3, LISTING_PRICE, AUCTION_DURATION_2_DAYS);
        vm.stopPrank();

        vm.warp(block.timestamp + AUCTION_DURATION_1_DAY + TIME_INCREMENT);
        // Remove the root auction
        vm.prank(seller);
        marketplace.performUpkeep(abi.encode(LISTING_ITEM_ID_2)); // End auction with listingItemId 2

        // Verify the new root auction
        HeapUtils.AuctionStruct memory newRootAuction = marketplace.getOngoingAuction(ROOT_AUCTION_INDEX); // Get the new root auction
        assertEq(newRootAuction.listingItemId, LISTING_ITEM_ID_3); // Auction with 2 days end time should be new root
    }

    // Verify heap property after multiple operations
    function testHeapPropertyAfterMultipleOperations() public createMultipleListItems {
        // Start multiple auctions
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_3_DAYS);
        marketplace.startAuction(LISTING_ITEM_ID_2, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        marketplace.startAuction(LISTING_ITEM_ID_3, LISTING_PRICE, AUCTION_DURATION_2_DAYS);
        vm.stopPrank();

        // Place bids to change auction states
        vm.prank(buyer);
        vm.deal(buyer, BUYER_INITIAL_BALANCE);
        marketplace.placeBid{value: BID_AMOUNT}(LISTING_ITEM_ID_1);

        // End an auction
        vm.warp(block.timestamp + AUCTION_DURATION_1_DAY + TIME_INCREMENT);
        vm.prank(seller);
        marketplace.performUpkeep(abi.encode(LISTING_ITEM_ID_2));

        // Verify the heap property is maintained
        HeapUtils.AuctionStruct memory rootAuction = marketplace.getOngoingAuction(ROOT_AUCTION_INDEX);
        assertEq(rootAuction.listingItemId, LISTING_ITEM_ID_3); // Auction with 2 days end time should be at root
    }

    // Verify auction ending with no bids
    function testEndAuctionNoBids() public createListItem {
        // Start an auction
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        vm.stopPrank();

        // Advance time to end the auction
        vm.warp(block.timestamp + AUCTION_DURATION_2_DAYS);

        // End the auction
        vm.prank(seller);
        marketplace.performUpkeep(abi.encode(LISTING_ITEM_ID_1));

        // Assert the auction is ended and no highest bidder
        HeapUtils.AuctionStruct memory auction = marketplace.getEndedAuction(LISTING_ITEM_ID_1);
        assertEq(auction.ended, true);
        assertEq(auction.highestBidder, address(0));
    }

    // Revert on starting auction with unapproved NFT
    function testRevertStartAuctionWithoutApproval() public {
        vm.startPrank(seller);
        // Attempt to start an auction without approving the marketplace
        vm.expectRevert();
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        vm.stopPrank();
    }

    // Revert on placing a bid lower than start price
    function testRevertPlaceBidLowerThanStartPrice() public createListItem {
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        vm.stopPrank();

        vm.prank(buyer);
        vm.deal(buyer, INSUFFICIENT_ETHER);
        // Attempt to place a bid lower than the starting price
        vm.expectRevert(Auction.Auction__BidNotHighEnough.selector);
        marketplace.placeBid{value: INSUFFICIENT_ETHER}(LISTING_ITEM_ID_1);
    }

    // Revert on ending auction before time
    function testRevertEndAuctionBeforeTime() public createListItem {
        vm.startPrank(seller);
        marketplace.startAuction(LISTING_ITEM_ID_1, LISTING_PRICE, AUCTION_DURATION_1_DAY);
        vm.stopPrank();

        // Attempt to end the auction before its end time
        vm.prank(seller);
        vm.expectRevert();
        marketplace.performUpkeep(abi.encode(LISTING_ITEM_ID_1));
    }
}
