// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "../../../lib/forge-std/src/Test.sol";
import {OrderStructs} from "../../../contracts/libraries/OrderStructs.sol";

abstract contract TestParameters is Test {
    address internal _owner = address(42);
    address internal _royaltyRecipient = address(22);
    address internal _emptyReferrer = address(0);
    uint16 internal _standardProtocolFee = uint16(200);
    uint16 internal _standardRoyaltyFee = uint16(100);
    uint256 internal makerUserPK = 1;
    uint256 internal takerUserPK = 2;
    address internal makerUser = vm.addr(makerUserPK);
    address internal takerUser = vm.addr(takerUserPK);
    OrderStructs.MerkleRoot internal _emptyMerkleRoot = OrderStructs.MerkleRoot({root: bytes32(0)});
    bytes32[] internal _emptyMerkleProof = new bytes32[](0);

    // Initial balances
    uint256 internal _initialETHBalanceUser = 100 ether;
    uint256 internal _initialWETHBalanceUser = 10 ether;
    uint256 internal _initialETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialWETHBalanceRoyaltyRecipient = 10 ether;
    uint256 internal _initialETHBalanceOwner = 50 ether;
    uint256 internal _initialWETHBalanceOwner = 15 ether;
    uint256 internal _initialETHBalanceReferrer = 30 ether;
    uint256 internal _initialWETHBalanceReferrer = 12 ether;

    // Referral parameters
    address public _referrerUser = address(2);
    uint256 public constant _timelock = 120;

    // Reused parameters
    OrderStructs.MakerAsk makerAsk;
    OrderStructs.MakerBid makerBid;
    OrderStructs.TakerBid takerBid;
    OrderStructs.TakerAsk takerAsk;
    bytes signature;
}
