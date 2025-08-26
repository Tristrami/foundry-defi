// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MiaoEngine} from "../src/MiaoEngine.sol";
import {MiaoToken} from "../src/MiaoToken.sol";
import {DeployHelper} from "./util/DeployHelper.sol";
import {Script} from "forge-std/Script.sol";

contract DeployMiaoEngine is Script {
    address[] private s_tokenAddresses;
    address[] private s_priceFeedAddresses;

    function run() external {
        deploy();
    }

    function deploy() public returns (MiaoEngine, DeployHelper.DeployConfig memory) {
        DeployHelper deployHelper = new DeployHelper();
        DeployHelper.DeployConfig memory deployConfig = deployHelper.getDeployConfig();
        s_tokenAddresses = [deployConfig.wethTokenAddress, deployConfig.wbtcTokenAddress];
        s_priceFeedAddresses = [deployConfig.wethPriceFeedAddress, deployConfig.wbtcPriceFeedAddress];
        vm.startBroadcast();
        MiaoToken miaoToken = new MiaoToken();
        MiaoEngine miaoEngine = new MiaoEngine(address(miaoToken), s_tokenAddresses, s_priceFeedAddresses);
        miaoToken.transferOwnership(address(miaoEngine));
        vm.stopBroadcast();
        return (miaoEngine, deployConfig);
    }
}
