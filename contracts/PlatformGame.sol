// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.16 <0.9.0;

import "./Game.sol";
import "./Ownable.sol";

contract PlatformGame is Ownable, Game {

    constructor(address storage_) Game(storage_){}

    function newGame(uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate) external onlyOwner returns (bytes32){
        bytes32 gameHash = newGameInternal(name, startTime, endTime, minAmount, maxAmount, feeRate);
        return gameHash;
    }

    function submitGameResult(bytes32 gameHash, uint result) external onlyOwner {
        submitGameResultInternal(gameHash, result);
    }

    function cancel(bytes32 gameHash) external onlyOwner {
        cancelInternal(gameHash);
    }

    function play(bytes32 gameHash, uint amount, uint option) external {
        playInternal(gameHash, amount, option);
    }

    function withdraw(bytes32 gameHash) external returns (uint amount){
        amount = withdrawInternal(gameHash);
    }
}
