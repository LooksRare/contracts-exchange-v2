// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";
import {IERC2981} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC2981.sol";

// Interfaces
import {IFeeManager} from "./interfaces/IFeeManager.sol";

/**
 * @title FeeManager
 * @notice This contract handles the fee logic for determining the protocol fee (including potential rebate).
 *         It allows the owner to update the protocol fee recipient and the source to fetch the rebate information.
 * @author LooksRare protocol team (👀,💎)
 */
contract FeeManager is IFeeManager, OwnableTwoSteps {
    // Protocol fee recipient
    address public protocolFeeRecipient;

    /**
     * @notice Set protocol fee recipient
     * @param newProtocolFeeRecipient New protocol fee recipient address
     */
    function setProtocolFeeRecipient(address newProtocolFeeRecipient) external onlyOwner {
        protocolFeeRecipient = newProtocolFeeRecipient;
        emit NewProtocolFeeRecipient(newProtocolFeeRecipient);
    }

    /**
     * @notice Get rebate recipient and amount for a collection, set of itemIds, and gross sale amount.
     * @param collection Collection address
     * @param itemIds Array of itemIds
     * @param amount Price amount of the sale
     * @return rebateRecipient Rebate recipient address
     * @return rebateAmount Amount to pay in rebates to the recipient
     * @dev //
     */
    function _getRebateRecipientAndAmount(
        address collection,
        uint256[] memory itemIds,
        uint256 amount
    ) internal view returns (address rebateRecipient, uint256 rebateAmount) {
        //
    }
}
