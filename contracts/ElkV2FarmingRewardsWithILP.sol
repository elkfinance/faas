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
import { StakingRewardsWithILP } from "./StakingRewardsWithILP.sol";
import { ElkV2StakingVault } from "./ElkV2StakingVault.sol";
import { IElkV2FarmingRewardsWithILP } from "./interfaces/IElkV2FarmingRewardsWithILP.sol";

/**
 * Contract enabling staking permissions for FarmingRewards.
 */
contract ElkV2FarmingRewardsWithILP is IElkV2FarmingRewardsWithILP, StakingRewardsWithILP {
    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _oracleAddress address of the ElkDex oracle
     * @param _lpTokenAddress address of the staking LP token (must be an ElkDex LP)
     * @param _coverageTokenAddress address of the token that the coverage is paid in
     * @param _coverageAmount total amount of coverage
     * @param _coverageVestingDuration time it takes to vest 100% of the coverage (min. 1 day)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     * @param _whitelisting whether whitelisting of stakers should be enabled or not
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps aligned to fee schedule
     * @param _unstakingFeeSchedule assumes a sorted array
     */
    constructor(
        address _oracleAddress,
        address _lpTokenAddress, // address of the staking LP token (must be an ElkDex LP)
        address _coverageTokenAddress,
        uint256 _coverageAmount,
        uint32 _coverageVestingDuration,
        address[] memory _rewardTokenAddresses, // addresses the reward tokens (must be ERC20)
        uint256 _rewardsDuration, // reward emission duration
        bool _whitelisting,
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    )
        StakingRewardsWithILP(
            _oracleAddress,
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
            _coverageTokenAddress,
            _coverageAmount,
            _coverageVestingDuration,
            _rewardTokenAddresses,
            _rewardsDuration
        )
    {}
}
