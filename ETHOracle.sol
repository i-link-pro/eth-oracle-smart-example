pragma solidity 0.5.10;

import "./base/OracleBase.sol";
import "./interfaces/IETHBasedStorage.sol";
import "./libs/RLPReader.sol";

/// @title ETH Oracle contract
/// @notice Lets validators commit and approve external information
contract ETHOracle is OracleBase {

    // =============================================== Storage ========================================================

    // WARNING: since this contract is upgradeable, do not remove
    // existing storage variables, do not change their order,
    // and do not change their types!

     // ============================================== Modifiers =======================================================

    // =============================================== Getters ========================================================

    // =============================================== Setters =========================================================

    // =============================================== Internal ========================================================

    function execCommit(bytes memory _headerBytes, uint256 _height) internal onlyInitialized {        
        (bytes32 blockHash, bytes32 prevHash, bytes32 transactionsRoot, bytes32 stateRoot) = deserializeHeader(_headerBytes);

        require(
            blockHash != bytes32(0) &&
            prevHash != bytes32(0) &&
            transactionsRoot != bytes32(0) &&
            stateRoot != bytes32(0)
            , "Zero value in header");

        IETHBasedStorage ETHStorageContract = IETHBasedStorage(address(storageContract));
        bytes32 topBlockHash = storageContract.getChainTop();
        (bytes32 prevTop, , , uint256 topHeight) = ETHStorageContract.getHeader(topBlockHash);
        require(_height == topHeight + 1 || prevTop == bytes32(0), "Blocks height is not contiguous");
        require(prevHash == topBlockHash || prevTop == bytes32(0), "Prev block hash does not link to chain top"); 

        if (checkMajority() == blockHash)
            storeHeader(blockHash, prevHash, transactionsRoot, stateRoot, _height);
    }

    /// @dev Write header to storage contract (ETHHeaderStore) if majority is achieved
    function storeHeader(
        bytes32 _blockHash,
        bytes32 _prevHash,
        bytes32 _transactionsRoot,
        bytes32 _stateRoot,
        uint256 _height
    ) internal onlyInitialized {
        IETHBasedStorage ETHStorageContract = IETHBasedStorage(address(storageContract));
        ETHStorageContract.storeHeader(_blockHash, _prevHash, _transactionsRoot, _stateRoot, _height);

        // reset values for current block
        currentHeight += 1;
        lastHash = _blockHash;

        // clean up commits
        resetState();
    }

    /// @dev Returns a deserialized block header fields
    /// @param _headerBytes Serialized header bytes
    /*[
         0: ('parentHash', hash32),
         1: ('sha3Uncles', hash32),
         2: ('miner', address),
         3: ('stateRoot', trie_root),
         4: ('transactionsRoot', trie_root),
         5: ('receiptsRoot', trie_root),
         6: ('logsBloom', uint256),
         7: ('difficulty', big_endian_int),
         8: ('number', big_endian_int),
         9: ('gasLimit', big_endian_int),
        10: ('gasUsed', big_endian_int),
        11: ('timestamp', big_endian_int),
        12: ('extraData', binary),
        13: ('mixHash', binary),
        14: ('nonce', Binary(8, allow_empty=True))
    ]*/
    function deserializeHeader(bytes memory _headerBytes) internal pure returns(
        bytes32 blockHash,
        bytes32 prevBlockHash,
        bytes32 transactionsRoot,
        bytes32 stateRoot
    ){
        blockHash = getHash(_headerBytes);

        RLPReader.RLPItem[] memory ls = RLPReader.toList(RLPReader.toRlpItem(_headerBytes));
        prevBlockHash = bytes32(RLPReader.toUint(ls[0]));
        stateRoot = bytes32(RLPReader.toUint(ls[3]));
        transactionsRoot = bytes32(RLPReader.toUint(ls[4]));

        return(blockHash, prevBlockHash, transactionsRoot, stateRoot);
    }

    /// @dev Returns calculated header hash
    /// @param _headerBytes Serialized header bytes
    function getHash(bytes memory _headerBytes) internal pure returns(bytes32) {
        return keccak256(_headerBytes);
    }
}
