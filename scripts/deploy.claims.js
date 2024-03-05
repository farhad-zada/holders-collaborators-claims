const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const token = ethers.ZeroAddress;

  const claims = await ethers.deployContract("Claims", [
    token,
    "Holders",
    Date.now() + 100,
    10n,
    1000n,
    deployer.address,
  ]);

  console.log("Claims address:", claims.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
