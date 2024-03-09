//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TestERC20 is ERC20 {
    uint8 public dec;
    uint constant _initial_supply = 100000000 * (10 ** 18);

    constructor(string memory _name, string memory _symbol, uint8 _dec) ERC20(_name, _symbol) {
        dec = _dec;
        _mint(msg.sender, _initial_supply);
    }

    function decimals() public view override returns (uint8) {
        return dec;
    }
}
