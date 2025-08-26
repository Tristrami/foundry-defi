// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {MiaoEngine} from "../../../src/MiaoEngine.sol";
import {Test} from "forge-std/Test.sol";

/**
 * @dev Test all the getter functions, make sure they won't revert no matter what input parameters are given
 * @notice You should set ** fail_on_revert = true ** in foundry.toml before testing
 * @notice All functions to fuzz should be public, not be view or pure, and shouldn't return anything
 */
contract FailOnRevertHandler is Test {
    MiaoEngine private miaoEngine;

    constructor(MiaoEngine _miaoEngine) {
        miaoEngine = _miaoEngine;
    }

    function getMinimumCollateralRatio() public {
        miaoEngine.getMinimumCollateralRatio();
    }

    function getCollateralAmount(address user, address collateralTokenAddress) public {
        miaoEngine.getCollateralAmount(user, collateralTokenAddress);
    }

    function getMiaoTokenMinted(address user) public {
        miaoEngine.getMiaoTokenMinted(user);
    }

    function getMiaoTokenAddress() public {
        miaoEngine.getMiaoTokenAddress();
    }

    function getCollateralTokenAddresses() public {
        miaoEngine.getCollateralTokenAddresses();
    }
}
