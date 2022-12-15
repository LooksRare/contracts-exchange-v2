// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";
import {IERC1271} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1271.sol";

// Libraries
import {OrderStructs} from "../libraries/OrderStructs.sol";

// Interfaces
import {ICreatorFeeManager} from "../interfaces/ICreatorFeeManager.sol";
import {IExecutionManager} from "../interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../interfaces/IStrategyManager.sol";

// Other dependencies
import {LooksRareProtocol} from "../LooksRareProtocol.sol";
import "./ValidationCodeConstants.sol";

/**
 * @title OrderValidator
 * @notice This contract is used to check the validity of a maker ask/bid order in the LooksRareProtocol (v2).
 *         It performs checks for:
 *         1. Nonce-related issues (e.g., nonce executed or cancelled)
 *         2. Signature-related issues and merkle tree parameters
 *         3. Internal whitelist-related issues (i.e., currency or strategy not whitelisted)
 *         4. Creator-fee related
 *         5. Timestamp-related issues (e.g., order expired)
 *         6. Transfer-related issues for ERC20/ERC721/ERC1155 (approvals and balances)
 *         7. Other potential restrictions where it can tap into specific contracts with specific validation codes
 * @author LooksRare protocol team (👀,💎)
 */
contract OrderValidator {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleTree;

    // Number of distinct criteria groups checked to evaluate the validity of an order
    uint256 public immutable CRITERIA_GROUPS = 7;

    // LooksRareProtocol domain separator
    bytes32 public domainSeparator;

    // LooksRareProtocol
    LooksRareProtocol public looksRareProtocol;

    // CreatorFeeManager
    ICreatorFeeManager public creatorFeeManager;

    /**
     * @notice Constructor
     * @param _looksRareProtocol LooksRare protocol address
     * @dev It derives automatically other external variables such as the creator fee manager and domain separator.
     */
    constructor(address _looksRareProtocol) {
        looksRareProtocol = LooksRareProtocol(_looksRareProtocol);
        domainSeparator = LooksRareProtocol(_looksRareProtocol).domainSeparator();
        creatorFeeManager = LooksRareProtocol(_looksRareProtocol).creatorFeeManager();
    }

    /**
     * @notice Adjust external parameters. Anyone can call this function.
     * @dev It is meant to be adjustable if domain separator or creator fee manager were to change
     */
    function adjustExternalParameters() external {
        domainSeparator = looksRareProtocol.domainSeparator();
        creatorFeeManager = looksRareProtocol.creatorFeeManager();
    }

    /**
     * @notice Verify the validity of an array of maker ask orders.
     * @param makerAsks Array of maker ask structs
     */
    function verifyMultipleMakerAskOrders(
        OrderStructs.MakerAsk[] calldata makerAsks
    ) external view returns (uint256[][] memory validationCodes) {
        validationCodes = new uint256[][](makerAsks.length);

        for (uint256 i; i < makerAsks.length; ) {
            validationCodes[i] = checkMakerAskOrderValidity(makerAsks[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Verify the validity of an array of maker bid orders.
     * @param makerBids Array of maker bid structs
     */
    function verifyMultipleMakerBidOrders(
        OrderStructs.MakerBid[] calldata makerBids
    ) external view returns (uint256[][] memory validationCodes) {
        validationCodes = new uint256[][](makerBids.length);

        for (uint256 i; i < makerBids.length; ) {
            validationCodes[i] = checkMakerBidOrderValidity(makerBids[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Verify the validity of a maker ask order.
     * @param makerAsk Maker ask struct
     */
    function checkMakerAskOrderValidity(
        OrderStructs.MakerAsk calldata makerAsk
    ) public view returns (uint256[] memory validationCodes) {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        validationCodes[0] = checkMakerAskValidityNonces(makerAsk);
    }

    /**
     * @notice Verify the validity of a maker bid order.
     * @param makerBid Maker bid struct
     */
    function checkMakerBidOrderValidity(
        OrderStructs.MakerBid calldata makerBid
    ) public view returns (uint256[] memory validationCodes) {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        validationCodes[0] = checkMakerBidValidityNonces(makerBid);
    }

    /**
     * @notice Check the validity for nonces for maker ask
     * @param makerAsk Maker ask struct
     * @return validationCode Validation code
     */
    function checkMakerAskValidityNonces(
        OrderStructs.MakerAsk calldata makerAsk
    ) public view returns (uint256 validationCode) {
        // 1. Check global ask nonce
        (, uint128 globalAskNonce) = looksRareProtocol.userBidAskNonces(makerAsk.signer);
        if (makerAsk.askNonce < globalAskNonce) return USER_GLOBAL_ASK_NONCE_HIGHER;
        if (makerAsk.askNonce > globalAskNonce) return USER_GLOBAL_ASK_NONCE_LOWER;

        // 2. Check subset nonce
        if (looksRareProtocol.userSubsetNonce(makerAsk.signer, makerAsk.subsetNonce))
            return USER_SUBSET_NONCE_CANCELLED;

        // 3. Check order nonce
        // TODO: post refactor
    }

    /**
     * @notice Check the validity for nonces for maker bid
     * @param makerBid Maker bid struct
     * @return validationCode Validation code
     */
    function checkMakerBidValidityNonces(
        OrderStructs.MakerBid calldata makerBid
    ) public view returns (uint256 validationCode) {
        // 1. Check global ask nonce
        (uint128 globalBidNonce, ) = looksRareProtocol.userBidAskNonces(makerBid.signer);
        if (makerBid.bidNonce < globalBidNonce) return USER_GLOBAL_ASK_NONCE_HIGHER;
        if (makerBid.bidNonce > globalBidNonce) return USER_GLOBAL_ASK_NONCE_LOWER;

        // 2. Check subset nonce
        if (looksRareProtocol.userSubsetNonce(makerBid.signer, makerBid.subsetNonce))
            return USER_SUBSET_NONCE_CANCELLED;

        // 3. Check order nonce
        // TODO: post refactor
    }

    /**
     * @notice Check the validity for currency/strategy whitelists
     * @param makerAsk Maker ask order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerAskWhitelists(
        OrderStructs.MakerAsk calldata makerAsk
    ) public view returns (uint256 validationCode) {
        // Verify whether the currency is whitelisted
        if (!looksRareProtocol.isCurrencyWhitelisted(makerAsk.currency)) return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is valid
        (
            bool strategyIsActive,
            ,
            ,
            ,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(makerAsk.strategyId);

        if (makerAsk.strategyId != 0 && strategyImplementation == address(0)) return STRATEGY_NOT_IMPLEMENTED;
        // @dev Native collection offers (strategyId = 1) only exist for maker bid orders
        if (makerAsk.strategyId != 0 && (strategySelector == bytes4(0) || strategyIsMakerBid))
            return STRATEGY_TAKER_BID_SELECTOR_INVALID;
        if (!strategyIsActive) return STRATEGY_NOT_ACTIVE;
    }

    /**
     * @notice Check the validity for currency/strategy whitelists
     * @param makerBid Maker bid order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerBidWhitelists(
        OrderStructs.MakerBid calldata makerBid
    ) public view returns (uint256 validationCode) {
        // Verify whether the currency is whitelisted
        if (!looksRareProtocol.isCurrencyWhitelisted(makerBid.currency)) return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is valid
        (
            bool strategyIsActive,
            ,
            ,
            ,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(makerBid.strategyId);

        if (makerBid.strategyId != 0 && strategyImplementation == address(0)) return STRATEGY_NOT_IMPLEMENTED;
        if (makerBid.strategyId != 0 && (strategySelector == bytes4(0) || !strategyIsMakerBid))
            return STRATEGY_TAKER_ASK_SELECTOR_INVALID;
        if (!strategyIsActive) return STRATEGY_NOT_ACTIVE;
    }

    /**
     * @notice Check the validity for order timestamps
     * @param makerAsk Maker ask order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerAskTimestamps(
        OrderStructs.MakerAsk calldata makerAsk
    ) public view returns (uint256 validationCode) {
        if (makerAsk.endTime < block.timestamp) return TOO_LATE_TO_EXECUTE_ORDER;
        if (makerAsk.startTime + 5 minutes > block.timestamp) return TOO_EARLY_TO_EXECUTE_ORDER;
    }

    /**
     * @notice Check the validity for order timestamps
     * @param makerBid Maker bid order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerBidTimestamps(
        OrderStructs.MakerBid calldata makerBid
    ) public view returns (uint256 validationCode) {
        if (makerBid.endTime < block.timestamp) return TOO_LATE_TO_EXECUTE_ORDER;
        if (makerBid.startTime + 5 minutes > block.timestamp) return TOO_EARLY_TO_EXECUTE_ORDER;
    }

    /**
     * @notice Check the validity of ERC20 approvals and balances that are required to process the maker bid order
     * @param currency Currency address
     * @param user User address
     * @param price Price (defined by the maker order)
     */
    function _validateERC20(
        address currency,
        address user,
        uint256 price
    ) internal view returns (uint256 validationCode) {
        if (IERC20(currency).balanceOf(user) < price) return ERC20_BALANCE_INFERIOR_TO_PRICE;
        if (IERC20(currency).allowance(user, address(looksRareProtocol)) < price)
            return ERC20_APPROVAL_INFERIOR_TO_PRICE;
    }

    /**
     * @notice Check the validity of ERC721 approvals and balances required to process the maker ask order
     * @param collection Collection address
     * @param assetType Asset type (e.g., 0 = ERC721)
     * @param user User address
     * @param itemIds Array of item ids
     */
    function _validateERC721AndEquivalents(
        address collection,
        uint256 assetType,
        address user,
        uint256[] memory itemIds
    ) internal view returns (uint256 validationCode) {
        // 1. Verify transfer manager exists for assetType
        (address transferManager, ) = looksRareProtocol.managerSelectorOfAssetType(assetType);
        if (transferManager == address(0)) return NO_TRANSFER_MANAGER_SELECTOR;

        // 2. Verify itemId is owned by user and catch revertion if ERC721 ownerOf fails
        uint256 length = itemIds.length;

        bool success;
        bytes memory data;

        for (uint256 i; i < length; ) {
            (success, data) = collection.staticcall(abi.encodeWithSelector(IERC721.ownerOf.selector, itemIds[i]));

            if (!success) return ERC721_ITEM_ID_DOES_NOT_EXIST;
            if (abi.decode(data, (address)) != user) return ERC721_ITEM_ID_NOT_IN_BALANCE;

            unchecked {
                ++i;
            }
        }

        // 3. Verify if collection is approved by transfer manager
        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC721.isApprovedForAll.selector, user, transferManager)
        );

        bool isApprovedAll;
        if (success) {
            isApprovedAll = abi.decode(data, (bool));
        }

        if (!isApprovedAll) {
            for (uint256 i; i < length; ) {
                // 4. If collection is not approved by transfer manager, try to see if it is approved individually
                (success, data) = collection.staticcall(
                    abi.encodeWithSelector(IERC721.getApproved.selector, itemIds[i])
                );

                address approvedAddress;
                if (success) {
                    approvedAddress = abi.decode(data, (address));
                }

                if (approvedAddress != transferManager) return ERC721_NO_APPROVAL_FOR_ALL_OR_ITEM_ID;

                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Check the validity of ERC1155 approvals and balances required to process the maker ask order
     * @param collection Collection address
     * @param assetType Asset type (e.g., 0 = ERC721)
     * @param user User address
     * @param itemIds Array of item ids
     * @param amounts Array of amounts
     */
    function _validateERC1155(
        address collection,
        uint256 assetType,
        address user,
        uint256[] memory itemIds,
        uint256[] memory amounts
    ) internal view returns (uint256 validationCode) {
        // 1. Verify transfer manager exists for assetType
        (address transferManager, ) = looksRareProtocol.managerSelectorOfAssetType(assetType);
        if (transferManager == address(0)) return NO_TRANSFER_MANAGER_SELECTOR;

        // 2. Verify each itemId is owned by user and catch revertion if ERC1155 ownerOf fails
        address[] memory users = new address[](1);
        users[0] = user;

        uint256 length = itemIds.length;

        // 2.1 Use balanceOfBatch
        (bool success, bytes memory data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.balanceOfBatch.selector, users, itemIds)
        );

        if (success) {
            uint256[] memory balances = abi.decode(data, (uint256[]));
            for (uint256 i; i < length; ) {
                if (balances[i] < amounts[i]) return ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT;
            }
        } else {
            // 2.2 If the balanceOfBatch doesn't work, use loop with balanceOf function
            for (uint256 i; i < length; ) {
                (success, data) = collection.staticcall(
                    abi.encodeWithSelector(IERC1155.balanceOf.selector, user, itemIds[i])
                );
                if (!success) return ERC1155_BALANCE_OF_DOES_NOT_EXIST;
                if (abi.decode(data, (uint256)) < amounts[i]) return ERC1155_BALANCE_OF_ITEM_ID_INFERIOR_TO_AMOUNT;
            }
        }

        // 3. Verify if collection is approved by transfer manager
        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.isApprovedForAll.selector, user, transferManager)
        );

        if (!success) return ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST;
        if (!abi.decode(data, (bool))) return ERC1155_NO_APPROVAL_FOR_ALL;
    }

    /**
     * @notice Check if any of the item id in an array of item ids is repeated
     * @param itemIds Array of item ids
     * @dev This is to be used for bundles
     */
    function _verifyAllItemIdsDiffer(uint256[] memory itemIds) internal pure returns (uint256 validationCode) {
        uint256 length = itemIds.length;

        // Only check if length of array is greater than 1
        if (length > 1) {
            for (uint256 i = 0; i < length; ) {
                for (uint256 j = i; j < length; ) {
                    if (itemIds[i] == itemIds[j]) {
                        return SAME_ITEM_ID_IN_BUNDLE;
                    }
                    unchecked {
                        ++j;
                    }
                }
                unchecked {
                    ++i;
                }
            }
        }
    }

    /**
     * @notice Validate signature
     * @param hash Message hash
     * @param signer Signer address
     * @param signature A 64 or 65 bytes signature
     * @return validationCode Validation code
     */
    function _validateSignature(
        bytes32 hash,
        address signer,
        bytes calldata signature
    ) internal view returns (uint256 validationCode) {
        // 1. Logic if EOA
        if (signer.code.length == 0) {
            bytes32 r;
            bytes32 s;
            uint8 v;

            if (signature.length == 64) {
                bytes32 vs;
                assembly {
                    r := calldataload(signature.offset)
                    vs := calldataload(add(signature.offset, 0x20))
                    s := and(vs, 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)
                    v := add(shr(255, vs), 27)
                }
            } else if (signature.length == 65) {
                assembly {
                    r := calldataload(signature.offset)
                    s := calldataload(add(signature.offset, 0x20))
                    v := byte(0, calldataload(add(signature.offset, 0x40)))
                }
            } else {
                return WRONG_SIGNATURE_LENGTH;
            }

            if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0)
                return INVALID_S_PARAMETER_EOA;

            if (v != 27 && v != 28) return INVALID_V_PARAMETER_EOA;

            address recoveredSigner = ecrecover(hash, v, r, s);
            if (signer == address(0)) return NULL_SIGNER_EOA;

            if (signer != recoveredSigner) return WRONG_SIGNER_EOA;
        } else {
            // 2. Logic if ERC1271
            if (IERC1271(signer).isValidSignature(hash, signature) == 0x1626ba7e) return SIGNATURE_INVALID_EIP1271;
        }
    }
}
