// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";

// LooksRareProtocol
import {LooksRareProtocol} from "./LooksRareProtocol.sol";

/**
 * @title LooksRareProtocolHelpers
 * @notice This contract contains helper view functions for order creation.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocolHelpers is SignatureChecker {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    enum RoyaltyType {
        NoRoyalty,
        RoyaltyFeeRegistry,
        RoyaltyEIP2981
    }

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    // LooksRareProtocol
    IRoyaltyFeeRegistry public royaltyFeeRegistry;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
        royaltyFeeRegistry = LooksRareProtocol(_looksRareProtocol).royaltyFeeRegistry();
    }

    /**
     * @notice Calculate protocol fee, collection discount (if any), royalty recipient, and royalty percentage
     * @param strategyId Strategy id (e.g., 0 --> standard order, 1 --> collection bid)
     * @param collection Collection addresss
     * @param itemIds Array of itemIds
     * @param price Order price
     */
    function calculateProtocolFeeAndCollectionDiscountFactorAndRoyaltyInfo(
        uint16 strategyId,
        address collection,
        uint256[] memory itemIds,
        uint256 price
    )
        public
        view
        returns (
            uint256 protocolFee,
            uint16 collectionDiscountFactor,
            uint256 royaltyFee,
            address royaltyRecipient,
            RoyaltyType royaltyType
        )
    {
        //
    }

    /**
     * @notice Verify maker ask order
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMakerAskOrder(
        OrderStructs.MakerAsk memory makerAsk,
        bytes memory makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerAsk(makerAsk);
        _verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify maker bid order
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMakerBidOrder(
        OrderStructs.MakerBid memory makerBid,
        bytes memory makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMakerBid(makerBid);
        _verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Verify merkle root
     * @param merkleRoot Merkle root struct
     * @param makerSignature Maker signature
     * @param signer Signer address
     */
    function verifyMerkleRoot(
        OrderStructs.MerkleRoot memory merkleRoot,
        bytes memory makerSignature,
        address signer
    ) public view returns (bool) {
        bytes32 digest = computeDigestMerkleRoot(merkleRoot);
        _verify(digest, signer, makerSignature);
        return true;
    }

    /**
     * @notice Compute digest for maker ask
     * @param makerAsk Maker ask struct
     * @return digest Digest
     */
    function computeDigestMakerAsk(OrderStructs.MakerAsk memory makerAsk) public view returns (bytes32 digest) {
        (, , bytes32 domainSeparator, ) = looksRareProtocol.information();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerAsk.hash()));
    }

    /**
     * @notice Compute digest for maker bid
     * @param makerBid Maker bid struct
     * @return digest Digest
     */
    function computeDigestMakerBid(OrderStructs.MakerBid memory makerBid) public view returns (bytes32 digest) {
        (, , bytes32 domainSeparator, ) = looksRareProtocol.information();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, makerBid.hash()));
    }

    /**
     * @notice Compute digest for merkle root
     * @param merkleRoot Merkle root struct
     */
    function computeDigestMerkleRoot(OrderStructs.MerkleRoot memory merkleRoot) public view returns (bytes32 digest) {
        (, , bytes32 domainSeparator, ) = looksRareProtocol.information();
        return keccak256(abi.encodePacked(_ENCODING_PREFIX, domainSeparator, merkleRoot.hash()));
    }
}
