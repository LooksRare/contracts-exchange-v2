// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProof} from "../libraries/OpenZeppelin/MerkleProof.sol";

// Others
import {StrategyBase} from "./StrategyBase.sol";

/**
 * @title StrategyCollectionOffer
 * @notice This contract allows the owner to define the maximum acceptable Chainlink price latency.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyCollectionOffer is StrategyBase {
    // If Merkle proof is invalid
    error OrderMerkleProofInvalid();

    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;

    /**
     * @notice Constructor
     * @param _looksRareProtocol Address of the LooksRare protocol.
     */
    constructor(address _looksRareProtocol) {
        LOOKSRARE_PROTOCOL = _looksRareProtocol;
    }

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
        {
            if (
                itemIds.length != 1 ||
                amounts.length != 1 ||
                price != takerAsk.minPrice ||
                takerAsk.amounts[0] != amounts[0] ||
                amounts[0] == 0
            ) revert OrderInvalid();
        }
    }

    /**
     * @notice Execute collection strategy with taker ask order with merkle proof
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
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

        if (makerBid.additionalParameters.length != 0) {
            // Precomputed merkleRoot (that contains the itemIds that match a common characteristic)
            bytes32 root = abi.decode(makerBid.additionalParameters, (bytes32));

            // MerkleProof + indexInTree + itemId
            bytes32[] memory proof = abi.decode(takerAsk.additionalParameters, (bytes32[]));

            // Compute the node
            bytes32 node = keccak256(abi.encodePacked(takerAsk.itemIds[0]));

            // Verify proof
            if (!MerkleProof.verify(proof, root, node)) revert OrderMerkleProofInvalid();
        }
    }
}
