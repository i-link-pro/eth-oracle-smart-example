pragma solidity 0.5.10;

interface IOracles {
    function isOracle(address contractAddress) external view returns(bool);
    function genEntropy() external returns(uint256);
}