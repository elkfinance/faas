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
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IFaasManager } from "./interfaces/IFaasManager.sol";
import { IFaasFactory } from "./interfaces/IFaasFactory.sol";
import { IStakingRewards } from "./interfaces/IStakingRewards.sol";

/**
 * This contract serves as the main point of contact between any FarmingRewards creators and their farm contract.
 * It contains any function in FarmingRewards that would normally be restricted to the owner and allows access to its functionality as long as the caller is the known owner in the ElkFarmFactory contract.
 */
abstract contract FaasManager is IFaasManager, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error UnknownFarm();
    error NotOwner();
    error TooShortDelay();
    error TooManyFarms();

    /* ========== CONSTANTS ========== */

    uint256 public constant MAX_MULTICLAIM_CONTRACTS = 30;

    /* ========== STATE VARIABLES ========== */

    /// @notice interface to the farm factory
    IFaasFactory public faasFactory;

    /// @notice last timestamp the farm was started
    mapping(address => uint256) public lastStarted;

    /// @notice minimum time before a started farm can be stopped
    uint256 public minDelayBeforeStop;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @param _factoryAddress The address of the ElkFarmFactory contract.
     * @param _minDelayBeforeStop The minimum time before a farm can be stopped after having been started.
     */
    constructor(address _factoryAddress, uint256 _minDelayBeforeStop) {
        setFaasFactory(_factoryAddress);
        setMinDelayBeforeStop(_minDelayBeforeStop);
    }

    /**
     * @notice Utility function for use by Elk in order to change the ElkFarmFactory if needed.
     * @param _factoryAddress The address of the ElkFarmFactory contract.
     */
    function setFaasFactory(address _factoryAddress) public onlyOwner {
        if (_factoryAddress == address(0)) revert ZeroAddress();
        faasFactory = IFaasFactory(_factoryAddress);
        emit FaasFactorySet(_factoryAddress);
    }

    /**
     * @notice Utility function for use by Elk in order to change the minimum delay before a farm can be stopped if needed.
     * @param _delay The minimum delay in seconds.
     */
    function setMinDelayBeforeStop(uint256 _delay) public onlyOwner {
        minDelayBeforeStop = _delay;
        emit MinDelayBeforeStopSet(_delay);
    }

    /* ========== MODIFIERS ========== */

    /**
     * @notice The check used by each function that interacts with the FarmingRewards contract. It reads from the owners stored in ElkFarmFactory to determine if the caller is the known owner of the FarmingRewards contract it is trying to interact with.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     */
    modifier checkOwnership(address _faasContractAddress) {
        if (!faasFactory.isFaasContract(_faasContractAddress)) revert UnknownFarm();
        if (
            faasFactory.faasContract(msg.sender, IStakingRewards(_faasContractAddress).stakingTokenAddress()) !=
            _faasContractAddress
        ) revert NotOwner();
        _;
    }

    /* ========== Farm Functions ========== */

    /**
     * @notice Same utility as startEmissionWithCoverage, but coverage does not need to be supplied.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     * @param _rewards The amount of rewards per rewards token.
     * @param _duration The duration of the farm emissions.
     */
    function startEmission(
        address _faasContractAddress,
        uint256[] memory _rewards,
        uint256 _duration
    ) external checkOwnership(_faasContractAddress) {
        IStakingRewards faasContract = IStakingRewards(_faasContractAddress);
        // Transfer rewards
        for (uint i = 0; i < _rewards.length; ++i) {
            IERC20(faasContract.rewardTokens(i)).safeTransferFrom(msg.sender, _faasContractAddress, _rewards[i]);
        }
        // Start emissions
        faasContract.startEmission(_rewards, _duration);
        lastStarted[_faasContractAddress] = block.timestamp;
    }

    /**
     * @notice Stops the given farm's emissions and refunds any leftover reward token(s) to the msg.sender.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     */
    function stopEmission(address _faasContractAddress) external checkOwnership(_faasContractAddress) {
        if (lastStarted[_faasContractAddress] + minDelayBeforeStop > block.timestamp) revert TooShortDelay();
        IStakingRewards(_faasContractAddress).stopEmission(msg.sender);
    }

    /**
     * @notice Recovers an ERC20 token to the owners wallet. The token cannot be the staking token or any of the rewards tokens for the farm.
     * @dev Ensures any unnecessary tokens are not lost if sent to the farm contract.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     * @param _tokenAddress The address of the token to recover.
     * @param _amount The amount of the token to recover.
     */
    function recoverERC20(
        address _faasContractAddress,
        address _tokenAddress,
        uint256 _amount,
        bool _fromStrategy
    ) external checkOwnership(_faasContractAddress) {
        IStakingRewards(_faasContractAddress).recoverERC20(_tokenAddress, msg.sender, _amount, _fromStrategy);
    }

    /**
     * @notice Recovers an ERC721 token to the owners wallet. The token cannot be the staking token or any of the rewards tokens for the farm.
     * @dev Ensures any unnecessary tokens are not lost if sent to the farm contract.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     * @param _tokenAddress The address of the token to recover.
     * @param _tokenId The ID of the token to recover.
     */
    function recoverERC721(
        address _faasContractAddress,
        address _tokenAddress,
        uint256 _tokenId,
        bool _fromStrategy
    ) external checkOwnership(_faasContractAddress) {
        IStakingRewards(_faasContractAddress).recoverERC721(_tokenAddress, msg.sender, _tokenId, _fromStrategy);
    }

    /**
     * @notice Recovers the given leftover reward token to the msg.sender. Cannot be called while the farm is active or if there are any LP tokens staked in the contract.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     * @param _tokenAddress The address of the token to recover.
     */
    function recoverLeftoverReward(
        address _faasContractAddress,
        address _tokenAddress
    ) external checkOwnership(_faasContractAddress) {
        IStakingRewards(_faasContractAddress).recoverLeftoverReward(_tokenAddress, msg.sender);
    }

    /**
     * @notice Utility function that allows the farm owner to add a new reward token to the contract. Cannot be called while the farm is active.
     * @param _faasContractAddress The address of the FarmingRewards contract.
     * @param _tokenAddress The address of the token to add.
     */
    function addRewardToken(
        address _faasContractAddress,
        address _tokenAddress
    ) external checkOwnership(_faasContractAddress) {
        IStakingRewards(_faasContractAddress).addRewardToken(_tokenAddress);
    }

    /* ========== FARMER FUNCTIONS ========== */

    /**
     * @notice Function for farm users to claim rewards from multiple farms at once.
     * @param _faasContractAddresses The addresses of the FarmingRewards contracts.
     */
    function multiClaim(address[] memory _faasContractAddresses) external {
        if (_faasContractAddresses.length >= MAX_MULTICLAIM_CONTRACTS) revert TooManyFarms();

        for (uint i = 0; i < _faasContractAddresses.length; i++) {
            address faasContractAddress = address(_faasContractAddresses[i]);
            IStakingRewards(faasContractAddress).getRewards(msg.sender);
            emit RewardsReceived(_faasContractAddresses[i]);
        }
    }
}
