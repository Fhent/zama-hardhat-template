// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/lib/TFHE.sol";

interface IZamaWEERC20 {
    function transferEncrypted(address recipient, einput encryptedAmount, bytes calldata inputProof) external;

    function transferFromEncrypted(
        address sender,
        address recipient,
        einput encryptedAmount,
        bytes calldata inputProof
    ) external;
}

contract ZamaBridge {
    IZamaWEERC20 public weerc20;

    address public constant gateway = 0xc8c9303Cd7F337fab769686B593B87DC3403E0ce;
    uint64 public nextIntentId = 0;

    event Packet(eaddress to, euint64 amount, address relayer);
    event TestPacket(uint256 num);

    constructor(address _tokenAddress) {
        weerc20 = IZamaWEERC20(_tokenAddress);
    }

    function bridgeWEERC20(
        einput _encryptedTo,
        einput _encryptedAmount,
        bytes calldata _inputProof,
        address _relayerAddress
    ) public {
        weerc20.transferFromEncrypted(msg.sender, address(this), _encryptedAmount, _inputProof);

        eaddress to = TFHE.asEaddress(_encryptedTo, _inputProof);
        euint64 amount = TFHE.asEuint64(_encryptedAmount, _inputProof);

        TFHE.allow(to, _relayerAddress);
        TFHE.allow(amount, _relayerAddress);

        emit Packet(to, amount, _relayerAddress);
    }

    function testEmit() public {
        emit TestPacket(123);
    }
}
