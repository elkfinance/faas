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

import { IElkSingleStakingRewards } from "./interfaces/IElkSingleStakingRewards.sol";
import { StakingRewards } from "./StakingRewards.sol";
import { ERC20StakingStrategyWithFees } from "./ERC20StakingStrategyWithFees.sol";

/**
 * Contract enabling staking permissions for FarmingRewards.
 */
contract ElkSingleStakingRewards is IElkSingleStakingRewards, StakingRewards {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _stakingTokenAddress address of the token used for staking (must be ERC20)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     * @param _whitelisting whether whitelisting of stakers should be enabled or not
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps aligned to fee schedule
     * @param _unstakingFeeSchedule assumes a sorted array
     */
    constructor(
        address _stakingTokenAddress,
        address[] memory _rewardTokenAddresses, // addresses the reward tokens (must be ERC20)
        uint256 _rewardsDuration, // reward emission duration
        bool _whitelisting,
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    )
        StakingRewards(
            address(
                new ERC20StakingStrategyWithFees(
                    address(this),
                    _stakingTokenAddress,
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
