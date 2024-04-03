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

import { IFaasFactory } from "./IFaasFactory.sol";

interface IElkV2FarmFactoryWithILP is IFaasFactory {
    event OracleWhitelisted(address indexed oracle, bool whitelisted);

    function whitelistedOracles(address oracle) external view returns (bool);

    function whitelistOracle(address _oracleAddress, bool _whitelisted) external;

    function createNewRewards(
        address _oracleAddress,
        address _lpTokenAddress,
        address _coverageTokenAddress,
        uint256 _coverageAmount,
        uint32 _coverageVestingDuration,
        address[] memory _rewardTokenAddresses,
        uint256 _rewardsDuration,
        uint16 _depositFeeBps,
        uint16[] memory _withdrawalFeesBps,
        uint32[] memory _withdrawalFeeSchedule
    ) external;
}
