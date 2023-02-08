// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    /**
     * @notice QuoteType is used in OrderStructs.Maker's quoteType to determine whether the maker order is a bid or an ask.
     */
    enum QuoteType { Bid, Ask }

    /**
     * 1. Maker struct
     */

    /**
     * @notice Maker is the struct for a maker order.
     * @param quoteType Quote type (i.e. 0 = BID, 1 = ASK)
     * @param globalNonce Global user order nonce for maker orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param orderNonce Order nonce (it can be shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param assetType Asset type (i.e. 0 = ERC721, 1 = ERC1155)
     * @param collection Collection address
     * @param currency Currency address (@dev address(0) = ETH)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param price Minimum price for maker ask, maximum price for maker bid
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct Maker {
        QuoteType quoteType;
        uint256 globalNonce;
        uint256 subsetNonce;
        uint256 orderNonce;
        uint256 strategyId;
        uint256 assetType;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 price;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 2. Taker struct
     */

    /**
     * @notice Taker is the struct for a taker ask/bid order. It contains the parameters required for a direct purchase.
     * @dev Taker struct is matched against MakerAsk/MakerBid structs at the protocol level.
     * @param recipient Recipient address (to receive NFTs or non-fungible tokens)
     * @param additionalParameters Extra data specific for the order
     */
    struct Taker {
        address recipient;
        bytes additionalParameters;
    }

    /**
     * 3. Merkle tree struct
     */

    /**
     * @notice MerkleTree is the struct for a merkle tree of order hashes.
     * @dev A Merkle tree can be computed with order hashes.
     *      It can contain order hashes from both maker bid and maker ask structs.
     * @param root Merkle root
     * @param proof Array containing the merkle proof
     */
    struct MerkleTree {
        bytes32 root;
        bytes32[] proof;
    }

    /**
     * 4. Constants
     */

    /**
     * @notice This is the type hash constant used to compute the maker order hash.
     */
    bytes32 internal constant _MAKER_TYPEHASH =
        keccak256(
            "Maker("
            "uint8 quoteType"
            "uint256 globalNonce,"
            "uint256 orderNonce,"
            "uint256 subsetNonce,"
            "uint256 strategyId,"
            "uint256 assetType,"
            "address collection,"
            "address currency,"
            "address signer,"
            "uint256 startTime,"
            "uint256 endTime,"
            "uint256 price,"
            "uint256[] itemIds,"
            "uint256[] amounts,"
            "bytes additionalParameters"
            ")"
        );

    /**
     * @notice This is the typehash constant used to compute the merkle root order hash.
     * @dev The proof is not included in the hashing function.
     */
    bytes32 internal constant _MERKLE_TREE_TYPEHASH =
        keccak256(
            "MerkleTree("
            "bytes32 root"
            ")"
        );

    /**
     * 5. Hash functions
     */

    /**
     * @notice This function is used to compute the order hash for a maker struct.
     * @param maker Maker order struct
     * @return makerHash Hash of the maker struct
     */
    function hash(Maker memory maker) internal pure returns (bytes32) {
        // Encoding is done into two parts to avoid stack too deep issues
        return
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_TYPEHASH,
                        maker.quoteType,
                        maker.globalNonce,
                        maker.subsetNonce,
                        maker.orderNonce,
                        maker.strategyId,
                        maker.assetType,
                        maker.collection,
                        maker.currency
                    ),
                    abi.encode(
                        maker.signer,
                        maker.startTime,
                        maker.endTime,
                        maker.price,
                        keccak256(abi.encodePacked(maker.itemIds)),
                        keccak256(abi.encodePacked(maker.amounts)),
                        keccak256(maker.additionalParameters)
                    )
                )
            );
    }

    /**
     * @notice This function is used to compute the hash for a merkle tree struct.
     * @param merkleTree Merkle tree struct
     * @return merkleTreeHash Hash of the merkle tree struct
     */
    function hash(MerkleTree memory merkleTree) internal pure returns (bytes32) {
        return keccak256(abi.encode(_MERKLE_TREE_TYPEHASH, merkleTree.root));
    }
}
