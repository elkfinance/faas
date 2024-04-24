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

import { IElkPair } from "./interfaces/IElkPair.sol";
import { StakingRewards } from "./StakingRewards.sol";
import { ElkV2StakingVault } from "./ElkV2StakingVault.sol";
import { IElkV2FarmingRewards } from "./interfaces/IElkV2FarmingRewards.sol";

/**
 * Contract enabling staking permissions for FarmingRewards.
 */
contract ElkV2FarmingRewards is IElkV2FarmingRewards, StakingRewards {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _lpTokenAddress address of the staking LP token (must be an ElkDex LP)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     * @param _whitelisting whether whitelisting of stakers should be enabled or not
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps aligned to fee schedule
     * @param _unstakingFeeSchedule assumes a sorted array
     */
    constructor(
        address _lpTokenAddress, // address of the staking LP token (must be an ElkDex LP)
        address[] memory _rewardTokenAddresses, // addresses the reward tokens (must be ERC20)
        uint256 _rewardsDuration, // reward emission duration
        bool _whitelisting,
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    )
        StakingRewards(
            address(
                new ElkV2StakingVault(
                    IElkPair(_lpTokenAddress).factory(),
                    address(this),
                    _lpTokenAddress,
                    _whitelisting,
                    _stakingFeeBps,
                    _unstakingFeesBps,
                    _unstakingFeeSchedule
                )
            ),
            _rewardTokenAddresses,
            _rewardsDuration
        )
    {}
}
