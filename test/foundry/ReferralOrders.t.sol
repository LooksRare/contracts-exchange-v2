// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OrderStructs} from "../../contracts/libraries/OrderStructs.sol";
import {ReferralStaking} from "../../contracts/ReferralStaking.sol";
import {ProtocolBase} from "./ProtocolBase.t.sol";
import {IReferralStaking} from "../../contracts/interfaces/IReferralStaking.sol";
import {MockERC20} from "../mock/MockERC20.sol";

contract ReferralOrdersTest is ProtocolBase {
    ReferralStaking public referralStaking;
    MockERC20 public mockERC20;

    function _setUpReferralStaking() public asPrankedUser(_owner) {
        mockERC20 = new MockERC20();
        referralStaking = new ReferralStaking(address(looksRareProtocol), address(mockERC20), _timelock);
        referralStaking.setTier(0, 1000, 10 ether);
        referralStaking.setTier(1, 2000, 20 ether);
        looksRareProtocol.updateReferralController(address(referralStaking));
    }
}
