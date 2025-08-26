// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseTest} from "../../BaseTest.t.sol";
import {MiaoEngine} from "../../../src/MiaoEngine.sol";
import {FailOnRevertHandler} from "./FailOnRevertHandler.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/erc20/IERC20.sol";
import {MiaoToken} from "../../../src/MiaoToken.sol";

contract FailOnRevertInvariants is BaseTest {
    function setUp() external {
        super._setUp();
        FailOnRevertHandler handler = new FailOnRevertHandler(miaoEngine);
        targetContract(address(handler));
    }

    function invariant_GetterFunctionsCantRevert() public pure {
        // Do nothing, just make sure all the getter functions won't revert
        assert(true);
    }
}
