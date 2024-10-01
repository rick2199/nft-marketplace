// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title NFT Contract
 * @author Ricardo Rojas
 * @notice This contract allows users to mint and manage NFTs
 * @dev Inherits from OpenZeppelin's ERC721 implementation
 */
contract NFT is ERC721 {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_tokenCounter;
    mapping(uint256 => string) private s_tokenIdToUri;

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor to initialize the NFT contract with a name and symbol
     */
    constructor() ERC721("RickNft", "RICK") {
        s_tokenCounter = 0;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Function to mint a new NFT
     * @param tokenUri The URI of the token to be minted
     */
    function mintNft(string memory tokenUri) public {
        s_tokenIdToUri[s_tokenCounter] = tokenUri;
        _safeMint(msg.sender, s_tokenCounter);
        s_tokenCounter++;
    }

    /**
     * @notice Function to get the URI of a token by its ID
     * @param tokenId The ID of the token
     * @return The URI of the token
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return s_tokenIdToUri[tokenId];
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Function to get the current token counter
     * @return The current token counter
     */
    function getTokenCounter() public view returns (uint256) {
        return s_tokenCounter;
    }
}
