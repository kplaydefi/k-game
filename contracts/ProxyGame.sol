// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.16 <0.9.0;

import "./Game.sol";
import "./IProxyFee.sol";

contract ProxyGame is Game {

    constructor(address storage_) Game(storage_){}

    modifier isProxy(){
        require(msg.sender == _storage.proxy(), "caller is not the proxy");
        _;
    }

    function newGame(uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate) external isProxy returns (bytes32){
        bytes32 gameHash = newGameInternal(name, startTime, endTime, minAmount, maxAmount, feeRate);

        /* The platform charges the proxy to create the game fee */
        IProxyFee(_storage.proxyFee()).payNewGame(msg.sender);
        return gameHash;
    }

    function submitGameResult(bytes32 gameHash, uint result) external isProxy {
        submitGameResultInternal(gameHash, result);
    }

    function cancel(bytes32 gameHash) external isProxy {
        cancelInternal(gameHash);
    }

    function play(bytes32 gameHash, uint amount, uint option) external {
        /* The betting player must exist in the current proxy relationship */
        bool  verify=  IRelationship(_storage.relationship()).verifyAndBind(msg.sender, _storage.proxy());
        require(verify, "Check user and proxy relationship error");

        playInternal(gameHash, amount, option);
    }

    function withdraw(bytes32 gameHash) external returns (uint amount){
        amount = withdrawInternal(gameHash);
    }
}
