const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

import { SafeZen } from "../typechain/SafeZen";
import { Governance } from "../typechain/Governance";
import { StakingContract } from "../typechain/StakingContract";

const safeZenAddress = "0xbe4511EBaa8530d17143e394c5e735C810a0b88a"

async function main() {
  // Just use Hardhat Environment
  const [deployer] = await ethers.getSigners();

  const stakingContract: StakingContract = await ethers.getContract('StakingContract', deployer);
  const govContract: Governance = await ethers.getContract("Governance", deployer);
  
  console.log("Updating safeZenCA for Staking contract...");
  let tx1 = await (
    await stakingContract.setSafeZenCA(safeZenAddress)
  ).wait();
  console.log("🚀 | mumbai | tx", tx1);

  console.log("Upading safeZenCA for Governance contract...")  
  let tx2 = await (
    await govContract.setSafeZenCA(safeZenAddress)
  ).wait();
  console.log("🚀 | mumbai | tx", tx2);

}


main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });

