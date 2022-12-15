// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    // Maker ask hash used to compute maker ask order hash
    // keccak256("MakerAsk(uint128 askNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
    bytes32 internal constant _MAKER_ASK_HASH = 0xe456ddf325d41020a456c6df6c94e31d12bc3ae1ac78afc1e2069f85e5c86703;

    // Maker bid hash used to compute maker bid order hash
    // keccak256("MakerBid(uint128 bidNonce,uint256 subsetNonce,uint256 strategyId,uint256 assetType,uint256 orderNonce,address collection,address currency,address signer,uint256 startTime,uint256 endTime,uint256 maxPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
    bytes32 internal constant _MAKER_BID_HASH = 0xdd33dda38569330c45d869f164c11209f07a1d5b782adc09bfd2137a134ac090;

    // Merkle root hash used to compute merkle root order (proof is not included in the hash)
    // keccak256("MerkleTree(bytes32 root)")
    bytes32 internal constant _MERKLE_TREE_HASH = 0x4339702fd09d392db18a2a980b04a717d48085f206207a9fe4472d7ba0ccbf0b;

    /**
     * 1. MAKER ORDERS
     */

    /**
     * @param askNonce Global user order nonce for maker ask orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param assetType Asset type (e.g., 0 = ERC721, 1 = ERC1155)
     * @param orderNonce Order nonce (can be shared across bid/ask maker orders)
     * @param collection Collection address
     * @param currency Currency address (@dev address(0) = ETH)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param minPrice Minimum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order (e.g., it can contain start price for Dutch Auction)
     */
    struct MakerAsk {
        uint128 askNonce;
        uint256 subsetNonce;
        uint256 strategyId;
        uint256 assetType;
        uint256 orderNonce;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * @param bidNonce Global user order nonce for maker bid orders
     * @param subsetNonce Subset nonce (shared across bid/ask maker orders)
     * @param strategyId Strategy id
     * @param assetType Asset type (e.g., 0 = ERC721, 1 = ERC1155)
     * @param orderNonce Order nonce (can be shared across bid/ask maker orders)
     * @param collection Collection address
     * @param currency Currency address (@dev ETH is not valid for bidding)
     * @param signer Signer address
     * @param startTime Start timestamp
     * @param endTime End timestamp
     * @param maxPrice Maximum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order (e.g., it can contain a merkle root for specific strategies)
     */
    struct MakerBid {
        uint128 bidNonce;
        uint256 subsetNonce;
        uint256 strategyId;
        uint256 assetType;
        uint256 orderNonce;
        address collection;
        address currency;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 2. TAKER ORDERS
     */

    /**
     * @param recipient Recipient address (to receive non fungible tokens)
     * @param maxPrice Maximum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct TakerBid {
        address recipient;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * @param recipient Recipient address (to receive non fungible tokens)
     * @param minPrice Minimum price for execution
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     * @param additionalParameters Extra data specific for the order
     */
    struct TakerAsk {
        address recipient;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 3. MERKLE TREE
     */

    /**
     * @param root Merkle root
     * @param proof Merkle proof
     */
    struct MerkleTree {
        bytes32 root;
        bytes32[] proof;
    }

    /**
     * @notice Hash the maker ask struct
     * @param makerAsk Maker ask order struct
     * @return makerAskHash Hash of the maker ask struct
     */
    function hash(MakerAsk memory makerAsk) internal pure returns (bytes32 makerAskHash) {
        // Encoding is done into two parts to avoid stack too deep issues
        return
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_ASK_HASH,
                        makerAsk.askNonce,
                        makerAsk.subsetNonce,
                        makerAsk.strategyId,
                        makerAsk.assetType,
                        makerAsk.orderNonce,
                        makerAsk.collection
                    ),
                    abi.encode(
                        makerAsk.currency,
                        makerAsk.signer,
                        makerAsk.startTime,
                        makerAsk.endTime,
                        makerAsk.minPrice,
                        keccak256(abi.encodePacked(makerAsk.itemIds)),
                        keccak256(abi.encodePacked(makerAsk.amounts)),
                        keccak256(makerAsk.additionalParameters)
                    )
                )
            );
    }

    /**
     * @notice Hash the maker bid struct
     * @param makerBid Maker bid order struct
     * @return makerBidHash Hash of the maker bid struct
     */
    function hash(MakerBid memory makerBid) internal pure returns (bytes32 makerBidHash) {
        return (
            keccak256(
                bytes.concat(
                    abi.encode(
                        _MAKER_BID_HASH,
                        makerBid.bidNonce,
                        makerBid.subsetNonce,
                        makerBid.strategyId,
                        makerBid.assetType,
                        makerBid.orderNonce,
                        makerBid.collection,
                        makerBid.currency
                    ),
                    abi.encode(
                        makerBid.signer,
                        makerBid.startTime,
                        makerBid.endTime,
                        makerBid.maxPrice,
                        keccak256(abi.encodePacked(makerBid.itemIds)),
                        keccak256(abi.encodePacked(makerBid.amounts)),
                        keccak256(makerBid.additionalParameters)
                    )
                )
            )
        );
    }

    /**
     * @notice Hash a merkle root
     * @param merkleTree Merkle tree struct
     * @return merkleTreeHash Hash of the merkle tree struct
     */
    function hash(MerkleTree memory merkleTree) internal pure returns (bytes32 merkleTreeHash) {
        merkleTreeHash = (keccak256(abi.encode(_MERKLE_TREE_HASH, merkleTree.root)));
    }
}
