// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

interface IGameStorage {

    /**
     * @notice Used to mark whether the current contract is storage
     */
    function isStorage() external view returns (bool);

    /**
     * @notice Return the corresponding game contract address
     */
    function admin() external view returns (address);

    /**
     * @notice Returns the ERC20 Token contract used for game wagering
     */
    function tokenContract() external view returns (address);

    /**
     * @notice Return platform fee address income
     */
    function platformFeeDst() external view returns (address);

    /**
     * @notice Return proxy address
     */
    function proxy() external view returns (address);

    /**
     * @notice Returns the contract address of the proxy fee
     */
    function proxyFee() external view returns (address);

    /**
     * @notice Returns the proxy and user relationship contract address
     */
    function relationship() external view returns (address);


    /**
     * @notice Create new game,only the game contract can be called
     */
    function createGame(bytes32 gameHash, uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status) external;

    /**
     * @notice game result
     */
    function setGameResult(bytes32 gameHash, uint status, uint result) external;

    /**
     * @notice Returns the game information
     */
    function getGame(bytes32 gameHash) external view returns (uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint chargeRate, uint status, uint result);

    /**
     * @notice Get game hash by games array index
     */
    function getGameHash(uint index) external view returns (bytes32 gameHash);

    /**
     * @notice Generate game hash based on game id
     */
    function generateGameHash(uint name) external view returns (bytes32 gameHash);

    /**
     * @notice Return the number of games
     */
    function getGameLength() external view returns (uint length);

    /**
     * @notice Set the total wagering information of a proxy in this game
     */
    function setProxyUserVote(bytes32 gameHash, uint proxyId, uint amount) external;

    /**
     * @notice Get the bet amount and the proxy id in the proxy according to the gameHash and proxy index
     */
    function getProxyVote(bytes32 gameHash, uint proxyIndex) external view returns (uint proxyId, uint amount);

    /**
     * @notice Returns the total number of proxies betting on the current game
     */
    function getProxyVoteCount(bytes32 gameHash) external view returns (uint length);

    /**
     * @notice Record the user's bet result in the game as option 1
     */
    function setOption1(bytes32 gameHash, address voter, uint amount) external;

    /**
     * @notice Return the user address and bet amount in option1 according to gameHash and user index
     */
    function getOption1(bytes32 gameHash, uint voterIndex) external view returns (address voter, uint amount);

    /**
     * @notice Record the user's bet result in the game as option 1
     */
    function setOption2(bytes32 gameHash, address voter, uint amount) external;

    /**
     * @notice Return the user address and bet amount in option2 according to gameHash and user index
     */
    function getOption2(bytes32 gameHash, uint voterIndex) external view returns (address voter, uint amount);

    /**
     * @notice Return the game betting information
     */
    function getGameVote(bytes32 gameHash) external view returns (uint option1Amount, uint option2Amount, uint option1Count, uint option2Count);

    /**
     * @notice Returns the amount of bets placed by the user in the game
     */
    function getPayerVote(bytes32 gameHash, address account) external view returns (uint option1Amount, uint option2Amount);

    /**
     * @notice Update the user's withdrawable balance
     */
    function setBalance(bytes32 gameHash, address account, uint newBalance) external;

    /**
     * @notice Returns the user's withdrawable balance
     */
    function getBalance(bytes32 gameHash, address account) external view returns (uint balance);

}