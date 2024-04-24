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
import { ERC20StakingVault } from "./ERC20StakingVault.sol";
import { IStakingRewards } from "./interfaces/IStakingRewards.sol";

/**
 * Contract implementing simple ERC20 token staking functionality and supporting staking/unstaking fees (no staking rewards).
 */
contract ERC20StakingVaultWithFees is ERC20StakingVault {
    using SafeERC20 for IERC20;

    error InvalidFees();
    error UnsortedFeeScheduleArray();
    error UnsortedFeeAmountArray();

    /* ========== STATE VARIABLES ========== */

    /// @notice Constant Fee Unit (1e4)
    uint256 public constant feesUnit = 10000;

    /// @notice Maximum fee (20%)
    uint256 public constant maxFee = 2000;

    /// @notice Schedule of unstaking fees represented as a sorted array of durations
    /// @dev example: 10% after 1 hour, 1% after a day, 0% after a week => [3600, 86400]
    uint256[] public unstakingFeeSchedule;

    /// @notice unstaking fees described in basis points (fee unit) represented as an array of the same length as unstakingFeeSchedule
    /// @dev example: 10% after 1 hour, 1% after a day, 0% after a week => [1000, 100]
    uint256[] public unstakingFeesBps;

    /// @notice staking (staking) fee in basis points (fee unit)
    uint256 public stakingFeeBps;

    /// @notice Counter of collected fees
    uint256 public collectedFees;

    /// @notice Last staking time for each user
    mapping(address => uint32) public userLastStakedTime;

    // Emitted when fees are (re)configured
    event FeesSet(uint16 _stakingFeeBps, uint16[] _unstakingFeesBps, uint32[] _feeSchedule);

    // Emitted when a staking fee is collected
    event StakingFeesCollected(address indexed _user, uint256 _amount);

    // Emitted when a unstaking fee is collected
    event UnstakingFeesCollected(address indexed _user, uint256 _amount);

    // Emitted when fees are recovered by governance
    event FeesRecovered(uint256 _amount);

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _stakingTokenAddress address of the token used for staking (must be ERC20)
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps aligned to fee schedule
     * @param _unstakingFeeSchedule assumes a sorted array
     */
    constructor(
        address _stakingControllerAddress,
        address _stakingTokenAddress,
        bool _whitelisting,
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    ) ERC20StakingVault(_stakingControllerAddress, _stakingTokenAddress, _whitelisting) {
        _setFees(_stakingFeeBps, _unstakingFeesBps, _unstakingFeeSchedule);
    }

    /* ========== VIEWS ========== */

    /**
     * @dev Calculate the staking fee for a given amount.
     * @param _stakingAmount amount to stake
     * @return fee paid upon staking
     */
    function stakingFee(uint256 _stakingAmount) public view returns (uint256) {
        return stakingFeeBps > 0 ? (_stakingAmount * stakingFeeBps) / feesUnit : 0;
    }

    /**
     * @dev Calculate the unstaking fee for a given amount.
     * @param _account user wallet address
     * @param _unstakingAmount amount to withdraw
     * @return fee paid upon unstaking
     */
    function unstakingFee(address _account, uint256 _unstakingAmount) public view returns (uint256) {
        if (IStakingRewards(stakingControllerAddress).emitting()) {
            uint256 userLastStakedTimestampDiff = block.timestamp - userLastStakedTime[_account];
            uint256 unstakingFeeAmount;
            for (uint i = 0; i < unstakingFeeSchedule.length; ++i) {
                if (userLastStakedTimestampDiff < unstakingFeeSchedule[i]) {
                    unstakingFeeAmount = (_unstakingAmount * unstakingFeesBps[i]) / feesUnit;
                    break;
                }
            }
            return unstakingFeeAmount;
        } else {
            return 0;
        }
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @dev Recover collected fees held in the contract.
     * Note: privileged function for governance
     * @param _recipient fee recovery address
     */
    function recoverFees(address _recipient) external onlyStakingController nonReentrant {
        _beforeRecoverFees(_recipient);
        uint256 previousFees = collectedFees;
        collectedFees = 0;
        emit FeesRecovered(previousFees);
        IERC20(stakingTokenAddress).safeTransfer(_recipient, previousFees);
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Configure the fees for this contract.
     * @param _stakingFeeBps staking fee in basis points
     * @param _unstakingFeesBps unstaking fees in basis points
     * @param _unstakingFeeSchedule unstaking fees schedule
     */
    function _setFees(
        uint16 _stakingFeeBps,
        uint16[] memory _unstakingFeesBps,
        uint32[] memory _unstakingFeeSchedule
    ) private {
        if (
            _unstakingFeeSchedule.length != _unstakingFeesBps.length ||
            _unstakingFeeSchedule.length > 10 ||
            _stakingFeeBps > maxFee
        ) revert InvalidFees();

        uint32 lastFeeSchedule = 0;
        uint256 lastUnstakingFee = maxFee + 1;

        for (uint i = 0; i < _unstakingFeeSchedule.length; ++i) {
            if (_unstakingFeeSchedule[i] <= lastFeeSchedule) revert UnsortedFeeScheduleArray();
            if (_unstakingFeesBps[i] >= lastUnstakingFee) revert UnsortedFeeAmountArray();
            lastFeeSchedule = _unstakingFeeSchedule[i];
            lastUnstakingFee = _unstakingFeesBps[i];
        }

        unstakingFeeSchedule = _unstakingFeeSchedule;
        unstakingFeesBps = _unstakingFeesBps;
        stakingFeeBps = _stakingFeeBps;

        emit FeesSet(_stakingFeeBps, _unstakingFeesBps, _unstakingFeeSchedule);
    }

    /* ========== HOOKS ========== */

    /**
     * @dev Override _beforeStake() hook to collect the staking fee and update associated state
     */
    function _beforeStake(address _account, uint256 _amount) internal virtual override returns (uint256) {
        uint256 fee = stakingFee(_amount);
        userLastStakedTime[_account] = uint32(block.timestamp);
        if (fee > 0) {
            collectedFees += fee;
            emit StakingFeesCollected(_account, fee);
        }
        return super._beforeStake(_account, _amount - fee);
    }

    /**
     * @dev Override _beforeUnstake() hook to collect the unstaking fee and update associated state
     */
    function _beforeUnstake(address _account, uint256 _amount) internal virtual override returns (uint256) {
        uint256 fee = unstakingFee(_account, _amount);
        if (fee > 0) {
            collectedFees += fee;
            emit UnstakingFeesCollected(_account, fee);
        }
        return super._beforeUnstake(_account, _amount - fee);
    }

    /**
     * @dev Internal hook called before recovering fees (in the recoverFees() function).
     * @param _recipient recovery address
     */
    function _beforeRecoverFees(address _recipient) internal virtual {}
}
