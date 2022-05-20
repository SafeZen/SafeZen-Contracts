const { ethers } = require("hardhat");
const fs = require("fs");
require("dotenv").config();

import { SafeZen } from "../typechain/SafeZen";
import { Governance } from "../typechain/Governance";
import { StakingContract } from "../typechain/StakingContract";

const safeZenAddress = "0xF64dd77E524e2b2781EBAf9d88028574390ACada"
const stakingContractAddress = "0x00fd1EEffb63403c0C55486172a0FcE0a5DFb78A"
const govContractAddress = "0xfb62d0d3A43502BB7431F80b392EFB300a9841Db"

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

