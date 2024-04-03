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
import { ERC721Holder } from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { StakingStrategy } from "./StakingStrategy.sol";

contract ERC721StakingStrategy is StakingStrategy, ERC721Holder {
    using SafeERC20 for IERC20;

    error NotTokenOwner();

    uint256 internal _totalSupply;

    // Mapping from token ID to owner address
    mapping(uint256 => address) public tokenOwner;

    // Mapping from owner to list of owned token IDs
    mapping(address => uint256[]) internal ownedTokens;

    // Mapping from token ID to index of the owner tokens list
    mapping(uint256 => uint256) internal ownedTokensIndex;

    constructor(
        address _stakingControllerAddress,
        address _stakingTokenAddress,
        bool _whitelisting
    ) StakingStrategy(_stakingControllerAddress, _stakingTokenAddress, _whitelisting) {}

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balances(address _account) external view virtual override returns (uint256) {
        return ownedTokens[_account].length;
    }

    function stake(address _from, uint256 _tokenId) public virtual override nonReentrant onlyStakingController {
        _tokenId = _beforeStake(_from, _tokenId);
        if (ERC721(stakingTokenAddress).ownerOf(_tokenId) != _from) revert NotTokenOwner();

        ERC721(stakingTokenAddress).safeTransferFrom(_from, address(this), _tokenId);
        _addTokenToOwnerEnumeration(_from, _tokenId);

        _totalSupply += 1;

        emit Staked(_from, _tokenId);
    }

    function unstake(address _to, uint256 _tokenId) public virtual override nonReentrant onlyStakingController {
        _tokenId = _beforeUnstake(_to, _tokenId);
        if (tokenOwner[_tokenId] != _to) revert NotTokenOwner();

        _removeTokenFromOwnerEnumeration(_to, _tokenId);
        ERC721(stakingTokenAddress).safeTransferFrom(address(this), _to, _tokenId);

        _totalSupply -= 1;

        emit Unstaked(_to, _tokenId);
    }

    /**
     * @dev Unstakes all previously staked tokens.
     * @param _to Address where unstaked tokens should be sent.
     */
    function unstakeAll(address _to) external override onlyStakingController {
        for (uint i = 0; i < ownedTokens[_to].length; ++i) {
            unstake(_to, ownedTokens[_to][i]);
        }
    }

    function _addTokenToOwnerEnumeration(address _to, uint256 _tokenId) internal {
        ownedTokensIndex[_tokenId] = ownedTokens[_to].length;
        tokenOwner[_tokenId] = _to;
        ownedTokens[_to].push(_tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address _from, uint256 _tokenId) internal {
        uint256 lastTokenIndex = ownedTokens[_from].length - 1;
        uint256 tokenIndex = ownedTokensIndex[_tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = ownedTokens[_from][lastTokenIndex];

            ownedTokens[_from][tokenIndex] = lastTokenId;
            ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        ownedTokens[_from].pop();
        delete tokenOwner[_tokenId];
        delete ownedTokensIndex[_tokenId];
    }
}
