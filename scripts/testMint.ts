const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

import { SafeZen } from "../typechain/SafeZen";

async function main() {
  // Just use Hardhat Environment
  const [signer, receiver] = await ethers.getSigners();

  const safezenContract: SafeZen = await ethers.getContract("SafeZen", signer);
  let tx = await (
    await safezenContract.mint("CAR", 100, "AIA", 69000000, 123, 369)
  ).wait();
  console.log("🚀 | main | tx", tx);

  console.log(await safezenContract.buildPolicy(1));
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

