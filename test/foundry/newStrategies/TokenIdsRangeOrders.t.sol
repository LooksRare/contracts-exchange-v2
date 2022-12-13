// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries and interfaces
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";
import {IExecutionStrategy} from "../../../contracts/interfaces/IExecutionStrategy.sol";
import {IExecutionManager} from "../../../contracts/interfaces/IExecutionManager.sol";
import {IStrategyManager} from "../../../contracts/interfaces/IStrategyManager.sol";

// Strategies
import {StrategyTokenIdsRange} from "../../../contracts/executionStrategies/StrategyTokenIdsRange.sol";

// Base test
import {ProtocolBase} from "../ProtocolBase.t.sol";

contract TokenIdsRangeOrdersTest is ProtocolBase, IStrategyManager {
    StrategyTokenIdsRange public strategyTokenIdsRange;
    bytes4 public selector = StrategyTokenIdsRange.executeStrategyWithTakerAsk.selector;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyTokenIdsRange = new StrategyTokenIdsRange(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selector,
            false,
            address(strategyTokenIdsRange)
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
            bool isTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(1);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelector, selector);
        assertFalse(isTakerBid);
        assertEq(strategyImplementation, address(strategyTokenIdsRange));
    }

    function testTokenIdsRangeERC721() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
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

        makerBid = _createMultiItemMakerBidOrder({
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

        takerAsk = OrderStructs.TakerAsk({
            recipient: takerUser,
            minPrice: makerBid.maxPrice,
            itemIds: takerAskItemIds,
            amounts: takerAskAmounts,
            additionalParameters: abi.encode()
        });

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
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
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidAmounts = new uint256[](3);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 0;
        invalidAmounts[2] = 2;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
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

    function testCallerNotLooksRareProtocol() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        // Valid, but wrong caller
        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.WrongCaller.selector);
        // Call the function directly
        strategyTokenIdsRange.executeStrategyWithTakerAsk(takerAsk, makerBid);
    }

    function testMakerBidItemIdsLowerBandHigherThanOrEqualToUpperBand() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](2);
        invalidItemIds[0] = 5;
        // lower band > upper band
        invalidItemIds[1] = 4;

        makerBid.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertFalse(isValid);
        assertEq(errorSelector, IExecutionStrategy.OrderInvalid.selector);

        vm.expectRevert(errorSelector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);

        // lower band == upper band
        invalidItemIds[1] = 5;

        makerBid.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskDuplicatedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 7;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskUnsortedItemIds() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory invalidItemIds = new uint256[](3);
        invalidItemIds[0] = 5;
        invalidItemIds[1] = 10;
        invalidItemIds[2] = 7;

        takerAsk.itemIds = invalidItemIds;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskOfferedAmountNotEqualToDesiredAmount() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        uint256[] memory itemIds = new uint256[](2);
        itemIds[0] = 5;
        itemIds[1] = 10;

        takerAsk.itemIds = itemIds;

        uint256[] memory invalidAmounts = new uint256[](2);
        invalidAmounts[0] = 1;
        invalidAmounts[1] = 1;

        takerAsk.amounts = invalidAmounts;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testTakerAskPriceTooHigh() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        takerAsk.minPrice = makerBid.maxPrice + 1 wei;

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(IExecutionStrategy.OrderInvalid.selector);
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }

    function testInactiveStrategy() public {
        _setUpUsers();
        _setUpNewStrategy();
        (makerBid, takerAsk) = _createMakerBidAndTakerAsk();

        // Sign order
        signature = _signMakerBid(makerBid, makerUserPK);

        vm.prank(_owner);
        looksRareProtocol.updateStrategy(1, _standardProtocolFee, _minTotalFee, false);

        // Valid, taker struct validation only happens during execution
        (bool isValid, bytes4 errorSelector) = strategyTokenIdsRange.isValid(makerBid);
        assertTrue(isValid);
        assertEq(errorSelector, bytes4(0));

        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyNotAvailable.selector, uint16(1)));
        vm.prank(takerUser);
        // Execute taker bid transaction
        looksRareProtocol.executeTakerAsk(takerAsk, makerBid, signature, _emptyMerkleTree, _emptyAffiliate);
    }
}
