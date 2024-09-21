// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

interface IZamaWEERC20 {
    function transferEncrypted(address recipient, einput encryptedAmount, bytes calldata inputProof) external;

    function transferFromEncrypted(
        address sender,
        address recipient,
        einput encryptedAmount,
        bytes calldata inputProof
    ) external;
}

contract ZamaBridge is GatewayCaller {
    IZamaWEERC20 public weerc20;

    struct Intent {
        address from;
        address to;
        euint64 encryptedAmount;
    }

    address public constant gateway = 0xc8c9303Cd7F337fab769686B593B87DC3403E0ce;
    uint64 public nextIntentId = 0;

    mapping(uint64 => Intent) public intents;

    event Packet(eaddress to, euint64 amount, address relayer);
    event TestPacket(uint256 num);
    event IntentProcessed(address indexed from, address indexed to, euint64 encryptedAmount);

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

    function onRecvIntent(address _to, einput _encryptedAmount, bytes calldata inputProof) external {
        weerc20.transferFromEncrypted(msg.sender, _to, _encryptedAmount, inputProof);

        euint64 eamount = TFHE.asEuint64(_encryptedAmount, inputProof);

        nextIntentId++;
        Intent memory intent = Intent({ from: msg.sender, to: _to, encryptedAmount: eamount });
        intents[nextIntentId] = intent;

        emit IntentProcessed(msg.sender, _to, eamount);
    }

    function testEmit() public {
        emit TestPacket(123);
    }
}
