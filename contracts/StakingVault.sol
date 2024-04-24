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

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IStakingVault } from "./interfaces/IStakingVault.sol";

/**
 * @title Staking Vault Vault Contract
 * @dev Abstract contract for implementing staking vault.
 * It includes basic functionality for staking, unstaking, and recovering tokens.
 */
abstract contract StakingVault is IStakingVault, ReentrancyGuard {
    using SafeERC20 for IERC20;

    error InvalidStakingControllerAddress();
    error InvalidStakingTokenAddress();
    error CannotRecoverStakingToken();
    error ContractDoesNotOwnToken();
    error NotStakingController();
    error NotWhitelisted();

    /* ========== STATE VARIABLES ========== */

    /// @notice Address of the staking controller.
    address public immutable stakingControllerAddress;

    /// @notice Address of the token used for staking.
    address public immutable override stakingTokenAddress;

    /// @notice Indicates if whitelisting is enabled for this staking vault.
    bool public whitelisting;

    /// @notice Mapping to keep track of whitelisted addresses.
    mapping(address => bool) public whitelist;

    /* ========== CONSTRUCTOR ========== */

    /**
     * @dev Initializes the contract with staking controller address, staking token address, and whitelisting option.
     * @param _stakingControllerAddress Address of the staking controller.
     * @param _stakingTokenAddress Address of the token used for staking.
     * @param _whitelisting Boolean indicating if whitelisting is enabled.
     */
    constructor(address _stakingControllerAddress, address _stakingTokenAddress, bool _whitelisting) {
        if (_stakingControllerAddress == address(0)) revert InvalidStakingControllerAddress();
        if (_stakingTokenAddress == address(0)) revert InvalidStakingTokenAddress();
        stakingControllerAddress = _stakingControllerAddress;
        stakingTokenAddress = _stakingTokenAddress;
        whitelisting = _whitelisting;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    /**
     * @dev Stakes tokens on behalf of an address.
     * @param _from Address of the staker.
     * @param _units Amount of tokens to stake.
     */
    function stake(address _from, uint256 _units) external virtual override nonReentrant onlyStakingController {
        _units = _beforeStake(_from, _units);
        emit Staked(_from, _units);
    }

    /**
     * @dev Unstakes previously staked tokens.
     * @param _to Address where unstaked tokens should be sent.
     * @param _units Amount of tokens to unstake.
     */
    function unstake(address _to, uint256 _units) external virtual override nonReentrant onlyStakingController {
        _units = _beforeUnstake(_to, _units);
        emit Unstaked(_to, _units);
    }
    
    /**
     * @dev Unstakes all previously staked tokens.
     * @param _to Address where unstaked tokens should be sent.
     */
    function unstakeAll(address _to) external virtual;

    /**
     * @dev Enables or disables whitelisting.
     * @param _enabled Boolean indicating whether whitelisting is enabled.
     */
    function setWhitelisting(bool _enabled) external onlyStakingController {
        bool oldValue = whitelisting;
        whitelisting = _enabled;
        if (oldValue != _enabled) {
            emit WhitelistingSet(_enabled);
        }
    }
    /**
     * @dev Adds or removes an address from the whitelist.
     * @param _account Address to be whitelisted or dewhitelisted.
     * @param _whitelisted Boolean indicating whether to whitelist or dewhitelist the address.
     */
    function setWhitelist(address _account, bool _whitelisted) external onlyStakingController {
        bool oldValue = whitelist[_account];
        whitelist[_account] = _whitelisted;
        if (oldValue != _whitelisted && _whitelisted) {
            emit Whitelisted(_account);
        } else if (oldValue != _whitelisted && !_whitelisted) {
            emit Dewhitelisted(_account);
        }
    }

    /**
     * @dev Recovers ERC20 tokens sent to the contract by mistake.
     * @param _tokenAddress Address of the ERC20 token to recover.
     * @param _recipient Address to send the recovered tokens to.
     * @param _amount Amount of tokens to withdraw.
     */
    function recoverERC20(
        address _tokenAddress,
        address _recipient,
        uint256 _amount
    ) external nonReentrant onlyStakingController {
        if (_tokenAddress == stakingTokenAddress) revert CannotRecoverStakingToken();

        IERC20(_tokenAddress).safeTransfer(_recipient, _amount);
        emit RecoveredERC20(_tokenAddress, _recipient, _amount);
    }

    /**
     * @dev Recovers an ERC721 token held in the contract.
     * @param _tokenAddress Address of the token to recover.
     * @param _recipient Address to send the recovered token to.
     * @param _tokenId Token ID to recover.
     */
    function recoverERC721(
        address _tokenAddress,
        address _recipient,
        uint256 _tokenId
    ) external nonReentrant onlyStakingController {
        if (_tokenAddress == stakingTokenAddress) revert CannotRecoverStakingToken();
        if (IERC721(_tokenAddress).ownerOf(_tokenId) != address(this)) revert ContractDoesNotOwnToken();

        IERC721(_tokenAddress).safeTransferFrom(address(this), _recipient, _tokenId);
        emit RecoveredERC721(_tokenAddress, _recipient, _tokenId);
    }

    /* ========== MODIFIERS ========== */

    /// @dev Modifier to restrict access to the staking controller
    modifier onlyStakingController() {
        if (msg.sender != stakingControllerAddress) revert NotStakingController();
        _;
    }

    /// @dev Modifier to restrict access to whitelisted addresses if whitelisting is enabled
    modifier onlyWhitelisted() {
        if (whitelisting && !whitelist[msg.sender]) revert NotWhitelisted();
        _;
    }

    /* ========== HOOKS ========== */

    /**
     * @dev Internal hook called before staking (in the stake() function).
     * @ param _account staker address
     * @param _units amount being staken
     * @return amount to stake (may be changed by the hook)
     */
    function _beforeStake(address /*_account*/, uint256 _units) internal virtual onlyWhitelisted returns (uint256) {
        return _units;
    }

    /**
     * @dev Internal hook called before unstaking (in the unstake() function).
     * @ param _account unstaker address
     * @param _units amount being unstaked
     * @return amount to unstake (may be changed by the hook)
     */
    function _beforeUnstake(address /*_account*/, uint256 _units) internal virtual returns (uint256) {
        return _units;
    }
}
