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

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    address payable private immutable i_feeAccount;
    uint256 private immutable i_feePercent;
    uint256 private listingItemCount;

    mapping(uint256 listingItemId => ListingItem listingItem) private listingItems;

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
}
