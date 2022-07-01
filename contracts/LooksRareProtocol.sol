// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare generalist libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {ITransferManager} from "./interfaces/ITransferManager.sol";

// Peripheral contracts
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
 * @notice This contract is the primary contract of the LooksRare protocol (v2). It inherits from other core contracts, such as CurrencyManager, ExecutionManager, and NonceManager.
 * @author LooksRare protocol team (👀,💎)
 */
contract LooksRareProtocol is
    CurrencyManager,
    ExecutionManager,
    NonceManager,
    ReferralManager,
    ReentrancyGuard,
    LowLevelETH,
    LowLevelERC20,
    SignatureChecker
{
    using OrderStructs for OrderStructs.MultipleMakerAskOrders;
    using OrderStructs for OrderStructs.MultipleMakerBidOrders;

    // Keep track of transfer managers
    mapping(uint16 => address) internal _transferManagers;

    // Initial domain separator
    bytes32 internal _INITIAL_DOMAIN_SEPARATOR;

    // Initial chainId
    uint256 internal _INITIAL_CHAIN_ID;

    // Current domain separator
    bytes32 internal _domainSeparator;

    // Current chainId
    uint256 internal _chainId;

    // Custom errors
    error NoTransferManagerForAssetType(uint16 assetType);
    error WrongNonces();
    error WrongAssetType(uint16 assetType);
    error WrongCurrency();
    error WrongCaller();

    // Events
    event TakerBid(
        uint128 orderNonce,
        address bidUser,
        address bidRecipient,
        address askUser,
        uint256 strategyId,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        address[] feeRecipients,
        uint256[] feeAmounts
    );

    event TakerAsk(
        uint128 orderNonce,
        address bidUser,
        address bidRecipient,
        address askUser,
        address askRecipient,
        address strategy,
        address currency,
        address collection,
        uint256[] itemIds,
        uint256[] amounts,
        uint256 price
    );

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

        // Transfer managers
        _transferManagers[0] = transferManager;
        _transferManagers[1] = transferManager;
    }

    /**
     * @notice Match multiple maker asks with taker bids
     * @param multipleTakerBids multiple taker bid orders
     * @param multipleMakerAsks multiple maker ask orders
     * @param makerArraySlots array of maker array slot
     * @param isExecutionAtomic whether the execution should revert if one of the transaction fails. If it is true, the execution must be atomic. Any revertion will make the transaction fail.
     */
    function matchMultipleAsksWithTakerBids(
        OrderStructs.MultipleTakerBidOrders calldata multipleTakerBids,
        OrderStructs.MultipleMakerAskOrders[] calldata multipleMakerAsks,
        uint256[] calldata makerArraySlots,
        bool isExecutionAtomic
    ) external payable nonReentrant {
        uint256 length = multipleTakerBids.takerBidOrders.length;

        if (length == 0 || multipleMakerAsks.length != length || makerArraySlots.length != length) {
            revert WrongLengths();
        }

        uint256 totalProtocolFee;

        // Fire the trades
        for (uint256 i; i < multipleMakerAsks.length; ) {
            // Verify currency is the same as taker bid
            if (multipleTakerBids.currency != multipleMakerAsks[i].baseMakerOrder.currency) {
                revert WrongCurrency();
            }

            if (isExecutionAtomic) // If execution is desired to be atomic, call function without try/catch pattern
            {
                uint256 protocolFee = _matchAskWithTakerBid(
                    multipleTakerBids.takerBidOrders[i],
                    msg.sender,
                    multipleMakerAsks[i],
                    makerArraySlots[i]
                );
                totalProtocolFee += protocolFee;
            } else {
                try
                    this.matchAskWithTakerBid(
                        multipleTakerBids.takerBidOrders[i],
                        msg.sender,
                        multipleMakerAsks[i],
                        makerArraySlots[i]
                    )
                returns (uint256 protocolFee) {
                    totalProtocolFee += protocolFee;
                } catch {}
            }

            unchecked {
                ++i;
            }
        }

        uint256 totalReferralFee;
        if (multipleTakerBids.referrer != address(0)) {
            totalReferralFee = (totalProtocolFee * _referrers[multipleTakerBids.referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;
        }

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        fees[0] = totalProtocolFee;
        fees[1] = totalReferralFee;
        recipients[0] = _protocolFeeRecipient;
        recipients[1] = multipleTakerBids.referrer;

        if (totalProtocolFee > 0) {
            _transferFungibleTokens(multipleTakerBids.currency, recipients, fees);
        }

        _returnETHIfAny();
    }

    /**
     * @notice Match takerBids with makerAsk
     * @param takerBid taker bid order
     * @param makerAsks maker ask orders
     * @param makerArraySlot array slot
     */
    function matchAskWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        address sender,
        OrderStructs.MultipleMakerAskOrders calldata makerAsks,
        uint256 makerArraySlot
    ) external payable returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) {
            revert();
        }

        return _matchAskWithTakerBid(takerBid, sender, makerAsks, makerArraySlot);
    }

    /**
     * @notice Match takerAsk with makerBid
     * @param takerAsk taker asks order
     * @param makerBids maker ask orders
     * @param makerArraySlot array slot
     */
    function matchBidWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        address sender,
        OrderStructs.MultipleMakerBidOrders calldata makerBids,
        uint256 makerArraySlot
    ) external returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) {
            revert WrongCaller();
        }

        if (
            makerBids.baseMakerOrder.currency == address(0) ||
            !_isCurrencyWhitelisted[makerBids.baseMakerOrder.currency]
        ) {
            revert WrongCurrency();
        }

        {
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, makerBids.hash()));
            _verify(digest, makerBids.baseMakerOrder.signer, makerBids.signature);
        }

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        recipients[0] = takerAsk.recipient == address(0) ? sender : takerAsk.recipient;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerAsk(
            takerAsk,
            makerBids.makerBidOrders[makerArraySlot],
            makerBids.baseMakerOrder
        );

        _transferNFT(
            makerBids.baseMakerOrder.collection,
            makerBids.baseMakerOrder.assetType,
            sender,
            makerBids.baseMakerOrder.recipient == address(0)
                ? makerBids.baseMakerOrder.signer
                : makerBids.baseMakerOrder.recipient,
            itemIds,
            amounts
        );

        _transferFungibleTokens(makerBids.baseMakerOrder.currency, recipients, fees);

        return protocolFeeAmount;
    }

    /**
     * @notice Return an array with initial domain separator, initial chainId, current domain separator, and current chainId address
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
    function addTransferManagerForAssetType(uint16 assetType, address transferManager) external onlyOwner {
        if (_transferManagers[assetType] != address(0)) {
            revert WrongAssetType(assetType);
        }

        _transferManagers[assetType] = transferManager;
    }

    /**
     * @notice Match takerBids with makerAsk
     * @param takerBid taker bid order
     * @param makerAsks maker ask orders
     * @param makerArraySlot array slot
     */
    function _matchAskWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        address sender,
        OrderStructs.MultipleMakerAskOrders calldata makerAsks,
        uint256 makerArraySlot
    ) internal returns (uint256 protocolFeeAmount) {
        if (!_isCurrencyWhitelisted[makerAsks.baseMakerOrder.currency]) {
            revert WrongCurrency();
        }

        // Verify nonce
        if (
            _userBidAskNonces[makerAsks.baseMakerOrder.signer].askNonce != makerAsks.baseMakerOrder.bidAskNonce ||
            _userSubsetNonce[makerAsks.baseMakerOrder.signer][makerAsks.baseMakerOrder.subsetNonce] ||
            _userOrderNonce[makerAsks.baseMakerOrder.signer][makerAsks.makerAskOrders[makerArraySlot].orderNonce]
        ) {
            revert WrongNonces();
        } else {
            // Invalidate order at this nonce for future execution
            _userOrderNonce[makerAsks.baseMakerOrder.signer][
                makerAsks.makerAskOrders[makerArraySlot].orderNonce
            ] = true;
        }

        {
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, makerAsks.hash()));
            _verify(digest, makerAsks.baseMakerOrder.signer, makerAsks.signature);

            delete digest;
        }

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerBid(
            takerBid,
            makerAsks.makerAskOrders[makerArraySlot],
            makerAsks.baseMakerOrder
        );

        _transferNFT(
            makerAsks.baseMakerOrder.collection,
            makerAsks.baseMakerOrder.assetType,
            takerBid.recipient == address(0) ? sender : takerBid.recipient,
            makerAsks.baseMakerOrder.signer,
            itemIds,
            amounts
        );

        recipients[0] = makerAsks.baseMakerOrder.recipient == address(0)
            ? makerAsks.baseMakerOrder.signer
            : makerAsks.baseMakerOrder.recipient;

        _transferFungibleTokens(makerAsks.baseMakerOrder.currency, recipients, fees);

        emit TakerBid(
            makerAsks.makerAskOrders[makerArraySlot].orderNonce,
            sender,
            takerBid.recipient,
            makerAsks.baseMakerOrder.signer,
            makerAsks.baseMakerOrder.strategyId,
            makerAsks.baseMakerOrder.currency,
            makerAsks.baseMakerOrder.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );

        return protocolFeeAmount;
    }

    /**
     * @notice Transfer funds and tokens
     * @param collection address of the collection
     * @param assetType asset type
     * @param recipient address of the recipient
     * @param transferrer address of the transferrer
     * @param itemIds array of itemIds
     * @param amounts array of amounts
     */
    function _transferNFT(
        address collection,
        uint8 assetType,
        address recipient,
        address transferrer,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal {
        address transferManager = _transferManagers[assetType];
        if (transferManager == address(0)) {
            revert NoTransferManagerForAssetType(assetType);
        }

        // 0 is not an option
        if (itemIds.length == 1) {
            ITransferManager(transferManager).transferSingleItem(
                collection,
                assetType,
                transferrer,
                recipient,
                itemIds[0],
                amounts[0]
            );
        } else {
            ITransferManager(transferManager).transferBatchItems(
                collection,
                assetType,
                transferrer,
                recipient,
                itemIds,
                amounts
            );
        }
    }

    /**
     * @notice Transfer fungible tokens
     * @param currency address of the currency
     * @param feeRecipients array of the fee recipient addresses
     * @param amounts array of amounts
     */
    function _transferFungibleTokens(
        address currency,
        address[] memory feeRecipients,
        uint256[] memory amounts
    ) internal {
        if (currency == address(0)) {
            for (uint256 i; i < amounts.length; ) {
                if (amounts[i] > 0 && feeRecipients[i] != address(0)) {
                    _transferETH(feeRecipients[i], (amounts[i]));
                }
                unchecked {
                    ++i;
                }
            }
        } else {
            for (uint256 i; i < amounts.length; ) {
                if (amounts[i] > 0 && feeRecipients[i] != address(0)) {
                    _executeERC20Transfer(currency, msg.sender, feeRecipients[i], amounts[i]);
                }
                unchecked {
                    ++i;
                }
            }
        }
    }
}
