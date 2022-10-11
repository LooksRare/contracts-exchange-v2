// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProof} from "../libraries/OpenZeppelin/MerkleProof.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// IExecutionStrategy
import {IExecutionStrategy} from "../interfaces/IExecutionStrategy.sol";

/**
 * @title ExecutionStrategyRarityOffer
 * @notice This contract handles a strategy that matches trades only if the rarity score (from the ask user) is above a specific score.
 * @author LooksRare protocol team (👀,💎)
 */

contract ExecutionStrategyRarityOffer is IExecutionStrategy {
    // Custom errors
    error OrderMerkleProofInvalid();
    error RarityScoreTooLow();

    /**
     * @notice Strategy not executable
     */
    function executeStrategyWithTakerBid(OrderStructs.TakerBid calldata, OrderStructs.MakerAsk calldata)
        external
        pure
        override
        returns (
            uint256,
            uint256[] calldata,
            uint256[] calldata,
            bool
        )
    {
        revert OrderInvalid();
    }

    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        pure
        override
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts,
            bool isNonceInvalidated
        )
    {
        price = makerBid.maxPrice;
        itemIds = takerAsk.itemIds;
        amounts = makerBid.amounts;

        // A collection order can only be executable for 1 itemId but quantity to fill can vary
        {
            if (
                itemIds.length != 1 ||
                amounts.length != 1 ||
                price != takerAsk.minPrice ||
                takerAsk.amounts[0] != amounts[0] ||
                amounts[0] == 0
            ) revert OrderInvalid();
        }

        // Check for ERC721
        if (makerBid.assetType == 0) {
            if (amounts[0] != 1) revert OrderInvalid();
        }

        // Precomputed merkleRoot (that contains the itemIds that match a common characteristic)
        (uint256 minimumRarityScore, bytes32 root) = abi.decode(makerBid.additionalParameters, (uint256, bytes32));

        // MerkleProof + indexInTree + itemId
        (uint256 rarityScore, bytes32[] memory proof) = abi.decode(takerAsk.additionalParameters, (uint256, bytes32[]));

        if (rarityScore < minimumRarityScore) revert RarityScoreTooLow();

        // Compute the node
        bytes32 node = keccak256(abi.encodePacked(takerAsk.itemIds[0], rarityScore));

        // Verify merkle proof
        if (!MerkleProof.verify(proof, root, node)) revert OrderMerkleProofInvalid();

        isNonceInvalidated = true;
    }
}
