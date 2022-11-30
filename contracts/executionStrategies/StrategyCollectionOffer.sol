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
 * @notice This contract allows users to create maker bid offers for items in a collection.
 *         There are two available functions:
 *         1. executeCollectionStrategyWithTakerAsk --> it applies too all itemId in a collection, the second
 *         2. executeCollectionStrategyWithTakerAskWithProof --> it is same except that it allows adding merkle proof criteria.
 *            Use cases include trait-based offers or rarity score offers.
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
        uint256[] memory amounts = makerBid.amounts;
        if (amounts.length != 1 || amounts[0] == 0) {
            return (orderIsValid, OrderInvalid.selector);
        }

        orderIsValid = true;
    }
}
