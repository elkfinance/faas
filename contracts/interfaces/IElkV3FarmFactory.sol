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

interface IElkV3FarmFactory is IFaasFactory {

    event PositionManagerWhitelisted(address indexed positionManager, bool whitelisted);

    function whitelistedPositionManagers(address positionManager) external view returns (bool);

    function whitelistPositionManager(address _positionManager, bool _whitelisted) external;

    function createNewRewards(
        address _positionManagerAddress,
        address _lpTokenAddress,
        address[] memory _rewardTokenAddresses,
        uint256 _rewardsDuration,
        uint16 _depositFeeBps,
        uint16[] memory _withdrawalFeesBps,
        uint32[] memory _withdrawalFeeSchedule
    ) external;
}
