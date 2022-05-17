const { ethers } = require('hardhat');
const { GasLogger } = require('../utils/helper.js');

require('dotenv').config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
	const { deploy } = deployments;
	const { deployer } = await getNamedAccounts();
	const chainId = await getChainId();
	const HOST_ADDRESS = "0xeD5B5b32110c3Ded02a07c8b8e97513FAfb883B6";
	const CFA = "0xF4C5310E51F6079F601a5fb7120bC72a70b96e2A";
	const ACCEPTEDTOKEN = "0x15F0Ca26781C3852f8166eD2ebce5D18265cceb7";
	// Config
	console.log(`Deploying Mock Contracts... from ${deployer}`);
	let govContract = await deploy('GovContract',{from: deployer});	
	gasLogger.addDeployment(govContract);
	let stakingContract = await deploy('StakingContract',{from: deployer});
	gasLogger.addDeployment(stakingContract);
	console.log(`Deploying SafeZen Contract... from ${deployer}`);

	let safezenContract = await deploy('SafeZen', {
		from: deployer,
		args: ['SafeZen', 'SZ', HOST_ADDRESS, CFA, ACCEPTEDTOKEN, stakingContract.address, govContract.address]
	});

	gasLogger.addDeployment(safezenContract);
};

module.exports.tags = ['SafeZen'];
