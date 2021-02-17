pragma solidity 0.5.10;

import "../interfaces/IOracle.sol";
import "../interfaces/IAbstractStorage.sol";
import "../interfaces/IValidatorSetAuRa.sol";
import "../upgradeability/UpgradeableOwned.sol";
import "../libs/OracleUtils.sol";

/// @title OracleBase contract
/// @notice Lets validators commit and approve external information
contract OracleBase is UpgradeableOwned, IOracle {

    using OracleUtils for bytes;

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

    mapping(address => bytes32) _commits; // maps committer to header hash
    mapping(bytes32 => uint256) _commits_count; // maps hash to commits count
    address[] _committers; // committers (validators) array
    bytes32[] _currentHashes;    

    bytes32 public lastHash;
    uint256 public currentHeight;

    /// @dev The address of the `ValidatorSetAuRa` contract.
    IValidatorSetAuRa public validatorSetContract;

    /// @dev The address of the storage contract.
    IAbstractStorage public storageContract;

    /// @dev Percent of validators required for writing to storage
    uint32 public majorityPercent;

    /// @dev Max number of header commit skips for validator before ban
    /// not implemented
    uint32 public maxCommitSkips;

    /// @dev The number of commit skips made by the specified validator
    mapping(address => uint256) public commitSkips;

    // Reserved storage space to allow for layout changes in the future.
    uint256[25] private ______gapForPublic;

    // ============================================== Modifiers =======================================================

    /// @dev Ensures the `initialize` function was called before.
    modifier onlyInitialized {
        require(isInitialized());
        _;
    }

    // =============================================== Getters ========================================================

    /// @dev Returns a boolean flag of whether the `commitHash` function can be called at the current block
    /// by the specified validator. Used by the `commitHash` function and the `TxPermission` contract.
    /// @param _miningAddress The mining address of the validator which tries to call the `commitHash` function.
    /// @param _blockHash The Keccak-256 hash of validator's number passed to the `commitHash` function.
    function commitHeaderCallable(address _miningAddress, bytes32 _blockHash) public view onlyInitialized returns(bool) {
        if (_blockHash == bytes32(0)) return false;

        if (!validatorSetContract.isValidator(_miningAddress)) return false;

        return true;
    }

    /// @dev Returns if address already commmitted current header
    /// @param _committer Committer address
    /// @param _hash Block hash
    function isCommitted(address _committer, bytes32 _hash) public view returns(bool) {
        return _commits[_committer] == _hash;
    }

    /// @dev Returns a boolean flag indicating if the `initialize` function has been called.
    function isInitialized() public view returns(bool) {
        return storageContract != IAbstractStorage(0);
    }

    /// @dev checks conditions for writing into storage
    function checkMajority() public view onlyInitialized returns(bytes32) {
        if (_currentHashes.length == 0)
            return bytes32(0);
        address[] memory validators = validatorSetContract.getValidators();
        uint256 threshold = majorityPercent * validators.length / 100;
        if (_committers.length <= threshold)
            return bytes32(0);

        for (uint256 i = 0; i < _currentHashes.length; i++) {
            if (_commits_count[_currentHashes[i]] > threshold)
                return _currentHashes[i];
        }

        return bytes32(0);
    }

    /// @dev checks if hash is present in _currentHashes
    function hasHash(bytes32 _hash) public view onlyInitialized returns(bool) {
        if (_currentHashes.length == 0)
            return false;

        for (uint256 i = 0; i < _currentHashes.length; i++) {
            if (_currentHashes[i] == _hash)
                return true;
        }

        return false;
    }

    /// @dev checks if _currentHashes is empty
    function hasHashes() public view onlyInitialized returns(bool) {
        return _currentHashes.length != 0;
    }

    // =============================================== Setters =========================================================

    /// @dev Commit block header to the oracle
    /// @param _headerBytes header bytes array
    /// @param _height Block height
    function commitHeader(bytes calldata _headerBytes, uint256 _height) external onlyInitialized {
        address miningAddress = msg.sender;
        bytes32 blockHash = getHash(_headerBytes);

        if (storageContract.hasHeader(blockHash)
             && currentHeight == _height + 1
             && _currentHashes.length == 0) {
            _committers.push(miningAddress);
            _commits[miningAddress] = blockHash;
            return;
        }
        address[] memory validators = validatorSetContract.getValidators();
        if (_currentHashes.length == 0 && _committers.length != 0) {
            for (uint i = 0; i < validators.length; ++i) {
                if (_commits[validators[i]] != lastHash) {
                    commitSkips[validators[i]]++;
                }                
            }
            clearCommits();
        }

        require(commitHeaderCallable(miningAddress, blockHash), "Header commit conditions not met");
        if (!hasHash(blockHash))
            _currentHashes.push(blockHash);

        require(currentHeight == _height, "Non contiguous height for new block");
        require(!isCommitted(miningAddress, blockHash), "Address already commmited this header");
        _commits_count[blockHash]++;
        _commits[miningAddress] = blockHash;
        _committers.push(miningAddress);

        execCommit(_headerBytes, _height);
    }

    /// @dev Initializes the contract at network startup.
    /// @param _validatorSet The address of the `ValidatorSetAuRa` contract.
    /// @param _storage The address of the storage contract
    /// @param _majorityPercent Majority percent for accepting header to storage
    function initialize(
        address _validatorSet,
        address _storage,
        uint32 _majorityPercent,
        uint256 _startHeight
    ) external {
        require(!isInitialized()); // initialization can only be done once
        require(msg.sender == _admin());
        require(_validatorSet != address(0));
        require(_storage != address(0));

        validatorSetContract = IValidatorSetAuRa(_validatorSet);
        storageContract = IAbstractStorage(_storage);
        majorityPercent = _majorityPercent;

        uint256 storageHeight = storageContract.getChainHeight();
        if (_startHeight == 0 && storageHeight > 0)
            currentHeight = storageHeight + 1;
        else
            currentHeight = _startHeight;
    }

    // =============================================== Internal ========================================================

    /// @dev Calculate header hash
    /// @param _headerBytes Serialized header
    function getHash(bytes memory _headerBytes) internal pure returns(bytes32);

    /// @dev execute chain specific logic to commit
    /// The function must call checkMajority and, if majority is reached, call storeHeader
    /// @param _headerBytes Serialized header
    /// @param _height Block height
    function execCommit(bytes memory _headerBytes, uint256 _height) internal;

    /// @dev Resets oracles state
    function resetState() internal onlyInitialized {
        for (uint256 i = 0; i < _currentHashes.length; i++) {
            delete _commits_count[_currentHashes[i]];
        }
        delete _currentHashes;
    }

    /// @dev Resets oracles state
    function clearCommits() internal onlyInitialized {
        for (uint256 i = 0; i < _committers.length; i++) {
            delete _commits[_committers[i]];
        }
        delete _committers;
    }
}
