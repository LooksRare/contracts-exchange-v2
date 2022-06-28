// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

/**
 * @title OrderStructs
 * @notice This library contains all order struct types for the LooksRare protocol (v2).
 * @author LooksRare protocol team (👀,💎)
 */
library OrderStructs {
    // keccak256("MultipleMakerAskOrders(SingleMakerAskOrder[] makerAskOrders,BaseMakerOrder baseMakerOrder,bytes signature)")
    bytes32 internal constant _MULTIPLE_MAKER_ASK_ORDERS =
        0xd64ff02cfb72eb79ff0952c037f152e6ad36fc5008a8fdaa2513bde0e1fcf15d;

    // keccak256("MultipleMakerBidOrders(SingleMakerBidOrder[] makerBidOrders,BaseMakerOrder baseMakerOrder,bytes signature)")
    bytes32 internal constant _MULTIPLE_MAKER_BID_ORDERS =
        0xbe879ec8e2b2320a9bfc29ff67b2f89f8854e91b0b64acf0be9ddaf9a510903d;

    function hash(MultipleMakerAskOrders calldata orders) internal pure returns (bytes32) {
        return keccak256(abi.encode(_MULTIPLE_MAKER_ASK_ORDERS, orders.makerAskOrders, orders.baseMakerOrder));
    }

    function hash(MultipleMakerBidOrders calldata orders) internal pure returns (bytes32) {
        return keccak256(abi.encode(_MULTIPLE_MAKER_BID_ORDERS, orders.makerBidOrders, orders.baseMakerOrder));
    }

    struct BaseMakerOrder {
        uint112 bidAskNonce;
        uint112 subsetNonce;
        uint16 strategyId; // 0: Standard; 1: Collection; 2. etc.
        uint8 assetType; // 0: ERC721; 1: ERC1155
        address collection;
        address currency;
        address recipient;
        address signer;
        uint256 startTime;
        uint256 endTime;
        uint256 minNetRatio; // e.g., 8500 = At least, 85% of the sale proceeds to the maker ask
    }

    struct SingleMakerAskOrder {
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts; // length = 1 if single sale // length > 1 if batch sale
        uint112 orderNonce;
        bytes additionalParameters;
    }

    struct SingleMakerBidOrder {
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        uint128 orderNonce;
        bytes additionalParameters;
    }

    // The struct that is signed
    struct MultipleMakerBidOrders {
        SingleMakerBidOrder[] makerBidOrders;
        BaseMakerOrder baseMakerOrder;
        bytes signature;
    }

    // The struct that is signed
    struct MultipleMakerAskOrders {
        SingleMakerAskOrder[] makerAskOrders;
        BaseMakerOrder baseMakerOrder;
        bytes signature;
    }

    struct TakerBidOrder {
        uint256 maxPrice;
        address recipient;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    struct MultipleTakerBidOrders {
        address referrer;
        address currency;
        TakerBidOrder[] takerBidOrders;
    }

    struct TakerAskOrder {
        address recipient;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        uint256 minNetRatio;
        bytes additionalParameters;
    }

    struct MultipleTakerAskOrders {
        address referrer;
        address currency;
        TakerAskOrder[] takerAskOrders;
    }
}
