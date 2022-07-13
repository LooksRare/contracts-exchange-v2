// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// LooksRare generalist libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {ReentrancyGuard} from "@looksrare/contracts-libs/contracts/ReentrancyGuard.sol";

// Order structs
import {OrderStructs} from "./libraries/OrderStructs.sol";

// Interfaces
import {ILooksRareProtocol} from "./interfaces/ILooksRareProtocol.sol";
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

    function matchAskWithTakerBid(
        OrderStructs.SingleTakerBidOrder calldata takerBidOrder,
        OrderStructs.MultipleMakerAskOrders calldata multipleMakerAsk,
        uint256 makerArraySlot
    ) external payable nonReentrant {
        {
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, multipleMakerAsk.hash()));
            _verify(digest, multipleMakerAsk.baseMakerOrder.signer, multipleMakerAsk.signature);
        }

        uint256 totalProtocolFee = _matchAskWithTakerBid(
            takerBidOrder.takerBidOrder,
            msg.sender,
            multipleMakerAsk.makerAskOrders[makerArraySlot],
            multipleMakerAsk.baseMakerOrder
        );

        if (takerBidOrder.referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[takerBidOrder.referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;
            _transferFungibleToken(
                multipleMakerAsk.baseMakerOrder.currency,
                msg.sender,
                takerBidOrder.referrer,
                totalReferralFee
            );
        }
        _transferFungibleToken(
            multipleMakerAsk.baseMakerOrder.currency,
            msg.sender,
            _protocolFeeRecipient,
            totalProtocolFee
        );

        _returnETHIfAny();
    }

    function matchBidWithTakerAsk(
        OrderStructs.SingleTakerAskOrder calldata takerAskOrder,
        OrderStructs.MultipleMakerBidOrders calldata multipleMakerBid,
        uint256 makerArraySlot
    ) external payable nonReentrant {
        {
            bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, multipleMakerBid.hash()));
            _verify(digest, multipleMakerBid.baseMakerOrder.signer, multipleMakerBid.signature);
        }

        uint256 totalProtocolFee = _matchBidWithTakerAsk(
            takerAskOrder.takerAskOrder,
            msg.sender,
            multipleMakerBid.makerBidOrders[makerArraySlot],
            multipleMakerBid.baseMakerOrder
        );

        if (takerAskOrder.referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[takerAskOrder.referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;
            _transferFungibleToken(
                multipleMakerBid.baseMakerOrder.currency,
                msg.sender,
                takerAskOrder.referrer,
                totalReferralFee
            );
        }
        _transferFungibleToken(
            multipleMakerBid.baseMakerOrder.currency,
            msg.sender,
            _protocolFeeRecipient,
            totalProtocolFee
        );
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
            {
                bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, multipleMakerAsks[i].hash()));
                _verify(digest, multipleMakerAsks[i].baseMakerOrder.signer, multipleMakerAsks[i].signature);
            }

            // Verify currency is the same as taker bid
            if (multipleTakerBids.currency != multipleMakerAsks[i].baseMakerOrder.currency) {
                revert WrongCurrency();
            }

            if (isExecutionAtomic) // If execution is desired to be atomic, call function without try/catch pattern
            {
                uint256 protocolFee = _matchAskWithTakerBid(
                    multipleTakerBids.takerBidOrders[i],
                    msg.sender,
                    multipleMakerAsks[i].makerAskOrders[makerArraySlots[i]],
                    multipleMakerAsks[i].baseMakerOrder
                );
                totalProtocolFee += protocolFee;
            } else {
                try
                    this.matchAskWithTakerBid(
                        multipleTakerBids.takerBidOrders[i],
                        msg.sender,
                        multipleMakerAsks[i].makerAskOrders[makerArraySlots[i]],
                        multipleMakerAsks[i].baseMakerOrder
                    )
                returns (uint256 protocolFee) {
                    totalProtocolFee += protocolFee;
                } catch {}
            }

            unchecked {
                ++i;
            }
        }

        if (multipleTakerBids.referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[multipleTakerBids.referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;
            _transferFungibleToken(
                multipleTakerBids.currency,
                msg.sender,
                multipleTakerBids.referrer,
                totalReferralFee
            );
        }
        _transferFungibleToken(multipleTakerBids.currency, msg.sender, _protocolFeeRecipient, totalProtocolFee);

        _returnETHIfAny();
    }

    /**
     * @notice Match multiple maker asks with taker bids
     * @param multipleTakerAsks multiple taker ask orders
     * @param multipleMakerBids multiple maker bid orders
     * @param makerArraySlots array of maker array slot
     * @param isExecutionAtomic whether the execution should revert if one of the transaction fails. If it is true, the execution must be atomic. Any revertion will make the transaction fail.
     */
    function matchMultipleAsksWithTakerBids(
        OrderStructs.MultipleTakerAskOrders calldata multipleTakerAsks,
        OrderStructs.MultipleMakerBidOrders[] calldata multipleMakerBids,
        uint256[] calldata makerArraySlots,
        bool isExecutionAtomic
    ) external payable nonReentrant {
        uint256 length = multipleTakerAsks.takerAskOrders.length;

        if (length == 0 || multipleMakerBids.length != length || makerArraySlots.length != length) {
            revert WrongLengths();
        }

        uint256 totalProtocolFee;

        // Fire the trades
        for (uint256 i; i < multipleMakerBids.length; ) {
            {
                bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator, multipleMakerBids[i].hash()));
                _verify(digest, multipleMakerBids[i].baseMakerOrder.signer, multipleMakerBids[i].signature);
            }

            // Verify currency is the same as taker bid
            if (multipleTakerAsks.currency != multipleMakerBids[i].baseMakerOrder.currency) {
                revert WrongCurrency();
            }

            if (isExecutionAtomic) // If execution is desired to be atomic, call function without try/catch pattern
            {
                uint256 protocolFee = _matchBidWithTakerAsk(
                    multipleTakerAsks.takerAskOrders[i],
                    msg.sender,
                    multipleMakerBids[i].makerBidOrders[makerArraySlots[i]],
                    multipleMakerBids[i].baseMakerOrder
                );
                totalProtocolFee += protocolFee;
            } else {
                try
                    this.matchBidWithTakerAsk(
                        multipleTakerAsks.takerAskOrders[i],
                        msg.sender,
                        multipleMakerBids[i].makerBidOrders[makerArraySlots[i]],
                        multipleMakerBids[i].baseMakerOrder
                    )
                returns (uint256 protocolFee) {
                    totalProtocolFee += protocolFee;
                } catch {}
            }

            unchecked {
                ++i;
            }
        }

        if (multipleTakerAsks.referrer != address(0)) {
            uint256 totalReferralFee = (totalProtocolFee * _referrers[multipleTakerAsks.referrer]) / 10000;
            totalProtocolFee -= totalReferralFee;
            _transferFungibleToken(
                multipleTakerAsks.currency,
                msg.sender,
                multipleTakerAsks.referrer,
                totalReferralFee
            );
        }
        _transferFungibleToken(multipleTakerAsks.currency, msg.sender, _protocolFeeRecipient, totalProtocolFee);
    }

    /**
     * @notice Match makerAsk with takerBid
     * This function is solely used by this contract when atomicity is not required for batch-selling
     */
    function matchAskWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        address sender,
        OrderStructs.SingleMakerAskOrder calldata makerAsk,
        OrderStructs.BaseMakerOrder calldata baseMakerOrder
    ) external payable returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) {
            revert();
        }

        protocolFeeAmount = _matchAskWithTakerBid(takerBid, sender, makerAsk, baseMakerOrder);
    }

    /**
     * @notice Match makerBid with takerAsk
     * This function is solely used by this contract when atomicity is not required for batch-buying
     */
    function matchBidWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        address sender,
        OrderStructs.SingleMakerBidOrder calldata makerBid,
        OrderStructs.BaseMakerOrder calldata baseMakerOrder
    ) external returns (uint256 protocolFeeAmount) {
        if (msg.sender != address(this)) {
            revert WrongCaller();
        }

        protocolFeeAmount = _matchBidWithTakerAsk(takerAsk, sender, makerBid, baseMakerOrder);
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
     */
    function _matchAskWithTakerBid(
        OrderStructs.TakerBidOrder calldata takerBid,
        address sender,
        OrderStructs.SingleMakerAskOrder calldata makerAsk,
        OrderStructs.BaseMakerOrder calldata baseMakerOrder
    ) internal returns (uint256 protocolFeeAmount) {
        if (!_isCurrencyWhitelisted[baseMakerOrder.currency]) {
            revert WrongCurrency();
        }

        // Verify nonce
        if (
            _userBidAskNonces[baseMakerOrder.signer].askNonce != baseMakerOrder.bidAskNonce ||
            _userSubsetNonce[baseMakerOrder.signer][baseMakerOrder.subsetNonce] ||
            _userOrderNonce[baseMakerOrder.signer][makerAsk.orderNonce]
        ) {
            revert WrongNonces();
        } else {
            // Invalidate order at this nonce for future execution
            _userOrderNonce[baseMakerOrder.signer][makerAsk.orderNonce] = true;
        }

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerBid(
            takerBid,
            makerAsk,
            baseMakerOrder
        );

        _transferNFT(
            baseMakerOrder.collection,
            baseMakerOrder.assetType,
            takerBid.recipient == address(0) ? sender : takerBid.recipient,
            baseMakerOrder.signer,
            itemIds,
            amounts
        );

        recipients[0] = baseMakerOrder.recipient == address(0) ? baseMakerOrder.signer : baseMakerOrder.recipient;

        for (uint256 i; i < recipients.length; ) {
            if (recipients[i] != address(0) && fees[i] != 0) {
                _transferFungibleToken(baseMakerOrder.currency, sender, recipients[i], fees[i]);
            }
            unchecked {
                ++i;
            }
        }

        emit TakerBid(
            makerAsk.orderNonce,
            sender,
            takerBid.recipient,
            baseMakerOrder.signer,
            baseMakerOrder.strategyId,
            baseMakerOrder.currency,
            baseMakerOrder.collection,
            itemIds,
            amounts,
            recipients,
            fees
        );

        return protocolFeeAmount;
    }

    function _matchBidWithTakerAsk(
        OrderStructs.TakerAskOrder calldata takerAsk,
        address sender,
        OrderStructs.SingleMakerBidOrder calldata makerBid,
        OrderStructs.BaseMakerOrder calldata baseMakerOrder
    ) internal returns (uint256 protocolFeeAmount) {
        if (!_isCurrencyWhitelisted[baseMakerOrder.currency]) {
            revert WrongCurrency();
        }

        // Verify nonce
        if (
            _userBidAskNonces[baseMakerOrder.signer].askNonce != baseMakerOrder.bidAskNonce ||
            _userSubsetNonce[baseMakerOrder.signer][baseMakerOrder.subsetNonce] ||
            _userOrderNonce[baseMakerOrder.signer][makerBid.orderNonce]
        ) {
            revert WrongNonces();
        } else {
            // Invalidate order at this nonce for future execution
            _userOrderNonce[baseMakerOrder.signer][makerBid.orderNonce] = true;
        }

        uint256[] memory fees = new uint256[](2);
        address[] memory recipients = new address[](2);
        uint256[] memory itemIds;
        uint256[] memory amounts;

        (itemIds, amounts, fees[0], protocolFeeAmount, recipients[1], fees[1]) = _executeStrategyForTakerAsk(
            takerAsk,
            makerBid,
            baseMakerOrder
        );

        for (uint256 i; i < recipients.length; ) {
            if (recipients[i] != address(0) && fees[i] != 0) {
                _transferFungibleToken(baseMakerOrder.currency, sender, recipients[i], fees[i]);
            }
            unchecked {
                ++i;
            }
        }

        baseMakerOrder.recipient == address(0) ? sender : baseMakerOrder.recipient;

        _transferNFT(
            baseMakerOrder.collection,
            baseMakerOrder.assetType,
            sender,
            baseMakerOrder.recipient,
            itemIds,
            amounts
        );

        emit TakerAsk(
            makerBid.orderNonce,
            baseMakerOrder.signer,
            baseMakerOrder.recipient,
            sender,
            takerAsk.recipient,
            baseMakerOrder.strategyId,
            baseMakerOrder.currency,
            baseMakerOrder.collection,
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
     * @param sender address of sender
     * @param recipient address recipient
     * @param amount array of amount
     */
    function _transferFungibleToken(
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
}
