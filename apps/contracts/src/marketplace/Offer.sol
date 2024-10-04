// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

abstract contract Offer {
    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    error Offer__MustBeSeller();
    error Offer__MustBeBidder();
    error Offer__RefundToBidderFailed();
    error Offer__InvalidOfferIndex();
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct OfferStruct {
        address bidder;
        uint256 offerAmount;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(uint256 => OfferStruct[]) internal offers;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to make an offer on a listing item
     * @param listingItemId The ID of the listing item
     * @param offerAmount The amount of the offer
     */
    function makeOffer(uint256 listingItemId, uint256 offerAmount) external payable virtual {}

    /**
     * @notice Function to accept an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to accept
     */
    function acceptOffer(uint256 listingItemId, uint256 offerIndex) external virtual {}

    /**
     * @notice Function to reject an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to reject
     */
    function rejectOffer(uint256 listingItemId, uint256 offerIndex) external virtual {}

    /**
     * @notice Function to retract an offer for a listing item
     * @param listingItemId The ID of the listing item
     * @param offerIndex The index of the offer to retract
     */
    function retractOffer(uint256 listingItemId, uint256 offerIndex) external virtual {}
}
