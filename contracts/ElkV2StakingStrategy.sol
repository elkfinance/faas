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
import { IElkPair } from "./interfaces/IElkPair.sol";
import { ERC20StakingStrategyWithFees } from "./ERC20StakingStrategyWithFees.sol";

/**
 * Contract implementing simple ERC20 token staking functionality and supporting staking/unstaking fees (no staking rewards).
 */
contract ElkV2StakingStrategy is ERC20StakingStrategyWithFees {
    using SafeERC20 for IERC20;

    error FactoryAddressesMismatched();

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _stakingTokenAddress address of the token used for staking (must be ERC20)
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps aligned to fee schedule
     * @param _unstakingFeeSchedule assumes a sorted array
     */
    constructor(
        address _factoryAddress,
        address _stakingControllerAddress,
        address _stakingTokenAddress,
        bool _whitelisting,
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    )
        ERC20StakingStrategyWithFees(
            _stakingControllerAddress,
            _stakingTokenAddress,
            _whitelisting,
            _stakingFeeBps,
            _unstakingFeesBps,
            _unstakingFeeSchedule
        )
    {
        if (IElkPair(_stakingTokenAddress).factory() != _factoryAddress) revert FactoryAddressesMismatched();
    }
}
