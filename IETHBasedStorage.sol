pragma solidity 0.5.10;


/// @title Ethereum based block header storage interface
interface IETHBasedStorage {
    function getChainTop() external view returns(bytes32);
    function getHeader(bytes32) external view returns(bytes32, bytes32, bytes32, uint256);
    function hasHeader(bytes32 _block) external view returns(bool);
    function storeHeader(bytes32, bytes32, bytes32, bytes32, uint256) external;
}