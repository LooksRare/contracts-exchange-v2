// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

/**
 * @title ILooksRareProtocol
 * @author LooksRare protocol team (👀,💎)
 */
interface ILooksRareProtocol {
    /**
     * @notice It is emitted when there is an affiliate fee paid.
     * @param affiliate Affiliate address
     * @param currency Address of the currency
     * @param affiliateFee Affiliate fee (in the currency)
     */
    event AffiliatePayment(address affiliate, address currency, uint256 affiliateFee);

    /**
     * @notice It is emitted if there is a new domain separator.
     */
    event NewDomainSeparator();

    /**
     * @notice It is emitted when there is a new gas limit for a ETH transfer (before it is wrapped to WETH).
     * @param gasLimitETHTransfer Gas limit for an ETH transfer
     */
    event NewGasLimitETHTransfer(uint256 gasLimitETHTransfer);

    /**
     * @notice It is returned if the domain separator cannot be updated (i.e., the chainId is the same).
     */
    error SameDomainSeparator();

    /**
     * @notice It is returned if the nonces are not valid.
     */
    error WrongNonces();

    struct SignatureParameters {
        bytes32 orderHash;
        uint256 orderNonce;
        bool isNonceInvalidated;
    }

    event TakerBid(
        SignatureParameters signatureParameters,
        address bidUser, // taker (initiates the transaction)
        address bidRecipient, // taker (receives the NFT)
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[3] feeRecipients,
        uint256[3] feeAmounts
    );

    event TakerAsk(
        SignatureParameters signatureParameters,
        address askUser, // taker (initiates the transaction)
        address bidUser, // maker (receives the NFT)
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[3] feeRecipients,
        uint256[3] feeAmounts
    );

    /**
     * @notice Sell with taker ask (against maker bid)
     * @param takerAsk Taker ask struct
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param merkleTree Merkle tree struct (if the signature contains multiple maker orders)
     * @param affiliate Affiliate address
     */
    function executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external;

    /**
     * @notice Buy with taker bid (against maker ask)
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param merkleTree Merkle tree struct (if the signature contains multiple maker orders)
     * @param affiliate Affiliate address
     */
    function executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external payable;

    /**
     * @notice Batch buy with taker bids (against maker asks)
     * @param takerBids Array of taker bid struct
     * @param makerAsks Array maker ask struct
     * @param makerSignatures Array of maker signatures
     * @param merkleTrees Array of merkle tree structs if the signature contains multiple maker orders
     * @param affiliate Affiliate address
     * @param isAtomic Whether the execution should be atomic i.e., whether it should revert if 1 or more order fails
     */
    function executeMultipleTakerBids(
        OrderStructs.TakerBid[] calldata takerBids,
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleTree[] calldata merkleTrees,
        address affiliate,
        bool isAtomic
    ) external payable;
}
