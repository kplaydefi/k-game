// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.5.16 <0.9.0;

contract Ownable {
    address private _owner;

    constructor(){
        _owner = msg.sender;
    }

    function owner() public view returns (address){
        return _owner;
    }

    function isOwner(address account) public view returns (bool){
        return account == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function transferOwnership(address newOwner) public onlyOwner returns (bool){
        _transferOwnership(newOwner);
        return true;
    }

    modifier onlyOwner(){
        require(isOwner(msg.sender), "caller is not the owner");
        _;
    }

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
}
