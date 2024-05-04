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
import { IFaasFactory } from "./interfaces/IFaasFactory.sol";
import { IStakingRewards } from "./interfaces/IStakingRewards.sol";

/**
 * Contract that is used by users to create FarmingRewards contracts.
 * It stores each farm as it's created, as well as the current owner of each farm.
 * It also contains various utility functions for use by Elk.
 */
contract FaasFactory is IFaasFactory, Ownable {
    using SafeERC20 for IERC20;

    error FaasContractExists();
    error NotEnoughBalance();
    error NotEnoughAllowance();
    error InvalidFee();
    error NoManagerAddress();
    error NotFaasContract();
    error NotFaasContractOwner();

    /* ========== STATE VARIABLES ========== */

    /// @notice get list of faasContracts associated with address
    mapping(address => mapping(address => address)) public faasContract;

    /// @notice check if given address is a faasContract
    mapping(address => bool) public isFaasContract;

    /// @notice all faasContracts associated with contract;
    address[] public allFaasContracts;

    /// @notice get address of faasContract owner
    mapping(address => address) public faasOwner;

    /// @notice address of faasContract manager
    address public faasContractManager;

    /// @notice ELK token
    address public feeTokenAddress;

    /// @notice fee in feeToken.
    uint256 public fee = 1000 ether;

    /// @notice maximum allowed fee.
    uint256 public maxFee = 100000 ether;

    constructor(address _feeTokenAddress) {
        feeTokenAddress = _feeTokenAddress;
    }

    function takeFeeAndAddContract(address faasContractAddress, address stakingTokenAddress) public {
        _payFee();

        isFaasContract[faasContractAddress] = true;
        faasContract[msg.sender][stakingTokenAddress] = faasContractAddress;
        faasOwner[faasContractAddress] = msg.sender;
        allFaasContracts.push(faasContractAddress);

        emit ContractCreated(faasContractAddress);
    }

    function allFaasContractsLength() external view override returns (uint) {
        return allFaasContracts.length;
    }

    function setManager(address _managerAddress) external override onlyOwner {
        if (_managerAddress == address(0)) revert NoManagerAddress();
        faasContractManager = _managerAddress;
        emit ManagerSet(_managerAddress);
    }

    function _payFee() private {
        if (IERC20(feeTokenAddress).balanceOf(msg.sender) < fee) revert NotEnoughBalance();
        if (IERC20(feeTokenAddress).allowance(msg.sender, address(this)) < fee) revert NotEnoughAllowance();
        IERC20(feeTokenAddress).safeTransferFrom(msg.sender, address(this), fee);
        emit FeePaid(msg.sender, fee);
    }

    function setFee(uint256 _newFee) external onlyOwner {
        if (_newFee >= maxFee) revert InvalidFee();
        fee = _newFee;
        emit FeeSet(_newFee);
    }

    function recoverFees() external onlyOwner {
        uint256 balance = IERC20(feeTokenAddress).balanceOf(address(this));
        IERC20(feeTokenAddress).safeTransfer(msg.sender, balance);
        emit FeesRecovered(balance);
    }

    /**
     * @notice Override ownership of a farm, only used by Elk.
     * @param _farmAddress The address of the farm to be changed.
     */
    function overrideOwnership(address _farmAddress) external onlyOwner {
        _transferFaasContractOwnership(_farmAddress, msg.sender);
    }

    function transferFaasContractOwnership(address _faasContractAddress, address _newOwner) external {
        if (!isFaasContract[_faasContractAddress]) revert NotFaasContract();
        if (faasOwner[_faasContractAddress] != msg.sender) revert NotFaasContractOwner();
        _transferFaasContractOwnership(_faasContractAddress, _newOwner);
    }

    function _transferFaasContractOwnership(address _faasContractAddress, address _newOwner) private {
        address creatorAddress = faasOwner[_faasContractAddress];
        address stakingTokenAddress = IStakingRewards(_faasContractAddress).stakingTokenAddress();

        faasContract[creatorAddress][stakingTokenAddress] = address(0);
        faasContract[_newOwner][stakingTokenAddress] = _faasContractAddress;
        faasOwner[_faasContractAddress] = _newOwner;
    }
}
