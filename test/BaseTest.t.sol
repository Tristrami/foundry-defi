// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MiaoEngine} from "../src/MiaoEngine.sol";
import {MiaoToken} from "../src/MiaoToken.sol";
import {DeployMiaoEngine} from "../script/DeployMiaoEngine.s.sol";
import {Constants} from "../script/util/Constants.sol";
import {DeployHelper} from "../script/util/DeployHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/erc20/IERC20.sol";

contract BaseTest is Test, Constants {
    DeployMiaoEngine internal deployer;
    DeployHelper.DeployConfig internal deployConfig;
    MiaoEngine internal miaoEngine;
    MiaoToken internal miaoToken;

    function _setUp() internal virtual {
        deployer = new DeployMiaoEngine();
        (miaoEngine, deployConfig) = deployer.deploy();
        miaoToken = MiaoToken(miaoEngine.getMiaoTokenAddress());
    }
}
