    // SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

library HeapUtils {
    /*//////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////*/
    error HeapUtils__AuctionNotFound();
    /*//////////////////////////////////////////////////////////////
                                    TYPES
    //////////////////////////////////////////////////////////////*/

    struct AuctionStruct {
        uint256 listingItemId;
        uint256 startPrice;
        address payable highestBidder;
        uint256 highestBid;
        uint256 endTime;
        bool ended;
    }

    /*//////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Insert a new auction into the heap and maintain the min-heap property
     * @param index The index of the auction to heapify up
     */
    function _heapifyUp(
        AuctionStruct[] storage auctionHeap,
        mapping(uint256 => uint256) storage auctionIndex,
        uint256 index
    ) internal {
        while (index > 0) {
            uint256 parentIndex = (index - 1) / 2;

            if (auctionHeap[parentIndex].endTime <= auctionHeap[index].endTime) {
                break;
            }

            // Swap with parent
            AuctionStruct memory temp = auctionHeap[parentIndex];
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
    function _popAuction(AuctionStruct[] storage auctionHeap, mapping(uint256 => uint256) storage auctionIndex)
        internal
    {
        if (auctionHeap.length == 0) {
            revert HeapUtils__AuctionNotFound();
        }

        // Delete the auction index
        delete auctionIndex[auctionHeap[0].listingItemId];

        // Move the last element to the root and pop the last element
        auctionHeap[0] = auctionHeap[auctionHeap.length - 1]; // Move the last element to the root
        auctionHeap.pop(); // Remove the last element

        // Heapify down the new root element to restore the heap property
        _heapifyDown(auctionHeap, auctionIndex, 0);
    }

    /**
     * @notice Heapify down from the root to maintain the min-heap property
     * @param index The index of the auction to heapify down
     */
    function _heapifyDown(
        AuctionStruct[] storage auctionHeap,
        mapping(uint256 => uint256) storage auctionIndex,
        uint256 index
    ) internal {
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
            AuctionStruct memory temp = auctionHeap[index];
            auctionHeap[index] = auctionHeap[smallest];
            auctionHeap[smallest] = temp;

            // Update the index map
            auctionIndex[auctionHeap[index].listingItemId] = index;
            auctionIndex[auctionHeap[smallest].listingItemId] = smallest;

            index = smallest;
        }
    }
}
