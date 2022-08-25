// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RoyaltyFeeRegistry} from "@looksrare/contracts-exchange-v1/contracts/royaltyFeeHelpers/RoyaltyFeeRegistry.sol";
import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";

import {LooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {IExecutionManager} from "../../contracts/interfaces/IExecutionManager.sol";

import {ProtocolHelpers} from "./utils/ProtocolHelpers.sol";
import {MockERC721} from "./utils/MockERC721.sol";

contract ExecutionManagerTest is IExecutionManager, ProtocolHelpers {
    using OrderStructs for OrderStructs.MultipleMakerAskOrders;
    using OrderStructs for OrderStructs.MultipleMakerBidOrders;

    address[] public operators;

    MockERC721 public mockERC721;
    RoyaltyFeeRegistry public royaltyFeeRegistry;
    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    WETH public weth;

    function _setUpUser(address user) internal asPrankedUser(user) {
        vm.deal(user, 100 ether);
        mockERC721.setApprovalForAll(address(transferManager), true);
        transferManager.grantApprovals(operators);
        weth.approve(address(looksRareProtocol), type(uint256).max);
        weth.deposit{value: 10 ether}();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function setUp() public asPrankedUser(_owner) {
        royaltyFeeRegistry = new RoyaltyFeeRegistry(9500);
        transferManager = new TransferManager();
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(royaltyFeeRegistry));
        mockERC721 = new MockERC721();
        weth = new WETH();

        vm.deal(_owner, 100 ether);
        vm.deal(_collectionOwner, 100 ether);

        // Verify interfaceId of ERC-2981 is not supported
        assertFalse(mockERC721.supportsInterface(0x2a55205a));

        // Update registry info
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(address(mockERC721), _collectionOwner, _collectionOwner, 100);

        (address recipient, uint256 amount) = royaltyFeeRegistry.royaltyInfo(address(mockERC721), 1 ether);
        assertEq(recipient, _collectionOwner);
        assertEq(amount, 1 ether / 100);

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(address(weth));
        looksRareProtocol.setProtocolFeeRecipient(_owner);

        // Fetch domain separator
        (_domainSeparator, , , ) = looksRareProtocol.information();
        operators.push(address(looksRareProtocol));
    }

    /**
     * Owner can change protocol fee and deactivate royalty
     */
    function testOwnerCanChangeStrategyProtocolFeeAndDeactivateRoyalty() public asPrankedUser(_owner) {
        uint16 strategyId = 0;
        bool hasRoyalties = false;
        uint16 protocolFee = 250;
        bool isActive = true;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, hasRoyalties, protocolFee);
        looksRareProtocol.updateStrategy(strategyId, hasRoyalties, protocolFee, isActive);

        Strategy memory strategy = looksRareProtocol.viewStrategy(strategyId);
        assertTrue(strategy.isActive);
        assertTrue(!strategy.hasRoyalties);
        assertEq(strategy.protocolFee, protocolFee);
        assertEq(strategy.implementation, address(0));
    }

    /**
     * Owner can discontinue strategy
     */
    function testOwnerCanDiscontinueStrategy() public asPrankedUser(_owner) {
        uint16 strategyId = 1;
        bool hasRoyalties = true;
        uint16 protocolFee = 299;
        bool isActive = false;

        vm.expectEmit(false, false, false, false);
        emit StrategyUpdated(strategyId, isActive, hasRoyalties, protocolFee);
        looksRareProtocol.updateStrategy(strategyId, hasRoyalties, protocolFee, isActive);

        Strategy memory strategy = looksRareProtocol.viewStrategy(strategyId);
        assertTrue(!strategy.isActive);
        assertTrue(strategy.hasRoyalties);
        assertEq(strategy.protocolFee, protocolFee);
        assertEq(strategy.implementation, address(0));
    }

    function testOwnerRevertionsForWrongParametersAddStrategy() public asPrankedUser(_owner) {
        uint16 strategyId = 1;
        bool hasRoyalties = true;
        uint16 protocolFee = 250;
        uint16 maxProtocolFee = 300;
        address implementation = address(0);

        // 1. Strategy already exists so cannot be added
        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyUsed.selector, strategyId));
        looksRareProtocol.addStrategy(strategyId, hasRoyalties, protocolFee, maxProtocolFee, implementation);

        // 2. Strategy does not exist but maxProtocolFee is lower than protocolFee
        strategyId = 3;
        maxProtocolFee = protocolFee - 1;
        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyProtocolFeeTooHigh.selector, strategyId));
        looksRareProtocol.addStrategy(strategyId, hasRoyalties, protocolFee, maxProtocolFee, implementation);

        // 3. Strategy does not exist but maxProtocolFee is higher than _MAX_PROTOCOL_FEE
        strategyId = 3;
        maxProtocolFee = 5000 + 1;
        vm.expectRevert(abi.encodeWithSelector(IExecutionManager.StrategyProtocolFeeTooHigh.selector, strategyId));
        looksRareProtocol.addStrategy(strategyId, hasRoyalties, protocolFee, maxProtocolFee, implementation);
    }
}
