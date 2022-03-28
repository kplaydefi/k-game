// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

interface IGameStorage {
    function isStorage() external view returns (bool);

    function agent() external view returns (address);

    function platform() external view returns (address);

    function agentFeeRate() external view returns (uint);

    function createGame(bytes32 gameHash, uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status) external;

    function setGameResult(bytes32 gameHash, uint status, uint result) external;

    function getGame(bytes32 gameHash) external view returns (uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status, uint result);

    function getGameHash(uint index) external view returns (bytes32 gameHash);

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