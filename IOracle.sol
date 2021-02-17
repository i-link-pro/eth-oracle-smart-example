pragma solidity 0.5.10;

import "./IAbstractStorage.sol";

interface IOracle {
    function commitHeader(bytes calldata, uint256) external;
    function commitHeaderCallable(address, bytes32) external view returns(bool);
    function storageContract() external view returns(IAbstractStorage);
}