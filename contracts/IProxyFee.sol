// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.16 <0.9.0;

interface IProxyFee {
    function payNewGame(address proxy) external;
}