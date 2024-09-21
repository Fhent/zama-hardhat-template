var hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const WrappedEncryptedERC20 = await hre.ethers.getContractFactory("ZamaWEERC20");
  const weerc20 = await WrappedEncryptedERC20.deploy("Zama Wrapped Ether", "ZWE");

  console.log("Contract deployed at:", weerc20.target);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
