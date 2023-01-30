// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

// Custom errors
import {OrderInvalid} from "../../../contracts/interfaces/SharedErrors.sol";

// Base strategy contracts
import {BaseStrategy} from "../../../contracts/executionStrategies/BaseStrategy.sol";

contract StrategyTestMultiFillCollectionOrder is BaseStrategy {
    using OrderStructs for OrderStructs.MakerBid;

    // Address of the protocol
    address public immutable LOOKSRARE_PROTOCOL;

    // Tracks historical fills
    mapping(bytes32 => uint256) internal countItemsFilledForOrderHash;

    /**
     * @notice Constructor
     * @param _looksRareProtocol Address of the LooksRare protocol
     */
    constructor(address _looksRareProtocol) {
        LOOKSRARE_PROTOCOL = _looksRareProtocol;
    }

    /**
     * @notice Execute collection strategy with taker ask order
     * @param takerAsk Taker ask struct (taker ask-specific parameters for the execution)
     * @param makerBid Maker bid struct (maker bid-specific parameters for the execution)
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    ) external returns (uint256 price, uint256[] memory itemIds, uint256[] memory amounts, bool isNonceInvalidated) {
        if (msg.sender != LOOKSRARE_PROTOCOL) revert OrderInvalid();
        // Only available for ERC721
        if (makerBid.assetType != 0) revert OrderInvalid();

        bytes32 orderHash = makerBid.hash();
        uint256 countItemsFilled = countItemsFilledForOrderHash[orderHash];
        uint256 countItemsFillable = makerBid.amounts[0];

        price = makerBid.maxPrice;
        (itemIds, amounts) = abi.decode(takerAsk.additionalParameters, (uint256[], uint256[]));
        uint256 countItemsToFill = amounts.length;

        if (
            countItemsToFill == 0 ||
            makerBid.amounts.length != 1 ||
            itemIds.length != countItemsToFill ||
            countItemsFillable < countItemsToFill + countItemsFilled
        ) revert OrderInvalid();

        for (uint256 i; i < countItemsToFill; ) {
            if (amounts[i] != 1) {
                revert OrderInvalid();
            }
            unchecked {
                ++i;
            }
        }

        price *= countItemsToFill;

        if (countItemsToFill + countItemsFilled == countItemsFillable) {
            delete countItemsFilledForOrderHash[orderHash];
            isNonceInvalidated = true;
        } else {
            countItemsFilledForOrderHash[orderHash] += countItemsToFill;
        }
    }
}
