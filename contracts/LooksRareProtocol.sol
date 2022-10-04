// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";
import {LowLevelETH} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETH.sol";
import {LowLevelERC20} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProof} from "./libraries/OpenZeppelin/MerkleProof.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {ILooksRareProtocol} from "./interfaces/ILooksRareProtocol.sol";
import {ITransferManager} from "./interfaces/ITransferManager.sol";

// Other core contracts
import {CurrencyManager} from "./CurrencyManager.sol";
import {ExecutionManager} from "./ExecutionManager.sol";
import {NonceManager} from "./NonceManager.sol";
import {ReferralManager} from "./ReferralManager.sol";
import {TransferManager} from "./TransferManager.sol";

/**
 * @title LooksRareProtocol
 * @notice This contract is the primary contract of the LooksRare protocol (v2).
 *         It inherits from other core contracts such as CurrencyManager, ExecutionManager, and NonceManager.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocol is
    ILooksRareProtocol,
    CurrencyManager,
    ExecutionManager,
    NonceManager,
    ReferralManager,
    ReentrancyGuard,
    LowLevelETH,
    LowLevelERC20,
    SignatureChecker
{
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    // Encoding prefix for EIP-712 signatures
    string internal constant _ENCODING_PREFIX = "\x19\x01";

    // Initial domain separator
    bytes32 internal immutable _INITIAL_DOMAIN_SEPARATOR;

    // Initial chainId
    uint256 internal immutable _INITIAL_CHAIN_ID;

    // Current domain separator
    bytes32 internal _domainSeparator;

    // Current chainId
    uint256 internal _chainId;

    // Transfer manager of asset type
    mapping(uint16 => address) public transferManagerOfAssetType;

    /**
     * @notice Constructor
     * @param transferManager Transfer manager address for asset types 0 and 1
     * @param royaltyFeeRegistry Royalty fee registry address
     */
    constructor(address transferManager, address royaltyFeeRegistry) ExecutionManager(royaltyFeeRegistry) {
        // Compute and store the initial domain separator
        _INITIAL_DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("LooksRareProtocol"),
                keccak256(bytes("2")),
                block.chainid,
                address(this)
            )
        );
        // Store initial chainId
        _INITIAL_CHAIN_ID = block.chainid;

        // Store the current domainSeparator and chainId
        _domainSeparator = _INITIAL_DOMAIN_SEPARATOR;
        _chainId = _INITIAL_CHAIN_ID;

        // Transfer managers for ERC-721/ERC-1155
        transferManagerOfAssetType[0] = transferManager;
        transferManagerOfAssetType[1] = transferManager;
    }

    /**
     * @notice Sell with taker ask (against maker bid)
     * @param takerAsk Taker ask struct
     * @param makerBid Maker bid struct
     * @param makerSignature Maker signature
     * @param merkleRoot Merkle root struct (if the signature contains multiple maker orders)
     * @param merkleProof Array containing the merkle proof (used only if multiple maker orders under the signature)
     * @param referrer Referrer address
     */
    function executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleRoot calldata merkleRoot,
        bytes32[] calldata merkleProof,
        address referrer
    ) external nonReentrant {
        // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
        if (merkleProof.length == 0) {
            _computeDigestAndVerify(makerBid.hash(), makerSignature, makerBid.signer);
        } else {
            _verifyMerkleProofForOrderHash(merkleProof, merkleRoot.root, makerBid.hash());
            _computeDigestAndVerify(merkleRoot.hash(), makerSignature, makerBid.signer);
        }

        // Execute the transaction and fetch protocol fee
        uint256 totalProtocolFee = _executeTakerAsk(takerAsk, makerBid, msg.sender);

        // Pay protocol fee (and referral fee if any)
        _payProtocolFeeAndReferralFee(makerBid.currency, makerBid.signer, referrer, totalProtocolFee);
    }

    /**
     * @notice Buy with taker bid (against maker ask)
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param makerSignature Maker signature
     * @param merkleRoot Merkle root struct (if the signature contains multiple maker orders)
     * @param merkleProof Array containing the merkle proof (if multiple maker orders under the signature)
     * @param referrer Referrer address
     */
    function executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleRoot calldata merkleRoot,
        bytes32[] calldata merkleProof,
        address referrer
    ) external payable nonReentrant {
        // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
        if (merkleProof.length == 0) {
            _computeDigestAndVerify(makerAsk.hash(), makerSignature, makerAsk.signer);
        } else {
            _verifyMerkleProofForOrderHash(merkleProof, merkleRoot.root, makerAsk.hash());
            _computeDigestAndVerify(merkleRoot.hash(), makerSignature, makerAsk.signer);
        }

        // Execute the transaction and fetch protocol fee
        uint256 totalProtocolFee = _executeTakerBid(takerBid, makerAsk, msg.sender);

        // Pay protocol fee (and referral fee if any)
        _payProtocolFeeAndReferralFee(makerAsk.currency, msg.sender, referrer, totalProtocolFee);

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
     * @param referrer Referrer address
     * @param isAtomic Whether the execution should be atomic i.e., whether it should revert if 1 or more order fails
     */
    function executeMultipleTakerBids(
        OrderStructs.TakerBid[] calldata takerBids,
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleRoot[] calldata merkleRoots,
        bytes32[][] calldata merkleProofs,
        address referrer,
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

        // Initialize protocol fee
        uint256 totalProtocolFee;
        for (uint256 i; i < takerBids.length; ) {
            {
                if (i != 0 && makerAsks[i].currency != makerAsks[i - 1].currency) revert WrongCurrency();
            }

            // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
            if (merkleProofs[i].length == 0) {
                _computeDigestAndVerify(makerAsks[i].hash(), makerSignatures[i], makerAsks[i].signer);
            } else {
                {
                    _verifyMerkleProofForOrderHash(merkleProofs[i], merkleRoots[i].root, makerAsks[i].hash());
                }
                _computeDigestAndVerify(merkleRoots[i].hash(), makerSignatures[i], makerAsks[i].signer);
            }

            if (isAtomic) {
                // Execute the transaction and add protocol fee
                totalProtocolFee += _executeTakerBid(takerBids[i], makerAsks[i], msg.sender);
            } else {
                try this.restrictedExecuteTakerBid(takerBids[i], makerAsks[i], msg.sender) returns (
                    uint256 protocolFee
                ) {
                    totalProtocolFee += protocolFee;
                } catch {}
            }

            unchecked {
                ++i;
            }
        }

        // Pay protocol fee (and referral fee if any)
        _payProtocolFeeAndReferralFee(makerAsks[0].currency, msg.sender, referrer, totalProtocolFee);

        // Return ETH if any
        _returnETHIfAny();
    }

    /**
     * @notice Function used to do non-atomic matching in the context of a batch taker bid
     * @param takerBid Taker bid struct
     * @param makerAsk Maker ask struct
     * @param sender Sender address (i.e., the initial msg sender)
     * @return protocolFeeAmount Protocol fee amount
     * @dev This function is only callable by this contract. It is used for non-atomic batch order matching.
     */
    function restrictedExecuteTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        address sender
    ) external returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) revert WrongCaller();
        return _executeTakerBid(takerBid, makerAsk, sender);
    }

    /**
     * @notice Update the domain separator
     * @dev If there is a fork of the network with a new chainId, it allows the owner to reset the domain separator for
     *      the chain with the new id. Anyone can call this function.
     */
    function updateDomainSeparator() external {
        if (block.chainid != _chainId) {
            _domainSeparator = keccak256(
                abi.encode(
                    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                    keccak256("LooksRareProtocol"),
                    keccak256(bytes("2")),
                    block.chainid,
                    address(this)
                )
            );
            _chainId = block.chainid;
            emit NewDomainSeparator();
        } else {
            revert SameDomainSeparator();
        }
    }

    /**
     * @notice Add transfer manager for new asset types
     * @param assetType Asset type
     * @param transferManager Transfer manager address
     */
    function addTransferManagerForAssetType(uint8 assetType, address transferManager) external onlyOwner {
        if (transferManagerOfAssetType[assetType] != address(0)) revert WrongAssetType(assetType);
        transferManagerOfAssetType[assetType] = transferManager;

        emit NewAssetType(assetType, transferManager);
    }

    /**
     * @notice Return an array with initial domain separator, initial chainId, current domain separator, and current chainId address
     * @return initialDomainSeparator Domain separator at the deployment
     * @return initialChainId ChainId at the deployment
     * @return currentDomainSeparator Current domain separator
     * @return currentChainId Current chainId
     */
    function information()
        external
        view
        returns (
            bytes32 initialDomainSeparator,
            uint256 initialChainId,
            bytes32 currentDomainSeparator,
            uint256 currentChainId
        )
    {
        return (_INITIAL_DOMAIN_SEPARATOR, _INITIAL_CHAIN_ID, _domainSeparator, _chainId);
    }

    /**
     * @notice Sell with taker ask (against maker bid)
     * @param takerAsk Taker ask order struct
     * @param makerBid Maker bid order struct
     * @param sender Sender of the transaction (i.e., msg.sender)
     * @return protocolFeeAmount Protocol fee amount
     */
    function _executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        address sender
    ) internal returns (uint256 protocolFeeAmount) {
        // Verify whether the currency is whitelisted but is not ETH (address(0))
        if (!isCurrencyWhitelisted[makerBid.currency] && makerBid.currency != address(0)) revert WrongCurrency();

        // Verify nonces and invalidate order nonce if valid
        if (
            _userBidAskNonces[makerBid.signer].askNonce != makerBid.bidNonce ||
            userSubsetNonce[makerBid.signer][makerBid.subsetNonce] ||
            userOrderNonce[makerBid.signer][makerBid.orderNonce]
        ) revert WrongNonces();

        // Invalidate order at this nonce for future execution
        userOrderNonce[makerBid.signer][makerBid.orderNonce] = true;

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        recipients[0] = takerAsk.recipient == address(0) ? sender : takerAsk.recipient;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerAsk(
            takerAsk,
            makerBid
        );

        for (uint256 i; i < recipients.length; ) {
            if (recipients[i] != address(0) && fees[i] != 0) {
                _transferFungibleTokens(makerBid.currency, makerBid.signer, recipients[i], fees[i]);
            }
            unchecked {
                ++i;
            }
        }

        _transferNFT(
            makerBid.collection,
            makerBid.assetType,
            sender,
            makerBid.recipient == address(0) ? makerBid.signer : makerBid.recipient,
            itemIds,
            amounts
        );

        emit TakerAsk(
            makerBid.orderNonce,
            makerBid.signer,
            makerBid.recipient == address(0) ? makerBid.signer : makerBid.recipient,
            sender,
            takerAsk.recipient,
            makerBid.strategyId,
            makerBid.currency,
            makerBid.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );
    }

    /**
     * @notice Execute taker bid (against maker ask)
     * @param takerBid Taker bid order struct
     * @param makerAsk Maker ask order struct
     * @param sender Sender of the transaction (i.e., msg.sender)
     * @return protocolFeeAmount Protocol fee amount
     */
    function _executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        address sender
    ) internal returns (uint256 protocolFeeAmount) {
        // Verify whether the currency is available
        if (!isCurrencyWhitelisted[makerAsk.currency]) revert WrongCurrency();

        // Verify nonces and invalidate order nonce if valid
        if (
            _userBidAskNonces[makerAsk.signer].askNonce != makerAsk.askNonce ||
            userSubsetNonce[makerAsk.signer][makerAsk.subsetNonce] ||
            userOrderNonce[makerAsk.signer][makerAsk.orderNonce]
        ) revert WrongNonces();

        // Invalidate order at this nonce for future execution
        userOrderNonce[makerAsk.signer][makerAsk.orderNonce] = true;

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        recipients[0] = makerAsk.recipient == address(0) ? makerAsk.signer : makerAsk.recipient;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerBid(
            takerBid,
            makerAsk
        );

        _transferNFT(
            makerAsk.collection,
            makerAsk.assetType,
            makerAsk.signer,
            takerBid.recipient == address(0) ? sender : takerBid.recipient,
            itemIds,
            amounts
        );

        for (uint256 i; i < recipients.length; ) {
            if (recipients[i] != address(0) && fees[i] != 0) {
                _transferFungibleTokens(makerAsk.currency, sender, recipients[i], fees[i]);
            }
            unchecked {
                ++i;
            }
        }

        emit TakerBid(
            makerAsk.orderNonce,
            sender,
            takerBid.recipient == address(0) ? sender : takerBid.recipient,
            makerAsk.signer,
            makerAsk.strategyId,
            makerAsk.currency,
            makerAsk.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );
    }

    /**
     * @notice Pay protocol fee and referral fee (if any)
     * @param currency Currency address to transfer (address(0) is ETH)
     * @param bidUser Bid user address
     * @param referrer Referrer address (address(0) if none)
     * @param totalProtocolFee Total protocol fee (denominated in the currency)
     */
    function _payProtocolFeeAndReferralFee(
        address currency,
        address bidUser,
        address referrer,
        uint256 totalProtocolFee
    ) internal {
        uint256 totalReferralFee;

        // Check whether referral program is active and whether to execute a referral logic (and adjust downward the protocol fee if so)
        if (isReferralProgramActive && referrer != address(0)) {
            totalReferralFee = (totalProtocolFee * referrerRates[referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;

            // If bid user isn't the referrer, pay the referral.
            // If currency is ETH, funds are returned to sender at the end of the execution.
            // If currency is ERC20, funds are not transferred from bidder to bidder.
            if (bidUser != referrer) {
                _transferFungibleTokens(currency, bidUser, referrer, totalReferralFee);
            }
        }

        // Transfer remaining protocol fee to the protocol fee recipient
        _transferFungibleTokens(currency, bidUser, protocolFeeRecipient, totalProtocolFee);

        if (totalReferralFee != 0) {
            emit ProtocolPaymentWithReferrer(currency, totalProtocolFee, referrer, totalReferralFee);
        } else {
            emit ProtocolPayment(currency, totalProtocolFee);
        }
    }

    /**
     * @notice Transfer non-fungible tokens
     * @param collection Collection address
     * @param assetType Asset type (0 = ERC721, 1 = ERC1155)
     * @param sender Sender address
     * @param recipient Recipient address
     * @param itemIds Array of itemIds
     * @param amounts Array of amounts
     */
    function _transferNFT(
        address collection,
        uint8 assetType,
        address sender,
        address recipient,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal {
        // Verify there is a transfer manager for the asset type
        address transferManager = transferManagerOfAssetType[assetType];
        if (transferManager == address(0)) revert NoTransferManagerForAssetType(assetType);

        // 0 is not an option
        if (itemIds.length == 1) {
            ITransferManager(transferManager).transferSingleItem(
                collection,
                assetType,
                sender,
                recipient,
                itemIds[0],
                amounts[0]
            );
        } else {
            ITransferManager(transferManager).transferBatchItems(
                collection,
                assetType,
                sender,
                recipient,
                itemIds,
                amounts
            );
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
        bytes32 digest = keccak256(abi.encodePacked(_ENCODING_PREFIX, _domainSeparator, computedHash));
        _verify(digest, signer, makerSignature);
    }

    /**
     * @notice Verify whether the merkle proofs provided for the order hash are correct
     * @param proof Array containing the merkle proof
     * @param root Merkle root
     * @param orderHash Order hash (can be maker bid hash or maker ask hash)
     */
    function _verifyMerkleProofForOrderHash(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 orderHash
    ) internal pure {
        if (!MerkleProof.verify(proof, root, orderHash)) revert WrongMerkleProof();
    }
}
