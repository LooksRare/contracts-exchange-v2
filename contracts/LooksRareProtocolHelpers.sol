// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {IRoyaltyFeeRegistry} from "./interfaces/IRoyaltyFeeRegistry.sol";
import {IStrategyManager} from "./interfaces/IStrategyManager.sol";

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
            uint256 protocolFeeAmount,
            uint16 collectionDiscountFactor,
            uint256 royaltyFeeAmount,
            address royaltyRecipient,
            uint256 netPrice,
            RoyaltyType royaltyType
        )
    {
        IStrategyManager.Strategy memory strategyInfo = looksRareProtocol.strategyInfo(strategyId);

        (royaltyRecipient, royaltyFeeAmount, royaltyType) = strategyInfo.hasRoyalties
            ? _getRoyaltyRecipientAndAmountAndRoyaltyType(collection, itemIds, price)
            : (address(0), 0, RoyaltyType.NoRoyalty);

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

    function _getRoyaltyRecipientAndAmountAndRoyaltyType(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    )
        internal
        view
        returns (
            address royaltyRecipient,
            uint256 royaltyAmount,
            RoyaltyType royaltyType
        )
    {
        // 1. Royalty fee registry
        (royaltyRecipient, royaltyAmount) = royaltyFeeRegistry.royaltyInfo(collection, amount);

        if (royaltyRecipient != address(0) || royaltyAmount != 0) {
            // Although royalties would not get paid at the moment using the registry, it can change in the future.
            royaltyType = RoyaltyType.RoyaltyFeeRegistry;
        }

        // 2. ERC2981 logic
        if (royaltyRecipient == address(0) && royaltyAmount == 0) {
            (bool status, bytes memory data) = collection.staticcall(
                abi.encodeWithSelector(IERC2981.royaltyInfo.selector, itemIds[0], amount)
            );

            if (status) {
                (royaltyRecipient, royaltyAmount) = abi.decode(data, (address, uint256));
                // The response is valid so royaltyType becomes EIP2981
                royaltyType = RoyaltyType.RoyaltyEIP2981;
            }

            if (status && itemIds.length > 1) {
                for (uint256 i = 1; i < itemIds.length; i++) {
                    (address royaltyRecipientForToken, uint256 royaltyAmountForToken) = IERC2981(collection)
                        .royaltyInfo(itemIds[i], amount);

                    if (royaltyRecipientForToken != royaltyRecipient || royaltyAmount != royaltyAmountForToken)
                        revert IFeeManager.BundleEIP2981NotAllowed(collection, itemIds);
                }
            }
        }
    }
}
