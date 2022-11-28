// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {SignatureChecker} from "@looksrare/contracts-libs/contracts/SignatureChecker.sol";
import {IERC20} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC20.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC721} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC721.sol";
import {IERC1155} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC1155.sol";

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
 *         2. Amount-related issues (e.g. order amount being 0)
 *         3. Signature-related issues
 *         4. Internal whitelist-related issues (i.e., currency or strategy not whitelisted)
 *         5. Creator fee related
 *         6. Timestamp-related issues (e.g., order expired)
 *         7. Transfer-related issues for ERC20/ERC721/ERC1155 (approvals and balances)
 *         8. Other potential restrictions where it can tap into specific contracts with specific validation codes
 * @author LooksRare protocol team (👀,💎)
 */
contract OrderValidatorV2A is SignatureChecker {
    using OrderStructs for OrderStructs.MakerAsk;
    using OrderStructs for OrderStructs.MakerBid;
    using OrderStructs for OrderStructs.MerkleRoot;

    // Number of distinct criteria groups checked to evaluate the validity of an order
    uint256 public immutable CRITERIA_GROUPS = 8;

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
     */
    function adjustExternalParameters() external {
        domainSeparator = looksRareProtocol.domainSeparator();
        creatorFeeManager = looksRareProtocol.creatorFeeManager();
    }

    /**
     * @notice Verify the validity of an array of maker ask orders.
     * @param makerAsks Array of maker ask structs
     */
    function verifyMultipleMakerAskOrders(OrderStructs.MakerAsk[] calldata makerAsks)
        external
        view
        returns (uint256[][] memory validationCodes)
    {
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
    function verifyMultipleMakerBidOrders(OrderStructs.MakerBid[] calldata makerBids)
        external
        view
        returns (uint256[][] memory validationCodes)
    {
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
    function checkMakerAskOrderValidity(OrderStructs.MakerAsk calldata makerAsk)
        public
        view
        returns (uint256[] memory validationCodes)
    {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        validationCodes[0] = checkMakerAskValidityNonces(makerAsk);
    }

    /**
     * @notice Verify the validity of a maker bid order.
     * @param makerBid Maker bid struct
     */
    function checkMakerBidOrderValidity(OrderStructs.MakerBid calldata makerBid)
        public
        view
        returns (uint256[] memory validationCodes)
    {
        validationCodes = new uint256[](CRITERIA_GROUPS);
        validationCodes[0] = checkMakerBidValidityNonces(makerBid);
    }

    /**
     * @notice Check the validity for nonces for maker ask
     * @param makerAsk Maker ask struct
     * @return validationCode Validation code
     */
    function checkMakerAskValidityNonces(OrderStructs.MakerAsk calldata makerAsk)
        public
        view
        returns (uint256 validationCode)
    {
        //
    }

    /**
     * @notice Check the validity for nonces for maker bid
     * @param makerBid Maker bid struct
     * @return validationCode Validation code
     */
    function checkMakerBidValidityNonces(OrderStructs.MakerBid calldata makerBid)
        public
        view
        returns (uint256 validationCode)
    {
        //
    }

    /**
     * @notice Check the validity for currency/strategy whitelists
     * @param makerAsk Maker ask order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerAskWhitelists(OrderStructs.MakerAsk calldata makerAsk)
        public
        view
        returns (uint256 validationCode)
    {
        // Verify whether the currency is whitelisted
        if (!looksRareProtocol.isCurrencyWhitelisted(makerAsk.currency)) return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is whitelisted
        // TODO
    }

    /**
     * @notice Check the validity for currency/strategy whitelists
     * @param makerBid Maker bid order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerBidWhitelists(OrderStructs.MakerBid calldata makerBid)
        public
        view
        returns (uint256 validationCode)
    {
        // Verify whether the currency is whitelisted
        if (!looksRareProtocol.isCurrencyWhitelisted(makerBid.currency)) return CURRENCY_NOT_WHITELISTED;

        // Verify whether the strategy is whitelisted
        // TODO
    }

    /**
     * @notice Check the validity of order timestamps
     * @param makerAsk Maker ask order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerAskTimestamps(OrderStructs.MakerAsk calldata makerAsk)
        public
        view
        returns (uint256 validationCode)
    {
        if (makerAsk.endTime < block.timestamp) return TOO_LATE_TO_EXECUTE_ORDER;
        if (makerAsk.startTime + 5 minutes > block.timestamp) return TOO_EARLY_TO_EXECUTE_ORDER;
    }

    /**
     * @notice Check the validity of order timestamps
     * @param makerBid Maker bid order struct
     * @return validationCode Validation code
     */
    function checkValidityMakerBidTimestamps(OrderStructs.MakerBid calldata makerBid)
        public
        view
        returns (uint256 validationCode)
    {
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
     * @param user User address
     * @param transferManager Transfer manager address
     * @param tokenId TokenId
     */
    function _validateERC721AndEquivalents(
        address collection,
        address user,
        address transferManager,
        uint256 tokenId
    ) internal view returns (uint256 validationCode) {
        // 1. Verify tokenId is owned by user and catch revertion if ERC721 ownerOf fails
        (bool success, bytes memory data) = collection.staticcall(
            abi.encodeWithSelector(IERC721.ownerOf.selector, tokenId)
        );

        if (!success) return ERC721_TOKEN_ID_DOES_NOT_EXIST;
        if (abi.decode(data, (address)) != user) return ERC721_TOKEN_ID_NOT_IN_BALANCE;

        // 2. Verify if collection is approved by transfer manager
        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC721.isApprovedForAll.selector, user, transferManager)
        );

        bool isApprovedAll;
        if (success) {
            isApprovedAll = abi.decode(data, (bool));
        }

        if (!isApprovedAll) {
            // 3. If collection is not approved by transfer manager, try to see if it is approved individually
            (success, data) = collection.staticcall(abi.encodeWithSelector(IERC721.getApproved.selector, tokenId));

            address approvedAddress;
            if (success) {
                approvedAddress = abi.decode(data, (address));
            }

            if (approvedAddress != transferManager) return ERC721_NO_APPROVAL_FOR_ALL_OR_TOKEN_ID;
        }
    }

    /**
     * @notice Check the validity of ERC1155 approvals and balances required to process the maker ask order
     * @param collection Collection address
     * @param user User address
     * @param transferManager Transfer manager address
     * @param tokenId TokenId
     * @param amount Amount
     */
    function _validateERC1155(
        address collection,
        address user,
        address transferManager,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (uint256 validationCode) {
        (bool success, bytes memory data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.balanceOf.selector, user, tokenId)
        );

        if (!success) return ERC1155_BALANCE_OF_DOES_NOT_EXIST;
        if (abi.decode(data, (uint256)) < amount) return ERC1155_BALANCE_OF_TOKEN_ID_INFERIOR_TO_AMOUNT;

        (success, data) = collection.staticcall(
            abi.encodeWithSelector(IERC1155.isApprovedForAll.selector, user, transferManager)
        );

        if (!success) return ERC1155_IS_APPROVED_FOR_ALL_DOES_NOT_EXIST;
        if (!abi.decode(data, (bool))) return ERC1155_NO_APPROVAL_FOR_ALL;
    }
}
