// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title MockERC721 Contract
 * @dev A simple mock implementation of an ERC721 token for testing purposes
 */
contract MockERC721 is ERC721 {
    uint256 private _currentTokenId;

    constructor() ERC721("MockNFT", "MNFT") {}

    /**
     * @notice Mints a new token to the given address
     * @param to The address to mint the token to
     * @param tokenId The token ID of the minted token
     */
    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    /**
     * @notice Returns the current token ID (for testing purposes)
     */
    function getCurrentTokenId() public view returns (uint256) {
        return _currentTokenId;
    }
}
