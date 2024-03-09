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
import { IStakingStrategy } from "./IStakingStrategy.sol";

/**
 * @title IStakingRewards
 * @dev This interface defines the methods for a staking rewards contract.
 * Users can stake tokens to earn rewards over time.
 */
interface IStakingRewards {
    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Returns the staking strategy.
     */
    function stakingStrategy() external returns (IStakingStrategy);

    /**
     * @dev Returns the address of the staking token.
     * @return address The staking token contract address.
     */
    function stakingTokenAddress() external view returns (address);

    /**
     * @dev Returns the total supply of the staked token.
     */
    function totalSupply() external returns (uint256);

    /**
     * @dev Returns the balance of the given account.
     * @param _account The address of the account.
     */
    function balances(address _account) external returns (uint256);

    /**
     * @dev Returns the period finish time.
     */
    function periodFinish() external view returns (uint256);

    /**
     * @dev Returns the rewards duration.
     */
    function rewardsDuration() external view returns (uint256);

    /**
     * @dev Returns the last update time.
     */
    function lastUpdateTime() external view returns (uint256);

    /**
     * @dev Returns the reward tokens.
     * @param _index The index of the reward token.
     */
    function rewardTokens(uint256 _index) external view returns (IERC20);

    /**
     * @dev Checks if a reward token address exists.
     * @param _rewardAddress The address of the reward token.
     */
    function rewardTokenAddresses(address _rewardAddress) external view returns (bool);

    /**
     * @dev Returns the index of a reward token.
     * @param _tokenAddress The address of the reward token.
     */
    function rewardTokenIndex(address _tokenAddress) external view returns (int8);

    /**
     * @dev Returns the reward rate for a given reward token.
     * @param _rewardAddress The address of the reward token.
     */
    function rewardRates(address _rewardAddress) external view returns (uint256);

    /**
     * @dev Returns the stored reward per token for a given reward token.
     * @param _rewardAddress The address of the reward token.
     */
    function rewardPerTokenStored(address _rewardAddress) external view returns (uint256);

    /**
     * @dev Returns the paid reward per token for a given user and reward token.
     * @param _walletAddress The address of the user.
     * @param _tokenAddress The address of the reward token.
     */
    function userRewardPerTokenPaid(address _walletAddress, address _tokenAddress) external view returns (uint256);

    /**
     * @dev Returns the rewards for a given user and reward token.
     * @param _walletAddress The address of the user.
     * @param _tokenAddress The address of the reward token.
     */
    function rewards(address _walletAddress, address _tokenAddress) external view returns (uint256);

    /**
     * @dev Returns the last time a reward was applicable.
     */
    function lastTimeRewardApplicable() external view returns (uint256);

    /**
     * @dev Returns the reward per token for a given reward token.
     * @param _tokenAddress The address of the reward token.
     */
    function rewardPerToken(address _tokenAddress) external view returns (uint256);

    /**
     * @dev Returns the earned rewards for a given user and reward token.
     * @param _tokenAddress The address of the reward token.
     * @param _account The address of the user.
     */
    function earned(address _tokenAddress, address _account) external view returns (uint256);

    /**
     * @dev Checks if the contract is emitting rewards.
     */
    function emitting() external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @dev Stakes a certain amount of tokens.
     * @param _amount The amount of tokens to stake.
     */
    function stake(uint256 _amount) external;

    /**
     * @dev Unstakes a certain amount of tokens.
     * @param _amount The amount of tokens to unstake.
     */
    function unstake(uint256 _amount) external;

    /**
     * @dev Exits the staking contract.
     */
    function exit() external;

    /**
     * @dev Gets the reward for a given user and reward token.
     * @param _tokenAddress The address of the reward token.
     */
    function getReward(address _tokenAddress, address _recipient) external;

    /**
     * @dev Gets all the rewards for a given user.
     * @param _recipient The address of the user.
     */
    function getRewards(address _recipient) external;

    /**
     * @dev Starts the emission of rewards. Must send reward before calling this!
     * @param _rewards The amounts of the rewards.
     * @param _duration The duration of the rewards emission in seconds.
     */
    function startEmission(uint256[] memory _rewards, uint256 _duration) external;

    /**
     * @dev Stops the emission of rewards.
     * @param _refundAddress The address where the remaining rewards will be sent.
     */
    function stopEmission(address _refundAddress) external;

    /**
     * @dev Recovers any leftover reward.
     * @param _tokenAddress The address of the reward token.
     * @param _recipient The address where the leftover rewards will be sent.
     */
    function recoverLeftoverReward(address _tokenAddress, address _recipient) external;

    /**
     * @dev Adds a new reward token.
     * @param _tokenAddress The address of the reward token to add.
     */
    function addRewardToken(address _tokenAddress) external;

    function setWhitelisting(bool _enabled) external;

    function setWhitelist(address _account, bool _whitelisted) external;

    /**
     * @dev Allows the recovery of accidentally sent ERC20 tokens.
     * @param _tokenAddress The address of the ERC20 token to recover.
     * @param _recipient The address to which the recovered tokens will be sent.
     * @param _amount The amount of tokens to recover.
     * @param _fromStrategy Whether to recover tokens from the strategy contract (true) or this contract (false).
     */
    function recoverERC20(address _tokenAddress, address _recipient, uint256 _amount, bool _fromStrategy) external;

    /**
     * @dev Allows the recovery of accidentally sent ERC721 tokens.
     * @param _tokenAddress The address of the ERC721 token to recover.
     * @param _recipient The address to which the recovered token will be sent.
     * @param _tokenId The ID of the token to recover.
     * @param _fromStrategy Whether to recover tokens from the strategy contract (true) or this contract (false).
     */
    function recoverERC721(address _tokenAddress, address _recipient, uint256 _tokenId, bool _fromStrategy) external;

    /* ========== EVENTS ========== */

    /**
     * @dev Emitted when ERC20 tokens are recovered from the contract.
     * @param token The address of the ERC20 token.
     * @param recipient The address of the recipient to whom the tokens are returned.
     * @param amount The amount of tokens recovered.
     */
    event RecoveredERC20(address indexed token, address indexed recipient, uint256 amount);

    /**
     * @dev Emitted when ERC721 tokens are recovered from the contract.
     * @param token The address of the ERC721 token.
     * @param recipient The address of the recipient to whom the token is returned.
     * @param tokenId The ID of the token recovered.
     */
    event RecoveredERC721(address indexed token, address indexed recipient, uint256 tokenId);

    /**
     * @dev Emitted when a reward is added.
     * @param reward The amount of the reward.
     */
    event RewardAdded(uint256 reward);

    /**
     * @dev Emitted when a user stakes tokens.
     * @param user The address of the user.
     * @param amount The amount of tokens staked.
     */
    event Staked(address indexed user, uint256 amount);

    /**
     * @dev Emitted when a user withdraws their staked tokens.
     * @param user The address of the user.
     * @param amount The amount of tokens withdrawn.
     */
    event Withdrawn(address indexed user, uint256 amount);

    /**
     * @dev Emitted when a reward is paid to a user.
     * @param _token The address of the reward token.
     * @param _account The address of the user.
     * @param _reward The amount of the reward.
     */
    event RewardPaid(address indexed _token, address indexed _account, uint256 _reward);

    /**
     * @dev Emitted when a leftover reward is recovered.
     * @param _recipient The address where the leftover rewards were sent.
     * @param _amount The amount of the leftover rewards.
     */
    event LeftoverRewardRecovered(address indexed _recipient, uint256 _amount);

    /**
     * @dev Emitted when rewards emission is started.
     * @param _rewards The amounts of the rewards.
     * @param _duration The duration of the rewards emission in seconds.
     */
    event RewardsEmissionStarted(uint256[] _rewards, uint256 _duration);

    /**
     * @dev Emitted when rewards emission ends.
     */
    event RewardsEmissionEnded();
}
