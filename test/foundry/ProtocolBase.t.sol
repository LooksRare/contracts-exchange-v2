// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// WETH
import {WETH} from "solmate/src/tokens/WETH.sol";

// Libraries
import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";

// Core contracts
import {LooksRareProtocol, ILooksRareProtocol} from "../../contracts/LooksRareProtocol.sol";
import {TransferManager} from "../../contracts/TransferManager.sol";
import {CreatorFeeManagerWithRebates} from "../../contracts/CreatorFeeManagerWithRebates.sol";

// Mock files
import {MockERC20} from "../mock/MockERC20.sol";
import {MockERC721} from "../mock/MockERC721.sol";
import {MockERC721WithRoyalties} from "../mock/MockERC721WithRoyalties.sol";
import {MockERC1155} from "../mock/MockERC1155.sol";
import {MockRoyaltyFeeRegistry} from "../mock/MockRoyaltyFeeRegistry.sol";

// Utils
import {MockOrderGenerator} from "./utils/MockOrderGenerator.sol";

contract ProtocolBase is MockOrderGenerator, ILooksRareProtocol {
    address[] public operators;

    MockERC20 public looksRareToken;
    MockERC721WithRoyalties public mockERC721WithRoyalties;
    MockERC721 public mockERC721;
    MockERC1155 public mockERC1155;

    LooksRareProtocol public looksRareProtocol;
    TransferManager public transferManager;
    MockRoyaltyFeeRegistry public royaltyFeeRegistry;
    CreatorFeeManagerWithRebates public creatorFeeManager;

    WETH public weth;

    function _setUpUser(address user) internal asPrankedUser(user) {
        // Do approvals for collections and WETH
        mockERC721.setApprovalForAll(address(transferManager), true);
        mockERC1155.setApprovalForAll(address(transferManager), true);
        mockERC721WithRoyalties.setApprovalForAll(address(transferManager), true);
        weth.approve(address(looksRareProtocol), type(uint256).max);

        // Grant approvals for transfer manager
        transferManager.grantApprovals(operators);

        // Receive ETH and WETH
        vm.deal(user, _initialETHBalanceUser + _initialWETHBalanceUser);
        weth.deposit{value: _initialWETHBalanceUser}();
    }

    function _setUpUsers() internal {
        _setUpUser(makerUser);
        _setUpUser(takerUser);
    }

    function _setupRegistryRoyalties(address collection, uint256 standardRoyaltyFee) internal {
        vm.prank(royaltyFeeRegistry.owner());
        royaltyFeeRegistry.updateRoyaltyInfoForCollection(
            collection,
            _royaltyRecipient,
            _royaltyRecipient,
            standardRoyaltyFee
        );
    }

    function setUp() public virtual {
        vm.startPrank(_owner);
        weth = new WETH();
        looksRareToken = new MockERC20();
        mockERC721 = new MockERC721();
        mockERC1155 = new MockERC1155();

        transferManager = new TransferManager();
        royaltyFeeRegistry = new MockRoyaltyFeeRegistry(9500);
        creatorFeeManager = new CreatorFeeManagerWithRebates(address(royaltyFeeRegistry));
        looksRareProtocol = new LooksRareProtocol(address(transferManager), address(weth));
        mockERC721WithRoyalties = new MockERC721WithRoyalties(_royaltyRecipient, _standardRoyaltyFee);

        // Operations
        transferManager.whitelistOperator(address(looksRareProtocol));
        looksRareProtocol.addCurrency(address(0));
        looksRareProtocol.addCurrency(address(weth));
        looksRareProtocol.setProtocolFeeRecipient(_owner);
        looksRareProtocol.setCreatorFeeManager(address(creatorFeeManager));

        // Fetch domain separator and store it as one of the operators
        _domainSeparator = looksRareProtocol.domainSeparator();
        operators.push(address(looksRareProtocol));

        // Distribute ETH and WETH to protocol owner
        vm.deal(_owner, _initialETHBalanceOwner + _initialWETHBalanceOwner);
        weth.deposit{value: _initialWETHBalanceOwner}();
        vm.stopPrank();

        // Distribute ETH and WETH to royalty recipient
        vm.deal(_royaltyRecipient, _initialETHBalanceRoyaltyRecipient + _initialWETHBalanceRoyaltyRecipient);
        vm.startPrank(_royaltyRecipient);
        weth.deposit{value: _initialWETHBalanceRoyaltyRecipient}();
        vm.stopPrank();
    }
}
