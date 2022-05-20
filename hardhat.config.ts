import { task } from "hardhat/config";

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-truffle5");
require('@nomiclabs/hardhat-ethers');
require("hardhat-gas-reporter");
require("hardhat-deploy");
require("hardhat-typechain");

require("dotenv").config();

let ethers = require("ethers");
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

task("newwallet", "Generate New Wallet", async (taskArgs, hre) => {
  const wallet = ethers.Wallet.createRandom();
  console.log("PK: ", wallet._signingKey().privateKey);
  console.log("Address: ", wallet.address);
});
console.log(process.env.POLYGONSCAN_API_KEY);
// Setup Default Values
let MAIN_PRIVATE_KEY;
if (process.env.MAIN_PRIVATE_KEY) {
  MAIN_PRIVATE_KEY = process.env.MAIN_PRIVATE_KEY;
} else {
  console.log("⚠️ Please set MAIN_PRIVATE_KEY in the .env file");
  MAIN_PRIVATE_KEY = ethers.Wallet.createRandom()._signingKey().privateKey;
}

if (!process.env.INFURA_API_KEY) {
  console.log("⚠️ Please set INFURA_API_KEY in the .env file");
}

if (!process.env.ETHERSCAN_API_KEY) {
  console.log("⚠️ Please set ETHERSCAN_API_KEY in the .env file");
}

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
	defaultNetwork: 'hardhat',
	networks: {
		localhost: {
			url: 'http://127.0.0.1:8545',
			saveDeployments: true,
			accounts: "remote",
		},
		hardhat: {
			// TODO: Add snapshot block
			// forking: {
			//   url: process.env.ALCHEMY_PROVIDER_MAINNET,
			//   block: 0,
			// },
			mining: {
				auto: true,
			},
		},
		mainnet: {
			url: `https://mainnet.infura.io/v3/${process.env.INFURA_API_KEY}`,
			chainId: 1,
			accounts: [MAIN_PRIVATE_KEY],
		},
		rinkeby: {
			url: `https://rinkeby.infura.io/v3/${process.env.INFURA_API_KEY}`,
			chainId: 4,
			accounts: [MAIN_PRIVATE_KEY],
		},
		// matic: {
		//   url: "https://polygon-rpc.com/",
		//   chainId: 137,
		//   accounts: [MAIN_PRIVATE_KEY],
		// },
		mumbai: {
			url: 'https://matic-mumbai.chainstacklabs.com',
			chainId: 80001,
			accounts: [MAIN_PRIVATE_KEY],
		},
	},
	solidity: {
		compilers: [
			{
				version: '0.8.10',
				settings: {
					optimizer: {
						enabled: true,
					},
				},
			},
			{
				version: '0.7.6',
				settings: {
					optimizer: {
						enabled: true,
					},
				},
			},
		],
	},
	namedAccounts: {
		deployer: 0
	},
	etherscan: {
		apiKey: process.env.POLYGONSCAN_API_KEY
	},

	paths: {
		sources: './contracts',
		tests: './test',
		cache: './cache',
		artifacts: './artifacts',
		deploy: './deploy',
	},
	mocha: {
		timeout: 2000000000,
	},
	typechain: {
		outDir: 'typechain',
		target: 'ethers-v5',
	},
};
