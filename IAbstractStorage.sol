pragma solidity 0.5.10;


/// @title Bitcoin based block header storage interface
interface IAbstractStorage {
    function getChainTop() external view returns(bytes32);
    function hasHeader(bytes32 _block) external view returns(bool);
    function getChainHeight() external view returns(uint256);
}