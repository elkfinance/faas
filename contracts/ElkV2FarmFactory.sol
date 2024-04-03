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
import { IElkV2FarmFactory } from "./interfaces/IElkV2FarmFactory.sol";
import { ElkV2FarmFactoryHelper } from "./ElkV2FarmFactoryHelper.sol";
import { FaasFactory } from "./FaasFactory.sol";

/**
 * Contract that is used by users to create FarmingRewards contracts.
 * It stores each farm as it's created, as well as the current owner of each farm.
 * It also contains various uitlity functions for use by Elk.
 */
contract ElkV2FarmFactory is IElkV2FarmFactory, FaasFactory {
    using SafeERC20 for IERC20;

    constructor(address _feeToken) FaasFactory(_feeToken) {}

    /**
     * @notice Main function in the contract. Creates a new FarmingRewards contract, stores the farm address by creator and the given LP token, and also stores the creator of the contract by the new farm address.  This is where the fee is taken from the user.
     * @dev each user is only able to create one FarmingRewards contract per LP token.
     * @param _lpTokenAddress The address of the LP token contract.
     * @param _rewardTokenAddresses The addresses of the reward tokens to be distributed.
     * @param _rewardsDuration The duration of the rewards period.
     * @param _depositFeeBps The deposit fee in basis points.
     * @param _withdrawalFeesBps The withdrawal fees in basis points.
     * @param _withdrawalFeeSchedule The schedule for the withdrawal fees.
     */
    function createNewRewards(
        address _lpTokenAddress,
        address[] memory _rewardTokenAddresses,
        uint256 _rewardsDuration,
        uint16 _depositFeeBps,
        uint16[] memory _withdrawalFeesBps,
        uint32[] memory _withdrawalFeeSchedule
    ) external override {
        if (faasContract[msg.sender][_lpTokenAddress] != address(0)) revert FaasContractExists();

        bytes memory abiCode = abi.encode(
            _lpTokenAddress,
            _rewardTokenAddresses,
            _rewardsDuration,
            _depositFeeBps,
            _withdrawalFeesBps,
            _withdrawalFeeSchedule
        );

        bytes32 salt = keccak256(abi.encodePacked(_lpTokenAddress, msg.sender));

        address faasContractAddress = ElkV2FarmFactoryHelper.createContract(abiCode, salt, faasContractManager);

        takeFeeAndAddContract(faasContractAddress, _lpTokenAddress);
    }
}
