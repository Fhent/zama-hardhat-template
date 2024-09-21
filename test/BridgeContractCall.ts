/* eslint-disable  @typescript-eslint/no-explicit-any */
import { createInstance as createFhevmInstance } from "fhevmjs";
import hre from "hardhat";

import { abi } from "../artifacts/contracts/ZamaBridge.sol/ZamaBridge.json";

const { ethers } = hre;

const contractAddress = "0x708633A302Dd17b85f7121a6E296C254d3584111";

const wallets: { [key: string]: string } = {
  1: process.env.PRIVATE_KEY_DEPLOYER as string,
};

async function BridgeContractCall(key: number, cfunc: string, cargs: any[] = [], cvalue: string = "0") {
  const args = cargs;
  const wallet = new ethers.Wallet(wallets[key], new ethers.JsonRpcProvider("https://devnet.zama.ai"));
  const instance = await createFhevmInstance({
    networkUrl: "https://devnet.zama.ai",
    gatewayUrl: "https://gateway.devnet.zama.ai",
  });

  if (cfunc === "bridgeWEERC20") {
    const input = instance.createEncryptedInput(contractAddress, wallet.address);
    input.addAddress(args[0]);
    input.add64(args[1]);
    const encryptedInput = input.encrypt();
    args[0] = encryptedInput.handles[0];
    args[1] = encryptedInput.handles[1];
    args[2] = encryptedInput.inputProof;
    args[3] = "0x9C3Ad2B5f00EC8e8564244EBa59692Dd5e57695b";
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

  switch (param1) {
    case "nextIntentId":
      await BridgeContractCall(Number(wallet), param1);
      break;

    case "bridgeWEERC20":
      await BridgeContractCall(Number(wallet), param1, [param2, BigInt(Number(param3) * 10 ** 6)]);
      break;

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
