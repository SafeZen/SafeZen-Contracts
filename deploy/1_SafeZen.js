const { ethers } = require('hardhat');
const { GasLogger } = require('../utils/helper.js');

require('dotenv').config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
	const { deploy } = deployments;
	const { deployer } = await getNamedAccounts();
	const chainId = await getChainId();

	// Config
	console.log(`Deploying SafeZen Contract... from ${deployer}`);


	let safezenContract = await deploy('SafeZen', {
		from: deployer,
		args: ['SafeZen', 'SZ']
	});

	gasLogger.addDeployment(safezenContract);
};

module.exports.tags = ['SafeZen'];
