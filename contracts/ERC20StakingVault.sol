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

pragma solidity ^0.8.0;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { StakingVault } from "./StakingVault.sol";

contract ERC20StakingVault is StakingVault {
    using SafeERC20 for IERC20;

    error CannotStakeZero();
    error CannotUnstakeZero();
    error CannotUnstakeTooHighAmount();

    uint256 public override totalSupply;

    mapping(address => uint256) public override balances;

    /// @param _stakingTokenAddress address of the token used for staking (must be ERC20)
    constructor(
        address _stakingControllerAddress,
        address _stakingTokenAddress,
        bool _whitelisting
    ) StakingVault(_stakingControllerAddress, _stakingTokenAddress, _whitelisting) {}

    /**
     * @dev Stake tokens.
     * Note: the contract must have sufficient allowance for the staking token.
     * @param _amount amount to stake
     */
    function stake(address _from, uint256 _amount) external override nonReentrant onlyStakingController {
        uint256 originalAmount = _amount;
        _amount = _beforeStake(_from, _amount);
        if (originalAmount == 0 || _amount == 0) revert CannotStakeZero(); // Check after the hook
        totalSupply += _amount;
        balances[_from] += _amount;
        IERC20(stakingTokenAddress).safeTransferFrom(_from, address(this), originalAmount);
        emit Staked(_from, _amount);
    }

    /**
     * @dev Unstake previously staked tokens.
     * @param _amount amount to unstake
     */
    function unstake(address _to, uint256 _amount) public override nonReentrant onlyStakingController {
        uint256 originalAmount = _amount;
        _amount = _beforeUnstake(_to, _amount);
        // Check after the hook
        if (_amount == 0) revert CannotUnstakeZero();
        if (originalAmount > balances[_to] || _amount > balances[_to]) revert CannotUnstakeTooHighAmount();
        totalSupply -= originalAmount;
        balances[_to] -= originalAmount;
        IERC20(stakingTokenAddress).safeTransfer(_to, _amount);
        emit Unstaked(_to, _amount);
    }

    /**
     * @dev Unstakes all previously staked tokens.
     * @param _to Address where unstaked tokens should be sent.
     */
    function unstakeAll(address _to) external override onlyStakingController {
        unstake(_to, balances[_to]);
    }

}
