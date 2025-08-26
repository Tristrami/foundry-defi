// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {MiaoEngine} from "../../../src/MiaoEngine.sol";
import {MiaoToken} from "../../../src/MiaoToken.sol";
import {Validator} from "../../../src/Validator.sol";
import {DeployMiaoEngine} from "../../../script/DeployMiaoEngine.s.sol";
import {Constants} from "../../../script/util/Constants.sol";
import {DeployHelper} from "../../../script/util/DeployHelper.sol";
import {ERC20Mock} from "../../../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../../../test/mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/erc20/IERC20.sol";
import {ContinueOnRevertHandler} from "./ContinueOnRevertHandler.t.sol";
import {BaseTest} from "../../BaseTest.t.sol";

contract ContinueOnRevertInvariants is BaseTest {
    function setUp() external {
        super._setUp();
        ContinueOnRevertHandler handler = new ContinueOnRevertHandler(miaoEngine, miaoToken);
        targetContract(address(handler));
    }

    function invariant_CollateralAlwaysExceedsMintedToken() public view {
        IERC20 weth = IERC20(deployConfig.wethTokenAddress);
        IERC20 wbtc = IERC20(deployConfig.wbtcTokenAddress);
        uint256 totalDepositedWethInUsd =
            miaoEngine.getTokenValueInUsd(address(weth), weth.balanceOf(address(miaoEngine)));
        uint256 totalDepositedWbtcInUsd =
            miaoEngine.getTokenValueInUsd(address(wbtc), wbtc.balanceOf(address(miaoEngine)));
        uint256 totalAmountMiaoMinted = miaoToken.totalSupply();
        assert(totalDepositedWethInUsd + totalDepositedWbtcInUsd >= totalAmountMiaoMinted);
    }
}
