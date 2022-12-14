// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../../../lib/forge-std/src/Test.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

abstract contract TestParameters is Test {
    address internal _owner = address(42);
    address internal _sender = address(88);
    address internal _recipient = address(90);
    address internal _transferrer = address(100);
    address internal _royaltyRecipient = address(22);
    address internal _emptyAffiliate = address(0);
    uint16 internal _standardProtocolFee = uint16(150);
    uint16 internal _minTotalFee = uint16(200);
    uint16 internal _maxProtocolFee = uint16(300);
    uint16 internal _standardRoyaltyFee = uint16(50);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
    OrderStructs.MerkleTree internal _emptyMerkleTree;
    bytes4 internal _emptyBytes4 = bytes4(0);
    bytes32 public MAGIC_VALUE_NONCE_EXECUTED = 0x000000000000000000000000000000000000000000000000000000000000002a;

    // Initial balances
    uint256 internal _initialETHBalanceUser = 100 ether;
    uint256 internal _initialWETHBalanceUser = 10 ether;
    uint256 internal _initialETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialWETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialETHBalanceOwner = 50 ether;
    uint256 internal _initialWETHBalanceOwner = 15 ether;
    uint256 internal _initialETHBalanceAffiliate = 30 ether;
    uint256 internal _initialWETHBalanceAffiliate = 12 ether;

    // Affiliate parameters
    address public _affiliate = address(2);

    // Chainlink ETH/USD price feed mainnet
    address internal constant CHAINLINK_ETH_USD_PRICE_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    // Reused parameters
    uint256 public price;
}
