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

import { IElkDexOracle } from "./IElkDexOracle.sol";
import { IElkPair } from "./IElkPair.sol";
import { IStakingRewards } from "./IStakingRewards.sol";

interface IStakingRewardsWithILP is IStakingRewards {
    /// @notice Represents a snapshot of an LP position at a given timestamp
    struct Position {
        uint112 amount0;
        uint112 amount1;
        uint32 blockTimestamp;
    }

    /* ========== STATE VARIABLES ========== */

    function oracle() external returns (IElkDexOracle);

    function lpToken() external returns (IElkPair);

    function coverageTokenAddress() external returns (address);

    function coverageAmount() external returns (uint256);

    function coverageVestingDuration() external returns (uint256);

    function coverageRate() external returns (uint256);

    function coveragePerTokenStored() external returns (uint256);

    function userCoveragePerTokenPaid(address _tokenPaid) external returns (uint256);

    function coverage(address _token) external returns (uint256);

    function lastStakedPosition(
        address _user
    ) external returns (uint112 amount0, uint112 amount1, uint32 blockTimeStamp);

    /* ========== VIEWS ========== */

    function coveragePerToken() external view returns (uint256);

    function coverageEarned(address _account) external view returns (uint256);

    /* ========== MUTATIVE FUNCTIONS ========== */

    function getCoverage(address _recipient) external;

    function startEmission(uint256[] memory _rewards, uint256 _coverage, uint256 _duration) external;

    function recoverLeftoverCoverage(address _recipient) external;

    /* ========== EVENTS ========== */

    // Emitted when the coverage is paid to an account
    event CoveragePaid(address indexed account, uint256 coverage);

    // Emitted when the leftover coverage is recovered
    event LeftoverCoverageRecovered(address indexed recipient, uint256 amount);
}
