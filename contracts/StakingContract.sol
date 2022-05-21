//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SafeZen.sol";

contract StakingContract is ERC20, Pausable, ReentrancyGuard, Ownable {
    SafeZen public safeZen;

    // @dev mapping to check whether the user has claimed the reward tokens or not
    mapping(uint256 => bool) public hasClaimedRewards;

    // @dev generating ERC20 reward token
    // @param _name : Reward token name, e.g. SafeZen Rewards
    // @param _symbol : Symbol for reward token, e.g. SZR
    constructor(string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
    {}

    // Event for successful token transfer
    event TokenTransfer(address indexed _to, uint256 _rewardTokensCount);
    // Generating error, in case of transaction failure
    error TransactionFailure();

    /* 
    @dev function: calculates the amount of tokens user is eligible to claim at a given time 
                    based on the data fetched from SafeZen's contract, i.e. purchase time of the insurance,
                    base amount user has paid for insurance and if the user has already claimed reward token or not.

    Calculation goes as follow: 
    1. If the user chooose to claim the reward "within 7 days" from the date of issuance of insurance, 
        then only "10% of the base amount" will be distributed to the user as reward token.
    2. If the user chooose to claim the reward "between 7 days to 30 days" from the date of issuance of insurance, 
        then only "20% of the base amount" will be distributed to the user as reward token.
    3. If the user chooose to claim the reward "after 30 days" from the date of issuance of insurance, 
        then "50% of the base amount" will be distributed to the user as reward token.

    Further, if the user has "already claimed the insurance and NOT reward tokens", then only half of the 
    above mentioned rewards will be distributed to user as token.

    @param _tokenID: User's unique insurance ID
    */
    function eligibleRewardTokenCount(uint256 _tokenID)
        public
        view
        returns (uint256 _rewardTokenCounts)
    {
        (, uint256 purchaseTime, uint256 baseAmount, bool hasClaimed) = safeZen
            .getRewardData(_tokenID);

        if (uint256(block.timestamp) < (purchaseTime + 7 days)) {
            _rewardTokenCounts = (baseAmount * 10) / 100;
        } else if (
            (uint256(block.timestamp) < (purchaseTime + 30 days)) &&
            (uint256(block.timestamp) > (purchaseTime + 7 days))
        ) {
            _rewardTokenCounts = (baseAmount * 20) / 100;
        } else {
            _rewardTokenCounts = baseAmount / 2;
        }
        // hasClaimed needs to be defined in SafeZen.sol in the Policy struct section.
        if (hasClaimed) {
            _rewardTokenCounts = _rewardTokenCounts / 2;
        }

        return _rewardTokenCounts;
    }

    /*
    @dev function: distributes the freshly minted token to the user if not claimed before.
                    The function further checks whether the person claiming the reward is policy owner or not. 
                    If yes, it calls the function written above, i.e. eligibleRewardTokenCount, to get the count 
                    of tokens user is eligible for, and update the hasClaimedRewards mappping, so as user cannot claim
                    the rewards again in the coming future against same insurance ID. 

    @param _tokenID: User's unique insurance ID
    */
    function claimRewardTokens(uint256 _tokenID) public {
        (address policyHolder, , , ) = safeZen.getRewardData(_tokenID);
        require(policyHolder == msg.sender);
        require(!hasClaimedRewards[_tokenID], "ALREADY CLAIMED");

        uint256 rewardTokenAmt = eligibleRewardTokenCount(_tokenID);
        _mint(msg.sender, rewardTokenAmt);
        hasClaimedRewards[_tokenID] = true; //makes sure that each policy can only be claimed once

        emit TokenTransfer(policyHolder, rewardTokenAmt);
    }

    function setSafeZenCA(address _safeZenCA) public onlyOwner {
        safeZen = SafeZen(_safeZenCA);
    }

    //  To pause and unpause the contract, in case, if any vulnerability is discovered.
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
