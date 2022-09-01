// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    // Maker ask hash used to compute maker ask order hash
    // keccak256("MakerAsk(uint112 askNonce,uint112 subsetNonce,uint16 strategyId,uint8 assetType,uint112 orderNonce,uint16 minNetRatio,address collection,address currency,address recipient,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
    bytes32 internal constant _MAKER_ASK_HASH = 0x85fa30b2b848c94bd5f5b88383658126eb3a69201d0b539f4bf956996bdb6af1;

    // Maker bid hash used to compute maker bid order hash
    // keccak256("MakerBid(uint112 bidNonce,uint112 subsetNonce,uint16 strategyId,uint8 assetType,uint112 orderNonce,uint16 minNetRatio,address collection,address currency,address recipient,address signer,uint256 startTime,uint256 endTime,uint256 maxPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
    bytes32 internal constant _MAKER_BID_HASH = 0xaac47bd6046bbe5acd60a92f52dde1bb26209688be10f8a6e723fb405c70721b;

    // Merkle root hash used to compute merkle root order
    bytes32 internal constant _MERKLE_ROOT_HASH = keccak256(abi.encodePacked(uint256(3)));

    /**
     * @notice Hash the makerAsk struct
     * @param makerAsk struct for maker ask order
     * @return makerAskHash hash of the struct
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
                        makerAsk.minNetRatio,
                        makerAsk.collection
                    ),
                    abi.encode(
                        makerAsk.currency,
                        makerAsk.recipient,
                        makerAsk.signer,
                        makerAsk.startTime,
                        makerAsk.endTime,
                        makerAsk.minPrice,
                        makerAsk.itemIds,
                        makerAsk.amounts,
                        keccak256(makerAsk.additionalParameters)
                    )
                )
            );
    }

    /**
     * @notice Hash the makerBid struct
     * @param makerBid struct for maker bid order
     * @return makerBidHash hash of the struct
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
                        makerBid.minNetRatio,
                        makerBid.collection
                    ),
                    abi.encode(
                        makerBid.currency,
                        makerBid.recipient,
                        makerBid.signer,
                        makerBid.startTime,
                        makerBid.endTime,
                        makerBid.maxPrice,
                        makerBid.itemIds,
                        makerBid.amounts,
                        keccak256(makerBid.additionalParameters)
                    )
                )
            )
        );
    }

    /**
     * @notice Hash a merkleRoot
     * @param merkleRoot merkle root containing a set of maker bid/ask struct hashes
     * @return merkleRootHash hash of the merkle root
     */
    function hash(bytes32 merkleRoot) internal pure returns (bytes32 merkleRootHash) {
        return (keccak256(abi.encode(_MERKLE_ROOT_HASH, merkleRoot)));
    }

    /**
     * 1. MAKER ORDERS
     */

    // MakerAsk
    struct MakerAsk {
        uint112 askNonce;
        uint112 subsetNonce;
        uint16 strategyId; // 0: Standard; 1: Collection; 2. etc.
        uint8 assetType;
        uint112 orderNonce;
        uint16 minNetRatio; // e.g., 8500 = At least, 85% of the sale proceeds to the maker ask
        address collection;
        address currency;
        address recipient;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts; // length = 1 if single sale // length > 1 if batch sale
        bytes additionalParameters;
    }

    // MakerBid
    struct MakerBid {
        uint112 bidNonce;
        uint112 subsetNonce;
        uint16 strategyId; // 0: Standard; 1: Collection; 2. etc.
        uint8 assetType;
        uint112 orderNonce;
        uint16 minNetRatio; // e.g., 8500 = At least, 85% of the sale proceeds to the maker ask
        address collection;
        address currency;
        address recipient;
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

    // TakerBid
    struct TakerBid {
        address recipient;
        uint16 minNetRatio;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    // TakerAsk
    struct TakerAsk {
        address recipient;
        uint16 minNetRatio;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }
}
