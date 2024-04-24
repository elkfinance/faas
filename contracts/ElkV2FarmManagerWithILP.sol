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

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { FaasManager } from "./FaasManager.sol";
import { IElkV2FarmManagerWithILP } from "./interfaces/IElkV2FarmManagerWithILP.sol";
import { IElkV2FarmingRewardsWithILP } from "./interfaces/IElkV2FarmingRewardsWithILP.sol";
import { ERC20StakingVaultWithFees } from "./ERC20StakingVaultWithFees.sol";

/**
 * This contract serves as the main point of contact between any FarmingRewards creators and their farm contract.
 * It contains any function in FarmingRewards that would normally be restricted to the owner and allows access to its functionality as long as the caller is the known owner in the ElkFarmFactory contract.
 */
contract ElkV2FarmManagerWithILP is IElkV2FarmManagerWithILP, FaasManager {
    using SafeERC20 for IERC20;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _factoryAddress The address of the ElkFarmFactory contract.
     * @param _minDelayBeforeStop The minimum time before a farm can be stopped after having been started.
     */
    constructor(
        address _factoryAddress,
        uint256 _minDelayBeforeStop
    ) FaasManager(_factoryAddress, _minDelayBeforeStop) {}

    /* ========== Farm Functions ========== */

    /**
     * @notice Starts the farm emission for the given FarmingRewards contract address. The amount of rewards per rewards token, ILP coverage amount, and duration of the
     * farm emissions must be supplied. Any reward or coverage tokens are sent to the FarmingRewards contract when this function is called.
     * @param _farmAddress The address of the FarmingRewards contract.
     * @param _rewards An array of rewards indexed by reward token number.
     * @param _coverage The amount of coverage for the farm.
     * @param _duration How long the farm will emit rewards and provide coverage.
     */
    function startEmissionWithCoverage(
        address _farmAddress,
        uint256[] memory _rewards,
        uint256 _coverage,
        uint256 _duration
    ) external checkOwnership(_farmAddress) {
        IElkV2FarmingRewardsWithILP farm = IElkV2FarmingRewardsWithILP(_farmAddress);
        // Transfer rewards
        for (uint i = 0; i < _rewards.length; ++i) {
            IERC20(farm.rewardTokens(i)).safeTransferFrom(msg.sender, _farmAddress, _rewards[i]);
        }
        // Transfer coverage
        if (_coverage > 0) {
            IERC20(farm.coverageTokenAddress()).safeTransferFrom(msg.sender, _farmAddress, _coverage);
        }
        // Start emissions
        IElkV2FarmingRewardsWithILP(_farmAddress).startEmission(_rewards, _coverage, _duration);
        lastStarted[_farmAddress] = block.timestamp;
    }

    /* ========== ILP ========== */

    /**
     * @notice Recovers the given leftover coverage token to the msg.sender. Cannot be called while the farm is active or if there are any LP tokens staked in the contract.
     * @param _farmAddress The address of the FarmingRewards contract.
     */
    function recoverLeftoverCoverage(address _farmAddress) external checkOwnership(_farmAddress) {
        IElkV2FarmingRewardsWithILP(_farmAddress).recoverLeftoverCoverage(msg.sender);
    }

    /* ========== FEES ========== */

    /**
     * @notice Withdraw fees collected from deposits/withdrawals in the FarmingRewards contract to msg.sender.
     * @param _farmAddress The address of the FarmingRewards contract.
     */
    function recoverFees(address _farmAddress) external checkOwnership(_farmAddress) {
        ERC20StakingVaultWithFees(address(IElkV2FarmingRewardsWithILP(_farmAddress).stakingVault())).recoverFees(
            msg.sender
        );
    }
}
