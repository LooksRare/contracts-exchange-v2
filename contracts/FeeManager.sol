// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// LooksRare unopinionated libraries
import {OwnableTwoSteps} from "@looksrare/contracts-libs/contracts/OwnableTwoSteps.sol";
import {IERC165} from "@looksrare/contracts-libs/contracts/interfaces/generic/IERC165.sol";

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
}
