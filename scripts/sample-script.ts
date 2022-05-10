const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

import {SafeZen} from "../typechain/SafeZen"

async function main() {
  // Just use Hardhat Environment
  const [signer] = await ethers.getSigners();

  const safezenContract: SafeZen = await ethers.getContract("SafeZen", signer);
  let tx = await (
    await safezenContract.mint("CAR", 100, "AIA", 69, 123, 369)
  ).wait();
  console.log("🚀 | main | tx", tx);

  console.log(await safezenContract.tokenURI(1));
}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
