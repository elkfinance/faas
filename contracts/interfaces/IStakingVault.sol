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

/**
 * @title IStakingVault Interface
 * @dev This interface defines the basic functionality for a staking vault. It allows for staking and unstaking
 * of tokens, querying balances and total supply, and recovery of accidentally sent ERC20 and ERC721 tokens.
 */
interface IStakingVault {
    /* ========== VIEW FUNCTIONS ========== */

    /**
     * @dev Returns the address of the staking token.
     * @return address The staking token contract address.
     */
    function stakingTokenAddress() external view returns (address);

    /**
     * @dev Returns the total supply of staked tokens.
     * @return uint256 The total amount of tokens staked.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the staked token balance of a specific account.
     * @param _account The address of the account to query.
     * @return uint256 The amount of tokens staked by the account.
     */
    function balances(address _account) external view returns (uint256);

    /**
     * @dev Checks if the whitelisting feature is enabled.
     * @return bool Returns true if whitelisting is enabled, false otherwise.
     */
    function whitelisting() external view returns (bool);

    /* ========== MUTATIVE FUNCTIONS ========== */

    /**
     * @dev Allows an account to stake a specified amount of tokens.
     * @param _from The address from which the tokens will be staked.
     * @param _units The amount of tokens to stake.
     */
    function stake(address _from, uint256 _units) external;

    /**
     * @dev Allows an account to unstake a specified amount of tokens.
     * @param _to The address to which the unstaked tokens will be transferred.
     * @param _units The amount of tokens to unstake.
     */
    function unstake(address _to, uint256 _units) external;

    /**
     * @dev Allows an account to unstake a specified amount of tokens.
     * @param _to The address to which the unstaked tokens will be transferred.
     */
    function unstakeAll(address _to) external;

    function setWhitelisting(bool _enabled) external;

    /**
     * @dev Adds or removes an address from the whitelist.
     * @param _account Address to be whitelisted or dewhitelisted.
     * @param _whitelisted Boolean indicating whether to whitelist or dewhitelist the address.
     */
    function setWhitelist(address _account, bool _whitelisted) external;

    /**
     * @dev Allows the recovery of accidentally sent ERC20 tokens.
     * @param _tokenAddress The address of the ERC20 token to recover.
     * @param _recipient The address to which the recovered tokens will be sent.
     * @param _amount The amount of tokens to recover.
     */
    function recoverERC20(address _tokenAddress, address _recipient, uint256 _amount) external;

    /**
     * @dev Allows the recovery of accidentally sent ERC721 tokens.
     * @param _tokenAddress The address of the ERC721 token to recover.
     * @param _recipient The address to which the recovered token will be sent.
     * @param _tokenId The ID of the token to recover.
     */
    function recoverERC721(address _tokenAddress, address _recipient, uint256 _tokenId) external;

    /* ========== EVENTS ========== */

    /**
     * @dev Emitted when tokens are staked.
     * @param account The address of the account that staked tokens.
     * @param units The amount of tokens staked.
     */
    event Staked(address indexed account, uint256 units);

    /**
     * @dev Emitted when tokens are unstaked.
     * @param account The address of the account that unstaked tokens.
     * @param units The amount of tokens unstaked.
     */
    event Unstaked(address indexed account, uint256 units);

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
     * @dev Emitted when an account is added to the whitelist.
     * @param account The address of the account added to the whitelist.
     */
    event Whitelisted(address indexed account);

    /**
     * @dev Emitted when an account is removed from the whitelist.
     * @param account The address of the account removed from the whitelist.
     */
    event Dewhitelisted(address indexed account);

    event WhitelistingSet(bool indexed enabled);
}
