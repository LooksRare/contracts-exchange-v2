// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";
import {LowLevelETHReturnETHIfAnyExceptOneWei} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelETHReturnETHIfAnyExceptOneWei.sol";
import {LowLevelWETH} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelWETH.sol";
import {LowLevelERC20Transfer} from "@looksrare/contracts-libs/contracts/lowLevelCallers/LowLevelERC20Transfer.sol";

// OpenZeppelin's library for verifying Merkle proofs
import {MerkleProofCalldata} from "./libraries/OpenZeppelin/MerkleProofCalldata.sol";

// Libraries
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {ILooksRareProtocol} from "./interfaces/ILooksRareProtocol.sol";

// Shared errors
import {WrongCaller, WrongCurrency, WrongLengths, WrongMerkleProof} from "./interfaces/SharedErrors.sol";

// Direct dependencies
import {TransferSelectorNFT} from "./TransferSelectorNFT.sol";

/**
 * @title LooksRareProtocol
 * @notice This contract is the core contract of the LooksRare protocol (v2).
LOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRAR'''''''''''''''''''''''''''''''''''OOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKS:.                                        .;OOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOO,.                                            .,KSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRAREL'                ..',;:LOOKS::;,'..                'RARELOOKSRARELOOKSR
LOOKSRARELOOKSRAR.              .,:LOOKSRARELOOKSRARELO:,.              .RELOOKSRARELOOKSR
LOOKSRARELOOKS:.             .;RARELOOKSRARELOOKSRARELOOKSl;.             .:OOKSRARELOOKSR
LOOKSRARELOO;.            .'OKSRARELOOKSRARELOOKSRARELOOKSRARE'.            .;KSRARELOOKSR
LOOKSRAREL,.            .,LOOKSRARELOOK:;;:"""":;;;lELOOKSRARELO,.            .,RARELOOKSR
LOOKSRAR.             .;okLOOKSRAREx:.              .;OOKSRARELOOK;.             .RELOOKSR
LOOKS:.             .:dOOOLOOKSRARE'      .''''..     .OKSRARELOOKSR:.             .LOOKSR
LOx;.             .cKSRARELOOKSRAR'     'LOOKSRAR'     .KSRARELOOKSRARc..            .OKSR
L;.             .cxOKSRARELOOKSRAR.    .LOOKS.RARE'     ;kRARELOOKSRARExc.             .;R
LO'             .;oOKSRARELOOKSRAl.    .LOOKS.RARE.     :kRARELOOKSRAREo;.             'SR
LOOK;.            .,KSRARELOOKSRAx,     .;LOOKSR;.     .oSRARELOOKSRAo,.            .;OKSR
LOOKSk:.            .'RARELOOKSRARd;.      ....       'oOOOOOOOOOOxc'.            .:LOOKSR
LOOKSRARc.             .:dLOOKSRAREko;.            .,lxOOOOOOOOOd:.             .ARELOOKSR
LOOKSRARELo'             .;oOKSRARELOOxoc;,....,;:ldkOOOOOOOOkd;.             'SRARELOOKSR
LOOKSRARELOOd,.            .,lSRARELOOKSRARELOOKSRARELOOKSRkl,.            .,OKSRARELOOKSR
LOOKSRARELOOKSx;.            ..;oxELOOKSRARELOOKSRARELOkxl:..            .:LOOKSRARELOOKSR
LOOKSRARELOOKSRARc.              .':cOKSRARELOOKSRALOc;'.              .ARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELl'                 ...'',,,,''...                 'SRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOo,.                                          .,OKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSx;.                                      .;xOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLO:.                                  .:SRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKl.                              .lOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRo'.                        .'oLOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARd;.                    .;xRELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARELO:.                .:kRARELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKl.            .cOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRo'        'oLOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRARE,.  .,dRELOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSR
LOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSRARELOOKSRARELOOKSRLOOKSRARELOOKSRARELOOKSR
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocol is
    ILooksRareProtocol,
    TransferSelectorNFT,
    ReentrancyGuard,
    LowLevelETHReturnETHIfAnyExceptOneWei,
    LowLevelWETH,
    LowLevelERC20Transfer
{
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    // Wrapped ETH
    address public immutable WETH;

    // Current chainId
    uint256 public chainId;

    // Current domain separator
    bytes32 public domainSeparator;

    // Gas limit
    uint256 private _gasLimitETHTransfer = 2_300;

    /**
     * @notice Constructor
     * @param _owner Owner address
     * @param _transferManager Transfer manager address
     * @param _weth Wrapped ETH address
     */
    constructor(address _owner, address _transferManager, address _weth) TransferSelectorNFT(_owner, _transferManager) {
        _updateDomainSeparator();
        WETH = _weth;
    }

    /**
     * @inheritdoc ILooksRareProtocol
     */
    function executeTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external nonReentrant {
        // Verify whether the currency is whitelisted but is not ETH (address(0))
        if (!isCurrencyWhitelisted[makerBid.currency] || makerBid.currency == address(0)) {
            revert WrongCurrency();
        }

        address signer = makerBid.signer;
        bytes32 orderHash = makerBid.hash();
        _verifyMerkleProofOrOrderHash(merkleTree, orderHash, makerSignature, signer);

        // Execute the transaction and fetch protocol fee amount
        uint256 totalProtocolFeeAmount = _executeTakerAsk(takerAsk, makerBid, orderHash);

        // Pay protocol fee (and affiliate fee if any)
        _payProtocolFeeAndAffiliateFee(makerBid.currency, signer, affiliate, totalProtocolFeeAmount);
    }

    /**
     * @inheritdoc ILooksRareProtocol
     */
    function executeTakerBid(
        OrderStructs.TakerBid calldata takerBid,
        OrderStructs.MakerAsk calldata makerAsk,
        bytes calldata makerSignature,
        OrderStructs.MerkleTree calldata merkleTree,
        address affiliate
    ) external payable nonReentrant {
        // Verify whether the currency is whitelisted
        if (!isCurrencyWhitelisted[makerAsk.currency]) {
            revert WrongCurrency();
        }

        bytes32 orderHash = makerAsk.hash();
        _verifyMerkleProofOrOrderHash(merkleTree, orderHash, makerSignature, makerAsk.signer);

        // Execute the transaction and fetch protocol fee amount
        uint256 totalProtocolFeeAmount = _executeTakerBid(takerBid, makerAsk, msg.sender, orderHash);

        // Pay protocol fee amount (and affiliate fee if any)
        _payProtocolFeeAndAffiliateFee(makerAsk.currency, msg.sender, affiliate, totalProtocolFeeAmount);

        // Return ETH if any
        _returnETHIfAnyWithOneWeiLeft();
    }

    /**
     * @inheritdoc ILooksRareProtocol
     */
    function executeMultipleTakerBids(
        OrderStructs.TakerBid[] calldata takerBids,
        OrderStructs.MakerAsk[] calldata makerAsks,
        bytes[] calldata makerSignatures,
        OrderStructs.MerkleTree[] calldata merkleTrees,
        address affiliate,
        bool isAtomic
    ) external payable nonReentrant {
        uint256 length = takerBids.length;
        if (
            length == 0 ||
            (makerAsks.length ^ length) | (makerSignatures.length ^ length) | (merkleTrees.length ^ length) != 0
        ) {
            revert WrongLengths();
        }

        // Verify whether the currency at array = 0 is whitelisted
        address currency = makerAsks[0].currency;
        if (!isCurrencyWhitelisted[currency]) {
            revert WrongCurrency();
        }

        {
            // Initialize protocol fee
            uint256 totalProtocolFeeAmount;

            for (uint256 i; i < length; ) {
                OrderStructs.MakerAsk calldata makerAsk = makerAsks[i];

                // Verify currency is the same
                if (i != 0) {
                    if (makerAsk.currency != currency) {
                        revert WrongCurrency();
                    }
                }

                OrderStructs.TakerBid calldata takerBid = takerBids[i];
                bytes32 orderHash = makerAsk.hash();

                {
                    _verifyMerkleProofOrOrderHash(merkleTrees[i], orderHash, makerSignatures[i], makerAsk.signer);

                    // If atomic, it uses the executeTakerBid function, if not atomic, it uses a catch/revert pattern with external function
                    if (isAtomic) {
                        // Execute the transaction and add protocol fee
                        totalProtocolFeeAmount += _executeTakerBid(takerBid, makerAsk, msg.sender, orderHash);
                    } else {
                        try this.restrictedExecuteTakerBid(takerBid, makerAsk, msg.sender, orderHash) returns (
                            uint256 protocolFeeAmount
                        ) {
                            totalProtocolFeeAmount += protocolFeeAmount;
                        } catch {}
                    }

                    unchecked {
                        ++i;
                    }
                }
            }

            // Pay protocol fee (and affiliate fee if any)
            _payProtocolFeeAndAffiliateFee(currency, msg.sender, affiliate, totalProtocolFeeAmount);
        }

        // Return ETH if any
        _returnETHIfAnyWithOneWeiLeft();
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
        if (msg.sender != address(this)) {
            revert WrongCaller();
        }

        protocolFeeAmount = _executeTakerBid(takerBid, makerAsk, sender, orderHash);
    }

    /**
     * @notice Update the domain separator
     * @dev  Only callable by owner. If there is a fork of the network with a new chainId,
     *      it allows the owner to reset the domain separator for the new chain id.
     */
    function updateDomainSeparator() external onlyOwner {
        if (block.chainid != chainId) {
            _updateDomainSeparator();
            emit NewDomainSeparator();
        } else {
            revert SameDomainSeparator();
        }
    }

    /**
     * @notice Update ETH gas limit for transfer
     * @param newGasLimitETHTransfer New gas limit for ETH transfer
     * @dev Only callable by owner.
     */
    function updateETHGasLimitForTransfer(uint256 newGasLimitETHTransfer) external onlyOwner {
        if (newGasLimitETHTransfer < 2_300) {
            revert NewGasLimitETHTransferTooLow();
        }

        _gasLimitETHTransfer = newGasLimitETHTransfer;

        emit NewGasLimitETHTransfer(newGasLimitETHTransfer);
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
        address signer = makerBid.signer;
        {
            bytes32 userOrderNonceStatus = userOrderNonce[signer][makerBid.orderNonce];
            // Verify nonces
            if (
                userBidAskNonces[signer].bidNonce != makerBid.bidNonce ||
                userSubsetNonce[signer][makerBid.subsetNonce] ||
                (userOrderNonceStatus != bytes32(0) && userOrderNonceStatus != orderHash)
            ) {
                revert WrongNonces();
            }
        }

        (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        ) = _executeStrategyForTakerAsk(takerAsk, makerBid, msg.sender);

        _updateUserOrderNonce(isNonceInvalidated, signer, makerBid.orderNonce, orderHash);

        _transferToAskRecipientAndCreatorIfAny(recipients, fees, makerBid.currency, signer);
        _transferNFT(makerBid.collection, makerBid.assetType, msg.sender, signer, itemIds, amounts);

        emit TakerAsk(
            SignatureParameters({
                orderHash: orderHash,
                orderNonce: makerBid.orderNonce,
                isNonceInvalidated: isNonceInvalidated
            }),
            msg.sender,
            signer,
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
        address signer = makerAsk.signer;
        {
            // Verify nonces
            bytes32 userOrderNonceStatus = userOrderNonce[signer][makerAsk.orderNonce];

            if (
                userBidAskNonces[signer].askNonce != makerAsk.askNonce ||
                userSubsetNonce[signer][makerAsk.subsetNonce] ||
                (userOrderNonceStatus != bytes32(0) && userOrderNonceStatus != orderHash)
            ) {
                revert WrongNonces();
            }
        }

        (
            uint256[] memory itemIds,
            uint256[] memory amounts,
            address[3] memory recipients,
            uint256[3] memory fees,
            bool isNonceInvalidated
        ) = _executeStrategyForTakerBid(takerBid, makerAsk);

        _updateUserOrderNonce(isNonceInvalidated, signer, makerAsk.orderNonce, orderHash);

        {
            _transferNFT(
                makerAsk.collection,
                makerAsk.assetType,
                signer,
                takerBid.recipient == address(0) ? sender : takerBid.recipient,
                itemIds,
                amounts
            );

            _transferToAskRecipientAndCreatorIfAny(recipients, fees, makerAsk.currency, sender);
        }

        emit TakerBid(
            SignatureParameters({
                orderHash: orderHash,
                orderNonce: makerAsk.orderNonce,
                isNonceInvalidated: isNonceInvalidated
            }),
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
     * @param totalProtocolFeeAmount Total protocol fee amount (denominated in the currency)
     */
    function _payProtocolFeeAndAffiliateFee(
        address currency,
        address bidUser,
        address affiliate,
        uint256 totalProtocolFeeAmount
    ) internal {
        uint256 totalAffiliateFeeAmount;

        // Check whether affiliate program is active and whether to execute a affiliate logic (and adjust downward the protocol fee if so)
        if (affiliate != address(0)) {
            if (isAffiliateProgramActive) {
                totalAffiliateFeeAmount = (totalProtocolFeeAmount * affiliateRates[affiliate]) / 10_000;
                totalProtocolFeeAmount -= totalAffiliateFeeAmount;

                // If bid user isn't the affiliate, pay the affiliate.
                // If currency is ETH, funds are returned to sender at the end of the execution.
                // If currency is ERC20, funds are not transferred from bidder to bidder (since it uses transferFrom).
                if (bidUser != affiliate) {
                    _transferFungibleTokens(currency, bidUser, affiliate, totalAffiliateFeeAmount);
                }
            }
        }

        // Transfer remaining protocol fee to the protocol fee recipient
        _transferFungibleTokens(currency, bidUser, protocolFeeRecipient, totalProtocolFeeAmount);

        if (totalAffiliateFeeAmount != 0) {
            emit AffiliatePayment(affiliate, currency, totalAffiliateFeeAmount);
        }
    }

    /**
     * @notice Transfer fungible tokens
     * @param currency Currency address
     * @param sender Sender address
     * @param recipient Recipient address
     * @param amount Amount (in fungible tokens)
     */
    function _transferFungibleTokens(address currency, address sender, address recipient, uint256 amount) internal {
        if (currency == address(0)) {
            _transferETHAndWrapIfFailWithGasLimit(WETH, recipient, amount, _gasLimitETHTransfer);
        } else {
            _executeERC20TransferFrom(currency, sender, recipient, amount);
        }
    }

    /**
     * @notice Compute digest and verify
     * @dev If chainId is not equal to the cached chain id, it would revert.
     * @param computedHash Hash of order (maker bid or maker ask) or merkle root
     * @param makerSignature Signature of the maker
     * @param signer Signer address
     */
    function _computeDigestAndVerify(bytes32 computedHash, bytes calldata makerSignature, address signer) private view {
        if (chainId == block.chainid) {
            // \x19\x01 is the standard encoding prefix
            SignatureChecker.verify(
                keccak256(abi.encodePacked("\x19\x01", domainSeparator, computedHash)),
                signer,
                makerSignature
            );
        } else {
            revert WrongChainId();
        }
    }

    /**
     * @notice Transfer funds to (1) creator recipient (if any), (2) ask recipient
     * @param recipients Recipient addresses
     * @param fees Fees
     * @param currency Currency address
     * @param bidUser Bid user address
     * @dev It does not send to the 0-th element in the array since it is the protocol fee, which is paid later in the execution flow.
     */
    function _transferToAskRecipientAndCreatorIfAny(
        address[3] memory recipients,
        uint256[3] memory fees,
        address currency,
        address bidUser
    ) private {
        // @dev There is no check for address(0), if the creator recipient is address(0), the fee is set to 0
        if (fees[1] != 0) {
            _transferFungibleTokens(currency, bidUser, recipients[1], fees[1]);
        }

        // @dev There is no check for address(0) since the ask recipient can never be address(0)
        // If ask recipient is the maker --> the signer cannot be the null address
        // If ask is the taker --> either it is the sender address or if the recipient (in TakerAsk) is set to address(0), it is adjusted to
        // the original taker address
        if (fees[2] != 0) {
            _transferFungibleTokens(currency, bidUser, recipients[2], fees[2]);
        }
    }

    /**
     * @notice Update the domain separator and cache the chain id
     */
    function _updateDomainSeparator() private {
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
    }

    /**
     * @notice Update the user order nonce
     * @param isNonceInvalidated Whether the nonce is being invalidated
     * @param signer Signer address
     * @param orderNonce Maker user order nonce
     * @param orderHash Hash of the order struct
     * @dev If isNonceInvalidated is true, this function invalidates the user order nonce for future execution.
     *      If it is equal to false, this function maps the order hash for this user order nonce to prevent other order structs sharing the same order nonce to be executed.
     */
    function _updateUserOrderNonce(
        bool isNonceInvalidated,
        address signer,
        uint256 orderNonce,
        bytes32 orderHash
    ) private {
        userOrderNonce[signer][orderNonce] = (isNonceInvalidated ? MAGIC_VALUE_ORDER_NONCE_EXECUTED : orderHash);
    }

    /**
     * @notice Verify whether the merkle proofs provided for the order hash are correct,
     *         or verify the order hash if it is not a merkle proof order
     * @param merkleTree Merkle tree
     * @param orderHash Order hash (can be maker bid hash or maker ask hash)
     * @param signature Maker order signature
     * @param signer Maker address
     * @dev It verifies (1) merkle proof (if necessary) (2) Signature is from the expected signer
     */
    function _verifyMerkleProofOrOrderHash(
        OrderStructs.MerkleTree calldata merkleTree,
        bytes32 orderHash,
        bytes calldata signature,
        address signer
    ) private view {
        if (merkleTree.proof.length != 0) {
            if (!MerkleProofCalldata.verifyCalldata(merkleTree.proof, merkleTree.root, orderHash)) {
                revert WrongMerkleProof();
            }
            _computeDigestAndVerify(merkleTree.hash(), signature, signer);
        } else {
            _computeDigestAndVerify(orderHash, signature, signer);
        }
    }
}
