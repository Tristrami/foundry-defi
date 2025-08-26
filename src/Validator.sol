// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Validator {
    error Validator__ValueCanNotBeZero(uint256 value);
    error Validator__InvalidAddress(address addr);

    modifier notZeroValue(uint256 value) {
        if (value == 0) {
            revert Validator__ValueCanNotBeZero(value);
        }
        _;
    }

    modifier notZeroAddress(address addr) {
        if (addr == address(0)) {
            revert Validator__InvalidAddress(addr);
        }
        _;
    }
}
