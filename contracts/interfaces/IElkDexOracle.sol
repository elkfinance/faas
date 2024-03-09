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

interface IElkDexOracle {
    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    function weth() external view returns (address);

    function factory() external view returns (address);

    function windowSize() external view returns (uint);

    function granularity() external view returns (uint8);

    function periodSize() external view returns (uint);

    function pairObservations(address _pair) external view returns (Observation[] memory);

    function observationIndexOf(uint _timestamp) external view returns (uint);

    function update(address _tokenA, address _tokenB) external;

    function updateWeth(address _token) external;

    function consult(address _tokenIn, uint _amountIn, address _tokenOut) external view returns (uint);

    function consultWeth(address _tokenIn, uint _amountIn) external view returns (uint);
}
