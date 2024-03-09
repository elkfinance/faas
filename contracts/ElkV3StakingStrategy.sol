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

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ERC721StakingStrategy } from "./ERC721StakingStrategy.sol";

interface INonfungiblePositionManager {
    function positions(
        uint256 tokenId
    )
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
}

contract ElkV3StakingStrategy is ERC721StakingStrategy {
    using SafeERC20 for IERC20;

    error InvalidAddress();
    error NoLiquidity();

    INonfungiblePositionManager public immutable positionManager;

    // Mapping to store liquidity of each NFT position by tokenId
    mapping(uint256 => uint256) public positionBalances;

    constructor(
        address _nftPositionManagerAddress,
        address _stakingControllerAddress,
        address _stakingTokenAddress,
        bool _whitelisting
    ) ERC721StakingStrategy(_stakingControllerAddress, _stakingTokenAddress, _whitelisting) {
        if (_nftPositionManagerAddress == address(0)) revert InvalidAddress();
        positionManager = INonfungiblePositionManager(_nftPositionManagerAddress);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balances(address _account) external view override returns (uint256) {
        uint256 balance = 0;
        for (uint i = 0; i < ownedTokens[_account].length; ++i) {
            balance += positionBalances[ownedTokens[_account][i]];
        }
        return balance;
    }

    function stake(address _from, uint256 _tokenId) public override nonReentrant onlyStakingController {
        super.stake(_from, _tokenId);

        uint256 balance = _getLiquidity(_tokenId);
        positionBalances[_tokenId] = balance;
        _totalSupply += balance - 1; // Compensate for the +1 done in the parent
    }

    /*function stake(address _from, uint256 _tokenId) external override nonReentrant onlyStakingController {
        _tokenId = _beforeStake(_from, _tokenId);
        if (ERC721(stakingTokenAddress).ownerOf(_tokenId) != _from) revert NotTokenOwner();

        ERC721(stakingTokenAddress).safeTransferFrom(_from, address(this), _tokenId);
        _addTokenToOwnerEnumeration(_from, _tokenId);

        uint256 balance = _getLiquidity(_tokenId);
        positionBalances[_tokenId] = balance;
        _totalSupply += balance;

        emit Staked(_from, _tokenId);
    }*/

    function unstake(address _to, uint256 _tokenId) public override nonReentrant onlyStakingController {
        super.unstake(_to, _tokenId);

        _totalSupply -= positionBalances[_tokenId] + 1; // Compensate for the -1 done in the parent
        positionBalances[_tokenId] = 0;
    }

    /*function unstake(address _to, uint256 _tokenId) public override nonReentrant onlyStakingController {
        _tokenId = _beforeUnstake(_to, _tokenId);
        if (tokenOwner[_tokenId] != _to) revert NotTokenOwner();

        _removeTokenFromOwnerEnumeration(_to, _tokenId);
        ERC721(stakingTokenAddress).safeTransferFrom(address(this), _to, _tokenId);

        _totalSupply -= positionBalances[_tokenId];
        positionBalances[_tokenId] = 0;

        emit Unstaked(_to, _tokenId);
    }*/

    // Function to add a position and update its liquidity
    function _getLiquidity(uint256 tokenId) private view returns (uint256) {
        (, , , , , , , uint128 liquidity, , , , ) = positionManager.positions(tokenId);
        if (liquidity == 0) revert NoLiquidity();
        return liquidity;
    }
}
