// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Shared errors
import "../../../contracts/interfaces/SharedErrors.sol";

// Strategies
import {StrategyItemIdsRange} from "../../../contracts/executionStrategies/StrategyItemIdsRange.sol";

// Base test
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract TokenIdsRangeOrdersTest is ProtocolBase, IStrategyManager {
    StrategyItemIdsRange public strategyItemIdsRange;
    bytes4 public selector = StrategyItemIdsRange.executeStrategyWithTakerAsk.selector;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyItemIdsRange = new StrategyItemIdsRange();
        looksRareProtocol.addStrategy(
            _standardProtocolFeeBp,
            _minTotalFeeBp,
            _maxProtocolFeeBp,
            selector,
            true,
            address(strategyItemIdsRange)
        );
    }

    function _createMakerBidAndTakerAsk()
        private
        returns (OrderStructs.MakerBid memory newMakerBid, OrderStructs.TakerAsk memory newTakerAsk)
    {
        uint256[] memory makerBidItemIds = new uint256[](2);
        makerBidItemIds[0] = 5;
        makerBidItemIds[1] = 10;

        uint256[] memory makerBidAmounts = new uint256[](1);
        makerBidAmounts[0] = 3;

        newMakerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 0,
            orderNonce: 0,
            collection: address(mockERC721),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 1 ether,
            itemIds: makerBidItemIds,
            amounts: makerBidAmounts
        });

        mockERC721.mint(takerUser, 4);
        mockERC721.mint(takerUser, 5);
        mockERC721.mint(takerUser, 7);
        mockERC721.mint(takerUser, 10);
        mockERC721.mint(takerUser, 11);

        uint256[] memory takerAskItemIds = new uint256[](3);
        takerAskItemIds[0] = 5;
        takerAskItemIds[1] = 7;
        takerAskItemIds[2] = 10;

        uint256[] memory takerAskAmounts = new uint256[](3);
        takerAskAmounts[0] = 1;
        takerAskAmounts[1] = 1;
        takerAskAmounts[2] = 1;

        newTakerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: newMakerBid.maxPrice,
            itemIds: takerAskItemIds,
            amounts: takerAskAmounts,
            additionalParameters: abi.encode()
        });
    }

    function testNewStrategy() public {
        _setUpNewStrategy();
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelector,
            bool strategyIsMakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFeeBp);
        assertEq(strategyMinTotalFee, _minTotalFeeBp);
        assertEq(strategyMaxProtocolFee, _maxProtocolFeeBp);
        assertEq(strategySelector, selector);
        assertTrue(strategyIsMakerBid);
        assertEq(strategyImplementation, address(strategyItemIdsRange));
    }

    function testTokenIdsRangeERC721() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(5), makerUser);
        assertEq(mockERC721.ownerOf(7), makerUser);
        assertEq(mockERC721.ownerOf(10), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 1 ether);
        // Taker ask user receives 98% of the whole price (2% protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testTokenIdsRangeERC1155() public {
        _setUpUsers();
        _setUpNewStrategy();

        uint256[] memory makerBidItemIds = new uint256[](2);
        makerBidItemIds[0] = 5;
        makerBidItemIds[1] = 10;

        uint256[] memory makerBidAmounts = new uint256[](1);
        makerBidAmounts[0] = 6;

        OrderStructs.MakerBid memory makerBid = _createMultiItemMakerBidOrder({
            bidNonce: 0,
            subsetNonce: 0,
            strategyId: 1,
            assetType: 1,
            orderNonce: 0,
            collection: address(mockERC1155),
            currency: address(weth),
            signer: makerUser,
            maxPrice: 1 ether,
            itemIds: makerBidItemIds,
            amounts: makerBidAmounts
        });

        mockERC1155.mint(takerUser, 5, 2);
        mockERC1155.mint(takerUser, 7, 2);
        mockERC1155.mint(takerUser, 10, 2);

        uint256[] memory takerAskItemIds = new uint256[](3);
        takerAskItemIds[0] = 5;
        takerAskItemIds[1] = 7;
        takerAskItemIds[2] = 10;

        uint256[] memory takerAskAmounts = new uint256[](3);
        takerAskAmounts[0] = 2;
        takerAskAmounts[1] = 2;
        takerAskAmounts[2] = 2;

        OrderStructs.TakerAsk memory takerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: makerBid.maxPrice,
            itemIds: takerAskItemIds,
            amounts: takerAskAmounts,
            additionalParameters: abi.encode()
        });

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Maker user has received the asset
        assertEq(mockERC1155.balanceOf(makerUser, 5), 2);
        assertEq(mockERC1155.balanceOf(makerUser, 7), 2);
        assertEq(mockERC1155.balanceOf(makerUser, 10), 2);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 1 ether);
        // Taker ask user receives 98% of the whole price (2% protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testTakerAskForceAmountOneIfERC721() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidAmounts = new uint256[](3);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 0;
        invalidAmounts[2] = 2;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // Maker user has received the asset
        assertEq(mockERC721.ownerOf(5), makerUser);
        assertEq(mockERC721.ownerOf(7), makerUser);
        assertEq(mockERC721.ownerOf(10), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 1 ether);
        // Taker ask user receives 98% of the whole price (2% protocol fee)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + 0.98 ether);
    }

    function testMakerBidItemIdsLowerBandHigherThanOrEqualToUpperBand() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](2);
        invalidItemIds[0] = 5;
        // lower band > upper band
        invalidItemIds[1] = 4;

        makerBid.itemIds = invalidItemIds;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertFalse(isValid);
        assertEq(errorSelector, OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // lower band == upper band
        invalidItemIds[1] = 5;

        makerBid.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskDuplicatedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 7;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskUnsortedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 10;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskOfferedAmountNotEqualToDesiredAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 5;
        itemIds[1] = 10;

        takerAsk.itemIds = itemIds;

        uint256[] memory invalidAmounts = new uint256[](2);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 1;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskPriceTooHigh() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        takerAsk.minPrice = makerBid.maxPrice + 1 wei;

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testInactiveStrategy() public {
        _setUpUsers();
        _setUpNewStrategy();
        (OrderStructs.MakerBid memory makerBid, OrderStructs.TakerAsk memory takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        bytes memory signature = _signMakerBid(makerBid, makerUserPK);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFeeBp, _minTotalFeeBp, false);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyItemIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, 1));
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }
}
