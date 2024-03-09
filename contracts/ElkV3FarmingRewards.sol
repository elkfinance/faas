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
import { ElkV3StakingStrategy } from "./ElkV3StakingStrategy.sol";

/**
 * Contract enabling staking permissions for FarmingRewards.
 */
contract ElkV3FarmingRewards is IElkV3FarmingRewards, StakingRewards {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _nftPositionManager address of the position manager
     * @param _lpTokenAddress address of the staking LP token (must be an ElkDex LP)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     * @param _whitelisting whether whitelisting of stakers should be enabled or not
     */
    constructor(
        address _nftPositionManager, // address of the position manager
        address _lpTokenAddress, // address of the staking LP token (must be an ElkDex LP)
        address[] memory _rewardTokenAddresses, // addresses the reward tokens (must be ERC20)
        uint256 _rewardsDuration, // reward emission duration
        bool _whitelisting
    )
        StakingRewards(
            address(new ElkV3StakingStrategy(_nftPositionManager, address(this), _lpTokenAddress, _whitelisting)),
            _rewardTokenAddresses,
            _rewardsDuration
        )
    {}
}
