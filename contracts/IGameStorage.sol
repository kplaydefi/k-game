// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

interface IGameStorage {
    function isStorage() external view returns (bool);

    function admin() external view returns (address);

    function tokenContract() external view returns (address);

    function proxyFeeDst() external view returns (address);

    function platformFeeDst() external view returns (address);

    function proxyFeeRate() external view returns (uint);

    function proxy() external view returns (address);

    function proxyFee() external view returns (address);

    function relationship() external view returns (address);



    function createGame(bytes32 gameHash, uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status) external;

    function setGameResult(bytes32 gameHash, uint status, uint result) external;

    function getGame(bytes32 gameHash) external view returns (uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status, uint result);

    function getGameHash(uint index) external view returns (bytes32 gameHash);

    function generateGameHash(uint name) external view returns (bytes32 gameHash);

    function getGameLength() external view returns (uint length);

    function setOption1(bytes32 gameHash, address voter, uint amount) external;

    function setOption2(bytes32 gameHash, address voter, uint amount) external;

    function getGameVote(bytes32 gameHash) external view returns (uint option1Amount, uint option2Amount, uint option1Count, uint option2Count);

    function getPayerVote(bytes32 gameHash, address account) external view returns (uint option1Amount, uint option2Amount);

    function setBalance(bytes32 gameHash, address account, uint newBalance) external;

    function getBalance(bytes32 gameHash, address account) external view returns (uint balance);

    function liquidateOption1(bytes32 gameHash, uint fee) external;

    function liquidateOption2(bytes32 gameHash, uint fee) external;

    function cancel(bytes32 gameHash) external;
}