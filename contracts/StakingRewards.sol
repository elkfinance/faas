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

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IStakingRewards } from "./interfaces/IStakingRewards.sol";
import { IStakingVault } from "./interfaces/IStakingVault.sol";

/**
 * @title StakingRewards
 * @dev This contract allows users to stake ERC20 tokens and earn rewards.
 * It supports multiple reward tokens. The staking and reward tokens are
 * specified during contract deployment. The contract owner can start and stop
 * reward emission, recover ERC20 and ERC721 tokens, and add new reward tokens.
 * Users can stake, unstake, and claim rewards. They can also exit, which is
 * equivalent to unstaking all tokens and claiming all rewards.
 */
contract StakingRewards is IStakingRewards, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    error InvalidStakingVaultAddress();
    error NoRewardTokens();
    error NonPositiveDuration();
    error RewardArraysLengthMismatch();
    error RewardAmountsTooHigh(address tokenAddress);
    error StakingSupplyNotEmpty();
    error SenderNotOwnerOrRecipient();
    error UnknownRewardToken(address tokenAddress);
    error TooManyRewardTokens();
    error InvalidRewardToken(address tokenAddress);
    error CannotRecoverRewardToken(address tokenAddress);
    error RewardsEmitting();
    error RewardsNotEmitting();

    uint256 public constant MAX_REWARD_TOKENS = 20;

    /* ========== STATE VARIABLES ========== */

    IStakingVault public immutable override stakingVault;

    /// @notice List of reward token interfaces
    IERC20[] public rewardTokens;

    /// @notice Reward token addresses (maps every reward token address to true, others to false)
    mapping(address tokenAddress => bool isRewardToken) public rewardTokenAddresses;

    /// @notice Timestamp when rewards stop emitting
    uint256 public periodFinish;

    /// @notice Duration for reward emission
    uint256 public rewardsDuration;

    /// @notice Last time the rewards were updated
    uint256 public lastUpdateTime;

    /// @notice Reward token rates (maps every reward token to an emission rate,
    //i.e., how many tokens emitted per second)
    mapping(address token => uint256 emissionRate) public rewardRates;

    /// @notice How many tokens are emitted per staked token
    mapping(address token => uint256 emissionRate) public rewardPerTokenStored;

    /// @notice How many reward tokens were paid per user (token address => wallet address => amount)
    mapping(address token => mapping(address walletAddress => uint256 amount)) public userRewardPerTokenPaid;

    /// @notice Accumulator of reward tokens per user (token address => wallet address => amount)
    mapping(address token => mapping(address walletAddress => uint256 amount)) public rewards;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Constructor.
     * @param _stakingVaultAddress Address of the staking vault contract.
     * @param _rewardTokenAddresses Array of reward token addresses.
     * @param _rewardsDuration Duration of reward emission in seconds.
     */
    constructor(address _stakingVaultAddress, address[] memory _rewardTokenAddresses, uint256 _rewardsDuration) {
        if (_stakingVaultAddress == address(0)) revert InvalidStakingVaultAddress();
        stakingVault = IStakingVault(_stakingVaultAddress);
        if (_rewardTokenAddresses.length == 0) revert NoRewardTokens();
        // Update reward data structures
        for (uint256 i = 0; i < _rewardTokenAddresses.length; ++i) {
            address tokenAddress = _rewardTokenAddresses[i];
            _addRewardToken(tokenAddress);
        }
        rewardsDuration = _rewardsDuration;
    }

    /**
     * @dev Returns the address of the staking token.
     * @return address The staking token contract address.
     */
    function stakingTokenAddress() public view returns (address) {
        return stakingVault.stakingTokenAddress();
    }

    /**
     * @dev Stake tokens.
     * Note: the contract must have sufficient allowance for the staking token.
     * @param _amount amount to stake
     */
    function stake(uint256 _amount) public nonReentrant whenEmitting updateRewards(msg.sender) {
        stakingVault.stake(msg.sender, _amount);
    }

    /**
     * @dev Unstake previously staked tokens.
     * @param _amount amount to unstake
     */
    function unstake(uint256 _amount) public nonReentrant updateRewards(msg.sender) {
        stakingVault.unstake(msg.sender, _amount);
    }

    /**
     * @dev Returns the total supply of the staked token.
     */
    function totalSupply() external view returns (uint256) {
        return stakingVault.totalSupply();
    }

    /**
     * @dev Returns the balance of the given account.
     * @param _account The address of the account.
     */
    function balances(address _account) external view returns (uint256) {
        return stakingVault.balances(_account);
    }

    /**
     * @dev Exit the farm, i.e., unstake the entire token balance of the calling account
     */
    function exit() external nonReentrant updateRewards(msg.sender) {
        _beforeExit(msg.sender);
        stakingVault.unstakeAll(msg.sender);
    }

    /* ========== VIEWS ========== */

    /**
     * @notice Return the last time rewards are applicable (the lowest of the
       current timestamp and the rewards expiry timestamp).
     * @return timestamp
     */
    function lastTimeRewardApplicable() public view returns (uint256) {
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    /**
     * @notice Return the reward per staked token for a given reward token address.
     * @param _tokenAddress reward token address
     * @return amount of reward per staked token
     */
    function rewardPerToken(address _tokenAddress) public view returns (uint256) {
        if (stakingVault.totalSupply() == 0) {
            return rewardPerTokenStored[_tokenAddress];
        }
        return
            rewardPerTokenStored[_tokenAddress] +
            ((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRates[_tokenAddress] *
                1e18) /
            stakingVault.totalSupply();
    }

    /**
     * @notice Return the total reward earned by a user for a given reward token address.
     * @param _tokenAddress reward token address
     * @param _account user wallet address
     * @return amount earned
     */
    function earned(address _tokenAddress, address _account) public view returns (uint256) {
        return
            (stakingVault.balances(_account) *
                (rewardPerToken(_tokenAddress) - userRewardPerTokenPaid[_tokenAddress][_account])) /
            1e18 +
            rewards[_tokenAddress][_account];
    }

    /**
     * @dev Returns true if the contract is currently emitting rewards.
     */
    function emitting() public view returns (bool) {
        return block.timestamp <= periodFinish;
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @dev claim the specified token reward for a staker
     * @param _tokenAddress the address of the reward token
     * @param _recipient the address of the staker that should receive the reward
     * @ return amount of reward received
     */
    function getReward(address _tokenAddress, address _recipient) public nonReentrant updateRewards(_recipient) {
        return _getReward(_tokenAddress, _recipient);
    }

    /**
     * @dev claim rewards for all the reward tokens for the staker
     * @param _recipient address of the recipient to receive the rewards
     */
    function getRewards(address _recipient) public nonReentrant updateRewards(_recipient) {
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            _getReward(address(rewardTokens[i]), _recipient);
        }
    }

    /**
     * @dev Start the emission of rewards to stakers. The owner must send reward
       tokens to the contract before calling this function.
     * Note: Can only be called by owner when the contract is not emitting
       rewards.
     * @param _rewards array of rewards amounts for each reward token
     * @param _duration duration in seconds for which rewards will be emitted
     */
    function startEmission(
        uint256[] memory _rewards,
        uint256 _duration
    ) public virtual nonReentrant onlyOwner whenNotEmitting updateRewards(address(0)) {
        if (_duration == 0) revert NonPositiveDuration();
        if (_rewards.length != rewardTokens.length) revert RewardArraysLengthMismatch();

        _beforeStartEmission(_rewards, _duration);

        rewardsDuration = _duration;

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            IERC20 token = rewardTokens[i];
            address tokenAddress = address(token);
            rewardRates[tokenAddress] = _rewards[i] / rewardsDuration;

            // Ensure the provided reward amount is not more than the balance in the contract.
            // This keeps the reward rate in the right range, preventing overflows due to
            // very high values of rewardRate in the earned and rewardsPerToken functions;
            // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
            uint256 balance = rewardTokens[i].balanceOf(address(this));
            if (rewardRates[tokenAddress] > balance / rewardsDuration) {
                revert RewardAmountsTooHigh(tokenAddress);
            }
        }

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        emit RewardsEmissionStarted(_rewards, _duration);
    }

    /**
     * @dev stop the reward emission process and transfer the remaining reward tokens to a specified address
     * Note: can only be called by owner when the contract is currently emitting rewards
     * @param _refundAddress the address to receive the remaining reward tokens
     */
    function stopEmission(address _refundAddress) external nonReentrant onlyOwner whenEmitting {
        _beforeStopEmission(_refundAddress);
        uint256 remaining = 0;
        if (periodFinish > block.timestamp) {
            remaining = periodFinish - block.timestamp;
        }

        periodFinish = block.timestamp;

        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            IERC20 token = rewardTokens[i];
            address tokenAddress = address(token);
            uint256 refund = rewardRates[tokenAddress] * remaining;
            if (refund > 0) {
                token.safeTransfer(_refundAddress, refund);
            }
        }

        emit RewardsEmissionEnded();
    }

    /**
     * @dev Enables or disables whitelisting.
     * @param _enabled Boolean indicating whether whitelisting is enabled.
     */
    function setWhitelisting(bool _enabled) external {
        stakingVault.setWhitelisting(_enabled);
    }

    /**
     * @dev Adds or removes an address from the whitelist.
     * @param _account Address to be whitelisted or dewhitelisted.
     * @param _whitelisted Boolean indicating whether to whitelist or dewhitelist the address.
     */
    function setWhitelist(address _account, bool _whitelisted) external {
        stakingVault.setWhitelist(_account, _whitelisted);
    }

    /**
     * @dev Recover ERC20 tokens.
     * @param _tokenAddress Address of the token.
     * @param _recipient Address of the recipient.
     * @param _amount Amount of tokens to recover.
     * @param _fromVault Whether to recover from the staking vault contract.
     */
    function recoverERC20(
        address _tokenAddress,
        address _recipient,
        uint256 _amount,
        bool _fromVault
    ) external onlyOwner {
        if (_fromVault) {
            stakingVault.recoverERC20(_tokenAddress, _recipient, _amount);
        } else {
            _beforeRecoverERC20(_tokenAddress, _recipient, _amount);
            IERC20(_tokenAddress).transfer(_recipient, _amount);
            emit RecoveredERC20(_tokenAddress, _recipient, _amount);
        }
    }

    /**
     * @dev Recover ERC721 tokens.
     * @param _tokenAddress Address of the token.
     * @param _recipient Address of the recipient.
     * @param _tokenId ID of the token to recover.
     * @param _fromVault Whether to recover from the staking vault contract.
     */
    function recoverERC721(
        address _tokenAddress,
        address _recipient,
        uint256 _tokenId,
        bool _fromVault
    ) external onlyOwner {
        if (_fromVault) {
            stakingVault.recoverERC721(_tokenAddress, _recipient, _tokenId);
        } else {
            IERC721(_tokenAddress).safeTransferFrom(address(this), _recipient, _tokenId);
            emit RecoveredERC721(_tokenAddress, _recipient, _tokenId);
        }
    }

    /**
     * @dev recover leftover reward tokens and transfer them to a specified recipient
     * Note: can only be called by owner when the contract is not emitting rewards
     * @param _tokenAddress address of the reward token to be recovered
     * @param _recipient address to receive the recovered reward tokens
     */
    function recoverLeftoverReward(address _tokenAddress, address _recipient) external onlyOwner whenNotEmitting {
        if (stakingVault.totalSupply() > 0) revert StakingSupplyNotEmpty();
        if (rewardTokenAddresses[_tokenAddress]) {
            _beforeRecoverLeftoverReward(_tokenAddress, _recipient);
            IERC20 token = IERC20(_tokenAddress);
            uint256 amount = token.balanceOf(address(this));
            if (amount > 0) {
                token.safeTransfer(_recipient, amount);
            }
            emit LeftoverRewardRecovered(_recipient, amount);
        }
    }

    /**
     * @dev add a reward token to the contract
     * Note: can only be called by owner when the contract is not emitting rewards
     * @param _tokenAddress address of the new reward token
     */
    function addRewardToken(address _tokenAddress) external onlyOwner whenNotEmitting {
        _addRewardToken(_tokenAddress);
    }

    /**
     * @dev Return the array index of the provided token address (if applicable)
     * @param _tokenAddress address of the LP token
     * @return the array index for _tokenAddress or -1 if it is not a reward token
     */
    function rewardTokenIndex(address _tokenAddress) public view returns (int8) {
        if (rewardTokenAddresses[_tokenAddress]) {
            for (uint256 i = 0; i < rewardTokens.length; ++i) {
                if (address(rewardTokens[i]) == _tokenAddress) {
                    return int8(int256(i));
                }
            }
        }
        return -1;
    }

    /* ========== PRIVATE FUNCTIONS ========== */

    /**
     * @dev Get the reward amount of a token for a specific recipient
     * @param _tokenAddress address of the token
     * @param _recipient address of the recipient
     */
    function _getReward(address _tokenAddress, address _recipient) private {
        if (msg.sender != owner() && msg.sender != _recipient) revert SenderNotOwnerOrRecipient();
        if (!rewardTokenAddresses[_tokenAddress]) revert UnknownRewardToken(_tokenAddress);
        uint256 reward = rewards[_tokenAddress][_recipient];
        if (reward > 0) {
            rewards[_tokenAddress][_recipient] = 0;
            IERC20(_tokenAddress).safeTransfer(_recipient, reward);
            emit RewardPaid(_tokenAddress, _recipient, reward);
        }
    }

    /**
     * @dev Add a token as a reward token
     * @param _tokenAddress address of the token to be added as a reward token
     */
    function _addRewardToken(address _tokenAddress) private {
        if (rewardTokens.length > MAX_REWARD_TOKENS) revert TooManyRewardTokens();
        if (_tokenAddress == address(0)) revert InvalidRewardToken(_tokenAddress);
        if (!rewardTokenAddresses[_tokenAddress]) {
            rewardTokens.push(IERC20(_tokenAddress));
            rewardTokenAddresses[_tokenAddress] = true;
        }
    }

    /* ========== HOOKS ========== */

    /**
     * @dev Internal hook called before exiting (in the exit() function).
     * Hook used here to claim all rewards for the account exiting
     * @param _account address exiting
     */
    function _beforeExit(address _account) internal virtual {
        // getRewards calls updateRewards so we don't need to call it explicitly again here
        getRewards(_account);
    }

    /**
     * @dev Internal hook called before exiting (in the exit() function).
     * Hook used here to claim all rewards for the account exiting
     * @param _account address exiting
     */
    function _beforeUpdateRewards(address _account) internal virtual {}

    /**
     * @dev Internal hook called before recovering ERC20 tokens.
     */
    function _beforeRecoverERC20(address _tokenAddress, address /*_recipient*/, uint256 /*_amount*/) internal virtual {
        if (rewardTokenAddresses[_tokenAddress]) revert CannotRecoverRewardToken(_tokenAddress);
    }

    /**
     * @dev Internal hook called before starting the emission process (in the
       startEmission() function).
     * @param _rewards array of rewards per token.
     * @param _duration emission duration.
     */
    function _beforeStartEmission(uint256[] memory _rewards, uint256 _duration) internal virtual {}

    /**
     * @dev Internal hook called before stopping the emission process (in the
       stopEmission() function).
     * @param _refundAddress address to refund the remaining reward to
     */
    function _beforeStopEmission(address _refundAddress) internal virtual {}

    /**
     * @dev Internal hook called before recovering leftover rewards (in the
       recoverLeftoverRewards() function).
     * @param _tokenAddress address of the token to recover
     * @param _recipient address to recover the leftover rewards to
     */
    function _beforeRecoverLeftoverReward(address _tokenAddress, address _recipient) internal virtual {}

    /* ========== MODIFIERS ========== */

    /**
     * @dev Modifier to update rewards of a given account.
     * @param _account account to update rewards for
     */
    modifier updateRewards(address _account) {
        _beforeUpdateRewards(_account);
        for (uint256 i = 0; i < rewardTokens.length; ++i) {
            address tokenAddress = address(rewardTokens[i]);
            rewardPerTokenStored[tokenAddress] = rewardPerToken(tokenAddress);
        }
        lastUpdateTime = lastTimeRewardApplicable();
        if (_account != address(0)) {
            for (uint256 i = 0; i < rewardTokens.length; ++i) {
                address tokenAddress = address(rewardTokens[i]);
                rewards[tokenAddress][_account] = earned(tokenAddress, _account);
                userRewardPerTokenPaid[tokenAddress][_account] = rewardPerTokenStored[tokenAddress];
            }
        }
        _;
    }

    /**
     * @dev Modifier to check if rewards are emitting.
     */
    modifier whenEmitting() {
        if (!emitting()) revert RewardsNotEmitting();
        _;
    }

    /**
     * @dev Modifier to check if rewards are not emitting.
     */
    modifier whenNotEmitting() {
        if (emitting()) revert RewardsEmitting();
        _;
    }
}
