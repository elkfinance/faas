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

pragma solidity =0.6.6;

import { FixedPoint } from "@elkdex/avax-exchange-contracts/contracts/elk-lib/libraries/FixedPoint.sol";
import { SafeMath } from "@elkdex/avax-exchange-contracts/contracts/elk-periphery/libraries/SafeMath.sol";
import { ElkLibrary } from "@elkdex/avax-exchange-contracts/contracts/elk-periphery/libraries/ElkLibrary.sol";
import {
    ElkOracleLibrary
} from "@elkdex/avax-exchange-contracts/contracts/elk-periphery/libraries/UniswapV2OracleLibrary.sol";

/**
 * @title SlidingWindowOracle
 * @notice provides moving price averages in the past `windowSize` with a precision of `windowSize / granularity`
 * @dev this is a singleton oracle. only needs to be deployed once per desired parameters.
 * @dev differs from the simple oracle which must be deployed once per pair.
 */
contract ElkDexOracle {
    using FixedPoint for *;
    using SafeMath for uint;

    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    /* ========== STATE VARIABLES ========== */

    /// @notice the wrapped native currency on this chain
    address public immutable weth;

    /// @notice the ElkDex factory
    address public immutable factory;

    /// @notice the desired amount of time over which the moving average should be computed, e.g. 24 hours
    uint public immutable windowSize;

    /**
     * @notice the number of observations stored for each pair,
     * @dev i.e. how many price observations are stored for the window.
     * as granularity increases from 1, more frequent updates are needed, but moving averages become more precise.
     * averages are computed over intervals with sizes in the range:
     *   [windowSize - (windowSize / granularity) * 2, windowSize]
     * e.g. if the window size is 24 hours, and the granularity is 24, the oracle will return the average price for
     *   the period:
     *   [now - [22 hours, 24 hours], now]
     */
    uint8 public immutable granularity;

    // this is redundant with granularity and windowSize, but stored for gas savings & informational purposes.
    uint public immutable periodSize;

    // mapping from pair address to a list of price observations of that pair
    mapping(address => Observation[]) public pairObservations;

    /**
     * @param _weth the address of the WETH contract
     * @param _factory the address of the ElkFactory contract
     * @param _windowSize the size of the time window over which the moving average is computed
     * @param _granularity the number of observations to store for each pair
     */
    constructor(address _weth, address _factory, uint _windowSize, uint8 _granularity) public {
        require(_weth != address(0) && _factory != address(0), "ElkDexOracle: ZERO_ADDRESS");
        require(_granularity > 1, "ElkDexOracle: GRANULARITY");
        require(
            (periodSize = _windowSize / _granularity) * _granularity == _windowSize,
            "ElkDexOracle: WINDOW_NOT_EVENLY_DIVISIBLE"
        );
        weth = _weth;
        factory = _factory;
        windowSize = _windowSize;
        granularity = _granularity;
    }

    /**
     * @notice returns the current price of the token in terms of the WETH token
     * @return index of the observation corresponding to the given timestamp
     */
    function observationIndexOf(uint _timestamp) public view returns (uint8 index) {
        uint epochPeriod = _timestamp / periodSize;
        return uint8(epochPeriod % granularity);
    }

    /**
     * @notice returns the current price of the token in terms of the WETH token
     * @param _pair the address of the token pair to compute the price of
     * @return firstObservation the observation from the oldest epoch (at the beginning of the window) relative to the current time
     */
    function getFirstObservationInWindow(address _pair) private view returns (Observation storage firstObservation) {
        uint8 observationIndex = observationIndexOf(block.timestamp);
        // no overflow issue. if observationIndex + 1 overflows, result is still zero.
        uint8 firstObservationIndex = (observationIndex + 1) % granularity;
        firstObservation = pairObservations[_pair][firstObservationIndex];
    }

    /**
     * @notice update the cumulative price for the observation at the current timestamp. each observation is updated at most once per epoch period.
     * @param _tokenA the address of the first token in the pair
     * @param _tokenB the address of the second token in the pair
     */
    function update(address _tokenA, address _tokenB) public {
        // Do nothing if both tokens are weth of the chain. Still want to require the tokens to be different for
        // the remaining logic.
        if (_tokenA == weth && _tokenB == weth) {
            return;
        }

        require(_tokenA != _tokenB, "ElkDexOracle: IDENTICAL_ADDRESSES");

        address pair = ElkLibrary.pairFor(factory, _tokenA, _tokenB);

        /// @dev populate the array with empty observations (first call only)
        for (uint i = pairObservations[pair].length; i < granularity; i++) {
            pairObservations[pair].push();
        }

        /// @dev get the observation for the current period
        uint8 observationIndex = observationIndexOf(block.timestamp);
        Observation storage observation = pairObservations[pair][observationIndex];

        /// @dev we only want to commit updates once per period (i.e. windowSize / granularity)
        uint timeElapsed = block.timestamp - observation.timestamp;
        if (timeElapsed > periodSize) {
            (uint price0Cumulative, uint price1Cumulative, ) = ElkOracleLibrary.currentCumulativePrices(pair);
            observation.timestamp = block.timestamp;
            observation.price0Cumulative = price0Cumulative;
            observation.price1Cumulative = price1Cumulative;
        }
    }

    /**
     * @notice returns the current price of the token in terms of the WETH token
     * @param _token the address of the token to compute the price of
     */
    function updateWeth(address _token) external {
        update(_token, weth);
    }

    /**
     * @notice given the cumulative prices of the start and end of a period, and the length of the period, compute the average price in terms of how much amount out is received for the amount in.
     * @param _priceCumulativeStart the cumulative price at the beginning of the period
     * @param _priceCumulativeEnd the cumulative price at the end of the period
     * @param _timeElapsed the length of the period over which the cumulative prices span
     * @param _amountIn the amount of token in to compute the output amount of token out
     */
    function computeAmountOut(
        uint _priceCumulativeStart,
        uint _priceCumulativeEnd,
        uint _timeElapsed,
        uint _amountIn
    ) private pure returns (uint amountOut) {
        // overflow is desired.
        FixedPoint.uq112x112 memory priceAverage = FixedPoint.uq112x112(
            uint224((_priceCumulativeEnd - _priceCumulativeStart) / _timeElapsed)
        );
        amountOut = priceAverage.mul(_amountIn).decode144();
    }

    /**
     * @notice returns the amount out corresponding to the amount in for a given token using the moving average over the time range [now - [windowSize, windowSize - periodSize * 2], now]
     * @dev update must have been called for the bucket corresponding to timestamp `now - windowSize`
     * @param _tokenIn the address of the token to swap from
     * @param _amountIn the amount of token to swap from
     * @param _tokenOut the address of the token to swap to
     * @return amountOut the amount of token to swap to
     */
    function consult(address _tokenIn, uint _amountIn, address _tokenOut) public view returns (uint amountOut) {
        if (_tokenIn == _tokenOut) {
            return _amountIn;
        }

        address pair = ElkLibrary.pairFor(factory, _tokenIn, _tokenOut);
        Observation storage firstObservation = getFirstObservationInWindow(pair);

        uint timeElapsed = block.timestamp - firstObservation.timestamp;
        require(timeElapsed <= windowSize, "ElkDexOracle: MISSING_HISTORICAL_OBSERVATION");

        /// @dev should never happen.
        require(timeElapsed >= windowSize - periodSize * 2, "ElkDexOracle: UNEXPECTED_TIME_ELAPSED");

        (uint price0Cumulative, uint price1Cumulative, ) = ElkOracleLibrary.currentCumulativePrices(pair);
        (address token0, ) = ElkLibrary.sortTokens(_tokenIn, _tokenOut);

        if (token0 == _tokenIn) {
            return computeAmountOut(firstObservation.price0Cumulative, price0Cumulative, timeElapsed, _amountIn);
        } else {
            return computeAmountOut(firstObservation.price1Cumulative, price1Cumulative, timeElapsed, _amountIn);
        }
    }

    /**
     * @notice calls consult for the WETH token
     * @param _tokenIn the address of the token to swap from
     * @param _amountIn the amount of token to swap from
     * @return amountOut the amount of WETH to swap to
     */
    function consultWeth(address _tokenIn, uint _amountIn) external view returns (uint amountOut) {
        return consult(_tokenIn, _amountIn, weth);
    }
}
