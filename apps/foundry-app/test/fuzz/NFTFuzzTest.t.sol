// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT} from "src/NFT.sol";

contract NFTFuzzTest is Test {
    NFT public nft;
    address public USER = makeAddr("user");

    function setUp() public {
        nft = new NFT();
    }

    /*//////////////////////////////////////////////////////////////
                           FUZZ TESTING FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Fuzz test minting with random URIs.
     * Test with various random URIs to check the mintNft function.
     */
    function testFuzzMintNft(string memory tokenUri) public {
        // Avoid empty URIs and long URIs that exceed gas limits
        vm.assume(bytes(tokenUri).length > 0 && bytes(tokenUri).length < 2000);

        // Get the current token counter before minting
        uint256 tokenId = nft.getTokenCounter();

        // Mint the NFT
        vm.prank(USER);
        nft.mintNft(tokenUri);

        // Ensure the minted token is assigned correctly
        assertEq(nft.ownerOf(tokenId), USER); // Check the owner is the minter
        assertEq(nft.tokenURI(tokenId), tokenUri); // Check the URI is set correctly
    }

    /**
     * @dev Fuzz test minting and validating tokenURIs with edge case inputs.
     * Ensure that even random strings generate valid NFTs and tokenURIs.
     */
    function testFuzzTokenURIMintAndRetrieve(string memory tokenUri) public {
        // Assume non-empty URI and sensible size
        vm.assume(bytes(tokenUri).length > 0 && bytes(tokenUri).length < 500);

        // Mint NFT and retrieve token ID
        vm.prank(USER);
        nft.mintNft(tokenUri);
        uint256 tokenId = nft.getTokenCounter() - 1;

        // Retrieve token URI
        string memory retrievedUri = nft.tokenURI(tokenId);

        // Assert that the URI matches the one given during minting
        assertEq(retrievedUri, tokenUri);
    }

    /**
     * @dev Fuzz test minting with various numbers of NFTs.
     * This checks if the contract can handle minting many NFTs in sequence.
     */
    function testFuzzMintMultipleNFTs(uint256 numTokens, string memory baseUri) public {
        // Limit the number of NFTs minted in one go for gas limits
        vm.assume(numTokens > 0 && numTokens <= 1000);
        vm.assume(bytes(baseUri).length > 0 && bytes(baseUri).length < 1000);

        for (uint256 i = 0; i < numTokens; i++) {
            address minter = address(uint160(uint256(uint160(USER)) + i));
            string memory tokenUri = string(abi.encodePacked(baseUri, uint2str(i)));
            vm.prank(minter);
            nft.mintNft(tokenUri);

            // Verify ownership and URI for each minted NFT
            uint256 tokenId = nft.getTokenCounter() - 1;
            assertEq(nft.ownerOf(tokenId), minter); // Check ownership
            assertEq(nft.tokenURI(tokenId), tokenUri); // Check token URI
        }
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Helper function to convert uint to string (for URI generation).
     */
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
