// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZamaWEERC20 is ERC20, GatewayCaller {
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

    function unwrap(einput encryptedAmount, bytes calldata inputProof) public {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);
        ebool canUnwrap = TFHE.le(amount, _encBalances[msg.sender]);
        euint64 canUnwrapAmount = TFHE.select(canUnwrap, amount, TFHE.asEuint64(0));

        eaddress to = TFHE.asEaddress(msg.sender);

        uint256[] memory cts = new uint256[](2);
        cts[0] = Gateway.toUint256(to);
        cts[1] = Gateway.toUint256(canUnwrapAmount);
        Gateway.requestDecryption(cts, this.callbackUnwrap.selector, 0, block.timestamp + 10000, false);
    }

    function callbackUnwrap(uint256, address to, uint64 amount) public onlyGateway returns (bool) {
        euint64 encAmount = TFHE.asEuint64(amount);

        ebool canUnwrap = TFHE.le(encAmount, _encBalances[to]);
        euint64 canUnwrapAmount = TFHE.select(canUnwrap, encAmount, TFHE.asEuint64(0));

        _encBalances[to] = TFHE.sub(_encBalances[to], canUnwrapAmount);
        TFHE.allow(_encBalances[to], address(this));
        TFHE.allow(_encBalances[to], to);
        _mint(to, _convertDecimalForUnwrap(amount));

        return true;
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
