// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";
import {LowLevelETH} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETH.sol";
import {LowLevelERC20Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20Transfer.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProof} from "./libraries/OpenZeppelin/MerkleProof.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {ILooksRareProtocol} from "./interfaces/ILooksRareProtocol.sol";
import {ITransferManager} from "./interfaces/ITransferManager.sol";

// Other dependencies
import {AffiliateManager} from "./AffiliateManager.sol";
import {CurrencyManager} from "./CurrencyManager.sol";
import {ExecutionManager} from "./ExecutionManager.sol";
import {TransferSelectorNFT} from "./TransferSelectorNFT.sol";

/**
 * @title LooksRareProtocol
 * @notice This contract is the primary contract of the LooksRare protocol (v2).
 *         It inherits other core contracts such as CurrencyManager, ExecutionManager, and NonceManager.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocol is
    ILooksRareProtocol,
    CurrencyManager,
    ExecutionManager,
    AffiliateManager,
    TransferSelectorNFT,
    ReentrancyGuard,
    LowLevelETH,
    LowLevelERC20Transfer,
    SignatureChecker
{
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    // Current chainId
    uint256 public chainId;

    // Current domain separator
    bytes32 public domainSeparator;

    /**
     * @notice Constructor
     * @param transferManager Transfer manager address
     */
    constructor(address transferManager) TransferSelectorNFT(transferManager) {
        // Compute and store the initial domain separator
        domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
        // Store initial chainId
        chainId = block.chainid;
    }

    /**
     * @notice Sell with taker ask (against maker bid)
     * @param takerAsk Taker ask struct
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param merkleRoot Merkle root struct (if the signature contains multiple maker orders)
     * @param merkleProof Array containing the merkle proof (used only if multiple maker orders under the signature)
     * @param affiliate Affiliate address
     */
    function executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleRoot calldata merkleRoot,
        bytes32[] calldata merkleProof,
        address affiliate
    ) external nonReentrant {
        // Verify whether the currency is whitelisted but is not ETH (address(0))
        if (!isCurrencyWhitelisted[makerBid.currency] || makerBid.currency == address(0)) revert WrongCurrency();

        uint256 totalProtocolFee;
        {
            bytes32 orderHash = makerBid.hash();
            // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
            if (merkleProof.length == 0) {
                _computeDigestAndVerify(orderHash, makerSignature, makerBid.signer);
            } else {
                _verifyMerkleProofForOrderHash(merkleProof, merkleRoot.root, orderHash);
                _computeDigestAndVerify(merkleRoot.hash(), makerSignature, makerBid.signer);
            }

            // Execute the transaction and fetch protocol fee
            totalProtocolFee = _executeTakerAsk(takerAsk, makerBid, orderHash);
        }

        // Pay protocol fee (and affiliate fee if any)
        _payProtocolFeeAndAffiliateFee(makerBid.currency, makerBid.signer, affiliate, totalProtocolFee);
    }

    /**
     * @notice Buy with taker bid (against maker ask)
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param merkleRoot Merkle root struct (if the signature contains multiple maker orders)
     * @param merkleProof Array containing the merkle proof (if multiple maker orders under the signature)
     * @param affiliate Affiliate address
     */
    function executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleRoot calldata merkleRoot,
        bytes32[] calldata merkleProof,
        address affiliate
    ) external payable nonReentrant {
        uint256 totalProtocolFee;

        // Verify whether the currency is whitelisted
        if (!isCurrencyWhitelisted[makerAsk.currency]) revert WrongCurrency();

        {
            bytes32 orderHash = makerAsk.hash();
            // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
            if (merkleProof.length == 0) {
                _computeDigestAndVerify(orderHash, makerSignature, makerAsk.signer);
            } else {
                _verifyMerkleProofForOrderHash(merkleProof, merkleRoot.root, orderHash);
                _computeDigestAndVerify(merkleRoot.hash(), makerSignature, makerAsk.signer);
            }

            // Execute the transaction and fetch protocol fee
            totalProtocolFee = _executeTakerBid(takerBid, makerAsk, msg.sender, orderHash);
        }
        // Pay protocol fee (and affiliate fee if any)
        _payProtocolFeeAndAffiliateFee(makerAsk.currency, msg.sender, affiliate, totalProtocolFee);

        // Return ETH if any
        _returnETHIfAny();
    }

    /**
     * @notice Batch buy with taker bids (against maker asks)
     * @param takerBids Array of taker bid struct
     * @param makerAsks Array maker ask struct
     * @param makerSignatures Array of maker signatures
     * @param merkleRoots Array of merkle root structs if the signature contains multiple maker orders
     * @param merkleProofs Array containing the merkle proof (if multiple maker orders under the signature)
     * @param affiliate Affiliate address
     * @param isAtomic Whether the execution should be atomic i.e., whether it should revert if 1 or more order fails
     */
    function executeMultipleTakerBids(
        OrderStructs.TakerBid[] calldata takerBids,
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleRoot[] calldata merkleRoots,
        bytes32[][] calldata merkleProofs,
        address affiliate,
        bool isAtomic
    ) external payable nonReentrant {
        {
            uint256 length = takerBids.length;
            if (
                length == 0 ||
                makerAsks.length != length ||
                makerSignatures.length != length ||
                merkleRoots.length != length ||
                merkleProofs.length != length
            ) revert WrongLengths();
        }

        // Verify whether the currency at array = 0 is whitelisted
        if (!isCurrencyWhitelisted[makerAsks[0].currency]) revert WrongCurrency();

        {
            // Initialize protocol fee
            uint256 totalProtocolFee;

            for (uint256 i; i < takerBids.length; ) {
                OrderStructs.MakerAsk calldata makerAsk = makerAsks[i];

                // Verify currency is the same
                if (i != 0) {
                    if (makerAsk.currency != makerAsks[i - 1].currency) revert WrongCurrency();
                }

                OrderStructs.TakerBid calldata takerBid = takerBids[i];
                bytes32 orderHash = makerAsk.hash();

                {
                    {
                        // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
                        if (merkleProofs[i].length == 0) {
                            _computeDigestAndVerify(orderHash, makerSignatures[i], makerAsk.signer);
                        } else {
                            _verifyMerkleProofForOrderHash(merkleProofs[i], merkleRoots[i].root, orderHash);
                            _computeDigestAndVerify(merkleRoots[i].hash(), makerSignatures[i], makerAsk.signer);
                        }
                    }

                    // If atomic, it uses the executeTakerBid function, if not atomic, it uses a catch/revert pattern with external function
                    if (isAtomic) {
                        // Execute the transaction and add protocol fee
                        totalProtocolFee += _executeTakerBid(takerBid, makerAsk, msg.sender, orderHash);
                    } else {
                        try this.restrictedExecuteTakerBid(takerBid, makerAsk, msg.sender, orderHash) returns (
                            uint256 protocolFee
                        ) {
                            totalProtocolFee += protocolFee;
                        } catch {}
                    }

                    unchecked {
                        ++i;
                    }
                }
            }

            // Pay protocol fee (and affiliate fee if any)
            _payProtocolFeeAndAffiliateFee(makerAsks[0].currency, msg.sender, affiliate, totalProtocolFee);
        }

        // Return ETH if any
        _returnETHIfAny();
    }

    /**
     * @notice Function used to do non-atomic matching in the context of a batch taker bid
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param sender Sender address (i.e., the initial msg sender)
     * @param orderHash Hash of the maker ask order
     * @return protocolFeeAmount Protocol fee amount
     * @dev This function is only callable by this contract. It is used for non-atomic batch order matching.
     */
    function restrictedExecuteTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        address sender,
        bytes32 orderHash
    ) external returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) revert WrongCaller();
        return _executeTakerBid(takerBid, makerAsk, sender, orderHash);
    }

    /**
     * @notice Update the domain separator
     * @dev If there is a fork of the network with a new chainId, it allows the owner to reset the domain separator for
     *      the chain with the new id. Anyone can call this function.
     */
    function updateDomainSeparator() external {
        if (block.chainid != chainId) {
            domainSeparator = keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("LooksRareProtocol"),
                    keccak256(bytes("2")),
                    block.chainid,
                    address(this)
                )
            );
            chainId = block.chainid;
            emit NewDomainSeparator();
        } else {
            revert SameDomainSeparator();
        }
    }

    /**
     * @notice Sell with taker ask (against maker bid)
     * @param takerAsk Taker ask order struct
     * @param makerBid Maker bid order struct
     * @param orderHash Hash of the maker bid order
     * @return protocolFeeAmount Protocol fee amount
     */
    function _executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes32 orderHash
    ) internal returns (uint256) {
        {
            // Verify nonces
            if (
                userBidAskNonces[makerBid.signer].askNonce != makerBid.bidNonce ||
                userSubsetNonce[makerBid.signer][makerBid.subsetNonce] ||
                userOrderNonce[makerBid.signer][makerBid.orderNonce]
            ) revert WrongNonces();
        }

        (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[] memory recipients,
            uint256[] memory fees,
            bool isNonceInvalidated
        ) = _executeStrategyForTakerAsk(takerAsk, makerBid, msg.sender);

        {
            // It starts at 1 since the protocol fee is transferred at the very end
            for (uint256 i = 1; i < 3; ) {
                if (recipients[i] != address(0)) {
                    if (fees[i] != 0) {
                        _transferFungibleTokens(makerBid.currency, makerBid.signer, recipients[i], fees[i]);
                    }
                }
                unchecked {
                    ++i;
                }
            }

            _transferNFT(
                makerBid.collection,
                makerBid.assetType,
                msg.sender,
                makerBid.recipient == address(0) ? makerBid.signer : makerBid.recipient,
                itemIds,
                amounts
            );
        }

        SignatureParameters memory signatureParameters = SignatureParameters({
            orderHash: orderHash,
            orderNonce: makerBid.orderNonce,
            isNonceInvalidated: isNonceInvalidated,
            signer: makerBid.signer
        });

        emit TakerAsk(
            signatureParameters,
            msg.sender,
            makerBid.recipient,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );

        // Return protocol fee
        return fees[0];
    }

    /**
     * @notice Execute taker bid (against maker ask)
     * @param takerBid Taker bid order struct
     * @param makerAsk Maker ask order struct
     * @param sender Sender of the transaction (i.e., msg.sender)
     * @param orderHash Hash of the maker ask order
     * @return protocolFeeAmount Protocol fee amount
     */
    function _executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        address sender,
        bytes32 orderHash
    ) internal returns (uint256) {
        {
            // Verify nonces
            if (
                userBidAskNonces[makerAsk.signer].askNonce != makerAsk.askNonce ||
                userSubsetNonce[makerAsk.signer][makerAsk.subsetNonce] ||
                userOrderNonce[makerAsk.signer][makerAsk.orderNonce]
            ) revert WrongNonces();
        }

        (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[] memory recipients,
            uint256[] memory fees,
            bool isNonceInvalidated
        ) = _executeStrategyForTakerBid(takerBid, makerAsk);

        {
            _transferNFT(
                makerAsk.collection,
                makerAsk.assetType,
                makerAsk.signer,
                takerBid.recipient == address(0) ? sender : takerBid.recipient,
                itemIds,
                amounts
            );

            // @dev It starts at 1 since 0 is the protocol fee
            for (uint256 i = 1; i < 3; ) {
                if (recipients[i] != address(0)) {
                    if (fees[i] != 0) {
                        _transferFungibleTokens(makerAsk.currency, sender, recipients[i], fees[i]);
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }

        SignatureParameters memory signatureParameters = SignatureParameters({
            orderHash: orderHash,
            orderNonce: makerAsk.orderNonce,
            isNonceInvalidated: isNonceInvalidated,
            signer: makerAsk.signer
        });

        emit TakerBid(
            signatureParameters,
            sender,
            takerBid.recipient == address(0) ? sender : takerBid.recipient,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );

        return fees[0];
    }

    /**
     * @notice Pay protocol fee and affiliate fee (if any)
     * @param currency Currency address to transfer (address(0) is ETH)
     * @param bidUser Bid user address
     * @param affiliate Affiliate address (address(0) if none)
     * @param totalProtocolFee Total protocol fee (denominated in the currency)
     */
    function _payProtocolFeeAndAffiliateFee(
        address currency,
        address bidUser,
        address affiliate,
        uint256 totalProtocolFee
    ) internal {
        uint256 totalAffiliateFee;

        // Check whether affiliate program is active and whether to execute a affiliate logic (and adjust downward the protocol fee if so)
        if (affiliate != address(0)) {
            if (isAffiliateProgramActive) {
                totalAffiliateFee = (totalProtocolFee * affiliateRates[affiliate]) / 10000;
                totalProtocolFee -= totalAffiliateFee;

                // If bid user isn't the affiliate, pay the affiliate.
                // If currency is ETH, funds are returned to sender at the end of the execution.
                // If currency is ERC20, funds are not transferred from bidder to bidder (since it uses transferFrom).
                if (bidUser != affiliate) {
                    _transferFungibleTokens(currency, bidUser, affiliate, totalAffiliateFee);
                }
            }
        }

        // Transfer remaining protocol fee to the protocol fee recipient
        _transferFungibleTokens(currency, bidUser, protocolFeeRecipient, totalProtocolFee);

        if (totalAffiliateFee != 0) {
            emit AffiliatePayment(affiliate, totalAffiliateFee);
        }
    }

    /**
     * @notice Transfer fungible tokens
     * @param currency Currency address
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount (in fungible tokens)
     */
    function _transferFungibleTokens(
        address currency,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        if (currency == address(0)) {
            _transferETH(recipient, amount);
        } else {
            _executeERC20TransferFrom(currency, sender, recipient, amount);
        }
    }

    /**
     * @notice Compute digest and verify
     * @param computedHash Hash of order (maker bid or maker ask) or merkle root
     * @param makerSignature Signature of the maker
     * @param signer Signer address
     */
    function _computeDigestAndVerify(
        bytes32 computedHash,
        bytes memory makerSignature,
        address signer
    ) internal view {
        // \x19\x01 is the encoding prefix
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, computedHash));
        _verify(digest, signer, makerSignature);
    }

    /**
     * @notice Verify whether the merkle proofs provided for the order hash are correct
     * @param proof Array containing the merkle proof
     * @param root Merkle root
     * @param orderHash Order hash (can be maker bid hash or maker ask hash)
     */
    function _verifyMerkleProofForOrderHash(
        bytes32[] calldata proof,
        bytes32 root,
        bytes32 orderHash
    ) internal pure {
        if (!MerkleProof.verifyCalldata(proof, root, orderHash)) revert WrongMerkleProof();
    }
}
