// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Validator} from "./Validator.sol";

contract MiaoToken is ERC20, Validator, Ownable {
    event MiaoToken__TokenBurned(uint256 indexed amount);
    event MiaoToken__TokenMinted(uint256 indexed amount);

    error MiaoToken__InsufficientBalance(uint256 balance);

    constructor() ERC20("MIAO", "MIAO") Ownable(msg.sender) {}

    function mint(address account, uint256 value) external onlyOwner notZeroAddress(account) notZeroValue(value) {
        _mint(account, value);
        emit MiaoToken__TokenMinted(value);
    }

    function burn(address account, uint256 value) external onlyOwner notZeroAddress(account) notZeroValue(value) {
        uint256 balance = balanceOf(account);
        if (balance < value) {
            revert MiaoToken__InsufficientBalance(balance);
        }
        _burn(account, value);
        emit MiaoToken__TokenBurned(value);
    }
}
