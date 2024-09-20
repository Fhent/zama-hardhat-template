// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZamaWEERC20 is ERC20 {
    uint8 public constant encDecimals = 6;

    mapping(address => euint64) internal _encBalances;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100 * 10 ** uint(decimals()));
    }

    function wrap(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount);

        _burn(msg.sender, amount);

        uint64 convertedAmount = _convertDecimalForWrap(amount);
        euint64 shieldedAmount = TFHE.asEuint64(convertedAmount);

        _encBalances[msg.sender] = TFHE.add(_encBalances[msg.sender], shieldedAmount);
    }

    // Converts the amount for deposit.
    function _convertDecimalForWrap(uint256 amount) internal view returns (uint64) {
        return uint64(amount / 10 ** (decimals() - encDecimals));
    }

    // Converts the amount for withdrawal.
    function _convertDecimalForUnwrap(uint64 amount) internal view returns (uint256) {
        return uint256(amount) * 10 ** (decimals() - encDecimals);
    }
}
