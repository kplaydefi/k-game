// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.16 <0.9.0;

import "./SafeMath.sol";
import "./EIP20NonStandardInterface.sol";
import "./EIP20Interface.sol";
import "./IGameStorage.sol";
import "./IRelationship.sol";

contract Game {
    using SafeMath for uint256;

    /**
    * @notice Game storage contract
     */
    IGameStorage internal _storage;

    /**
     * @notice The game state definition
     */
    enum GameStatus {
        NONE,
        RUNNING,
        ENDED,
        CANCELLED
    }

    /**
     * @notice The game result definition
     */
    enum GameResult {
        NONE,
        OPTION1,
        OPTION2
    }

    /**
     * @notice Event emitted when the new game created
     */
    event GameCreated(bytes32 gameHash, uint gameName, uint status, uint feeRate);

    /**
     * @notice Event emitted when the game over submitted result
     */
    event GameResultSubmitted(bytes32 gameHash, uint gameName, uint fee, uint proxyFee, uint platformFee, uint wonAmount, uint lossAmount, uint status, uint result);

    /**
     * @notice Event emitted when the game canceled
     */
    event GameCancelled(bytes32 gameHash, uint gameName);

    /**
     * @notice Event emitted when user betting game
     */
    event PayerVote (bytes32 gameHash, uint gameName, address voter, uint amount, uint option, uint option1Amount, uint option2Amount);

    /**
     * @notice Event emitted when player cash out after game
     */
    event Withdraw(bytes32 gameHash, address account, uint amount, uint balance);

    /**
     * @notice Game constructor
     * @param storage_ The address of the storage contract
     */
    constructor(address storage_){
        _storage = IGameStorage(storage_);

        /* Check whether the storage contract address is legal */
        require(_storage.isStorage(), "Check storage error");
    }

    function database() external view returns (IGameStorage){
        return _storage;
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

    /**
     * @notice Proxy add new game
     * @param name Unique game name
     * @param startTime The game start time
     * @param endTime The game end time
     * @param minAmount The game bet minimum amount
     * @param maxAmount The game betting maximum amount
     * @param feeRate The fee rate charged by the platform and the proxy after the game is over
     */
    function newGameInternal(uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate) internal returns (bytes32 gameHash){

        /* Verify that the game start time must be greater than the current time */
        require(startTime >= block.timestamp, "Start time must be >= current time");

        /* Verify that the end time of the game must be greater than the start time */
        require(endTime > startTime, "End time must be > start time");

        /* Verify that the end time of the game must be greater than the current time */
        require(endTime > block.timestamp, "End time must be > current time");

        /* Verify that the maximum bet amount must be greater than the minimum bet amount */
        require(maxAmount > minAmount, "min amount must be > max amount");

        /* Generate game hash based on game name */
        gameHash = _storage.generateGameHash(name);

        NewGameVars memory vars;

        /* Check if the game already exists */
        (,, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(vars.status == uint(GameStatus.NONE), "Game exists");

        /* Write the game info into storage */
        _storage.createGame(gameHash, name, startTime, endTime, minAmount, maxAmount, feeRate, uint(GameStatus.RUNNING));

        /* Emit a GameCreated event */
        emit GameCreated(gameHash, name, uint(GameStatus.RUNNING), feeRate);
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


        address voter;
        uint amount;
    }

    /**
     * @notice Proxy cancel the game
     * @param gameHash Hash of the game to be canceled
     */
    function cancelInternal(bytes32 gameHash) internal  {
        CancelGameVars memory vars;

        /* Check if the game exists */
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(vars.name > 0, "Game doesn't exist");

        /* Cancellation of the game must be made before submitting the game results */
        require(vars.status == uint(GameStatus.RUNNING), "Check status failed");

        (, , uint option1Count, uint option2Count) = _storage.getGameVote(gameHash);

        //Cancel and liquidate user bets Option 1
        for (uint256 i = 0; i < option1Count; i++) {
            (vars.voter, vars.amount) = _storage.getOption1(gameHash, i);
            uint balance = _storage.getBalance(gameHash, vars.voter);
            uint newBalance = balance.add(vars.amount);
            _storage.setBalance(gameHash, vars.voter, newBalance);
        }

        //Cancel and liquidate user bets Option 2
        for (uint256 i = 0; i < option2Count; i++) {
            (vars.voter, vars.amount) = _storage.getOption2(gameHash, i);
            uint balance = _storage.getBalance(gameHash, vars.voter);
            uint newBalance = balance.add(vars.amount);
            _storage.setBalance(gameHash, vars.voter, newBalance);
        }

        /* Write the game state and result into storage */
        _storage.setGameResult(gameHash, uint(GameStatus.CANCELLED), uint(GameResult.NONE));

        /* Emit a GameCancelled event */
        emit GameCancelled(gameHash, vars.name);
    }


    function getGameVoteByResult(bytes32 gameHash, uint result) public view returns (uint wonAmount, uint wonCount, uint lossAmount, uint lossCount){

        (uint option1Amount, uint option2Amount, uint option1Count, uint option2Count) = _storage.getGameVote(gameHash);

        if (result == uint(GameResult.OPTION1)) {
            return (option1Amount, option1Count, option2Amount, option2Count);

        } else if (result == uint(GameResult.OPTION2)) {

            return (option2Amount, option2Count, option1Amount, option1Count);
        } else {
            return (0, 0, 0, 0);
        }
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

        uint wonAmount;
        uint wonCount;
        uint lossAmount;
        uint totalAmount;

        //fee
        uint fee;
        uint proxyFee;
        uint platformFee;
    }

    /**
     * @notice Proxy submit game result
     * @param gameHash Hash of the game result to be submitted
     * @param result The game result value of GameResult.OPTION1 or  GameResult.OPTION2
     */
    function submitGameResultInternal(bytes32 gameHash, uint result) internal {
        SubmitVars memory vars;

        /* Check if the game end time is reached */
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(block.timestamp > vars.endTime, "The game is not over");

        /* Check if the game state is over or canceled */
        require(vars.status == uint(GameStatus.RUNNING), "The game results have been submitted");

        /* The result value submitted by the game must be within the specified value range */
        require(result == uint(GameResult.OPTION1) || result == uint(GameResult.OPTION2), "Option not in specified range");

        (vars.wonAmount, vars.wonCount, vars.lossAmount,) = getGameVoteByResult(gameHash, result);
        //Check for void bets
        require(vars.wonAmount > 0 && vars.lossAmount > 0, "Option 1 or Option2 total bet amount is 0");

        // fee = loseAmount * gameFeeRate
        vars.fee = vars.lossAmount.wmul(vars.feeRate);

        vars.totalAmount = vars.wonAmount.add(vars.lossAmount);

        /* Liquidation betting user's winning amount */
        liquidate(gameHash, result, vars.wonCount, vars.wonAmount, vars.lossAmount, vars.fee);

        /* The calculation platform and the proxy will transfer the fee amount and send it away */
        (vars.proxyFee, vars.platformFee) = calculateFee(gameHash, vars.fee, vars.totalAmount);

        /* Write the game state and result into storage */
        _storage.setGameResult(gameHash, uint(GameStatus.ENDED), result);

        /* Emit a GameResultSubmitted event */
        emit GameResultSubmitted(gameHash, vars.name, vars.fee, vars.proxyFee, vars.platformFee, vars.wonAmount, vars.lossAmount, uint(GameStatus.ENDED), result);
    }

    struct CalculateFeeVars {
        uint proxyId;
        address proxyAddress;
        uint proxyFeeRate;
        uint proxyBetAmount;
        uint proxyBetRatio;
        uint proxyFeeAmount;
        uint platformFee;
    }

    function calculateFee(bytes32 gameHash, uint fee, uint totalAmount) internal returns (uint proxyFee, uint platformFee){
        CalculateFeeVars memory vars;
        //Get the number of proxies who are betting users in the current game
        uint proxyLength = _storage.getProxyVoteCount(gameHash);

        for (uint256 i = 0; i < proxyLength; i++) {

            //Get the proxy bet amount and proxyId
            (vars.proxyId, vars.proxyBetAmount) = _storage.getProxyVote(gameHash, i);

            //Obtain the proxy address and fee sharing ratio in the relationship
            (, vars.proxyAddress, vars.proxyFeeRate) = IRelationship(_storage.relationship()).getProxyDetail(vars.proxyId);

            //Calculate the proportion of proxy betting
            // proxyBetRatio = proxyBetAmount / totalAmount
            vars.proxyBetRatio = vars.proxyBetAmount.wdiv(totalAmount);

            //Calculate the proxy profit sharing fee
            //proxyFeeAmount = proxyBetRatio * fee * proxyFeeRate
            vars.proxyFeeAmount = vars.proxyBetRatio.wmul(fee).wmul(vars.proxyFeeRate);

            //Accumulated proxy fee to proxyFee
            proxyFee = proxyFee.add(vars.proxyFeeAmount);

            //Transfer the fee to the fee address of the proxy
            //TODO if proxyFeeAmount=0 whether to send a transfer
            doTransferOut(vars.proxyAddress, vars.proxyFeeAmount);
        }

        //Calculation platform fee
        // platformFee = fee - totalProxyFee
        platformFee = fee.sub(proxyFee);

        //Transfer the fee to the fee address of the platform
        //TODO if platformFee=0 whether to send a transfer
        doTransferOut(_storage.platformFeeDst(), platformFee);
        return (proxyFee, platformFee);
    }

    struct LiquidateVars {
        address voter;
        uint amount;
    }

    /**
     * @notice Liquidation betting users and winning amounts after game result submission
     * @param gameHash The betting game hash
     * @param result Platform and agency fees
     */
    function liquidate(bytes32 gameHash, uint result, uint wonCount, uint wonAmount, uint lossAmount, uint fee) internal {
        LiquidateVars memory vars;

        for (uint256 i = 0; i < wonCount; i++) {
            if (result == uint(GameResult.OPTION1)) {

                //Get the vote winner and betting amount
                (vars.voter, vars.amount) = _storage.getOption1(gameHash, i);

            } else if (result == uint(GameResult.OPTION2)) {

                //Get the vote winner and betting amount
                (vars.voter, vars.amount) = _storage.getOption2(gameHash, i);

            } else {
                revert("Option not in specified range");
            }

            //winner betting ratio
            uint rate = vars.amount.wdiv(wonAmount);

            //The amount the winner will share = lossAmount - lossAmount * gameFeeRate
            uint _lossAmount = lossAmount.sub(fee);

            //winner bet winning amount = winnerBettingAmount / winSideTotalBetting * (lossAmount - lossAmount * gameFeeRate)
            uint winAmount = rate.wmul(_lossAmount).add(vars.amount);

            uint balance = _storage.getBalance(gameHash, vars.voter);

            uint newBalance = balance.add(winAmount);

            _storage.setBalance(gameHash, vars.voter, newBalance);
        }
    }

    struct PlayGameVars {

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

        uint proxyId;
    }

    /**
     * @notice User initiates game bet
     * @param gameHash Betting game hash
     * @param amount Bet amount
     * @param option Bet option
     */
    function playInternal(bytes32 gameHash, uint amount, uint option) internal {
        PlayGameVars memory vars;

        /* Check if game exists and game state must be in running state */
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(vars.status == uint(GameStatus.RUNNING), "Game status error");

        /* Check if the game has started */
        require(block.timestamp > vars.startTime, "Game has not started");

        /* Check if the game is over */
        require(block.timestamp < vars.endTime, "Game is over");

        /* Check if the bet amount is greater than the minimum amount */
        require(amount >= vars.minAmount, "The bet amount is less than the minimum amount");

        /* Check if the bet amount is less than the maximum amount */
        require(amount <= vars.maxAmount, "The bet amount is greater than the minimum amount");

        /* Check if the bet option is the specified option */
        require(option == uint(GameResult.OPTION1) || option == uint(GameResult.OPTION2), "Option not in specified range");

        /* Transfer the amount of bet authorized by the player */
        uint _amount = doTransferIn(msg.sender, amount);


        if (option == uint(GameResult.OPTION1)) {
            /* Write the payer betting option1 amount into storage */
            _storage.setOption1(gameHash, msg.sender, _amount);

        } else if (option == uint(GameResult.OPTION2)) {
            /* Write the payer betting option1 amount into storage */
            _storage.setOption2(gameHash, msg.sender, _amount);

        } else {
            revert("Option not in specified range");

        }

        (vars.proxyId,,) = IRelationship(_storage.relationship()).getProxyDetail(msg.sender);

        //Determine whether the user is bound to a proxy relationship
        if (vars.proxyId > 0) {
            /* Write the proxy user betting amount into storage */
            _storage.setProxyUserVote(gameHash, vars.proxyId, _amount);
        }

        /* Get all bet amounts of the current player */
        (vars.option1Amount, vars.option2Amount) = _storage.getPayerVote(gameHash, msg.sender);

        /* Emit a PayerVote event */
        emit PayerVote(gameHash, vars.name, msg.sender, _amount, option, vars.option1Amount, vars.option2Amount);
    }

    /**
     * @notice The user withdraws the kusd won or wagered in a game
     * @param gameHash The betting game hash
     */
    function withdrawInternal(bytes32 gameHash) internal returns (uint amount){

        /* Check the amount of cash that the user can withdraw in the game */
        amount = _storage.getBalance(gameHash, msg.sender);
        require(amount > 0, "Insufficient balance");

        /* Write user balance into storage */
        _storage.setBalance(gameHash, msg.sender, 0);

        /* Transfer to msg.sender */
        doTransferOut(msg.sender, amount);

        /* Emit a PayerVote event */
        emit Withdraw(gameHash, msg.sender, amount, 0);
    }

    /**
    * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
     *      This will revert due to insufficient balance or insufficient allowance.
     *      This function returns the actual amount received,
     *      which may be less than `amount` if there is a fee attached to the transfer.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferIn(address from, uint amount) internal returns (uint) {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(_storage.tokenContract());
        uint balanceBefore = EIP20Interface(_storage.tokenContract()).balanceOf(address(this));
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
        uint balanceAfter = EIP20Interface(_storage.tokenContract()).balanceOf(address(this));
        require(balanceAfter >= balanceBefore, "Token transfer in overflow");
        return balanceAfter - balanceBefore;
        // underflow already checked above, just subtract
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address to, uint amount) internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(_storage.tokenContract());
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


