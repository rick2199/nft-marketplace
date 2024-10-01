// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Marketplace} from "src/Marketplace.sol";
import {MockERC721} from "../mocks/MockERC721.sol";

contract MarketplaceFuzzTest is Test {
    Marketplace public marketplace;
    MockERC721 public nft;

    uint256 public feePercent = 2;
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");

    function setUp() public {
        nft = new MockERC721();

        marketplace = new Marketplace(feePercent);

        for (uint256 i = 1; i <= 10; i++) {
            vm.prank(seller);
            nft.mint(seller, i);
        }
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Fuzz test for creating listings with random token IDs and prices.
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
     * @dev Fuzz test for purchasing a listing with random Ether amounts.
     * Tests various Ether values to simulate potential underpayments and overpayments.
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
     * @dev Fuzz test for invalid listing IDs.
     * Tests various invalid IDs to ensure the contract handles them properly.
     */
    function testFuzzInvalidListing(uint256 listingId) public {
        vm.assume(listingId > 100); // Assume listing ID is not valid (not created)

        // Buyer attempts to purchase an invalid listing
        vm.prank(buyer);
        vm.deal(buyer, 2 ether); // Give buyer some Ether
        vm.expectRevert(Marketplace.Marketplace__ListingItemDoesNotExist.selector);
        marketplace.purchaseListingItem{value: 1.02 ether}(listingId); // Try to purchase invalid listing
    }
}
