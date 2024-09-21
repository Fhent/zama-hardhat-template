/* eslint-disable  @typescript-eslint/no-explicit-any */
import { createInstance as createFhevmInstance } from "fhevmjs";
import hre from "hardhat";

import { abi } from "../artifacts/contracts/EncryptedERC20.sol/ZamaWEERC20.json";

const { ethers } = hre;

const contractAddress = "0xC3797a5a8eD831A2C4AA4fDf9E22cb42332b7F36";

const wallets: { [key: string]: string } = {
  1: process.env.PRIVATE_KEY_DEPLOYER as string,
};

async function TokenContractCall(key: number, cfunc: string, cargs: any[] = [], cvalue: string = "0") {
  const args = cargs;
  const wallet = new ethers.Wallet(wallets[key], new ethers.JsonRpcProvider("https://devnet.zama.ai"));
  const instance = await createFhevmInstance({
    networkUrl: "https://devnet.zama.ai",
    gatewayUrl: "https://gateway.devnet.zama.ai",
  });

  if (cfunc === "balanceOf") {
    if (args[0] === undefined) {
      args[0] = wallet.address;
    }
  } else if (cfunc === "unwrap") {
    const input = instance.createEncryptedInput(contractAddress, wallet.address);
    input.add64(args[0]);
    const encryptedInput = input.encrypt();
    args[0] = encryptedInput.handles[0];
    args[1] = encryptedInput.inputProof;
  } else if (cfunc === "approveEncrypted") {
    const input = instance.createEncryptedInput(contractAddress, wallet.address);
    input.add64(args[1]);
    const encryptedInput = input.encrypt();
    args[1] = encryptedInput.handles[0];
    args[2] = encryptedInput.inputProof;
  } else if (cfunc === "transferEncrypted") {
    const input = instance.createEncryptedInput(contractAddress, wallet.address);
    input.add64(args[1]);
    const encryptedInput = input.encrypt();
    args[1] = encryptedInput.handles[0];
    args[2] = encryptedInput.inputProof;
  } else if (cfunc === "transferFromEncrypted") {
    const input = instance.createEncryptedInput(contractAddress, wallet.address);
    input.add64(args[2]);
    const encryptedInput = input.encrypt();
    args[2] = encryptedInput.handles[0];
    args[3] = encryptedInput.inputProof;
  }

  const contract = new ethers.Contract(contractAddress, abi, wallet);
  const result = await contract[cfunc](...args, {
    value: BigInt(Number(cvalue) * 10 ** 18),
    gasLimit: 6000000,
  });
  console.log("result: ", result);
}

async function main() {
  const wallet = process.argv[2];
  const param1 = process.argv[3];
  const param2 = process.argv[4];
  const param3 = process.argv[5];
  const param4 = process.argv[6];
  switch (param1) {
    case "totalSupply":
      await TokenContractCall(Number(wallet), param1);
      break;
    case "balanceOf":
      await TokenContractCall(Number(wallet), param1, [param2]);
      break;
    case "getEncryptedBalance":
      await TokenContractCall(Number(wallet), param1, [param2]);
      break;
    case "getAllowance":
      await TokenContractCall(Number(wallet), "getAllowance", [param2, param3]);
      break;
    case "wrap": {
      await TokenContractCall(Number(wallet), param1, [BigInt(Number(param2) * 10 ** 18)]);
      break;
    }
    case "unwrap": {
      await TokenContractCall(Number(wallet), param1, [BigInt(Number(param2) * 10 ** 6)]);
      break;
    }
    case "approveEncrypted": {
      await TokenContractCall(Number(wallet), param1, [param2, BigInt(Number(param3) * 10 ** 6)]);
      break;
    }
    case "allowBalance": {
      await TokenContractCall(Number(wallet), param1, [param2]);
      break;
    }
    case "allowAllowance": {
      await TokenContractCall(Number(wallet), param1, [param2, param3]);
      break;
    }
    case "transferEncrypted": {
      await TokenContractCall(Number(wallet), param1, [param2, BigInt(Number(param3) * 10 ** 6)]);
      break;
    }
    case "transferFromEncrypted": {
      await TokenContractCall(Number(wallet), param1, [param2, param3, BigInt(Number(param4) * 10 ** 6)]);
      break;
    }
    default:
      console.log("Invalid parameter");
      console.log("Your param: ", param1);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
