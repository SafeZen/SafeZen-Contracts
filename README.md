# SafeZen Smart Contracts
This repository contains all code written for project SafeZen as part of the HackMoney2022 Hackathon organised by ETHGlobal. The repository is powered by [Hardhat](https://hardhat.org/)

Before running any scripts, install necessary packages:
```
npm install
```

Make sure you set up your environment variables shown in `.env.example`

---
## Test Cases
To run the test cases:
```
npx hardhat test
```
This is a brief description of the purpose of the 3 main smart contracts for SafeZen:
1. **SafeZen.sol** - Main ERC721 SC that handles purchase and activation of on-chain insurance policies
2. **Governance.sol** - Decentralised voting mechanism for handling insurance claims
3. **StakingContract.sol** - Generates and calculates rewards based on policy purchases

---
## Deployment
Because we are dealing with [Superfluid](https://www.superfluid.finance/). Please ensure that the required contract addresses are accurate depending on the chain you are deploying on:
1. Superfluid Host Address
2. Central Flow Agreement Address
3. Accepted SuperToken Address

Our team has chosen Polygon as our deployment blockchain and will be using the Mumbai testnet.

Step 1: To deploy SafeZen onto Mumbai:
```
npm run deploy-mumbai
```
Step 2: Update SafeZen CA for Governance and Staking contracts, remember to grab the latest deployed SafeZen CA and update in `setCA.ts`:
```
npm run updateCA-mumbai
```
Step 3 [optional]: Verify smart contracts:
```
npm run verify-mumbai
```