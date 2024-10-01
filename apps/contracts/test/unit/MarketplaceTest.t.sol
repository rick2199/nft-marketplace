// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {Marketplace} from "src/Marketplace.sol";
import {DeployMarketplace} from "script/DeployMarketplace.s.sol";
import {MockERC721} from "../mocks/MockERC721.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    DeployMarketplace public deployer;
    MockERC721 public nft;

    uint256 public feePercent = 2;
    address public seller = makeAddr("seller");
    address public buyer = makeAddr("buyer");
    address public buyer2 = makeAddr("buyer2");

    modifier createListItem() {
        // Ensure the seller is performing both the approval and the listing creation
        vm.startPrank(seller);
        // Approve the marketplace to transfer the NFT on behalf of the seller
        nft.approve(address(marketplace), 1);
        // Create the listing
        marketplace.createListingItem(nft, 1, 1 ether);
        // Stop the prank (stop simulating the seller's actions)
        vm.stopPrank();
        _;
    }

    function setUp() public {
        // Deploy the mock ERC721 contract
        nft = new MockERC721(); // Deploy the MockERC721 token
        // Deploy the marketplace contract via the deployer script
        deployer = new DeployMarketplace();
        marketplace = deployer.run();
        // Mint an NFT to seller
        vm.startPrank(seller);
        nft.mint(seller, 1);
        nft.mint(seller, 2);
        vm.stopPrank();
    }

    // Test 1: Ensure contract is deployed with correct fee percentage and fee account
    function testMarketplaceInitialState() public view {
        assertEq(marketplace.getFeePercent(), feePercent);
    }

    // Test 2: Create a valid listing
    function testCreateListingItem() public createListItem {
        // Retrieve the ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(1);

        // Assert the listing item is created
        assertEq(listingItem.listingItemId, 1);
        assertEq(address(listingItem.nft), address(nft));
        assertEq(listingItem.tokenId, 1);
        assertEq(listingItem.price, 1 ether);
        assertEq(listingItem.seller, seller);
        assertEq(listingItem.sold, false);
    }

    // Test 3: Revert if the listing price is 0
    function testRevertInvalidListingPrice() public {
        vm.prank(seller);
        nft.approve(address(marketplace), 1);
        vm.expectRevert(Marketplace.Marketplace__InvalidPrice.selector);
        marketplace.createListingItem(nft, 1, 0); // Price cannot be zero
    }

    // Test 4: Purchase a listing successfully
    function testPurchaseListingItem() public createListItem {
        // Buyer purchases the item
        vm.prank(buyer);
        vm.deal(buyer, 2 ether); // Give buyer some Ether
        marketplace.purchaseListingItem{value: 1.02 ether}(1); // Fee is 2%

        // Retrieve the ListingItem struct
        Marketplace.ListingItem memory listingItem = marketplace.getListingItem(1);

        // Assert the item is marked as sold
        assertEq(listingItem.sold, true);

        // Assert NFT ownership transferred to buyer
        assertEq(nft.ownerOf(1), buyer);
    }

    // Test 5: Revert if not enough Ether is sent
    function testRevertInsufficientEther() public createListItem {
        // Buyer tries to purchase the item with insufficient Ether
        vm.prank(buyer);
        vm.deal(buyer, 2 ether); // Give buyer some Ether
        vm.expectRevert(Marketplace.Marketplace__NotEnoughEther.selector);
        marketplace.purchaseListingItem{value: 0.5 ether}(1); // Not enough Ether
    }

    // Test 6: Revert if trying to purchase a sold item
    function testRevertPurchaseAlreadySoldItem() public createListItem {
        // Buyer purchases the item
        vm.prank(buyer);
        vm.deal(buyer, 2 ether);
        marketplace.purchaseListingItem{value: 1.02 ether}(1);

        // Another buyer tries to purchase the same item, should revert
        vm.prank(buyer2); // Another buyer
        vm.deal(buyer2, 2 ether);
        vm.expectRevert(Marketplace.Marketplace__ListingItemAlreadySold.selector);
        marketplace.purchaseListingItem{value: 1.02 ether}(1);
    }

    // Test 7: Revert if listing item does not exist
    function testRevertListingDoesNotExist() public {
        vm.prank(buyer);
        vm.deal(buyer, 2 ether);
        vm.expectRevert(Marketplace.Marketplace__ListingItemDoesNotExist.selector);
        marketplace.purchaseListingItem{value: 1.02 ether}(999); // Invalid listing ID
    }

    // Test 8: Check fee calculation
    function testFeeCalculation() public createListItem {
        // Assert the total price including the marketplace fee (1.02 ether for 2% fee)
        uint256 totalPrice = marketplace.getTotalPrice(1);
        assertEq(totalPrice, 1.02 ether);
    }
}
