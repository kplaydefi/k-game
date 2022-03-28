// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.16 <0.9.0;

import "./SafeMath.sol";
import "./EIP20NonStandardInterface.sol";
import "./EIP20Interface.sol";
import "./IGameStorage.sol";
import "./IProxyFee.sol";
import "./IRelationship.sol";

contract Game {
    using SafeMath for uint256;

    address public tokenContract;
    address public proxy;
    IGameStorage public gameStorage;
    IProxyFee public proxyFee;
    IRelationship public relationship;


    enum GameStatus {
        NONE,
        RUNNING,
        ENDED,
        CANCELLED
    }

    enum GameResult {
        NONE,
        OPTION1,
        OPTION2
    }

    event GameCreated(bytes32 gameHash, uint gameName, uint status, uint feeRate);
    event GameResultSubmitted(bytes32 gameHash, uint gameName, uint fee, uint agentFee, uint platformFee, uint option1Amount, uint option2Amount, uint status, uint result);
    event PayerVote (bytes32 gameHash, uint gameName, address voter, uint amount, uint option, uint option1Amount, uint option2Amount);
    event Withdraw(bytes32 gameHash, address account, uint amount, uint balance);
    event GameCancelled(bytes32 gameHash, uint gameName);

    modifier isProxy(){
        require(msg.sender == proxy, "caller is not the proxy");
        _;
    }


    constructor(address tokenContract_, address storage_, address proxyFee_, address relationship_, address proxy_){
        tokenContract = tokenContract_;
        gameStorage = IGameStorage(storage_);
        proxyFee = IProxyFee(proxyFee_);
        relationship = IRelationship(relationship_);
        proxy = proxy_;

        require(relationship.isProxy(proxy), "Check proxy error");
        require(gameStorage.isStorage(), "Check storage error");
    }


    struct NewGameVars {
        uint startTime;
        uint endTime;
        uint minAmount;
        uint maxAmount;
        uint feeRate;
        uint status;
        uint result;
    }

    function newGame(uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate) external isProxy returns (bytes32 gameHash){
        require(startTime >= block.timestamp, "Start time must be >= current time");
        require(endTime > startTime, "End time must be > start time");
        require(maxAmount > minAmount, "min amount must be > max amount");
        require(endTime > block.timestamp, "End time must be > current time");

        gameHash = sha256(abi.encodePacked(address(this), name));
        NewGameVars memory vars;

        (,, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = gameStorage.getGame(gameHash);

        require(vars.status == uint(GameStatus.NONE), "Game exists");

        gameStorage.createGame(gameHash, name, startTime, endTime, minAmount, maxAmount, feeRate, uint(GameStatus.RUNNING));

        //Charge game fees
        proxyFee.payNewGame(msg.sender);

        emit GameCreated(gameHash, name, uint(GameStatus.RUNNING), feeRate);
        return gameHash;
    }

    struct CancelGameVars {
        uint name;
        uint startTime;
        uint endTime;
        uint minAmount;
        uint maxAmount;
        uint feeRate;
        uint status;
        uint result;
    }

    function cancel(bytes32 gameHash) external isProxy {
        CancelGameVars memory vars;
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = gameStorage.getGame(gameHash);
        require(vars.name > 0, "Game doesn't exist");
        require(vars.status == uint(GameStatus.RUNNING), "Check status failed");

        //liquidate user bets
        gameStorage.cancel(gameHash);

        //Change game status and result
        gameStorage.setGameResult(gameHash, uint(GameStatus.CANCELLED), uint(GameResult.NONE));

        emit GameCancelled(gameHash, vars.name);
    }

    struct SubmitVars {

        // Game info
        uint name;
        uint startTime;
        uint endTime;
        uint minAmount;
        uint maxAmount;
        uint feeRate;
        uint status;

        //Vote options total amount
        uint option1Amount;
        uint option2Amount;

        //fee
        uint fee;
        uint agentFee;
        uint platformFee;
        uint result;

        //address
        address agent;
        address platform;
    }

    function submitGameResult(bytes32 gameHash, uint result) external isProxy {
        SubmitVars memory vars;

        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = gameStorage.getGame(gameHash);

        require(block.timestamp > vars.endTime, "The game is not over");
        require(vars.status == uint(GameStatus.RUNNING), "The game results have been submitted");
        require(result == uint(GameResult.OPTION1) || result == uint(GameResult.OPTION2), "Option not in specified range");

        (vars.option1Amount, vars.option2Amount,,) = gameStorage.getGameVote(gameHash);

        //Option1 win
        if (result == uint(GameResult.OPTION1)) {

            //Calculate game service charge of agent and platform
            (vars.fee, vars.agentFee, vars.platformFee) = calculateFee(vars.option2Amount, vars.feeRate);
            vars.result = uint(GameResult.OPTION1);
            gameStorage.liquidateOption1(gameHash, vars.fee);
            //Option2 win
        } else if (result == uint(GameResult.OPTION2)) {

            (vars.fee, vars.agentFee, vars.platformFee) = calculateFee(vars.option1Amount, vars.feeRate);
            vars.result = uint(GameResult.OPTION2);
            gameStorage.liquidateOption2(gameHash, vars.fee);
        } else {
            revert("Option not in specified range");

        }
        vars.agent = gameStorage.agent();
        vars.platform = gameStorage.platform();

        doTransferOut(vars.agent, vars.agentFee);
        doTransferOut(vars.platform, vars.platformFee);
        gameStorage.setGameResult(gameHash, uint(GameStatus.ENDED), vars.result);
        emit GameResultSubmitted(gameHash, vars.name, vars.fee, vars.agentFee, vars.platformFee, vars.option1Amount, vars.option2Amount, uint(GameStatus.ENDED), vars.result);
    }

    function calculateFee(uint amount, uint feeRate) public view returns (uint fee, uint agentFee, uint platformFee){
        uint agentFeeRate = gameStorage.agentFeeRate();
        // fee = loseAmount * feeRate
        fee = amount.wmul(feeRate);

        // agentFee = fee * agentRate
        agentFee = fee.wmul(agentFeeRate);

        // platformFee = fee * (1-agentRate)
        platformFee = fee.sub(agentFee);
    }


    function getGameHash(uint name) public view returns (bytes32){
        return sha256(abi.encodePacked(address(this), name));
    }


    struct PlayGameVars {
        bool verify;

        uint name;
        uint startTime;
        uint endTime;
        uint minAmount;
        uint maxAmount;
        uint feeRate;
        uint status;
        uint result;

        uint option1Amount;
        uint option2Amount;
    }

    function play(bytes32 gameHash, uint amount, uint option) external {
        PlayGameVars memory vars;
        vars.verify = relationship.verifyAndBind(msg.sender, proxy);
        require(vars.verify, "Check user and proxy relationship error");

        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = gameStorage.getGame(gameHash);
        require(vars.status == uint(GameStatus.RUNNING), "Game is over");
        require(block.timestamp > vars.startTime, "Game has not started");
        require(block.timestamp < vars.endTime, "Game is over2");
        require(amount >= vars.minAmount, "The bet amount is less than the minimum amount");
        require(amount <= vars.maxAmount, "The bet amount is greater than the minimum amount");
        require(option == uint(GameResult.OPTION1) || option == uint(GameResult.OPTION2), "Option not in specified range");

        uint _amount = doTransferIn(msg.sender, amount);

        if (option == uint(GameResult.OPTION1)) {
            gameStorage.setOption1(gameHash, msg.sender, _amount);
        } else if (option == uint(GameResult.OPTION2)) {
            gameStorage.setOption2(gameHash, msg.sender, _amount);

        } else {
            revert("Option not in specified range");

        }
        (vars.option1Amount, vars.option2Amount) = gameStorage.getPayerVote(gameHash, msg.sender);

        emit PayerVote(gameHash, vars.name, msg.sender, _amount, option, vars.option1Amount, vars.option2Amount);
    }

    function withdraw(bytes32 gameHash) external returns (uint amount){
        amount = gameStorage.getBalance(gameHash, msg.sender);
        require(amount > 0, "Insufficient balance");

        doTransferOut(msg.sender, amount);

        gameStorage.setBalance(gameHash, msg.sender, 0);

        emit Withdraw(gameHash, msg.sender, amount, 0);
    }

    function doTransferIn(address from, uint amount) internal returns (uint) {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(tokenContract);
        uint balanceBefore = EIP20Interface(tokenContract).balanceOf(address(this));
        token.transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
            case 0 {// This is a non-standard ERC-20
                success := not(0)          // set success to true
            }
            case 32 {// This is a compliant ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)        // Set `success = returndata` of external call
            }
            default {// This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "Token transfer in failed");

        // Calculate the amount that was *actually* transferred
        uint balanceAfter = EIP20Interface(tokenContract).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Token transfer in overflow");
        return balanceAfter - balanceBefore;
        // underflow already checked above, just subtract
    }

    function doTransferOut(address to, uint amount) internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(tokenContract);
        token.transfer(to, amount);
        bool success;
        assembly {
            switch returndatasize()
            case 0 {// This is a non-standard ERC-20
                success := not(0)          // set success to true
            }
            case 32 {// This is a complaint ERC-20
                returndatacopy(0, 0, 32)
                success := mload(0)        // Set `success = returndata` of external call
            }
            default {// This is an excessively non-compliant ERC-20, revert.
                revert(0, 0)
            }
        }
        require(success, "Token transfer out failed");
    }
}


