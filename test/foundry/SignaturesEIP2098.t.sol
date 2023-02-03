// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries, interfaces, errors
import "@looksrare/contracts-libs/contracts/errors/SignatureCheckerErrors.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP, ASSET_TYPE_ERC721} from "../../contracts/constants/NumericConstants.sol";

contract SignaturesEIP2098Test is ProtocolBase {
    function setUp() public {
        _setUp();
    }

    function testCanSignValidMakerAskEIP2098(uint256 price, uint256 itemId) public {
        vm.assume(price <= 2 ether);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        // Mint asset
        mockERC721.mint(makerUser, itemId);

        (
            OrderStructs.MakerAsk memory makerAsk,
            ,
            bytes memory signature
        ) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: ETH,
                signer: makerUser,
                minPrice: price,
                itemId: itemId
            });

        // Adjust the signature
        signature = _eip2098Signature(signature);

        // Verify validity of maker ask order
        _assertValidMakerAskOrder(makerAsk, signature);
    }

    function testCanSignValidMakerBidEIP2098(uint256 price, uint256 itemId) public {
        vm.assume(price <= 2 ether);

        _setUpUsers();
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        // Mint asset
        mockERC721.mint(takerUser, itemId);

        (
            OrderStructs.MakerBid memory makerBid,
            ,
            bytes memory signature
        ) = _createSingleItemMakerBidAndTakerAskOrderAndSignature({
                bidNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: ASSET_TYPE_ERC721,
                orderNonce: 0,
                collection: address(mockERC721),
                currency: address(weth),
                signer: makerUser,
                maxPrice: price,
                itemId: itemId
            });

        // Adjust the signature
        signature = _eip2098Signature(signature);

        // Verify validity of maker bid order
        _assertValidMakerBidOrder(makerBid, signature);
    }
}
