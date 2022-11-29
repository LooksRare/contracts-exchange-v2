// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {StrategyBase} from "../../contracts/executionStrategies/StrategyBase.sol";
import {IStrategyManager} from "../../contracts/interfaces/IStrategyManager.sol";

import {ProtocolBase} from "./ProtocolBase.t.sol";

contract StrategyTestMultiFillCollectionOrder is StrategyBase {
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
     * @notice Execute collection strategy with taker bid
     * @dev It always reverts.
     */
    function executeStrategyWithTakerBid(OrderStructs.TakerBid calldata, OrderStructs.MakerAsk calldata)
        external
        pure
        returns (
            uint256,
            uint256[] calldata,
            uint256[] calldata,
            bool
        )
    {
        revert OrderInvalid();
    }

    /**
     * @notice Execute collection strategy with taker ask order
     * @param takerAsk Taker ask struct (contains the taker ask-specific parameters for the execution of the transaction)
     * @param makerBid Maker bid struct (contains the maker bid-specific parameters for the execution of the transaction)
     */
    function executeStrategyWithTakerAsk(
        OrderStructs.TakerAsk calldata takerAsk,
        OrderStructs.MakerBid calldata makerBid
    )
        external
        returns (
            uint256 price,
            uint256[] calldata itemIds,
            uint256[] calldata amounts,
            bool isNonceInvalidated
        )
    {
        if (msg.sender != LOOKSRARE_PROTOCOL) revert OrderInvalid();
        // Only available for ERC721
        if (makerBid.assetType != 0) revert OrderInvalid();

        bytes32 orderHash = makerBid.hash();
        uint256 countItemsFilled = countItemsFilledForOrderHash[orderHash];
        uint256 countItemsToFill = takerAsk.amounts.length;
        uint256 countItemsFillable = makerBid.amounts[0];

        price = makerBid.maxPrice;
        amounts = takerAsk.amounts;
        itemIds = takerAsk.itemIds;

        if (
            countItemsToFill == 0 ||
            makerBid.amounts.length != 1 ||
            itemIds.length != countItemsToFill ||
            makerBid.maxPrice != takerAsk.minPrice ||
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

contract CollectionOrdersTest is ProtocolBase, IStrategyManager {
    bytes4 public selectorTakerAsk = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerAsk.selector;
    bytes4 public selectorTakerBid = StrategyTestMultiFillCollectionOrder.executeStrategyWithTakerBid.selector;

    StrategyTestMultiFillCollectionOrder public strategyMultiFillCollectionOrder;

    function _setUpNewStrategy() private asPrankedUser(_owner) {
        strategyMultiFillCollectionOrder = new StrategyTestMultiFillCollectionOrder(address(looksRareProtocol));
        looksRareProtocol.addStrategy(
            _standardProtocolFee,
            _minTotalFee,
            _maxProtocolFee,
            selectorTakerAsk,
            selectorTakerBid,
            address(strategyMultiFillCollectionOrder)
        );
    }

    function testNewStrategy() public {
        _setUpNewStrategy();
        (
            bool strategyIsActive,
            uint16 strategyStandardProtocolFee,
            uint16 strategyMinTotalFee,
            uint16 strategyMaxProtocolFee,
            bytes4 strategySelectorTakerAsk,
            bytes4 strategySelectorTakerBid,
            address strategyImplementation
        ) = looksRareProtocol.strategyInfo(2);

        assertTrue(strategyIsActive);
        assertEq(strategyStandardProtocolFee, _standardProtocolFee);
        assertEq(strategyMinTotalFee, _minTotalFee);
        assertEq(strategyMaxProtocolFee, _maxProtocolFee);
        assertEq(strategySelectorTakerAsk, selectorTakerAsk);
        assertEq(strategySelectorTakerBid, selectorTakerBid);
        assertEq(strategyImplementation, address(strategyMultiFillCollectionOrder));
    }

    /**
     * Maker bid user wants to buy 4 ERC721 items in a collection. The order can be filled in multiple parts.
     * First takerUser sells 1 item.
     * Second takerUser sells 3 items.
     */
    function testMultiFill() public {
        _setUpUsers();
        _setUpNewStrategy();

        price = 1 ether; // Fixed price of sale
        uint256 amountsToFill = 4;

        {
            uint256[] memory itemIds = new uint256[](0);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amountsToFill;

            {
                // Prepare the order hash
                makerBid = _createMultiItemMakerBidOrder(
                    0, // bidNonce
                    0, // subsetNonce
                    2, // strategyId (Multi-fill bid offer)
                    0, // assetType ERC721,
                    0, // orderNonce
                    address(mockERC721),
                    address(weth),
                    makerUser,
                    price,
                    itemIds,
                    amounts
                );

                // Sign order
                signature = _signMakerBid(makerBid, makerUserPK);
            }
        }

        // First taker user actions
        vm.startPrank(takerUser);
        {
            uint256[] memory itemIds = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            itemIds[0] = 0;
            amounts[0] = 1;

            mockERC721.mint(takerUser, itemIds[0]);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(takerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );

            emit log_named_uint(
                "TakerAsk // 1 ERC721 Sold // Protocol Fee // Collection Order (Multi-fills) // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        vm.stopPrank();

        // Taker user has received the asset
        assertEq(mockERC721.ownerOf(0), makerUser);
        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(takerUser), _initialWETHBalanceUser + (price * 9800) / 10000);
        // Verify the nonce is not marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), computeOrderHashMakerBid(makerBid));

        // Second taker user actions
        address secondTakerUser = address(420);
        _setUpUser(secondTakerUser);
        vm.startPrank(secondTakerUser);

        {
            uint256[] memory itemIds = new uint256[](3);
            uint256[] memory amounts = new uint256[](3);

            itemIds[0] = 1; // tokenId = 1
            itemIds[1] = 2; // tokenId = 2
            itemIds[2] = 3; // tokenId = 3
            amounts[0] = 1;
            amounts[1] = 1;
            amounts[2] = 1;

            mockERC721.batchMint(secondTakerUser, itemIds);

            // Prepare the taker ask
            takerAsk = OrderStructs.TakerAsk(secondTakerUser, makerBid.maxPrice, itemIds, amounts, abi.encode());

            uint256 gasLeft = gasleft();

            // Execute taker ask transaction
            looksRareProtocol.executeTakerAsk(
                takerAsk,
                makerBid,
                signature,
                _emptyMerkleRoot,
                _emptyMerkleProof,
                _emptyAffiliate
            );

            emit log_named_uint(
                "TakerAsk // 3 ERC721 Sold // Protocol Fee // Collection Order (Multi-fills) // Registry Royalties",
                gasLeft - gasleft()
            );
        }

        // Taker user has received the 3 assets
        assertEq(mockERC721.ownerOf(1), makerUser);
        assertEq(mockERC721.ownerOf(2), makerUser);
        assertEq(mockERC721.ownerOf(3), makerUser);

        // Maker bid user pays the whole price
        assertEq(weth.balanceOf(makerUser), _initialWETHBalanceUser - 4 * price);
        // Taker ask user receives 98% of the whole price (2% protocol)
        assertEq(weth.balanceOf(secondTakerUser), _initialWETHBalanceUser + 3 * ((price * 9800) / 10000));
        // Verify the nonce is now marked as executed
        assertEq(looksRareProtocol.userOrderNonce(makerUser, makerBid.orderNonce), MAGIC_VALUE_NONCE_EXECUTED);
    }
}
