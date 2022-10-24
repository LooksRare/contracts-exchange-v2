// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Interfaces
import {IFeeManager} from "../interfaces/IFeeManager.sol";
import {IStrategyManager} from "../interfaces/IStrategyManager.sol";

// Other dependencies
import {LooksRareProtocol} from "../LooksRareProtocol.sol";

/**
 * @title LooksRareProtocolHelpers
 * @notice This contract contains helper view functions for order creation.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocolHelpers is SignatureChecker {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
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
            uint256 protocolFeeAmount,
            uint16 collectionDiscountFactor,
            uint256 royaltyFeeAmount,
            address royaltyRecipient,
            uint256 netPrice
        )
    {
        IStrategyManager.Strategy memory strategyInfo = looksRareProtocol.strategyInfo(strategyId);

        (royaltyRecipient, royaltyFeeAmount) = _getRebateRecipientAndAmountAndRoyaltyType(collection, itemIds, price);
        protocolFeeAmount = (price * strategyInfo.protocolFee) / 10000;
        collectionDiscountFactor = looksRareProtocol.collectionDiscountFactor(collection);
        netPrice = price - protocolFeeAmount - royaltyFeeAmount;
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

    function _getRebateRecipientAndAmountAndRoyaltyType(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    ) internal view returns (address rebateRecipient, uint256 rebateAmount) {
        //
    }
}
