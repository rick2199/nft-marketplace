// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {NFT} from "src/NFT.sol";
import {DeployNFT} from "script/DeployNFT.s.sol";

contract NFTTest is Test {
    DeployNFT public deployer;
    NFT public nft;
    address public USER = makeAddr("user");

    string public constant TOKEN_URI_1 = "https://mytokenmetadata.com/1";
    string public constant TOKEN_URI_2 = "https://mytokenmetadata.com/2";

    function setUp() public {
        deployer = new DeployNFT();
        nft = deployer.run();
    }

    // Test 1: Ensure contract deploys with correct initial state
    function testNftInitialState() public view {
        assertEq(nft.name(), "RickNft");
        assertEq(nft.symbol(), "RICK");
    }

    // Test 2: Minting an NFT successfully
    function testMintNft() public {
        vm.prank(USER);
        nft.mintNft(TOKEN_URI_1);

        // Assert that the minter owns the token
        assertEq(nft.ownerOf(0), USER);

        // Assert that the token URI is set correctly
        assertEq(nft.tokenURI(0), TOKEN_URI_1);
    }

    // Test 3: Mint multiple NFTs and verify token counter increments
    function testMintMultipleNfts() public {
        vm.startPrank(USER);
        nft.mintNft(TOKEN_URI_1);
        nft.mintNft(TOKEN_URI_2);
        vm.stopPrank();
        // Assert ownership and token URIs
        assertEq(nft.ownerOf(0), USER);
        assertEq(nft.ownerOf(1), USER);
        assertEq(nft.tokenURI(0), TOKEN_URI_1);
        assertEq(nft.tokenURI(1), TOKEN_URI_2);
    }

    // Test 5: Ensure tokenCounter increments correctly
    function testTokenCounterIncrement() public {
        vm.startPrank(USER);
        nft.mintNft(TOKEN_URI_1);
        // Mint another token and check the counter
        nft.mintNft(TOKEN_URI_2);
        vm.stopPrank();
        assertEq(nft.tokenURI(1), TOKEN_URI_2);
    }

    // Test 6: Mint an NFT and verify balance and token URI
    function testCanMintAndHaveABalance() public {
        // Simulate USER calling the mintNft function
        vm.prank(USER);
        nft.mintNft(TOKEN_URI_1);

        // Assert that the USER's balance is 1 after minting
        assert(nft.balanceOf(USER) == 1);

        // Assert that the token URI is set correctly for the minted token
        assert(keccak256(abi.encodePacked(TOKEN_URI_1)) == keccak256(abi.encodePacked(nft.tokenURI(0))));
    }

    // Test 7: Minting with empty token URI
    function testMintWithEmptyUri() public {
        // Empty string should be treated as an invalid URI
        string memory emptyUri = "";

        // Check for a revert if you decide empty URIs shouldn't be allowed
        vm.expectRevert();
        nft.mintNft(emptyUri);
    }
}
