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

interface IFaasManager {
    event FaasFactorySet(address indexed factoryAddress);
    event MinDelayBeforeStopSet(uint256 delay);
    event RewardsReceived(address indexed farmAddress);

    function setFaasFactory(address _factoryAddress) external;

    function setMinDelayBeforeStop(uint256 _delay) external;

    function startEmission(address _faasContractAddress, uint256[] memory _rewards, uint256 _duration) external;

    function stopEmission(address _faasContractAddress) external;

    function recoverERC20(
        address _faasContractAddress,
        address _tokenAddress,
        uint256 _amount,
        bool _fromVault
    ) external;

    function recoverERC721(
        address _faasContractAddress,
        address _tokenAddress,
        uint256 _tokenId,
        bool _fromVault
    ) external;

    function recoverLeftoverReward(address _faasContractAddress, address _tokenAddress) external;

    function addRewardToken(address _faasContractAddress, address _tokenAddress) external;

    function multiClaim(address[] memory _faasContractAddresses) external;
}
