// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Constants {
    /* -------------------------------------------------------------------------- */
    /*                                  Chain Id                                  */
    /* -------------------------------------------------------------------------- */

    uint256 internal constant ETH_MAIN_NET_CHAIN_ID = 1;
    uint256 internal constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 internal constant ANVIL_CHAIN_ID = 31337;

    /* -------------------------------------------------------------------------- */
    /*                                Deploy Config                               */
    /* -------------------------------------------------------------------------- */

    /// @dev Initial account balance of ERC20Mock Token
    uint256 internal constant INITIAL_BALANCE = 10000 * 10 ** PRECISION;
    /// @dev Initial MockV3Aggregator price feed decimals
    uint8 internal constant PRICE_FEED_DECIMALS = 8;
    /// @dev The precision of number when calculating
    uint256 internal constant PRECISION = 18;
    /// @dev The usd / weth price of wbtc token
    uint256 internal constant WETH_USD_PRICE = 2000 * 10 ** PRICE_FEED_DECIMALS;
    /// @dev The usd / wbtc price of wbtc token
    uint256 internal constant WBTC_USD_PRICE = 1000 * 10 ** PRICE_FEED_DECIMALS;
}
