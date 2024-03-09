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

import { ElkSingleStakingRewards } from "./ElkSingleStakingRewards.sol";

/**
 * @title contains a helper function that creates new FarmingRewards contracts in the ElkFarmFactory
 * @notice this is a separate contract so that the FarmFactory contract is not too large
 */
library ElkSingleStakeFactoryHelper {
    /**
     * @notice creates a new single stake contract and transfers ownership to the provided farm manager
     * @param _abi the abi of the single stake contract
     * @param _salt the salt used to create the contract
     * @param _farmManager the address of the farm manager
     */
    function createContract(bytes memory _abi, bytes32 _salt, address _farmManager) external returns (address addr) {
        bytes memory bytecode = abi.encodePacked(type(ElkSingleStakingRewards).creationCode, _abi);

        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        ElkSingleStakingRewards(addr).transferOwnership(_farmManager);
    }
}
