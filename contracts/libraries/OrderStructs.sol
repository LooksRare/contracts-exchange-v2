// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    // Maker ask hash used to compute maker ask order hash
    // keccak256("MakerAsk(uint112 askNonce,uint112 subsetNonce,uint16 strategyId,uint8 assetType,uint112 orderNonce,address collection,address currency,address recipient,address signer,uint256 startTime,uint256 endTime,uint256 minPrice,uint256[] itemIds,uint256[] amounts,bytes additionalParameters)")
    bytes32 internal constant _MAKER_ASK_HASH = 0xc7a3b6254405d9b044a63d83e724f64f1b8c511097d23b2ec8922767c2dbcb06;

    // Maker bid hash used to compute maker bid order hash
    // keccak256("MakerBid(uint112 bidNonce,uint112 subsetNonce,uint16 strategyId,uint8 assetType,uint112 orderNonce,address collection,address currency,address recipient,address signer,uint256 startTime,uint256 endTime,uint256 maxPrice,uint256[] itemIds,uint256[] amounts,AdditionalRecipient[] additionalRecipients,bytes additionalParameters)")
    bytes32 internal constant _MAKER_BID_HASH = 0xb32799c81782b0e0c53c7b929dd860d9c76623cc02ffa12bd4cc18514f82fd15;

    // Merkle root hash used to compute merkle root order
    // keccak256("MerkleRoot(bytes32 root)")
    bytes32 internal constant _MERKLE_ROOT_HASH = 0x0cb314254867c611b4ba06dea78882bd68b33649e1ddb950d6db2ee328a55ad0;

    /**
     * 1. ADDITIONAL RECIPIENT
     */

    // AdditionalRecipient
    struct AdditionalRecipient {
        address recipient;
        uint16 percentage;
    }

    /**
     * 2. MAKER ORDERS
     */

    // MakerAsk
    struct MakerAsk {
        uint112 askNonce;
        uint112 subsetNonce;
        uint16 strategyId;
        uint8 assetType;
        uint112 orderNonce;
        address collection;
        address currency;
        address recipient;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    // MakerBid
    struct MakerBid {
        uint112 bidNonce;
        uint112 subsetNonce;
        uint16 strategyId;
        uint8 assetType;
        uint112 orderNonce;
        address collection;
        address currency;
        address recipient;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        AdditionalRecipient[] additionalRecipients;
        bytes additionalParameters;
    }

    /**
     * 3. TAKER ORDERS
     */

    // TakerBid
    struct TakerBid {
        address recipient;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        AdditionalRecipient[] additionalRecipients;
        bytes additionalParameters;
    }

    // TakerAsk
    struct TakerAsk {
        address recipient;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    /**
     * 4. MERKLE ROOT
     */

    // MerkleRoot
    struct MerkleRoot {
        bytes32 root;
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
                        makerAsk.recipient,
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
                        makerBid.recipient,
                        makerBid.signer,
                        makerBid.startTime,
                        makerBid.endTime,
                        makerBid.maxPrice,
                        keccak256(abi.encodePacked(makerBid.itemIds)),
                        keccak256(abi.encodePacked(makerBid.amounts)),
                        keccak256(abi.encode(makerBid.additionalRecipients)),
                        keccak256(makerBid.additionalParameters)
                    )
                )
            )
        );
    }

    /**
     * @notice Hash a merkle root
     * @param merkleRoot Merkle root struct
     * @return merkleRootHash Hash of the merkle root struct
     */
    function hash(MerkleRoot memory merkleRoot) internal pure returns (bytes32 merkleRootHash) {
        return (keccak256(abi.encode(_MERKLE_ROOT_HASH, merkleRoot.root)));
    }
}
