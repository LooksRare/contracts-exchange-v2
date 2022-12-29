// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProofMemory} from "../libraries/OpenZeppelin/MerkleProofMemory.sol";

// Shared errors
import {OrderInvalid, WrongMerkleProof} from "../interfaces/SharedErrors.sol";

/**
 * @title StrategyCollectionOffer
 * @notice This contract allows users to create maker bid offers for items in a collection.
 *         There are two available functions:
 *         1. executeCollectionStrategyWithTakerAsk --> it applies too all itemId in a collection, the second
 *         2. executeCollectionStrategyWithTakerAskWithProof --> it is same except that it allows adding merkle proof criteria.
 *            Use cases include trait-based offers or rarity score offers.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyCollectionOffer {
    /**
     * @notice Execute collection strategy with taker ask order without merkle proofs
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function executeCollectionStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;
        isNonceInvalidated = true;

        // A collection order can only be executable for 1 itemId but quantity to fill can vary
        if (itemIds.length != 1 || amounts.length != 1 || price != takerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 makerAmount = amounts[0];

        if (makerAmount != takerAsk.amounts[0]) {
            revert OrderInvalid();
        }

        if (amounts[0] != 1) {
            if (amounts[0] == 0) {
                revert OrderInvalid();
            }
            if (makerBid.assetType == 0) {
                revert OrderInvalid();
            }
        }
    }

    /**
     * @notice Execute collection strategy with taker ask order with merkle proof
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @dev The transaction reverts if there is the maker does not include a merkle root in the additionalParameters.
     */
    function executeCollectionStrategyWithTakerAskWithProof(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        returns (uint256 price, uint256[] calldata itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;
        isNonceInvalidated = true;

        // A collection order can only be executable for 1 itemId but the actual quantity to fill can vary
        if (itemIds.length != 1 || amounts.length != 1 || price != takerAsk.minPrice) {
            revert OrderInvalid();
        }

        uint256 makerAmount = amounts[0];

        if (makerAmount != takerAsk.amounts[0]) {
            revert OrderInvalid();
        }

        if (makerAmount != 1) {
            if (makerAmount == 0) {
                revert OrderInvalid();
            }
            if (makerBid.assetType == 0) {
                revert OrderInvalid();
            }
        }

        // Precomputed merkleRoot (that contains the itemIds that match a common characteristic)
        bytes32 root = abi.decode(makerBid.additionalParameters, (bytes32));

        // MerkleProof + indexInTree + itemId
        bytes32[] memory proof = abi.decode(takerAsk.additionalParameters, (bytes32[]));

        // Compute the node
        bytes32 node = keccak256(abi.encodePacked(takerAsk.itemIds[0]));

        // Verify the merkle proof
        if (!MerkleProofMemory.verify(proof, root, node)) {
            revert WrongMerkleProof();
        }
    }

    /**
     * @notice Validate *only the maker* order under the context of the chosen strategy. It does not revert if
     *         the maker order is invalid. Instead it returns false and the error's 4 bytes selector.
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     * @return orderIsValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, return the error's 4 bytes selector
     */
    function isValid(
        OrderStructs.MakerBid calldata makerBid
    ) external pure returns (bool orderIsValid, bytes4 errorSelector) {
        if (makerBid.amounts.length != 1) {
            return (orderIsValid, OrderInvalid.selector);
        }

        if (makerBid.amounts[0] != 1) {
            if (makerBid.amounts[0] == 0) {
                return (orderIsValid, OrderInvalid.selector);
            }
            if (makerBid.assetType == 0) {
                return (orderIsValid, OrderInvalid.selector);
            }
        }
        orderIsValid = true;
    }
}
