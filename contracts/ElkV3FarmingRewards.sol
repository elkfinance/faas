// SPDX-License-Identifier: BUSL-1.1
//
// Copyright (c) 2023 ElkLabs
// License terms: https://github.com/elkfinance/faas/blob/main/LICENSE
//
// Authors:
// - Seth <seth@elklabs.org>
// - Baal <baal@elklabs.org>
// - Elijah <elijah@elklabs.org>
// - Snake <snake@elklabs.org>

pragma solidity >=0.8.0;

import { IElkV3FarmingRewards } from "./interfaces/IElkV3FarmingRewards.sol";
import { StakingRewards } from "./StakingRewards.sol";
import { ElkV3StakingVault } from "./ElkV3StakingVault.sol";

/**
 * Contract enabling staking permissions for FarmingRewards.
 */
contract ElkV3FarmingRewards is IElkV3FarmingRewards, StakingRewards {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _lpTokenAddress address of the staking LP token (must be an ElkDex LP)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     * @param _whitelisting whether whitelisting of stakers should be enabled or not
     */
    constructor(
        address _lpTokenAddress, // address of the staking LP token (must be an ElkDex LP)
        address[] memory _rewardTokenAddresses, // addresses the reward tokens (must be ERC20)
        uint256 _rewardsDuration, // reward emission duration
        bool _whitelisting
    )
        StakingRewards(
            address(new ElkV3StakingVault(address(this), _lpTokenAddress, _whitelisting)),
            _rewardTokenAddresses,
            _rewardsDuration
        )
    {}
}
