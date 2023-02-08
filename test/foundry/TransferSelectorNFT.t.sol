// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// LooksRare unopinionated libraries
import {IOwnableTwoSteps} from "@looksrare/contracts-libs/contracts/interfaces/IOwnableTwoSteps.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Interfaces
import {ITransferSelectorNFT} from "../../contracts/interfaces/ITransferSelectorNFT.sol";

// Errors
import {ASSET_TYPE_NOT_SUPPORTED} from "../../contracts/constants/ValidationCodeConstants.sol";
import {AssetTypeInvalid} from "../../contracts/errors/SharedErrors.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

contract TransferSelectorNFTTest is ProtocolBase, ITransferSelectorNFT {
    function setUp() public {
        _setUp();
    }

    function testCannotTransferIfNoManagerSelectorForAssetType() public {
        _setUpUsers();
        uint256 price = 0.1 ether;

        //  Prepare the orders and signature
        (OrderStructs.Maker memory makerAsk, OrderStructs.Taker memory takerBid, bytes memory signature) = _createSingleItemMakerAskAndTakerBidOrderAndSignature({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: 2, // It does not exist
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: makerUser,
            minPrice: price,
            itemId: 10
        });

        _doesMakerAskOrderReturnValidationCode(makerAsk, signature, ASSET_TYPE_NOT_SUPPORTED);

        vm.prank(takerUser);
        vm.expectRevert(abi.encodeWithSelector(AssetTypeInvalid.selector, 2));
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );
    }
}
