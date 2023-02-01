// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";

// Libraries
import {OrderStructs} from "../../libraries/OrderStructs.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProofMemory} from "../../libraries/OpenZeppelin/MerkleProofMemory.sol";

// Assembly
import {OrderInvalid_error_selector, OrderInvalid_error_length, Error_selector_offset} from "../../constants/StrategyConstants.sol";

// Errors
import {FunctionSelectorInvalid, MerkleProofInvalid, OrderInvalid} from "../../errors/SharedErrors.sol";
import {ItemIdFlagged, ItemTransferredTooRecently, LastTransferTimeInvalid, MessageIdInvalid, SignatureTimestampExpired} from "../../errors/ReservoirErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "../BaseStrategy.sol";

// Constants
import {ASSET_TYPE_ERC721} from "../../constants/NumericConstants.sol";

/**
 * @title StrategyReservoirCollectionOffer
 * @notice This contract offers execution strategies for users to create maker bid offers for items in a collection.
 *         The taker must provide the proof that the item is not flagged and that it hasn't been transferred for
 *         a specific time.
 *         There are two available functions:
 *         1. executeCollectionStrategyWithTakerAsk --> it applies to all itemIds in a collection
 *         2. executeCollectionStrategyWithTakerAskWithProof --> it allows adding merkle proof criteria.
 *         The bidder can only bid on 1 token id at a time.
 *         1. If ERC721, the amount must be 1.
 *         2. If ERC1155, the amount can be greater than 1.
 * @author LooksRare protocol team (👀,💎)
 */
contract StrategyReservoirCollectionOffer is BaseStrategy {
    /**
     * @notice Reservoir's oracle address.
     */
    address public constant ORACLE_ADDRESS = 0xAeB1D03929bF87F69888f381e73FBf75753d75AF;

    /**
     * @notice Default validity period of a signature.
     */
    uint256 public constant SIGNATURE_VALIDITY_PERIOD = 1 minutes;

    /**
     * @notice This function validates the order under the context of the chosen strategy and
     *         returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order without the need of merkle proofs.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function executeCollectionStrategyWithTakerAsk(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        amounts = makerBid.amounts;

        // A collection order can only be executable for 1 itemId but quantity to fill can vary
        if (amounts.length != 1) {
            revert OrderInvalid();
        }

        uint256 offeredItemId = _validateAdditionalParametersAndGetOfferedItemId(
            makerBid.collection,
            makerBid.additionalParameters,
            takerAsk.additionalParameters
        );

        itemIds = new uint256[](1);
        itemIds[0] = offeredItemId;
        isNonceInvalidated = true;

        _validateAmountERC721(amounts[0], makerBid.assetType);
    }

    /**
     * @notice This function validates the order under the context of the chosen strategy
     *         and returns the fulfillable items/amounts/price/nonce invalidation status.
     *         This strategy executes a collection offer against a taker ask order with the need of merkle proofs.
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @dev The transaction reverts if there is the maker does not include a merkle root in the additionalParameters.
     */
    function executeCollectionStrategyWithTakerAskWithProof(
        OrderStructs.Taker calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        view
        returns (uint256 price, uint256[] memory itemIds, uint256[] calldata amounts, bool isNonceInvalidated)
    {
        price = makerBid.maxPrice;
        amounts = makerBid.amounts;

        // A collection order can only be executable for 1 itemId but the actual quantity to fill can vary
        if (amounts.length != 1) {
            revert OrderInvalid();
        }

        uint256 offeredItemId = _validateAdditionalParametersAndGetOfferedItemIdWithProof(
            makerBid.collection,
            makerBid.additionalParameters,
            takerAsk.additionalParameters
        );

        itemIds = new uint256[](1);
        itemIds[0] = offeredItemId;
        isNonceInvalidated = true;
        uint256 makerAmount = amounts[0];

        _validateAmountERC721(makerAmount, makerBid.assetType);
    }

    /**
     * @notice This function validates *only the maker* order under the context of the chosen strategy.
     *         It does not revert if the maker order is invalid.
     *         Instead it returns false and the error's 4 bytes selector.
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     * @param functionSelector Function selector for the strategy
     * @return isValid Whether the maker struct is valid
     * @return errorSelector If isValid is false, it returns the error's 4 bytes selector
     */
    function isMakerBidValid(
        OrderStructs.MakerBid calldata makerBid,
        bytes4 functionSelector
    ) external pure returns (bool isValid, bytes4 errorSelector) {
        if (
            functionSelector !=
            StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector &&
            functionSelector != StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector
        ) {
            return (isValid, FunctionSelectorInvalid.selector);
        }

        if (makerBid.amounts.length != 1) {
            return (isValid, OrderInvalid.selector);
        }

        if (makerBid.amounts[0] != 1 || makerBid.assetType != ASSET_TYPE_ERC721) {
            return (isValid, OrderInvalid.selector);
        }

        // If transfer cooldown period is not provided or invalid length, it should be invalid.
        if (
            functionSelector == StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAsk.selector &&
            makerBid.additionalParameters.length != 32
        ) {
            return (isValid, OrderInvalid.selector);
        }

        // If root and transfer cooldown period are not provided or invalid length, it should be invalid.
        // @dev It does not mean the merkle root is valid against a specific itemId that exists in the collection.
        if (
            functionSelector ==
            StrategyReservoirCollectionOffer.executeCollectionStrategyWithTakerAskWithProof.selector &&
            makerBid.additionalParameters.length != 64
        ) {
            return (isValid, OrderInvalid.selector);
        }

        isValid = true;
    }

    function _validateAdditionalParametersAndGetOfferedItemIdWithProof(
        address collection,
        bytes calldata makerAdditionalParameters,
        bytes calldata takerAdditionalParameters
    ) private view returns (uint256) {
        (
            bytes32 messageId,
            bytes memory payload,
            uint256 timestamp,
            bytes memory signature,
            uint256 offeredItemId,
            bytes32[] memory proof
        ) = abi.decode(takerAdditionalParameters, (bytes32, bytes, uint256, bytes, uint256, bytes32[]));

        (bytes32 root, uint256 transferCooldownPeriod) = abi.decode(makerAdditionalParameters, (bytes32, uint256));

        {
            bytes32 node = keccak256(abi.encodePacked(offeredItemId));

            // Verify the merkle root for the given merkle proof
            if (!MerkleProofMemory.verify(proof, root, node)) {
                revert MerkleProofInvalid();
            }
        }

        _verifyReservoirOracle(
            collection,
            offeredItemId,
            transferCooldownPeriod,
            messageId,
            payload,
            timestamp,
            signature
        );

        return offeredItemId;
    }

    function _validateAdditionalParametersAndGetOfferedItemId(
        address collection,
        bytes calldata makerAdditionalParameters,
        bytes calldata takerAdditionalParameters
    ) private view returns (uint256) {
        (
            bytes32 messageId,
            bytes memory payload,
            uint256 timestamp,
            bytes memory signature,
            uint256 offeredItemId
        ) = abi.decode(takerAdditionalParameters, (bytes32, bytes, uint256, bytes, uint256));

        uint256 transferCooldownPeriod = abi.decode(makerAdditionalParameters, (uint256));

        _verifyReservoirOracle(
            collection,
            offeredItemId,
            transferCooldownPeriod,
            messageId,
            payload,
            timestamp,
            signature
        );

        return offeredItemId;
    }

    function _verifyReservoirOracle(
        address collection,
        uint256 itemId,
        uint256 transferCooldownPeriod,
        bytes32 messageId,
        bytes memory payload,
        uint256 timestamp,
        bytes memory signature
    ) private view {
        // Check the signature timestamp
        if (block.timestamp > timestamp + SIGNATURE_VALIDITY_PERIOD) {
            revert SignatureTimestampExpired();
        }

        // Check the message id
        bytes32 expectedMessageId = keccak256(
            abi.encode(keccak256("Token(address contract,uint256 tokenId)"), collection, itemId)
        );

        if (expectedMessageId != messageId) {
            revert MessageIdInvalid();
        }

        // Check the signature is from the oracle
        bytes32 hash = _computeMessageHash(messageId, payload, timestamp);
        _verifySignature(hash, ORACLE_ADDRESS, signature);

        // Fetch the flagged item
        (bool isFlagged, uint256 lastTransferTime) = abi.decode(payload, (bool, uint256));

        // Check if item is flagged
        if (isFlagged) {
            revert ItemIdFlagged(collection, itemId);
        }

        // Check if message was signed with data invalid
        if (lastTransferTime == 0) {
            revert LastTransferTimeInvalid();
        }

        // Check if item was transferred too recently
        if (block.timestamp < lastTransferTime + transferCooldownPeriod) {
            revert ItemTransferredTooRecently(collection, itemId);
        }
    }

    function _computeMessageHash(
        bytes32 id,
        bytes memory payload,
        uint256 timestamp
    ) private pure returns (bytes32 hash) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(
                        abi.encode(
                            keccak256("Message(bytes32 id,bytes payload,uint256 timestamp)"),
                            id,
                            keccak256(payload),
                            timestamp
                        )
                    )
                )
            );
    }

    function _validateAmountERC721(uint256 amount, uint256 assetType) internal pure {
        assembly {
            if and(xor(amount, 1), iszero(assetType)) {
                mstore(0x00, OrderInvalid_error_selector)
                revert(Error_selector_offset, OrderInvalid_error_length)
            }
        }
    }

    // TODO: Import from library later
    function _verifySignature(bytes32 hash, address signer, bytes memory signature) private view {
        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 0x20))
            s := mload(add(signature, 0x40))
            v := byte(0, mload(add(signature, 0x60)))
        }

        // If the signature is valid (and not malleable), return the signer's address
        address recoveredSigner = ecrecover(hash, v, r, s);

        if (signer != recoveredSigner) {
            revert();
        }
    }
}
