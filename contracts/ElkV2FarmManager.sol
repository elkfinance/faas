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
import { IElkV2FarmManager } from "./interfaces/IElkV2FarmManager.sol";
import { IElkV2FarmingRewards } from "./interfaces/IElkV2FarmingRewards.sol";
import { ERC20StakingStrategyWithFees } from "./ERC20StakingStrategyWithFees.sol";

/**
 * This contract serves as the main point of contact between any FarmingRewards creators and their farm contract.
 * It contains any function in FarmingRewards that would normally be restricted to the owner and allows access to its functionality as long as the caller is the known owner in the ElkFarmFactory contract.
 */
contract ElkV2FarmManager is IElkV2FarmManager, FaasManager {
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
    
    /* ========== FEES ========== */

    /**
     * @notice Withdraw fees collected from deposits/withdrawals in the FarmingRewards contract to msg.sender.
     * @param _farmAddress The address of the FarmingRewards contract.
     */
    function recoverFees(address _farmAddress) external checkOwnership(_farmAddress) {
        ERC20StakingStrategyWithFees(address(IElkV2FarmingRewards(_farmAddress).stakingStrategy())).recoverFees(
            msg.sender
        );
    }
}
