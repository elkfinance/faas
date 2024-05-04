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

interface IFaasFactory {
    function faasContract(address, address) external view returns (address);

    function isFaasContract(address) external view returns (bool);

    function allFaasContracts(uint256 idx) external view returns (address);

    function faasOwner(address) external view returns (address);

    function faasContractManager() external view returns (address);

    function feeTokenAddress() external view returns (address);

    function fee() external view returns (uint256);

    function maxFee() external view returns (uint256);

    function allFaasContractsLength() external view returns (uint);

    function setManager(address _managerAddress) external;

    function setFee(uint256 _newFee) external;

    function recoverFees() external;

    function overrideOwnership(address _faasContractAddress) external;

    function transferFaasContractOwnership(address _faasContractAddress, address _newOwner) external;

    event ContractCreated(address indexed faasContract);
    event ManagerSet(address indexed manager);
    event FeeSet(uint256 fee);
    event FeesRecovered(uint256 balance);
    event FeePaid(address indexed from, uint256 amount);
}
