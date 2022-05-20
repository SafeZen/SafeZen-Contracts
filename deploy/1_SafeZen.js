const { ethers } = require('hardhat');
const { GasLogger } = require('../utils/helper.js');

require('dotenv').config();
const gasLogger = new GasLogger();

module.exports = async ({ getNamedAccounts, deployments, getChainId }) => {
	// Config
	const { deploy } = deployments;
	const { deployer } = await getNamedAccounts();
	const chainId = await getChainId();
	const HOST_ADDRESS = "0xEB796bdb90fFA0f28255275e16936D25d3418603";
	const CFA = "0x49e565Ed1bdc17F3d220f72DF0857C26FA83F873";
	const ACCEPTEDTOKEN = "0x5D8B4C2554aeB7e86F387B4d6c00Ac33499Ed01f"; //fDAIx

	// Deployment
	console.log(`Deploying Governance Contract... from ${deployer}`);
	let govContract = await deploy('Governance',{from: deployer});	
	gasLogger.addDeployment(govContract);

	console.log(`Deploying Staking Contract... from ${deployer}`);
	let stakingContract = await deploy('StakingContract',{
		from: deployer ,
		args:[
			'SafeZenTokens', 'SZT'
		]});
	gasLogger.addDeployment(stakingContract);


	console.log(`Deploying SafeZen Contract... from ${deployer}`);
	let safezenContract = await deploy('SafeZen', {
		from: deployer,
		args: ['SafeZen', 'SZ', HOST_ADDRESS, CFA, ACCEPTEDTOKEN, stakingContract.address, govContract.address]
	});
	gasLogger.addDeployment(safezenContract);

};

module.exports.tags = ['SafeZen'];
