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

import { ElkV2FarmingRewardsWithILP } from "./ElkV2FarmingRewardsWithILP.sol";

/**
 * @title contains a helper function that creates new FarmingRewards contracts in the ElkFarmFactory
 * @notice this is a separate contract so that the FarmFactory contract is not too large
 */
library ElkV2FarmFactoryHelperWithILP {
    /**
     * @notice creates a new v2 farm contract and transfers ownership to the provided farm manager
     * @param _abi the abi of the v2 farm contract
     * @param _salt the salt used to create the contract
     * @param _farmManager the address of the farm manager
     */
    function createContract(bytes memory _abi, bytes32 _salt, address _farmManager) external returns (address addr) {
        bytes memory bytecode = abi.encodePacked(type(ElkV2FarmingRewardsWithILP).creationCode, _abi);

        assembly {
            addr := create2(0, add(bytecode, 0x20), mload(bytecode), _salt)
            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        ElkV2FarmingRewardsWithILP(addr).transferOwnership(_farmManager);
    }
}
