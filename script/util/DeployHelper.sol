// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {Script, console2} from "forge-std/Script.sol";
import {Constants} from "./Constants.sol";

contract DeployHelper is Script, Constants {
    struct DeployConfig {
        address wethTokenAddress;
        address wethPriceFeedAddress;
        address wbtcTokenAddress;
        address wbtcPriceFeedAddress;
    }

    DeployConfig private s_activeConfig;

    error DeployHelper__ChainNotSupported(uint256 chainId);

    constructor() {
        _initialize();
    }

    function getDeployConfig() public view returns (DeployConfig memory) {
        return s_activeConfig;
    }

    function _initialize() private {
        if (block.chainid == ANVIL_CHAIN_ID) {
            s_activeConfig = _createAnvilConfig();
        } else {
            revert DeployHelper__ChainNotSupported(block.chainid);
        }
    }

    function _createAnvilConfig() private returns (DeployConfig memory) {
        vm.startBroadcast();
        ERC20Mock wrappedEth = new ERC20Mock("WETH", "WETH", msg.sender, INITIAL_BALANCE);
        MockV3Aggregator wethPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, int256(WETH_USD_PRICE));
        ERC20Mock wrappedBtc = new ERC20Mock("WBTC", "WBTC", msg.sender, INITIAL_BALANCE);
        MockV3Aggregator wbtcPriceFeed = new MockV3Aggregator(PRICE_FEED_DECIMALS, int256(WBTC_USD_PRICE));
        vm.stopBroadcast();
        return DeployConfig({
            wethTokenAddress: address(wrappedEth),
            wethPriceFeedAddress: address(wethPriceFeed),
            wbtcTokenAddress: address(wrappedBtc),
            wbtcPriceFeedAddress: address(wbtcPriceFeed)
        });
    }
}
