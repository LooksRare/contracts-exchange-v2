// SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

contract OrderStructs {
    struct BaseMakerOrder {
        uint112 userBidAskNonce;
        uint112 userSubsetNonce;
        uint16 strategyId; // 0: Standard; 1: Collection; 2. etc.
        uint8 assetType; // 0: ERC721; 1: ERC1155
        address collection;
        address currency;
        address recipient;
        address signer;
        uint256 startTime;
        uint256 endTime;
    }

    struct SingleMakerAskOrder {
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts; // length = 1 if single sale // length > 1 if batch sale
        uint112 orderNonce;
        uint256 minNetRatio; // e.g., 8500 = At least, 85% of the sale proceeds to the maker ask
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
        address recipient;
        address referrer;
        uint256 maxPrice;
        uint256[] itemIds;
        uint256[] amounts;
        bytes additionalParameters;
    }

    struct TakerAskOrder {
        address recipient;
        address referrer;
        uint256 minPrice;
        uint256[] itemIds;
        uint256[] amounts;
        uint256 minNetRatio;
        bytes additionalParameters;
    }
}
