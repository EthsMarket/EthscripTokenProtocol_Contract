import { ethers } from "hardhat";

async function main() {

  const rec = '';
  const merkleRoot_og = ''

  const EthscripTokenProtocol = await ethers.getContractFactory("EthscripTokenProtocol");
  const ethscripTokenProtocol = await EthscripTokenProtocol.deploy(rec,merkleRoot_og);

  await ethscripTokenProtocol.deployed();
  console.log(`EthscripTokenProtocol deployed to ${ethscripTokenProtocol.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
