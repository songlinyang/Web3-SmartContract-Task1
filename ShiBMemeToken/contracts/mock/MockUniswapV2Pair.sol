// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockUniswapV2Pair {
    function transferFrom(address from, address to, uint value) external returns (bool) {
        return true;
    }
    
    function approve(address spender, uint value) external returns (bool) {
        return true;
    }
    
    function balanceOf(address owner) external view returns (uint) {
        return 1000;
    }
}