const { assert, expect } = require("chai");
const daiABI = require("../abis/fDAIABI");
const { ethers, web3 } = require('hardhat');
const { Framework } = require("@superfluid-finance/sdk-core"); 
const traveler = require("ganache-time-traveler");
const deployFramework = require("@superfluid-finance/ethereum-contracts/scripts/deploy-framework");
const deployTestToken = require("@superfluid-finance/ethereum-contracts/scripts/deploy-test-token");
const deploySuperToken = require("@superfluid-finance/ethereum-contracts/scripts/deploy-super-token");
const TEST_TRAVEL_TIME = 3600 * 2
const provider = web3;
require('dotenv').config();

let accounts;
let sf;
let dai;
let daix;
let superSigner;
let SafeZen;


const errorHandler = (err) => {
    if (err) throw err;
};

before(async function() {
  accounts = await ethers.getSigners();

	//deploy framework
	console.log ("Deploying Superfluid Framework")
	await deployFramework(errorHandler, {
		web3,
		from: accounts[0].address,
	});

	//deploy a fake erc20 token
	console.log ("Deploying Fake ERC20 Token")
	let fDAIAddress = await deployTestToken(errorHandler, [":", "fDAI"], {
			web3,
			from: accounts[0].address,
	});

	//deploy a fake erc20 wrapper super token around the fDAI token
	console.log ("Deploying Fake ERC20 Wrapper Super token")
	let fDAIxAddress = await deploySuperToken(errorHandler, [":", "fDAI"], {
			web3,
			from: accounts[0].address,
	});

	//initialize the superfluid framework...put custom and web3 only bc we are using hardhat locally
	sf = await Framework.create({
			networkName: "custom",
			provider,
			dataMode: "WEB3_ONLY",
			resolverAddress: process.env.RESOLVER_ADDRESS, //this is how you get the resolver address
			protocolReleaseVersion: "test",
	});

	superSigner = await sf.createSigner({
			signer: accounts[0],
			provider: provider
	});
	// Use the framework to get the super toen
	daix = await sf.loadSuperToken("fDAIx");
	
	// Get the contract object for the erc20 token
	let daiAddress = daix.underlyingToken.address;
	dai = new ethers.Contract(daiAddress, daiABI, accounts[0]);

	// Deploy mock Staking and Governance Contract
	console.log(`Deploying Mock Contracts... from ${accounts[0].address}`);
	govContract = await ethers.getContractFactory("GovContract");
	GovContract = await govContract.deploy();
	
	stakingContract = await ethers.getContractFactory("StakingContract")
	StakingContract = await stakingContract.deploy();

	let safeZen = await ethers.getContractFactory("SafeZen", accounts[0]);

	console.log(`Deploying SafeZen Contract... from ${accounts[0].address}`);
	SafeZen = await safeZen.deploy(
		"SafeZen",
		"SZ",
		sf.settings.config.hostAddress,
		sf.settings.config.cfaV1Address,
		daix.address,
		StakingContract.address,
		GovContract.address
	)
});

beforeEach(async function () {
  await dai.connect(accounts[0]).mint(
    accounts[0].address, ethers.utils.parseEther("1000")
  );

  await dai.connect(accounts[0]).approve(daix.address, ethers.utils.parseEther("1000"));

  const daixUpgradeOperation = daix.upgrade({
    amount: ethers.utils.parseEther("1000")
  });

  await daixUpgradeOperation.exec(accounts[0]);

  const daiBal = await daix.balanceOf({account: accounts[0].address, providerOrSigner: accounts[0]});
  console.log('daix bal for acct 0:', daiBal);
})

describe("minting policy", async function () {
	it("Mints a single Policy", async () => {

		const mintTxn = await SafeZen.connect(accounts[0]).mint("CAR", 100, "AIA", 69000000, 123, 369);

		userBalance = await SafeZen.balanceOf(accounts[0].address);
		isPolicyActive = await SafeZen.isActive(1);
		assert.equal(userBalance, 1, "User should have minted 1 policy");
		assert.equal(isPolicyActive, false, "Policy should not be active")
	});
});

describe("Activating a flow", async function () {
	it("User starts a flow - reflected correctly in balance", async () => {
		const SafeZenInitialBalance = await daix.balanceOf({
			account: SafeZen.address,
			providerOrSigner: accounts[0]
		});

		const createFlowOperation = sf.cfaV1.createFlow({
			receiver: SafeZen.address,
			superToken: daix.address,
			flowRate: "70000000",
		});

		const txn = await createFlowOperation.exec(accounts[0]);
		const receipt = await txn.wait();

		const SafeZenFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: SafeZen.address,
			providerOrSigner: superSigner
		})
		const ownerFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: accounts[0].address,
			providerOrSigner: superSigner
		})

		console.log(`Go forward in time by ${TEST_TRAVEL_TIME} ms`);
		await traveler.advanceTimeAndBlock(TEST_TRAVEL_TIME);

		const SafeZenFinalBalance = await daix.balanceOf({
			account: SafeZen.address,
			providerOrSigner: superSigner
		})

		assert.equal(SafeZenFlowRate, "70000000", "SafeZen is not receiving 100% of the flowRate")
		assert.equal(ownerFlowRate, "-70000000", "OwnerFlowRate is not reflected correctly")
		assert.equal(SafeZenFinalBalance-SafeZenInitialBalance,SafeZenFlowRate*TEST_TRAVEL_TIME, "Wrong balance from flowrate")
	})

	it("Policy should be started", async () => {
		policyId = SafeZen.totalSupply();
		isPolicyActive = await SafeZen.isActive(policyId)
		assert.equal(isPolicyActive, true, "Policy should be activated with the flow")
	})

	it("Policy should not be active if no flow from owner", async () => {
		const DeleteFlowOperation = sf.cfaV1.deleteFlow({
			sender: accounts[0].address,
			receiver: SafeZen.address,
			superToken: daix.address,
		})

		const txn = await DeleteFlowOperation.exec(accounts[0]);

		const SafeZenFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: SafeZen.address,
			providerOrSigner: superSigner
		})
		const ownerFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: accounts[0].address,
			providerOrSigner: superSigner
		})

		assert.equal(SafeZenFlowRate, "0", "App flow rate should be 0");
		assert.equal(ownerFlowRate, "0", "Owner flow rate should be 0")

		policyId = SafeZen.totalSupply();
		isPolicyActive = await SafeZen.isActive(policyId)
		assert.equal(isPolicyActive, false, "Policy should not be activated with no flow")
	})

	it("Policy should not be active if flow is insufficient", async () => {
		const SafeZenInitialBalance = await daix.balanceOf({
			account: SafeZen.address,
			providerOrSigner: accounts[0]
		});
		
		const createFlowOperation = sf.cfaV1.createFlow({
			receiver: SafeZen.address,
			superToken: daix.address,
			flowRate: "10000",
		});

		const txn = await createFlowOperation.exec(accounts[0]);
		const receipt = await txn.wait();

		const SafeZenFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: SafeZen.address,
			providerOrSigner: superSigner
		})
		const ownerFlowRate = await sf.cfaV1.getNetFlow({
			superToken: daix.address,
			account: accounts[0].address,
			providerOrSigner: superSigner
		})

		console.log(`Go forward in time by ${TEST_TRAVEL_TIME} ms`);
		await traveler.advanceTimeAndBlock(TEST_TRAVEL_TIME);

		const SafeZenFinalBalance = await daix.balanceOf({
			account: SafeZen.address,
			providerOrSigner: superSigner
		})

		assert.equal(SafeZenFlowRate, "10000", "App flow rate should be 0");
		assert.equal(ownerFlowRate, "-10000", "Owner flow rate should be 0")
		assert.equal(SafeZenFinalBalance-SafeZenInitialBalance,SafeZenFlowRate*TEST_TRAVEL_TIME, "Wrong balance from flowrate")

		policyId = SafeZen.totalSupply();
		isPolicyActive = await SafeZen.isActive(policyId)
		assert.equal(isPolicyActive, false, "Policy should not be activated with insufficient flow")
	})
})
	


