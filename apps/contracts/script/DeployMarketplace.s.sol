// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Marketplace} from "src/marketplace/Marketplace.sol";

contract DeployMarketplace is Script {
    uint256 private constant FEE_PERCENT = 2;

    function run() external returns (Marketplace) {
        vm.startBroadcast();
        Marketplace marketplace = new Marketplace(FEE_PERCENT);
        vm.stopBroadcast();
        return marketplace;
    }
}
