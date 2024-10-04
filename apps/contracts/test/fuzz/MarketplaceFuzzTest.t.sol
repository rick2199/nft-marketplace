// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Marketplace} from "src/marketplace/Marketplace.sol";
import {HeapUtils} from "src/marketplace/HeapUtils.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {Constants} from "../Constants.sol";

contract MarketplaceFuzzTest is Test, Constants {
    Marketplace public marketplace;
    MockERC721 public nft;

    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

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

    function setUp() public {
        nft = new MockERC721();

        marketplace = new Marketplace(FEE_PERCENT);

        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(seller);
            nft.mint(seller, i);
        }
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Tests creating listings with random token IDs and prices.
     * @dev Assumes tokenId is valid and has been minted. Ensures price is greater than 0.
     * @param tokenId The ID of the token to list.
     * @param price The price at which the token is listed.
     */
    function testFuzzCreateListingItem(uint256 tokenId, uint256 price) public {
        // Assume tokenId is valid and has been minted
        vm.assume(tokenId == 1 || tokenId == 2);
        vm.assume(price > 0); // Ensure price is greater than 0

        // Seller approves the marketplace and creates a listing
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.createListingItem(nft, tokenId, price);
        vm.stopPrank();

        // Retrieve the listing and validate it was created correctly
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(1);
        assertEq(listingItem.tokenId, tokenId);
        assertEq(listingItem.price, price);
        assertEq(listingItem.seller, seller);
        assertEq(listingItem.sold, false);
    }

    /**
     * @notice Tests purchasing a listing with random Ether amounts.
     * @dev Tests various Ether values to simulate potential underpayments and overpayments.
     * @param tokenId The ID of the token to purchase.
     * @param price The price at which the token is listed.
     * @param payment The amount of Ether used for the purchase.
     */
    function testFuzzPurchaseListingItem(uint256 tokenId, uint256 price, uint256 payment) public {
        // Assume valid tokenId
        vm.assume(tokenId == 1 || tokenId == 2);

        // Bound the price within a reasonable range (e.g., 1000 wei to 1 ether)
        price = bound(price, 1000, 1e18); // Price between 1000 wei and 1 ether

        // Bound the payment to be between price and price + 10%
        payment = bound(payment, price, price + (price / 10)); // Payment between price and 110% of price

        // Seller approves the marketplace and creates a listing
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.createListingItem(nft, tokenId, price);
        vm.stopPrank();

        // Get the total price including the marketplace fee
        uint256 totalPrice = marketplace.getTotalPrice(1);

        // Deal the buyer enough Ether for the payment
        vm.deal(buyer, payment); // Allocate the bounded payment to the buyer

        // Buyer attempts to purchase the listing
        if (payment >= totalPrice) {
            // Prank the buyer and make the purchase
            vm.prank(buyer);
            try marketplace.purchaseListingItem{value: payment}(1) {
                if (payment == totalPrice) {
                    // Verify the listing is marked as sold and ownership is transferred
                    Marketplace.ListingItem memory listingItem = marketplace.getListingItem(1);
                    assertEq(listingItem.sold, true);
                    assertEq(nft.ownerOf(tokenId), buyer);

                    // Ensure payments to seller and fee account succeed
                    uint256 feeAmount = totalPrice - price;
                    assertEq(address(buyer).balance, payment - totalPrice); // Check buyer's balance after purchase

                    // Check the seller's balance
                    assertEq(address(seller).balance, price);

                    // Check the fee account's balance
                    assertEq(address(marketplace.getFeeAccount()).balance, feeAmount);
                }
            } catch (bytes memory reason) {
                if (
                    keccak256(reason)
                        == keccak256(abi.encodeWithSelector(Marketplace.Marketplace__PaymentToSellerFailed.selector))
                ) {
                    // Assert that the PaymentToSellerFailed error occurred
                    assertEq(
                        keccak256(reason),
                        keccak256(abi.encodeWithSelector(Marketplace.Marketplace__PaymentToSellerFailed.selector)),
                        "Expected PaymentToSellerFailed"
                    );
                } else if (
                    keccak256(reason)
                        == keccak256(abi.encodeWithSelector(Marketplace.Marketplace__PaymentOfFeeFailed.selector))
                ) {
                    // Assert that the PaymentOfFeeFailed error occurred
                    assertEq(
                        keccak256(reason),
                        keccak256(abi.encodeWithSelector(Marketplace.Marketplace__PaymentOfFeeFailed.selector)),
                        "Expected PaymentOfFeeFailed"
                    );
                } else {
                    // Assert that no unexpected error occurred
                    revert("Unexpected error occurred");
                }
            }
        } else {
            // Expect revert if payment is insufficient
            vm.prank(buyer);
            vm.expectRevert(Marketplace.Marketplace__NotEnoughEther.selector);
            marketplace.purchaseListingItem{value: payment}(1); // Use bounded payment here
        }
    }

    /**
     * @notice Tests handling of invalid listing IDs.
     * @dev Assumes listing ID is not valid (not created) and expects a revert.
     * @param listingId The ID of the listing to test.
     */
    function testFuzzInvalidListing(uint256 listingId) public {
        vm.assume(listingId > 100); // Assume listing ID is not valid (not created)

        // Buyer attempts to purchase an invalid listing
        vm.prank(buyer);
        vm.deal(buyer, 2 ether); // Give buyer some Ether
        vm.expectRevert(Marketplace.Marketplace__ListingItemDoesNotExist.selector);
        marketplace.purchaseListingItem{value: 1.02 ether}(listingId); // Try to purchase invalid listing
    }

    /**
     * @notice Tests updating listing price with random values.
     * @dev Assumes the new price is within a reasonable range.
     * @param newPrice The new price to update the listing to.
     */
    function testFuzzUpdateListingPrice(uint256 newPrice) public createListItem {
        // Assume the new price is within a reasonable range
        vm.assume(newPrice > 0 && newPrice < 100 ether);

        // Update the listing price
        vm.prank(seller);
        marketplace.updateListingPrice(1, newPrice);

        // Retrieve the updated ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(1);

        // Assert the price is updated
        assertEq(listingItem.price, newPrice);
    }

    /**
     * @notice Tests making offers with random amounts.
     * @dev Assumes the offer amount is within a reasonable range.
     * @param offerAmount The amount of the offer to make.
     */
    function testFuzzMakeOffer(uint256 offerAmount) public createListItem {
        // Assume the offer amount is within a reasonable range
        vm.assume(offerAmount > 0 && offerAmount < 100 ether);

        // Make an offer
        vm.prank(buyer);
        vm.deal(buyer, offerAmount);
        marketplace.makeOffer{value: offerAmount}(1, offerAmount);

        // Retrieve the offers
        Marketplace.OfferStruct[] memory offers = marketplace.getOffers(1);

        // Assert the offer is recorded
        assertEq(offers.length, 1);
        assertEq(offers[0].bidder, buyer);
        assertEq(offers[0].offerAmount, offerAmount);
    }

    /**
     * @notice Tests recording price history with random new prices.
     * @dev Assumes the new price is within a reasonable range.
     * @param newPrice The new price to update the listing to.
     */
    function testFuzzPriceHistory(uint256 newPrice) public createListItem {
        // Assume the new price is within a reasonable range
        vm.assume(newPrice > 0 && newPrice < 100 ether);

        // Update the listing price
        vm.prank(seller);
        marketplace.updateListingPrice(1, newPrice);

        // Retrieve the price history
        Marketplace.PriceHistory[] memory history = marketplace.getPriceHistory(1);

        // Assert the new price is recorded
        assertEq(history[history.length - 1].price, newPrice);
    }

    /**
     * @notice Tests starting auctions with random durations and prices.
     * @dev Assumes the start price and duration are within reasonable ranges.
     * @param startPrice The starting price of the auction.
     * @param duration The duration of the auction.
     */
    function testFuzzStartAuction(uint256 startPrice, uint256 duration) public createListItem {
        // Assume the start price and duration are within reasonable ranges
        vm.assume(startPrice > 0 && startPrice < 100 ether);
        vm.assume(duration > 1 hours && duration < 30 days);

        // Start an auction
        vm.prank(seller);
        marketplace.startAuction(1, startPrice, duration);

        // Retrieve the auction details
        HeapUtils.AuctionStruct memory auction = marketplace.getOngoingAuction(0);

        // Assert the auction is started with correct parameters
        assertEq(auction.startPrice, startPrice);
        assertEq(auction.endTime, block.timestamp + duration);
    }

    /**
     * @notice Tests placing bids with random amounts.
     * @dev Assumes the bid amount is within a reasonable range.
     * @param bidAmount The amount of the bid to place.
     */
    function testFuzzPlaceBid(uint256 bidAmount) public createListItem {
        // Start an auction
        vm.startPrank(seller);
        marketplace.startAuction(1, 1 ether, 1 days);
        vm.stopPrank();

        // Assume the bid amount is within a reasonable range
        vm.assume(bidAmount > 1 ether && bidAmount < 100 ether);

        // Place a bid
        vm.prank(buyer);
        vm.deal(buyer, bidAmount);
        marketplace.placeBid{value: bidAmount}(1);

        // Retrieve the auction details
        HeapUtils.AuctionStruct memory auction = marketplace.getOngoingAuction(0);

        // Assert the bid is recorded
        assertEq(auction.highestBid, bidAmount);
        assertEq(auction.highestBidder, buyer);
    }

    /**
     * @notice Tests ending auctions with random time advancements.
     * @dev Assumes the time advance is within a reasonable range.
     * @param timeAdvance The amount of time to advance to end the auction.
     */
    function testFuzzEndAuction(uint256 timeAdvance) public createListItem {
        // Start an auction
        vm.startPrank(seller);
        marketplace.startAuction(1, 1 ether, 1 days);
        vm.stopPrank();

        // Assume the time advance is within a reasonable range
        // Adjust the range to ensure more valid inputs
        vm.assume(timeAdvance > 1 days && timeAdvance < 5 days);

        // Advance time to end the auction
        vm.warp(block.timestamp + timeAdvance);

        // End the auction
        vm.prank(seller);
        marketplace.performUpkeep(abi.encode(1));

        // Retrieve the auction details
        HeapUtils.AuctionStruct memory auction = marketplace.getEndedAuction(1);

        // Assert the auction is ended
        assertEq(auction.ended, true);
    }
}
