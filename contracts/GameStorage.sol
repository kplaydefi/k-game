// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

import "./SafeMath.sol";
import "./Ownable.sol";
import "./IRelationship.sol";
import "./EIP20Interface.sol";


contract GameStorage is Ownable {
    using SafeMath for uint256;

    /*
     * @notice Indicator that this is a Storage contract (for inspection)
     */
    bool internal _isStorage = true;

    /*
     * @notice Administrator for this contract(only game contract)
     */
    address internal _admin;

    /**
    * @notice Specified currency for betting
     */
    address public tokenContract;

    /*
     * @notice Platform fee receiving address
     */
    address payable internal _platformFeeDst;

    /*
     * @notice Proxy fee receiving address
     */
    address payable internal _proxyFeeDst;

    /*
     * @notice Proxy fee rate
     */
    uint internal _proxyFeeRate;

    /*
     * @notice Proxy address
     */
    address internal _proxy;

    /*
     * @notice The platform deducts the fee for the proxy to create the game
     */
    address internal _proxyFee;

    /*
     * @notice User-Proxy Relationship Binding and Verification
     */
    address internal _relationship;



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

    /*
     * @notice All game hash collection (not repeated)
     */
    bytes32 [] internal _gameList;

    /*
     * @notice Game hash and game mapping
     */
    mapping(bytes32 => Game) internal _games;

    /*
     * @notice Investment mapping of hash and game option 1
     */
    mapping(bytes32 => Vote) internal _option1;

    /*
     * @notice Investment mapping of hash and game option 2
     */
    mapping(bytes32 => Vote) internal _option2;

    /*
     * @notice The mapping between users and the amount won by users in a game
     */
    mapping(bytes32 => mapping(address => uint)) internal _balances;




    // ============================== Events ==============================
    /**
     * @notice Event emitted when set admin account
     */
    event AdminSet(address indexed previousAdmin, address indexed newAdmin);

    /**
     * @notice Event emitted when set proxy fee account
     */
    event ProxyFeeDstSet(address indexed previousProxyFeeDst, address indexed newProxyFeeDst);

    /**
     * @notice Event emitted when set platform fee account
     */
    event PlatformFeeDstSet(address indexed previousPlatformFeeDst, address indexed newPlatformFeeDst);

    /**
     * @notice Event emitted when set proxy fee rate
     */
    event ProxyRateSet(uint rate);

    /**
     * @notice Event emitted when set proxy address
     */
    event ProxySet(address indexed previousProxy, address indexed newProxy);

    /**
     * @notice Event emitted when set proxy fee contract address
     */
    event ProxyFeeSet(address indexed previousProxyFee, address indexed newProxyFee);

    /**
     * @notice Event emitted when set relationship contract address
     */
    event RelationshipSet(address indexed previousRelationship, address indexed newRelationship);


    constructor(address tokenContract_){

        // Set token contract and sanity check it
        tokenContract = tokenContract_;

        EIP20Interface(tokenContract).totalSupply();
    }

    modifier onlyAdmin(){
        require(msg.sender == _admin, "caller is not the admin");
        _;
    }

    /**
     * @notice Returns whether the current contract is a storage contract for verification
     */
    function isStorage() public view returns (bool){
        return _isStorage;
    }



    // ============================== Ownable functions ==============================
    /**
     * @notice The contract owner sets up a new administrator (game contract)
     * @param newAdmin Game contract address
     */
    function setAdmin(address newAdmin) public onlyOwner {
        /* Check if admin is a non-zero address */
        require(newAdmin != address(0), "new admin is the zero address");

        /* Update admin to new admin */
        _admin = newAdmin;

        /* Emit an AdminSet event */
        emit AdminSet(_admin, newAdmin);
    }

    /**
     * @notice Return the admin contract address
     */
    function admin() public view returns (address){
        return _admin;
    }


    /**
    * @notice Set the platform fee receiving address
     * @param newPlatformFeeDst Platform fee address of payable
     */
    function setPlatformFeeDst(address payable newPlatformFeeDst) public onlyOwner {
        /* Check if newPlatformFeeDst  is a non-zero address */
        require(newPlatformFeeDst != address(0), "new platform fee address is the zero address");

        /* Update platform fee address  to new platform fee address*/
        _platformFeeDst = newPlatformFeeDst;

        /* Emit a PlatformFeeDstSet event */
        emit PlatformFeeDstSet(_platformFeeDst, newPlatformFeeDst);
    }

    /**
     * @notice Return the platform fee receiving address
     */
    function platformFeeDst() public view returns (address){
        return _platformFeeDst;
    }

    /**
     * @notice Set the proxy fee receiving address
     * @param newProxyFeeDst Proxy fee address of payable
     */
    function setProxyFeeDst(address payable newProxyFeeDst) public onlyOwner {
        /* Check if newProxyFeeDst  is a non-zero address */
        require(newProxyFeeDst != address(0), "new proxy fee address is the zero address");

        /* Update proxyFeeDst to new newProxyFeeDst */
        _proxyFeeDst = newProxyFeeDst;

        /* Emit an ProxyFeeDstSet event */
        emit ProxyFeeDstSet(_proxyFeeDst, newProxyFeeDst);
    }

    /**
     * @notice Return the proxy fee receiving address
     */
    function proxyFeeDst() public view returns (address){
        return _proxyFeeDst;
    }


    /**
     * @notice Set the proxy fee collection ratio
     * @param newProxyFeeRate Proxy fee ratio
     */
    function setProxyFeeRate(uint newProxyFeeRate) public onlyOwner {
        /* Check if fee rate is 0 */
        require(newProxyFeeRate > 0, "The fee rate cannot be 0");

        /* Update proxyFeeRate to new rate */
        _proxyFeeRate = newProxyFeeRate;

        /* Emit an ProxyRateSet event */
        emit ProxyRateSet(newProxyFeeRate);
    }

    /**
     * @notice Return the proxy fee collection ratio
     */
    function proxyFeeRate() public view returns (uint){
        return _proxyFeeRate;
    }

    /**
    * @notice Set the proxy address
     * @param newProxy Proxy address
     */
    function setProxy(address newProxy) public onlyOwner {
        /* Check if newProxy  is a non-zero address */
        require(newProxy != address(0), "new proxy address is the zero address");

        /* Update proxy to new newProxy */
        _proxy = newProxy;

        /* Check if proxy address exists in proxy relationship */
        require(IRelationship(_relationship).isProxy(_proxy), "Check proxy error");

        /* Emit an ProxySet event */
        emit ProxySet(_proxy, newProxy);
    }

    /**
     * @notice Return the proxy fee address
     */
    function proxy() public view returns (address){
        return _proxy;
    }


    /**
    * @notice Set up the platform to charge the proxy to create a game fee contract
     * @param newProxyFee Proxy fee contract address
     */
    function setProxyFee(address newProxyFee) public onlyOwner {
        /* Check if newProxyFee  is a non-zero address */
        require(newProxyFee != address(0), "new proxy fee address is the zero address");

        /* Update proxyFee to new newProxyFee */
        _proxyFee = newProxyFee;

        /* Emit an ProxyFeeSet event */
        emit ProxyFeeSet(_proxyFee, newProxyFee);
    }

    /**
     * @notice Return the proxy fee contract address
     */
    function proxyFee() public view returns (address){
        return _proxyFee;
    }

    /**
    * @notice Set User-Proxy Relationship Binding and Verification contract address
     * @param newRelationship Relationship contract
     */
    function setRelationship(address payable newRelationship) public onlyOwner {
        /* Check if newRelationship  is a non-zero address */
        require(newRelationship != address(0), "new relationship contract address is the zero address");

        /* Update relationship to new relationship */
        _relationship = newRelationship;

        /* Emit an RelationshipSet event */
        emit RelationshipSet(_relationship, newRelationship);
    }

    /**
     * @notice Return the relationship contract address
     */
    function relationship() public view returns (address){
        return _relationship;
    }




    // ============================== Game Storage functions ==============================

    /**
     * @notice Add a new game to game mappings
     * @param gameHash The game hash
     * @param name The game name
     * @param startTime The game start time
     * @param endTime The game end time
     * @param minAmount The game bet minimum amount
     * @param maxAmount The game betting maximum amount
     * @param feeRate The fee rate charged by the platform and the proxy after the game is over
     * @param status The game state
     */
    function createGame(bytes32 gameHash, uint name, uint startTime, uint endTime, uint minAmount, uint maxAmount, uint feeRate, uint status) public onlyAdmin {
        /* Write the game info into _games mappings storage */
        Game storage game = _games[gameHash];
        game.name = name;
        game.startTime = startTime;
        game.endTime = endTime;
        game.minAmount = minAmount;
        game.maxAmount = maxAmount;
        game.feeRate = feeRate;
        game.status = status;

        /* Write the game hash into _gameList array storage */
        _gameList.push(gameHash);
    }

    /**
     * @notice Set game state and results
     * @param gameHash The game hash
     * @param status The game new state
     * @param result The game new result
     */
    function setGameResult(bytes32 gameHash, uint status, uint result) public onlyAdmin {
        /* Write the game status and result into storage */
        Game storage game = _games[gameHash];
        game.status = status;
        game.result = result;
    }

    /**
     * @notice Return the game info by game hash
     * @param gameHash The game hash
     */
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

    /**
     * @notice Return the game hash by game hash index
     * @param index The game hash index
     */
    function getGameHash(uint index) public view returns (bytes32 gameHash) {
        return _gameList[index];
    }

    /**
     * @notice Generate game hash by game name
     * @param name The game name
     */
    function generateGameHash(uint name) public view returns (bytes32 gameHash) {
        return sha256(abi.encodePacked(address(this), name));
    }

    /**
     * @notice Returns the number of all games that have been created
     */
    function getGameLength() public view returns (uint length){
        return _gameList.length;
    }

    /**
     * @notice Update betting information when player bets on game option 1
     * @param gameHash The betting game hash
     * @param voter The game payer
     * @param amount The game bet amount
     */
    function setOption1(bytes32 gameHash, address voter, uint amount) public onlyAdmin {
        /* Update player's stake and total stake in game option 1 */
        Vote storage vote = _option1[gameHash];
        vote.votes[voter] = vote.votes[voter].add(amount);
        vote.voteAmount = vote.voteAmount.add(amount);

        /* Check voter is unique */
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

    /**
     * @notice Update betting information when player bets on game option 2
     * @param gameHash The betting game hash
     * @param voter The game payer
     * @param amount The game bet amount
     */
    function setOption2(bytes32 gameHash, address voter, uint amount) public onlyAdmin {
        /* Update player's stake and total stake in game option 2 */
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

    /**
     * @notice Returns the total bet and investment total for the game
     * @param gameHash The betting game hash
     */
    function getGameVote(bytes32 gameHash) public view returns (uint option1Amount, uint option2Amount, uint option1Count, uint option2Count){
        Vote storage option1 = _option1[gameHash];
        Vote storage option2 = _option2[gameHash];

        option1Amount = option1.voteAmount;
        option2Amount = option2.voteAmount;

        option1Count = option1.voters.length;
        option2Count = option2.voters.length;
    }

    /**
     * @notice Returns the total amount bet by the user for option 1 and option 2 in the game
     * @param gameHash The betting game hash
     * @param account User betting address
     */
    function getPayerVote(bytes32 gameHash, address account) public view returns (uint option1Amount, uint option2Amount){
        Vote storage option1 = _option1[gameHash];
        Vote storage option2 = _option2[gameHash];

        option1Amount = option1.votes[account];
        option2Amount = option2.votes[account];
    }

    /**
     * @notice Set the amount the user will win in the game
     * @param gameHash The betting game hash
     * @param account User betting address
     * @param newBalance User balance
     */
    function setBalance(bytes32 gameHash, address account, uint newBalance) public onlyAdmin {
        _balances[gameHash][account] = newBalance;
    }

    /**
     * @notice Returns the amount the user has won in the game
     * @param gameHash The betting game hash
     * @param account User betting address
     */
    function getBalance(bytes32 gameHash, address account) public view returns (uint){
        return _balances[gameHash][account];
    }

    /**
     * @notice Liquidation of Option 1 betting users and winning amounts after game result submission
     * @param gameHash The betting game hash
     * @param fee Platform and agency fees
     */
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

    /**
     * @notice Liquidation of Option 2 betting users and winning amounts after game result submission
     * @param gameHash The betting game hash
     * @param fee Platform and agency fees
     */
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

    /**
     * @notice Cancel games and liquidate user bets
     * @param gameHash The betting game hash
     */
    function cancel(bytes32 gameHash) public onlyAdmin {
        Vote storage vote1 = _option1[gameHash];

        // liquidate option1
        for (uint256 i = 0; i < vote1.voters.length; i++) {
            address voter = vote1.voters[i];
            uint voteAmount = vote1.votes[voter];
            uint balance = getBalance(gameHash, voter);
            uint newBalance = balance.add(voteAmount);
            setBalance(gameHash, voter, newBalance);
        }

        // liquidate option2
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
