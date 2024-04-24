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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IElkDexOracle } from "./interfaces/IElkDexOracle.sol";
import { IElkPair } from "./interfaces/IElkPair.sol";
import { IStakingRewards } from "./interfaces/IStakingRewards.sol";
import { IStakingRewardsWithILP } from "./interfaces/IStakingRewardsWithILP.sol";
import { StakingRewards } from "./StakingRewards.sol";
import { IElkV2FarmingRewards } from "./interfaces/IElkV2FarmingRewards.sol";

/**
 * Contract implementing simple ERC20 token staking functionality with staking rewards, impermanent loss coverage, and staking/unstaking fees.
 */
contract StakingRewardsWithILP is IStakingRewardsWithILP, StakingRewards {
    using SafeERC20 for IERC20;

    error Unauthorized();
    error InvalidCoverageToken();
    error InvalidCoverageParameters();
    error InvalidCoverageAmount();
    error InvalidCoverageVestingDuration();
    error InvalidLPTokenFactory();
    error InvalidCoverageTokenAddress();
    error InvalidCoveragePerTokenStored();
    error InvalidCoverageVestingDurationForRewards();
    error InvalidCoverageRate();
    error InvalidTotalSupply();
    error InvalidCoverageTokenBalance();

    /* ========== STATE VARIABLES ========== */

    /// @notice Interface to the ElkDex pricing oracle on this blockchain
    IElkDexOracle public immutable oracle;

    /// @notice Interface to the LP token that is staked in this farm
    IElkPair public immutable lpToken;

    /// @notice Address of the coverage token
    address public coverageTokenAddress;

    /// @notice Total amount of coverage available (worst case max amount)
    uint256 public coverageAmount;

    /// @notice Time until a farmed position is fully covered against impermanent loss (100%)
    uint256 public coverageVestingDuration;

    /// @notice Rate of coverage vesting
    uint256 public coverageRate;

    /// @notice Coverage amount per token staked in the farm
    uint256 public coveragePerTokenStored;

    /// @notice How much coverage was paid per user (wallet address => amount)
    mapping(address => uint256) public userCoveragePerTokenPaid;

    /// @notice Accumulator of coverage tokens per user (wallet address => amount)
    mapping(address => uint256) public coverage;

    /// @notice Last farming position for a given user (wallet address => position)
    mapping(address => Position) public lastStakedPosition;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _oracleAddress address of the price oracle
     * @param _stakingVaultAddress address of the staking vault contract (must be configured with an ELP token)
     * @param _coverageTokenAddress address of the token that the coverage is paid in
     * @param _coverageAmount total amount of coverage
     * @param _coverageVestingDuration time it takes to vest 100% of the coverage (min. 1 day)
     * @param _rewardTokenAddresses addresses the reward tokens (must be ERC20)
     * @param _rewardsDuration reward emission duration
     */
    constructor(
        address _oracleAddress,
        address _stakingVaultAddress,
        address _coverageTokenAddress,
        uint256 _coverageAmount,
        uint32 _coverageVestingDuration,
        address[] memory _rewardTokenAddresses,
        uint256 _rewardsDuration
    ) StakingRewards(_stakingVaultAddress, _rewardTokenAddresses, _rewardsDuration) {
        oracle = IElkDexOracle(_oracleAddress);
        lpToken = IElkPair(stakingVault.stakingTokenAddress());

        if (_coverageTokenAddress != address(0)) {
            if (!(lpToken.token0() == _coverageTokenAddress || lpToken.token1() == _coverageTokenAddress))
                revert InvalidCoverageTokenAddress();
            if (!(_coverageVestingDuration >= 24 * 3600 && _coverageVestingDuration <= rewardsDuration))
                revert InvalidCoverageVestingDuration();
        }
        if (!(lpToken.factory() == oracle.factory())) revert InvalidLPTokenFactory();

        coverageTokenAddress = _coverageTokenAddress;
        coverageAmount = _coverageAmount;
        coverageVestingDuration = _coverageVestingDuration;
    }

    /**
     * @dev Return the coverage per staked token (in coverage token amounts)
     * @return amount of coverage per staked token
     */
    function coveragePerToken() public view returns (uint256) {
        return
            stakingVault.totalSupply() == 0
                ? coveragePerTokenStored
                : coveragePerTokenStored +
                    (((lastTimeRewardApplicable() - lastUpdateTime) *
                        coverageRate *
                        1e18) / stakingVault.totalSupply());
    }

    /**
     * @dev Return the total coverage earned by a user.
     * @param _account user wallet address
     * @return coverage amount earned
     */
    function coverageEarned(address _account) public view returns (uint256) {
        if (coverageTokenAddress == address(0)) {
            return 0;
        }
        Position memory lastStake = lastStakedPosition[_account];
        uint256 hodlValue = lpValueWeth(lastStake);
        if (hodlValue == 0) {
            return coverage[_account];
        }
        uint256 outValue = lpValueWeth(position(stakingVault.balances(_account)));
        uint256 balance = stakingVault.balances(_account);
        uint256 cappedCoverage = (balance * (coveragePerToken() - userCoveragePerTokenPaid[_account])) / 1e18;
        uint256 vested = vestedCoverage(hodlValue, outValue, lastStake.blockTimestamp);
        return
            (vested > cappedCoverage ? cappedCoverage : vested) - (vested * outValue) / hodlValue + coverage[_account];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    
    /**
     * @dev claim the coverage for a staker
     * @param _recipient the address of the staker that should receive the coverage
     * @ return the amount of reward received
     */
    function getCoverage(address _recipient) public nonReentrant updateCoverage(_recipient) {
        if (!(msg.sender == owner() || msg.sender == _recipient)) revert Unauthorized();
        if (coverageTokenAddress == address(0)) revert InvalidCoverageToken();

        uint256 cov = coverage[_recipient];
        if (cov == 0) return;

        coverage[_recipient] = 0;
        IERC20(coverageTokenAddress).safeTransfer(_recipient, cov);
        emit CoveragePaid(_recipient, cov);
    }

    /**
     * @dev Set the coverage parameters if none were set in the constructor. Gives the option for farm owners to change coverage tokens.
     * Note: Can't change coverage token if coverage is already accumulated
     * @param _tokenAddress address of token to be used for coverage emissions
     * @param _coverageAmount total amount of coverage token to emit
     * @param _coverageVestingDuration vesting period in seconds that users need to have staked to claim coverage
     */
    function setCoverage(
        address _tokenAddress,
        uint256 _coverageAmount,
        uint32 _coverageVestingDuration
    ) external onlyOwner whenNotEmitting {
        if (coveragePerTokenStored != 0) revert InvalidCoveragePerTokenStored();
        if (
            !((lpToken.token0() == _tokenAddress || lpToken.token1() == _tokenAddress) &&
                (_coverageVestingDuration >= 24 * 3600) &&
                (_coverageVestingDuration <= rewardsDuration))
        ) revert InvalidCoverageParameters();
        coverageTokenAddress = _tokenAddress;
        coverageAmount = _coverageAmount;
        coverageVestingDuration = _coverageVestingDuration;
    }

    // Override startEmission() so it calls the expanded function that includes the coverage amount
    /**
     * @dev Start the emission of rewards to stakers with no coverage. The owner must send reward tokens to the contract before calling this function.
     * Note: Can only be called by owner when the contract is not emitting rewards.
     * @param _rewards array of rewards amounts for each reward token
     * @param _duration duration in seconds for which rewards will be emitted
     */
    function startEmission(
        uint256[] memory _rewards,
        uint256 _duration
    ) public override(IStakingRewards, StakingRewards) onlyOwner {
        return startEmission(_rewards, 0, _duration);
    }

    /**
     * @dev Start the emission of rewards to stakers. The owner must send reward and coverage tokens to the contract before calling this function.
     * Note: Can only be called by owner when the contract is not emitting rewards.
     * @param _rewards array of rewards amounts for each reward token
     * @param _coverage total amount of coverage provided to users (worst case max)
     * @param _duration duration in seconds for which rewards will be emitted (and coverage will be active)
     */
    function startEmission(
        uint256[] memory _rewards,
        uint256 _coverage,
        uint256 _duration
    ) public onlyOwner updateCoverage(address(0)) {
        super.startEmission(_rewards, _duration);
        if (!(coverageVestingDuration <= rewardsDuration)) revert InvalidCoverageVestingDurationForRewards(); // must check again

        coverageRate = _coverage / rewardsDuration; // rewardsDuration, not coverageVestingDuration which can be shorter!

        if (coverageTokenAddress != address(0) && _coverage > 0) {
            // Ensure the provided coverage amount is not more than the balance in the contract
            uint256 balance = IERC20(coverageTokenAddress).balanceOf(address(this));
            int8 tokenIndex = rewardTokenIndex(coverageTokenAddress);
            if (tokenIndex >= 0) {
                balance -= _rewards[uint256(int256(tokenIndex))];
            }
            if (!(coverageRate <= balance / rewardsDuration)) revert InvalidCoverageRate();
        }
    }

    /**
     * @dev recover leftover coverage tokens and transfer them to a specified recipient
     * Note: can only be called by owner when the contract is not emitting rewards
     * @param _recipient address to receive the recovered coverage tokens
     */
    function recoverLeftoverCoverage(address _recipient) public onlyOwner whenNotEmitting {
        if (!(stakingVault.totalSupply() == 0 && coverageTokenAddress != address(0))) revert InvalidTotalSupply();
        _beforeRecoverLeftoverCoverage(_recipient);
        IERC20 token = IERC20(coverageTokenAddress);
        uint256 amount = token.balanceOf(address(this));
        if (amount > 0) {
            token.safeTransfer(_recipient, amount);
            emit LeftoverCoverageRecovered(_recipient, amount);
        }
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Return the LP position for a given amount of LP token.
     * @param _amount the amount of LP token
     * @return the corresponding LP position (amount0, amount1, timestamp)
     */
    function position(uint256 _amount) private view returns (Position memory) {
        (uint112 reserve0, uint112 reserve1, uint32 timestamp) = lpToken.getReserves();
        uint256 totalAmount = lpToken.totalSupply();
        return
            Position(
                uint112((_amount * reserve0) / totalAmount),
                uint112((_amount * reserve1) / totalAmount),
                timestamp
            );
    }

    /**
     * @dev Return the value in WETH of the given LP position.
     * @param _position LP position
     * @return the value in WETH
     */
    function lpValueWeth(Position memory _position) private view returns (uint256) {
        return
            oracle.consultWeth(lpToken.token0(), _position.amount0) +
            oracle.consultWeth(lpToken.token1(), _position.amount1);
    }

    /**
     * @dev Return the vested coverage in coverage token amount for the given HODL and OUT values since the provided timestamp.
     * @param _hodlValue the value (in WETH) if the tokens making up the LP were kept unpaired
     * @param _outValue the value (in WETH) of the LP token position
     * @param _lastTimestamp the start timestamp (when the LP token position was created)
     * @return vested coverage in coverage token amount
     */
    function vestedCoverage(
        uint256 _hodlValue,
        uint256 _outValue,
        uint32 _lastTimestamp
    ) private view returns (uint256) {
        uint256 timeElapsed = block.timestamp - _lastTimestamp;
        uint256 wethCov = _hodlValue > _outValue ? _hodlValue - _outValue : 0;
        uint256 tokenCoverage = wethCov == 0 ? 0 : oracle.consult(oracle.weth(), wethCov, coverageTokenAddress);
        if (timeElapsed >= coverageVestingDuration) {
            return tokenCoverage;
        }
        return (tokenCoverage * timeElapsed) / coverageVestingDuration;
    }

    /* ========== HOOKS ========== */

    /**
     * @dev Override _beforeUpdateRewards() hook to ensure staking/unstaking updates the coverage
     */
    function _beforeUpdateRewards(address _account) internal virtual override updateCoverage(_account) {
        return super._beforeUpdateRewards(_account);
    }

    /**
     * @dev Override _beforeExit() hook to claim all coverage for the account exiting
     */
    function _beforeExit(address _account) internal virtual override {
        if (coverageTokenAddress != address(0)) {
            getCoverage(_account);
        }
        super._beforeExit(_account);
    }

    /**
     * @dev Override _beforeRecoverERC20() hook to prevent recovery of a coverage token
     */
    function _beforeRecoverERC20(address _tokenAddress, address _recipient, uint256 _amount) internal virtual override {
        require(_tokenAddress != coverageTokenAddress, "E16");
        super._beforeRecoverERC20(_tokenAddress, _recipient, _amount);
    }

    // New hooks

    /**
     * @dev Internal hook called before recovering leftover coverage (in the recoverLeftoverCoverage() function).
     * @param _recipient address to recover the leftover coverage to
     */
    function _beforeRecoverLeftoverCoverage(address _recipient) internal virtual {}

    /* ========== MODIFIERS ========== */

    /**
     * @dev Modifier to update the coverage of a given account.
     * @param _account account to update coverage for
     */
    modifier updateCoverage(address _account) {
        if (coverageTokenAddress != address(0)) {
            coveragePerTokenStored = coveragePerToken();
            lastUpdateTime = lastTimeRewardApplicable(); // it seems fine to redo this here
            oracle.update(lpToken.token0(), oracle.weth()); // update oracle for first token
            oracle.update(lpToken.token1(), oracle.weth()); // ditto for the second token
            if (_account != address(0)) {
                coverage[_account] = coverageEarned(_account);
                userCoveragePerTokenPaid[_account] = coveragePerTokenStored;
                lastStakedPosition[_account] = position(stakingVault.balances(_account)); // don't forget to reset the last position info
            }
        }
        _;
    }
}
