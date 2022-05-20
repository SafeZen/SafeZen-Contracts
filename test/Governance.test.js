const { ethers, web3 } = require('hardhat');
const { assert, expect } = require('chai');
const daiABI = require('../abis/fDAIABI');
const { Framework } = require('@superfluid-finance/sdk-core');
const traveler = require('ganache-time-traveler');
const deployFramework = require('@superfluid-finance/ethereum-contracts/scripts/deploy-framework');
const deployTestToken = require('@superfluid-finance/ethereum-contracts/scripts/deploy-test-token');
const deploySuperToken = require('@superfluid-finance/ethereum-contracts/scripts/deploy-super-token');
const TEST_TRAVEL_TIME = 3600 * 2;
const provider = web3;
require('dotenv').config();

// TODO: REMOVE all SKIPs from SafeZen test
let accounts;
let sf;
let dai;
let daix;
let superSigner;
let SafeZen;

const errorHandler = (err) => {
  if (err) throw err;
};

before('Deploy SafeZen and Governance Contracts', async () => {
  accounts = await ethers.getSigners();

  //deploy framework
  console.log('Deploying Superfluid Framework...');
  await deployFramework(errorHandler, {
    web3,
    from: accounts[0].address,
  });

  //deploy a fake erc20 token
  console.log('Deploying Fake ERC20 Token...');
  let fDAIAddress = await deployTestToken(errorHandler, [':', 'fDAI'], {
    web3,
    from: accounts[0].address,
  });

  //deploy a fake erc20 wrapper super token around the fDAI token
  console.log('Deploying Fake ERC20 Wrapper Super token...');
  let fDAIxAddress = await deploySuperToken(errorHandler, [':', 'fDAI'], {
    web3,
    from: accounts[0].address,
  });

  //initialize the superfluid framework...put custom and web3 only bc we are using hardhat locally
  sf = await Framework.create({
    networkName: 'custom',
    provider,
    dataMode: 'WEB3_ONLY',
    resolverAddress: process.env.RESOLVER_ADDRESS, //this is how you get the resolver address
    protocolReleaseVersion: 'test',
  });

  superSigner = await sf.createSigner({
    signer: accounts[0],
    provider: provider,
  });
  // Use the framework to get the super token
  daix = await sf.loadSuperToken('fDAIx');

  // Get the contract object for the erc20 token
  let daiAddress = daix.underlyingToken.address;
  dai = new ethers.Contract(daiAddress, daiABI, accounts[0]);

  // Deploy mock Staking and Governance Contract
  console.log('Deploying Governance Contract...');
  govContract = await ethers.getContractFactory('Governance');
  GovContract = await govContract.deploy();

  console.log('Deploying Staking Contract...');
  stakingContract = await ethers.getContractFactory('StakingContract');
  StakingContract = await stakingContract.deploy();

  let safeZen = await ethers.getContractFactory('SafeZen', accounts[0]);

  console.log('Deploying SafeZen Contract...');
  SafeZen = await safeZen.deploy(
    'SafeZen',
    'SZ',
    sf.settings.config.hostAddress,
    sf.settings.config.cfaV1Address,
    daix.address,
    StakingContract.address,
    GovContract.address
  );

  console.log('SafeZen contract minting a policy...');
  const mintTxn = await SafeZen.connect(accounts[0]).mint(
    'CAR',
    100,
    'AIA',
    69000000,
    1000
  );
});

describe('Adding and Removing Governance Token holder', async () => {
  it('Should give governance token to account', async () => {
    await GovContract.addGovHolder(accounts[0].address);
    const isHolder = await GovContract.checkIfTokenHolder(accounts[0].address);
    assert.equal(isHolder, true, 'Account should have governace token');
  });

  it('Should return the number of accounts with governance tokens (1)', async () => {
    await assert(
      GovContract.getTokeHolderCount(),
      1,
      'Exactly 1 account should have a governance token'
    );
  });

  it('Should attempt giving governance token and revert', async () => {
    await expect(
      GovContract.addGovHolder(accounts[0].address)
    ).to.be.revertedWith('Account already has governance token');
  });

  it('Should remove governance token from account', async () => {
    await GovContract.removeGovHolder(accounts[0].address);
    const isHolder = await GovContract.checkIfTokenHolder(accounts[0].address);
    assert.equal(isHolder, false, 'Account should have governace token');
  });

  it('Should return the number of accounts with governance tokens (0)', async () => {
    await assert(
      GovContract.getTokeHolderCount(),
      0,
      'No account should have a governance token'
    );
  });

  it('Should attempt removing governance token and revert', async () => {
    await expect(
      GovContract.removeGovHolder(accounts[0].address)
    ).to.be.revertedWith('Account does not have governance token');
  });
});

describe('Governance Token holder Voting', async () => {});
