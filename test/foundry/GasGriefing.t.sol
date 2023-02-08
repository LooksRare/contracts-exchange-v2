// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {WETH} from "solmate/src/tokens/WETH.sol";

// Base test
import {ProtocolBase} from "./ProtocolBase.t.sol";

// Mocks and other utils
import {GasGriefer} from "./utils/GasGriefer.sol";

// Constants
import {ONE_HUNDRED_PERCENT_IN_BP} from "../../contracts/constants/NumericConstants.sol";

// Enums
import {AssetType} from "../../contracts/enums/AssetType.sol";

contract GasGriefingTest is ProtocolBase {
    uint256 private constant price = 1 ether; // Fixed price of sale
    address private gasGriefer;

    // WETH events
    event Deposit(address indexed from, uint256 amount);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    function setUp() public {
        _setUp();
        gasGriefer = address(new GasGriefer());
        _setUpUser(gasGriefer);
        _setUpUser(takerUser);
    }

    function testTakerBidGasGriefing() public {
        _setupRegistryRoyalties(address(mockERC721), _standardRoyaltyFee);

        uint256 itemId = 0;

        // Mint asset
        mockERC721.mint(gasGriefer, itemId);

        // Prepare the order hash
        OrderStructs.Maker memory makerAsk = _createSingleItemMakerAskOrder({
            askNonce: 0,
            subsetNonce: 0,
            strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
            assetType: AssetType.ERC721,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: ETH,
            signer: gasGriefer,
            minPrice: price,
            itemId: itemId
        });

        bytes memory signature;

        // Prepare the taker bid
        OrderStructs.Taker memory takerBid = OrderStructs.Taker(takerUser, abi.encode());

        uint256 sellerProceed = (price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP;

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true});
        emit Deposit(address(looksRareProtocol), sellerProceed);

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
        emit Transfer(address(looksRareProtocol), gasGriefer, sellerProceed);

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerBid{value: price}(
            takerBid,
            makerAsk,
            signature,
            _EMPTY_MERKLE_TREE,
            _EMPTY_AFFILIATE
        );

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(itemId), takerUser);
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - price);
        // Maker ask user receives 98% of the whole price (2%)
        assertEq(weth.balanceOf(gasGriefer), _initialWETHBalanceUser + sellerProceed);
        // Royalty recipient receives 0.5% of the whole price
        assertEq(
            address(_royaltyRecipient).balance,
            _initialETHBalanceRoyaltyRecipient + (price * _standardRoyaltyFee) / ONE_HUNDRED_PERCENT_IN_BP
        );
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
        // Verify the nonce is marked as executed
        assertEq(looksRareProtocol.userOrderNonce(gasGriefer, makerAsk.orderNonce), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
    }

    function testThreeTakerBidsGasGriefing() public {
        uint256 numberPurchases = 3;

        OrderStructs.Maker[] memory makerAsks = new OrderStructs.Maker[](numberPurchases);
        OrderStructs.Taker[] memory takerBids = new OrderStructs.Taker[](numberPurchases);
        bytes[] memory signatures = new bytes[](numberPurchases);

        for (uint256 i; i < numberPurchases; i++) {
            // Mint asset
            mockERC721.mint(gasGriefer, i);

            // Prepare the order hash
            makerAsks[i] = _createSingleItemMakerAskOrder({
                askNonce: 0,
                subsetNonce: 0,
                strategyId: STANDARD_SALE_FOR_FIXED_PRICE_STRATEGY,
                assetType: AssetType.ERC721,
                orderNonce: i,
                collection: address(mockERC721),
                currency: ETH,
                signer: gasGriefer,
                minPrice: price, // Fixed
                itemId: i // (0, 1, etc.)
            });

            takerBids[i] = OrderStructs.Taker(takerUser, abi.encode());
        }

        // Other execution parameters
        OrderStructs.MerkleTree[] memory merkleTrees = new OrderStructs.MerkleTree[](numberPurchases);

        uint256 sellerProceedPerItem = (price * 9_800) / ONE_HUNDRED_PERCENT_IN_BP;

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: false, checkData: true});
        emit Deposit(address(looksRareProtocol), sellerProceedPerItem);

        vm.expectEmit({checkTopic1: true, checkTopic2: true, checkTopic3: true, checkData: true});
        emit Transfer(address(looksRareProtocol), gasGriefer, sellerProceedPerItem);

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeMultipleTakerBids{value: price * numberPurchases}(
            takerBids,
            makerAsks,
            signatures,
            merkleTrees,
            _EMPTY_AFFILIATE,
            false
        );

        for (uint256 i; i < numberPurchases; i++) {
            // Taker user has received the asset
            assertEq(mockERC721.ownerOf(i), takerUser);
            // Verify the nonce is marked as executed
            assertEq(looksRareProtocol.userOrderNonce(gasGriefer, i), MAGIC_VALUE_ORDER_NONCE_EXECUTED);
        }
        // Taker bid user pays the whole price
        assertEq(address(takerUser).balance, _initialETHBalanceUser - (numberPurchases * price));
        // Maker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(gasGriefer), _initialWETHBalanceUser + sellerProceedPerItem * numberPurchases);
        // No leftover in the balance of the contract
        assertEq(address(looksRareProtocol).balance, 0);
    }
}
