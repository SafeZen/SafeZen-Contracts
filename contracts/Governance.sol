//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;
import "./SafeZen.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable{
    SafeZen safeZen;

    uint256 public minPercVotes = 50;
    uint256 public tokenHolderCount;

    struct Claim{
        address Owner;
        uint Policy_ID;
        string Proof;
        uint256 claimAmount;
        uint No_of_Votes_for;
        uint No_of_Votes_against;
        uint Total_Votes;
        bool claimSuccessful;
    }

    mapping(uint256 => mapping(address => bool)) hasVoted;
    mapping(uint256 => Claim) claims;
    mapping(address => bool) isTokenHolder;

    constructor() {}
    
    ///@notice Function gives Governance Token Holder privileges
    function addGovHolder(address _newHolder) public onlyOwner {
        isTokenHolder[_newHolder] = true;
        tokenHolderCount++;
    }
    
    ///@notice Function removes governance token holder
    function removeGovHolder(address _newHolder) public onlyOwner {
        isTokenHolder[_newHolder] = false;
        tokenHolderCount--;
    }

    ///@notice Function is used to Cast a Vote
    ///@params Voting_side : if true, then it votes for passing the claim
		          ///if false, then it votes against passing the claim

    function Vote(bool Voting_side, uint256 _claimID) public {
        require(isTokenHolder[msg.sender], "NOT TOKEN HOLDER");
        Claim storage currentClaim = claims[_claimID];
        require(!hasVoted[_claimID][msg.sender], "USER HAS VOTED");
        require(!currentClaim.claimSuccessful, "CLAIM IS ALREADY APPROVED");

        if (Voting_side == true){
                currentClaim.Total_Votes+=1;
                currentClaim.No_of_Votes_for+=1;
        }

        if (Voting_side == false){
                currentClaim.Total_Votes+=1;
                currentClaim.No_of_Votes_against+=1;
        } 

        hasVoted[_claimID][msg.sender] = true;

        if(checkDecision(_claimID)){
            if(currentClaim.claimSuccessful==false){
                // Call NFT contract to transfer ETH to user
                safeZen.sendInsuranceClaim(currentClaim.Owner, currentClaim.claimAmount);
                currentClaim.claimSuccessful = true;
            }
        }
    }

    ///@notice Function is used to Apply for a Claim by the user
    function ApplyClaim(uint256 _policyID,string memory _Proof, uint256 _claimAmount) public {
        address policyHolder = safeZen.getHolder(_policyID);
        require( msg.sender == policyHolder, "NOT POLICY HOLDER");

        Claim memory _claim = Claim(msg.sender,_policyID,_Proof,_claimAmount,0,0,0,false);
        claims[_policyID] = _claim;
    }

    ///@notice Function is used to check what decision is taken based on the number of votes for/against
requires a minimum participation
    function checkDecision(uint256 _claimID) public view returns (bool decision) {
        Claim storage currentClaim = claims[_claimID];
        require(currentClaim.Total_Votes >= tokenHolderCount/2, "NOT ENOUGH HAS VOTED");

        uint256 minRequiredVotes =  (tokenHolderCount * minPercVotes) / 100;

        if(currentClaim.No_of_Votes_for >= minRequiredVotes){
            return true;
        }

        if(currentClaim.No_of_Votes_against > minRequiredVotes){
            return false;
        }
    }

    function setSafeZenCA(address _safeZenCA) public onlyOwner {
        safeZen = SafeZen(_safeZenCA);
    }
}
