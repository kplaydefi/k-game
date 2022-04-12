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

    /**
     * @notice Specified currency for betting
     */
    address public tokenContract;

    /**
     * @notice Proxy address
     */
    address public proxy;

    /**
     * @notice Game storage contract
     */
    IGameStorage public _storage;

    /**
     * @notice The platform deducts the fee for the agent to create the game
     */
    IProxyFee public proxyFee;

    /**
     * @notice User-Agent Relationship Binding and Verification
     */
    IRelationship public relationship;

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
    event GameResultSubmitted(bytes32 gameHash, uint gameName, uint fee, uint agentFee, uint platformFee, uint option1Amount, uint option2Amount, uint status, uint result);

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


    modifier isProxy(){
        require(msg.sender == proxy, "caller is not the proxy");
        _;
    }

    /**
     * @notice Game constructor
     * @param tokenContract_ The address of the Kusdt erc20 token
     * @param storage_ The address of the storage contract
     * @param proxyFee_ The address of proxy fee contract
     * @param relationship_ The address of User-Agent Relationship contract
     * @param proxy_ The address of proxy admin account
     */
    constructor(address tokenContract_, address storage_, address proxyFee_, address relationship_, address proxy_){
        tokenContract = tokenContract_;
        _storage = IGameStorage(storage_);
        proxyFee = IProxyFee(proxyFee_);
        relationship = IRelationship(relationship_);
        proxy = proxy_;

        /* Check if proxy address exists in proxy relationship */
        require(relationship.isProxy(proxy), "Check proxy error");

        /* Check whether the storage contract address is legal */
        require(_storage.isStorage(), "Check storage error");
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
     * @param feeRate The fee rate charged by the platform and the agent after the game is over
     */
    function newGame(uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate) external isProxy returns (bytes32 gameHash){

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

        /* The platform charges the proxy to create the game fee */
        proxyFee.payNewGame(msg.sender);

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
    }

    /**
     * @notice Proxy cancel the game
     * @param gameHash Hash of the game to be canceled
     */
    function cancel(bytes32 gameHash) external isProxy {
        CancelGameVars memory vars;

        /* Check if the game exists */
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(vars.name > 0, "Game doesn't exist");

        /* Cancellation of the game must be made before submitting the game results */
        require(vars.status == uint(GameStatus.RUNNING), "Check status failed");

        /* Cancel and liquidate user bets */
        _storage.cancel(gameHash);

        /* Write the game state and result into storage */
        _storage.setGameResult(gameHash, uint(GameStatus.CANCELLED), uint(GameResult.NONE));

        /* Emit a GameCancelled event */
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

    /**
     * @notice Proxy submit game result
     * @param gameHash Hash of the game result to be submitted
     * @param result The game result value of GameResult.OPTION1 or  GameResult.OPTION2
     */
    function submitGameResult(bytes32 gameHash, uint result) external isProxy {
        SubmitVars memory vars;

        /* Check if the game end time is reached */
        (vars.name, vars.startTime, vars.endTime, vars.minAmount, vars.maxAmount, vars.feeRate, vars.status,) = _storage.getGame(gameHash);
        require(block.timestamp > vars.endTime, "The game is not over");

        /* Check if the game state is over or canceled */
        require(vars.status == uint(GameStatus.RUNNING), "The game results have been submitted");

        /* The result value submitted by the game must be within the specified value range */
        require(result == uint(GameResult.OPTION1) || result == uint(GameResult.OPTION2), "Option not in specified range");

        /* If one option bet amount is 0, the win or loss cannot be calculated */
        (vars.option1Amount, vars.option2Amount,,) = _storage.getGameVote(gameHash);
        require(vars.option1Amount > 0 && vars.option2Amount > 0, "Option 1 or Option2 total bet amount is 0");

        /* Calculation of fees and settlement of user betting wins and losses */
        if (result == uint(GameResult.OPTION1)) {
            /* Calculate game service charge of agent and platform */
            (vars.fee, vars.agentFee, vars.platformFee) = calculateFee(vars.option2Amount, vars.feeRate);

            /* Set game result to option 1 */
            vars.result = uint(GameResult.OPTION1);

            /* Liquidation option 1 betting user's winning amount */
            _storage.liquidateOption1(gameHash, vars.fee);

        } else if (result == uint(GameResult.OPTION2)) {
            /* Calculate game service charge of agent and platform */
            (vars.fee, vars.agentFee, vars.platformFee) = calculateFee(vars.option1Amount, vars.feeRate);

            /* Set game result to option 2 */
            vars.result = uint(GameResult.OPTION2);

            /* Liquidation option 2 betting user's winning amount */
            _storage.liquidateOption2(gameHash, vars.fee);
        } else {
            revert("Option not in specified range");

        }
        /* Send the fees of the platform and the agent to the corresponding address */
        vars.agent = _storage.agent();
        vars.platform = _storage.platform();
        doTransferOut(vars.agent, vars.agentFee);
        doTransferOut(vars.platform, vars.platformFee);

        /* Write the game state and result into storage */
        _storage.setGameResult(gameHash, uint(GameStatus.ENDED), vars.result);

        /* Emit a GameResultSubmitted event */
        emit GameResultSubmitted(gameHash, vars.name, vars.fee, vars.agentFee, vars.platformFee, vars.option1Amount, vars.option2Amount, uint(GameStatus.ENDED), vars.result);
    }

    /**
     * @notice Calculate the fee amount charged by the final platform and agent
     * @param amount Total amount of losers' bets
     * @param feeRate The game setting fee ratio
     */
    function calculateFee(uint amount, uint feeRate) public view returns (uint fee, uint agentFee, uint platformFee){
        /* Get the fee rate of fees charged by the agent */
        uint agentFeeRate = _storage.agentFeeRate();

        // fee = loseAmount * feeRate
        fee = amount.wmul(feeRate);

        // agentFee = fee * agentRate
        agentFee = fee.wmul(agentFeeRate);

        // platformFee = fee * (1-agentRate)
        platformFee = fee.sub(agentFee);
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

    /**
     * @notice User initiates game bet
     * @param gameHash Betting game hash
     * @param amount Bet amount
     * @param option Bet option
     */
    function play(bytes32 gameHash, uint amount, uint option) external {
        PlayGameVars memory vars;

        /* The betting player must exist in the current proxy relationship */
        vars.verify = relationship.verifyAndBind(msg.sender, proxy);
        require(vars.verify, "Check user and proxy relationship error");

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

        /* Get all bet amounts of the current player */
        (vars.option1Amount, vars.option2Amount) = _storage.getPayerVote(gameHash, msg.sender);

        /* Emit a PayerVote event */
        emit PayerVote(gameHash, vars.name, msg.sender, _amount, option, vars.option1Amount, vars.option2Amount);
    }

    /**
     * @notice The user withdraws the kusd won or wagered in a game
     * @param gameHash The betting game hash
     */
    function withdraw(bytes32 gameHash) external returns (uint amount){

        /* Check the amount of cash that the user can withdraw in the game */
        amount = _storage.getBalance(gameHash, msg.sender);
        require(amount > 0, "Insufficient balance");

        /* Transfer to msg.sender */
        doTransferOut(msg.sender, amount);

        /* Write user balance into storage */
        _storage.setBalance(gameHash, msg.sender, 0);

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
        return balanceAfter - balanceBefore; // underflow already checked above, just subtract
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


