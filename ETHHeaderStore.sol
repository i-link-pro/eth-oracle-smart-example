pragma solidity 0.5.10;

import "./interfaces/IETHBasedStorage.sol";
import "./interfaces/IOracle.sol";
import "./upgradeability/UpgradeableOwned.sol";

/// @title Ethereum block header storage contract
/// @notice Stores Ethereum block header data for the *main chain* (no forks!)
contract ETHHeaderStore is UpgradeableOwned, IETHBasedStorage {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    // Data structure representing some Ethereum block header fields
    struct HeaderInfo {
        bytes32 prevHash;
        bytes32 transactionsRoot;
        bytes32 stateRoot;
        uint256 blockHeight;
    }

    /// @dev Mapping of irreversible block hashes to block headers
    mapping(bytes32 => HeaderInfo) public irHeaders;

    /// @dev Mapping of block heights to block hashes
    mapping(uint256 => bytes32) public mainChain;

    /// @dev Blockchain tip
    bytes32 public topHeader;

    /// @dev The address of the `Oracle` contract.
    IOracle public oracleContract;

    // ============================================== Constants =======================================================

    /// @dev Ethereum genesis block hash
    uint256 public constant GENESIS_HASH = 0xd4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the caller is the ValidatorSetAuRa contract address.
    modifier onlyOracle() {
        require(msg.sender == address(oracleContract), "Only oracle can call this method");
        _;
    }

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Getters ========================================================

    /// @dev Get header from storage
    /// @param _block Block hash
    function getHeader(bytes32 _block) public view returns(
        bytes32 prev,
        bytes32 transactionsRoot,
        bytes32 stateRoot,
        uint256 height
    ){
        return (irHeaders[_block].prevHash, irHeaders[_block].transactionsRoot, irHeaders[_block].stateRoot, irHeaders[_block].blockHeight);
    }

    /// @dev Check if header is present
    /// @param _block Block hash
    function hasHeader(bytes32 _block) public view returns(bool) {
        return irHeaders[_block].stateRoot != 0;
    }

    /// @dev Get top header hash from storage
    function getChainTop() public view returns(bytes32) {
        return topHeader;
    }

    /// @dev Get top height from storage
    function getChainHeight() public view returns(uint256) {
        return irHeaders[topHeader].blockHeight;
    }    

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return oracleContract != IOracle(0);
    }

    // =============================================== Setters ========================================================

    /// @dev Write block header to storage
    /// @param _block Block hash
    /// @param _prev Previous block hash
    /// @param _transaction Transactions trie root
    /// @param _state State trie root
    /// @param _height Block height
    function storeHeader(
        bytes32 _block,
        bytes32 _prev,
        bytes32 _transaction,
        bytes32 _state,
        uint256 _height
    ) external onlyOracle onlyInitialized {
        require(_block != bytes32(0) && _prev != bytes32(0) && _transaction != bytes32(0) && _state != bytes32(0), "Zero value in argument");
        if (topHeader != bytes32(0)) {
            require(irHeaders[_block].prevHash == bytes32(0), "Block already present");
            require(topHeader == _prev, "Prev block hash mismatch");
            require(_height == irHeaders[topHeader].blockHeight + 1, "New block height is not contiguous");
        }

        irHeaders[_block].prevHash = _prev;
        irHeaders[_block].transactionsRoot = _transaction;
        irHeaders[_block].stateRoot = _state;
        irHeaders[_block].blockHeight = _height;

        mainChain[_height] = _block;
        topHeader = _block;
    }

    /// @dev Initializes the contract at network startup.
    /// @param _oracle The address of the `ETHOracle` contract.
    function initialize(
        address _oracle
    ) external {
        require(!isInitialized()); // initialization can only be done once
        require(msg.sender == _admin());
        require(_oracle != address(0));

        oracleContract = IOracle(_oracle);
    }

    /// @dev Set oracleContract address
    /// @param oracle oracle address
    function setOracleContract(address oracle) public onlyOwner {
        oracleContract = IOracle(oracle);
    }
}
