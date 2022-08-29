// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";

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

// Low-level callers
import {LowLevelETH} from "./lowLevelCallers/LowLevelETH.sol";
import {LowLevelERC20} from "./lowLevelCallers/LowLevelERC20.sol";

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
    using OrderStructs for bytes32;

    // Initial domain separator
    bytes32 internal _INITIAL_DOMAIN_SEPARATOR;

    // Initial chainId
    uint256 internal _INITIAL_CHAIN_ID;

    // Current domain separator
    bytes32 internal _domainSeparator;

    // Current chainId
    uint256 internal _chainId;

    // Keep track of transfer managers
    mapping(uint16 => address) internal _transferManagers;

    /**
     * @notice Constructor
     * @param transferManager address of the transfer manager
     * @param royaltyFeeManager address of the royalty fee manager
     */
    constructor(address transferManager, address royaltyFeeManager) ExecutionManager(royaltyFeeManager) {
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
        _transferManagers[0] = transferManager;
        _transferManagers[1] = transferManager;
    }

    /**
     * @notice Buy with taker bid (against makerAsk)
     * @param takerBid taker bid struct
     * @param makerAsk maker ask struct
     * @param makerSignature maker signature
     * @param merkleRoot merkle root if the signature contains multiple maker orders
     * @param merkleProofs array containing merkle proofs (if multiple maker orders under the signature)
     * @param referrer address of the referrer
     */
    function executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        bytes32 merkleRoot,
        bytes32[] calldata merkleProofs,
        address referrer
    ) external payable nonReentrant {
        // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
        {
            bytes32 digest;
            if (merkleProofs.length == 0) {
                digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, makerAsk.hash()));
            } else {
                _verifyMerkleProofForOrderHash(merkleProofs, merkleRoot, makerAsk.hash());
                digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, merkleRoot.hash()));
            }
            _verify(digest, makerAsk.signer, makerSignature);
        }

        // Execute the transaction and fetch protocol fee
        uint256 totalProtocolFee = _executeTakerBid(takerBid, msg.sender, makerAsk);

        // Check whether to execute a referral logic (and adjust downward the protocol fee if so)
        if (referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;

            // Transfer the referral fee if anything to transfer
            _transferFungibleTokens(makerAsk.currency, msg.sender, referrer, totalReferralFee);
        }

        // Transfer remaining protocol fee to the fee recipient
        _transferFungibleTokens(makerAsk.currency, msg.sender, _protocolFeeRecipient, totalProtocolFee);

        // Return ETH if any
        _returnETHIfAny();
    }

    /**
     * @notice Buy with taker ask (against maker bid)
     * @param takerAsk taker ask struct
     * @param makerBid maker bid struct
     * @param makerSignature maker signature
     * @param merkleRoot merkle root if the signature contains multiple maker orders
     * @param merkleProofs array containing merkle proofs (if multiple maker orders under the signature)
     * @param referrer address of the referrer
     */
    function executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        bytes32 merkleRoot,
        bytes32[] calldata merkleProofs,
        address referrer
    ) external nonReentrant {
        // Verify (1) MerkleProof (if necessary) (2) Signature is from the signer
        {
            bytes32 digest;
            if (merkleProofs.length == 0) {
                digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, makerBid.hash()));
            } else {
                _verifyMerkleProofForOrderHash(merkleProofs, merkleRoot, makerBid.hash());
                digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, merkleRoot.hash()));
            }
            _verify(digest, makerBid.signer, makerSignature);
        }

        // Execute the transaction and fetch protocol fee
        uint256 totalProtocolFee = _executeTakerAsk(takerAsk, msg.sender, makerBid);

        // Check whether to execute a referral logic (and adjust downward the protocol fee if so)
        if (referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;

            // Transfer the referral fee if anything to transfer
            _transferFungibleTokens(makerBid.currency, makerBid.signer, referrer, totalReferralFee);
        }

        // Transfer remaining protocol fee to the fee recipient
        _transferFungibleTokens(makerBid.currency, makerBid.signer, _protocolFeeRecipient, totalProtocolFee);
    }

    /**
     * @notice Return an array with initial domain separator, initial chainId, current domain separator, and current chainId address
     * @return initialDomainSeparator domain separator at the deployment
     * @return initialChainId chainId at the deployment
     * @return currentDomainSeparator current domain separator
     * @return currentChainId current chainId
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
     * @notice Add transfer manager for new asset types
     * @param assetType asset type
     * @param transferManager transfer manager address
     */
    function addTransferManagerForAssetType(uint8 assetType, address transferManager) external onlyOwner {
        if (_transferManagers[assetType] != address(0)) {
            revert WrongAssetType(assetType);
        }

        _transferManagers[assetType] = transferManager;
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
                    keccak256("LooksRareExchange"),
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
     * @notice Execute takerBid
     * @param takerBid taker bid order struct
     * @param sender sender of the transaction (i.e., msg.sender)
     * @param makerAsk maker ask order struct
     */
    function _executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        address sender,
        OrderStructs.MakerAsk calldata makerAsk
    ) internal returns (uint256 protocolFeeAmount) {
        // Verify whether the currency is available
        if (!_isCurrencyWhitelisted[makerAsk.currency]) {
            revert WrongCurrency();
        }

        // Verify nonces and invalidate order nonce if valid
        if (
            _userBidAskNonces[makerAsk.signer].askNonce != makerAsk.askNonce ||
            _userSubsetNonce[makerAsk.signer][makerAsk.subsetNonce] ||
            _userOrderNonce[makerAsk.signer][makerAsk.orderNonce]
        ) {
            revert WrongNonces();
        } else {
            // Invalidate order at this nonce for future execution
            _userOrderNonce[makerAsk.signer][makerAsk.orderNonce] = true;
        }

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
     * @notice Execute takerAsk
     * @param takerAsk taker ask order struct
     * @param sender sender of the transaction (i.e., msg.sender)
     * @param makerBid maker bid order struct
     */
    function _executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        address sender,
        OrderStructs.MakerBid calldata makerBid
    ) internal returns (uint256 protocolFeeAmount) {
        // Verify whether the currency is whitelisted but is not ETH (address(0))
        if (!_isCurrencyWhitelisted[makerBid.currency] && makerBid.currency != address(0)) {
            revert WrongCurrency();
        }

        // Verify nonces and invalidate order nonce if valid
        if (
            _userBidAskNonces[makerBid.signer].askNonce != makerBid.bidNonce ||
            _userSubsetNonce[makerBid.signer][makerBid.subsetNonce] ||
            _userOrderNonce[makerBid.signer][makerBid.orderNonce]
        ) {
            revert WrongNonces();
        } else {
            // Invalidate order at this nonce for future execution
            _userOrderNonce[makerBid.signer][makerBid.orderNonce] = true;
        }

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
     * @notice Transfer non-fungible tokens
     * @param collection address of the collection
     * @param assetType asset type (0 = ERC721, 1 = ERC1155)
     * @param sender address of the sender
     * @param recipient address of the recipient
     * @param itemIds array of itemIds
     * @param amounts array of amounts
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
        address transferManager = _transferManagers[assetType];
        if (transferManager == address(0)) {
            revert NoTransferManagerForAssetType(assetType);
        }

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
     * @param currency address of the currency
     * @param sender address of sender
     * @param recipient address recipient
     * @param amount array of amount
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
            _executeERC20Transfer(currency, sender, recipient, amount);
        }
    }

    /**
     * @notice Verify whether the merkle proofs provided for the order hash are correct
     * @param proof array containing merkle proofs
     * @param root merkle root
     * @param orderHash order hash
     */
    function _verifyMerkleProofForOrderHash(
        bytes32[] memory proof,
        bytes32 root,
        bytes32 orderHash
    ) internal pure returns (bool isVerified) {
        return MerkleProof.verify(proof, root, orderHash);
    }
}
