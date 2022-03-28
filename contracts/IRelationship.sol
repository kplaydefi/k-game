// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

interface IRelationship {
    /**
    * return false if user already binded，else return true or bind to proxy then return true
    */
    function verifyAndBind(address user, address proxy) external returns (bool);

    /**
    * return true when user binded to proxy
    */
    function isBinded(address user, address proxy) external returns (bool);
    
    function isProxy(address proxy) external returns (bool);
}