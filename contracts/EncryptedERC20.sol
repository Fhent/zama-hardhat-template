// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ZamaWEERC20 is ERC20, GatewayCaller {
    uint8 public constant encDecimals = 6;
    address public constant gateway = 0xc8c9303Cd7F337fab769686B593B87DC3403E0ce;

    mapping(address => euint64) internal _encBalances;
    mapping(address => mapping(address => euint64)) internal _allowances;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100 * 10 ** uint(decimals()));
    }
    function getEncryptedBalance(address account) public view returns (euint64) {
        return _encBalances[account];
    }

    function getAllowance(address owner, address spender) public view returns (euint64) {
        return _allowances[owner][spender];
    }

    function wrap(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount);

        _burn(msg.sender, amount);

        uint64 convertedAmount = _convertDecimalForWrap(amount);
        euint64 shieldedAmount = TFHE.asEuint64(convertedAmount);

        _encBalances[msg.sender] = TFHE.add(_encBalances[msg.sender], shieldedAmount);
        TFHE.allow(_encBalances[msg.sender], address(this));
        TFHE.allow(_encBalances[msg.sender], msg.sender);
        TFHE.allow(_encBalances[msg.sender], gateway);
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

    function approveEncrypted(
        address spender,
        einput encryptedAmount,
        bytes calldata inputProof
    ) public returns (bool) {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);

        _allowances[msg.sender][spender] = amount;
        TFHE.allow(_allowances[msg.sender][spender], address(this));
        TFHE.allow(_allowances[msg.sender][spender], msg.sender);
        TFHE.allow(_allowances[msg.sender][spender], spender);

        return true;
    }

    function allowBalance(address allowed) public {
        TFHE.allow(_encBalances[msg.sender], allowed);
    }

    function allowAllowance(address spender, address allowed) public {
        TFHE.allow(_allowances[msg.sender][spender], allowed);
    }

    function transferEncrypted(address to, einput encryptedAmount, bytes calldata inputProof) public {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);
        require(TFHE.isSenderAllowed(amount));

        ebool canTransfer = TFHE.le(amount, _encBalances[msg.sender]);
        euint64 canTransferAmount = TFHE.select(canTransfer, amount, TFHE.asEuint64(0));

        _transferEncrypted(msg.sender, to, canTransferAmount, canTransfer);
    }

    function transferFromEncrypted(address from, address to, einput encryptedAmount, bytes calldata inputProof) public {
        euint64 amount = TFHE.asEuint64(encryptedAmount, inputProof);
        require(TFHE.isSenderAllowed(amount));

        ebool canTransfer = TFHE.le(amount, _encBalances[from]);
        euint64 canTransferAmount = TFHE.select(canTransfer, amount, TFHE.asEuint64(0));

        ebool isTransferable = _updateAllowance(from, msg.sender, canTransferAmount);

        _transferEncrypted(from, to, canTransferAmount, isTransferable);
    }

    function _updateAllowance(address owner, address spender, euint64 amount) internal returns (ebool) {
        euint64 currentAllowance = _allowances[owner][spender];
        ebool allowedTransfer = TFHE.le(amount, currentAllowance);
        ebool canTransfer = TFHE.le(amount, _encBalances[owner]);
        ebool isTransferable = TFHE.and(canTransfer, allowedTransfer);
        _allowances[owner][spender] = TFHE.select(isTransferable, TFHE.sub(currentAllowance, amount), currentAllowance);
        TFHE.allow(_allowances[owner][spender], address(this));
        TFHE.allow(_allowances[owner][spender], owner);
        TFHE.allow(_allowances[owner][spender], spender);

        return isTransferable;
    }

    function _transferEncrypted(address from, address to, euint64 amount, ebool isTransferable) internal {
        euint64 transferValue = TFHE.select(isTransferable, amount, TFHE.asEuint64(0));
        euint64 newBalanceTo = TFHE.add(_encBalances[to], transferValue);
        _encBalances[to] = newBalanceTo;
        TFHE.allow(newBalanceTo, address(this));
        TFHE.allow(newBalanceTo, to);
        euint64 newBalanceFrom = TFHE.sub(_encBalances[from], transferValue);
        _encBalances[from] = newBalanceFrom;
        TFHE.allow(newBalanceFrom, address(this));
        TFHE.allow(newBalanceFrom, from);
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
