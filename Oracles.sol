pragma solidity 0.5.10;

import "./interfaces/IOracle.sol";
import "./interfaces/IAbstractStorage.sol";
import "./upgradeability/UpgradeableOwned.sol";

/// @title Oracles contract
/// @notice List of all available oracles
contract Oracles is UpgradeableOwned {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    IOracle public BTCOracleContract;
    IOracle public ZECOracleContract;
    IOracle public ETHOracleContract;

    /// @dev Entropy caller address
    /// expected to be ValidatorSetAuRa contract
    address _entropyCaller;
    /// @dev Supported chains enum
    enum Chain { BTC, ZEC, ETH }
    /// @dev mapping from chain index to last height, used for entropy
    mapping(uint256 => uint256) _heights;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    /// @dev Ensures the caller is _entropyCaller
    modifier onlyEntropyCaller {
        require(msg.sender == _entropyCaller, "only entropy caller can call this method");
        _;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return BTCOracleContract != IOracle(0) ||
               ZECOracleContract != IOracle(0) ||
               ETHOracleContract != IOracle(0);
    }

    /// @dev Returns true, if address represents oracle contract
    /// @param contractAddress address to check
    function isOracle(address contractAddress) public view onlyInitialized returns(bool) {
        return  contractAddress != address(0) && 
                (contractAddress == address(BTCOracleContract) ||
                 contractAddress == address(ZECOracleContract) ||
                 contractAddress == address(ETHOracleContract));
    }

    // =============================================== Setters ========================================================

    /// @dev Change BTCOracleContract
    /// @param BTCOracleAddress new contract address
    function setBTCOracle(IOracle BTCOracleAddress) public onlyOwner {
        BTCOracleContract = BTCOracleAddress;
    }

    /// @dev Change ZECOracleContract
    /// @param ZECOracleAddress new contract address
    function setZECOracle(IOracle ZECOracleAddress) public onlyOwner {
        ZECOracleContract = ZECOracleAddress;
    }

    /// @dev Change ETHOracleContract
    /// @param ETHOracleAddress new contract address
    function setETHOracle(IOracle ETHOracleAddress) public onlyOwner {
        ETHOracleContract = ETHOracleAddress;
    }

    /// @dev Set entropy caller address
    /// @param entropyCaller address who can generate entropy
    function setEntropyCaller(address entropyCaller) public onlyOwner {
        _entropyCaller = entropyCaller;
    }

    /// @dev Initializes the contract at network startup.
    /// @param _BTCOracle The address of the `BTCOracle` contract.
    function initialize(
        address _BTCOracle,
        address _ZECOracle,
        address _ETHOracle
    ) external {
        require(!isInitialized()); // initialization can only be done once
        require(msg.sender == _admin());
        require(_BTCOracle != address(0));
        require(_ZECOracle != address(0));
        require(_ETHOracle != address(0));

        BTCOracleContract = IOracle(_BTCOracle);
        ZECOracleContract = IOracle(_ZECOracle);
        ETHOracleContract = IOracle(_ETHOracle);
    }

    function genEntropy() public onlyInitialized onlyEntropyCaller returns(uint256) {
        uint256 _seed = 0;
        _seed ^= _getLastHash(BTCOracleContract, Chain.BTC);
        _seed ^= _getLastHash(ZECOracleContract, Chain.ZEC);
        _seed ^= _getLastHash(ETHOracleContract, Chain.ETH);
        return _seed;
    }

    // =============================================== Internal ========================================================    

    function _getLastHash(IOracle _oracle, Chain _chain) internal returns(uint256) {
        if (_oracle == IOracle(0)) return 0;
        IAbstractStorage storageContract = _oracle.storageContract();
        uint256 currentHeight = storageContract.getChainHeight();
        if (currentHeight > _heights[uint256(_chain)]) {
            _heights[uint256(_chain)] = currentHeight;
            return uint256(storageContract.getChainTop());
        }
        return 0;
    }
}
