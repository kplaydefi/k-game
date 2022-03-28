// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

import "./SafeMath.sol";
import "./Ownable.sol";

contract GameStorage is Ownable {
    using SafeMath for uint256;

    bool internal _isStorage = true;
    address internal _admin;
    address payable internal _agent;
    address payable internal _platform;
    uint internal _agentFeeRate;

    struct Game {
        uint name;
        uint startTime;
        uint endTime;
        uint minAmount;
        uint maxAmount;
        uint feeRate;
        uint status;
        uint result;
    }

    struct Vote {
        address [] voters;
        mapping(address => uint) votes;
        uint voteAmount;
    }

    bytes32 [] internal _gameList;

    mapping(bytes32 => Game) internal _games;

    mapping(bytes32 => Vote) internal _option1;

    mapping(bytes32 => Vote) internal _option2;

    mapping(bytes32 => mapping(address => uint)) internal _balances;


    event AdminSet(address indexed previousAdmin, address indexed newAdmin);
    event AgentAccountSet(address indexed previousAgent, address indexed newAgent);
    event PlatformAccountSet(address indexed previousPlatform, address indexed newPlatform);
    event AgentRateSet(uint rate);


    constructor(){
    }

    modifier onlyAdmin(){
        require(msg.sender == _admin, "caller is not the admin");
        _;
    }

    function isStorage() public view returns (bool){
        return _isStorage;
    }


    // ============================== Ownable functions ==============================
    // admin
    function setAdmin(address newAdmin) public onlyOwner {
        require(newAdmin != address(0), "new admin is the zero address");
        emit AdminSet(_admin, newAdmin);
        _admin = newAdmin;
    }

    function admin() public view returns (address){
        return _admin;
    }

    // agent account
    function setAgentAccount(address payable newAgent) public onlyOwner {
        require(newAgent != address(0), "new agent account is the zero address");
        emit AgentAccountSet(_agent, newAgent);
        _agent = newAgent;
    }

    function agent() public view returns (address){
        return _agent;
    }

    // platform account
    function setPlatformAccount(address payable newPlatform) public onlyOwner {
        require(newPlatform != address(0), "new platform account is the zero address");
        emit PlatformAccountSet(_platform, newPlatform);
        _platform = newPlatform;
    }

    function platform() public view returns (address){
        return _platform;
    }

    // agent fee rate
    function setAgentFeeRate(uint newAgentFeeRate) public onlyOwner {
        emit AgentRateSet(newAgentFeeRate);
        _agentFeeRate = newAgentFeeRate;
    }

    function agentFeeRate() public view returns (uint){
        return _agentFeeRate;
    }

    // ============================== Storage functions ==============================

    function createGame(bytes32 gameHash, uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate, uint status) public onlyAdmin {
        Game storage game = _games[gameHash];
        game.name = name;
        game.startTime = startTime;
        game.endTime = endTime;
        game.minAmount = minAmount;
        game.maxAmount = maxAmount;
        game.feeRate = feeRate;
        game.status = status;
        _gameList.push(gameHash);
    }

    function setGameResult(bytes32 gameHash, uint status, uint result) public onlyAdmin {
        Game storage game = _games[gameHash];
        game.status = status;
        game.result = result;
    }

    function getGame(bytes32 gameHash) public view returns (uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate, uint status, uint result){
        Game memory game = _games[gameHash];
        name = game.name;
        startTime = game.startTime;
        endTime = game.endTime;
        minAmount = game.minAmount;
        maxAmount = game.maxAmount;
        feeRate = game.feeRate;
        status = game.status;
        result = game.result;
    }

    function getGameHash(uint index) public view returns (bytes32 gameHash) {
        return _gameList[index];
    }

    function getGameLength() public view returns (uint length){
        return _gameList.length;
    }

    function setOption1(bytes32 gameHash, address voter, uint amount) public onlyAdmin {
        Vote storage vote = _option1[gameHash];
        vote.votes[voter] = vote.votes[voter].add(amount);
        vote.voteAmount = vote.voteAmount.add(amount);

        //Check voter is unique
        bool isExists = false;
        for (uint i = 0; i < vote.voters.length; i++) {
            if (vote.voters[i] == voter) {
                isExists = true;
                break;
            }
        }
        if (!isExists) {
            vote.voters.push(voter);
        }

    }

    function setOption2(bytes32 gameHash, address voter, uint amount) public onlyAdmin {
        Vote storage vote = _option2[gameHash];
        vote.votes[voter] = vote.votes[voter].add(amount);
        vote.voteAmount = vote.voteAmount.add(amount);

        //Check voter is unique
        bool isExists = false;
        for (uint i = 0; i < vote.voters.length; i++) {
            if (vote.voters[i] == voter) {
                isExists = true;
                break;
            }
        }
        if (!isExists) {
            vote.voters.push(voter);
        }
    }

    function getGameVote(bytes32 gameHash) public view returns (uint option1Amount, uint option2Amount, uint option1Count, uint option2Count){
        Vote storage option1 = _option1[gameHash];
        Vote storage option2 = _option2[gameHash];

        option1Amount = option1.voteAmount;
        option2Amount = option2.voteAmount;

        option1Count = option1.voters.length;
        option2Count = option2.voters.length;
    }

    function getPayerVote(bytes32 gameHash, address account) public view returns (uint option1Amount, uint option2Amount){
        Vote storage option1 = _option1[gameHash];
        Vote storage option2 = _option2[gameHash];

        option1Amount = option1.votes[account];
        option2Amount = option2.votes[account];
    }

    function setBalance(bytes32 gameHash, address account, uint newBalance) public onlyAdmin {
        _balances[gameHash][account] = newBalance;
    }

    function getBalance(bytes32 gameHash, address account) public view returns (uint){
        return _balances[gameHash][account];
    }

    function liquidateOption1(bytes32 gameHash, uint fee) public onlyAdmin {

        Vote storage vote = _option1[gameHash];

        (uint option1Amount, uint option2Amount,,) = getGameVote(gameHash);

        for (uint256 i = 0; i < vote.voters.length; i++) {
            //Get the vote winner
            address voter = vote.voters[i];

            //Get the investment amount of the bet winner
            uint voteAmount = vote.votes[voter];

            uint rate = voteAmount.wdiv(option1Amount);

            uint loseTotalAmount = option2Amount.sub(fee);

            uint winAmount = rate.wmul(loseTotalAmount).add(voteAmount);

            uint balance = getBalance(gameHash, voter);

            uint newBalance = balance.add(winAmount);

            setBalance(gameHash, voter, newBalance);
        }
    }

    function liquidateOption2(bytes32 gameHash, uint fee) public onlyAdmin {
        Vote storage vote = _option2[gameHash];

        (uint option1Amount, uint option2Amount,,) = getGameVote(gameHash);

        for (uint256 i = 0; i < vote.voters.length; i++) {
            //Get the vote winner
            address voter = vote.voters[i];

            //Get the investment amount of the bet winner
            uint voteAmount = vote.votes[voter];

            uint rate = voteAmount.wdiv(option2Amount);

            uint loseTotalAmount = option1Amount.sub(fee);

            uint winAmount = rate.wmul(loseTotalAmount).add(voteAmount);

            uint balance = getBalance(gameHash, voter);

            uint newBalance = balance.add(winAmount);

            setBalance(gameHash, voter, newBalance);
        }
    }

    function cancel(bytes32 gameHash) public onlyAdmin {
        Vote storage vote1 = _option1[gameHash];
        for (uint256 i = 0; i < vote1.voters.length; i++) {
            address voter = vote1.voters[i];
            uint voteAmount = vote1.votes[voter];
            uint balance = getBalance(gameHash, voter);
            uint newBalance = balance.add(voteAmount);
            setBalance(gameHash, voter, newBalance);
        }

        Vote storage vote2 = _option2[gameHash];
        for (uint256 i = 0; i < vote2.voters.length; i++) {
            address voter = vote2.voters[i];
            uint voteAmount = vote2.votes[voter];
            uint balance = getBalance(gameHash, voter);
            uint newBalance = balance.add(voteAmount);
            setBalance(gameHash, voter, newBalance);
        }
    }
}
