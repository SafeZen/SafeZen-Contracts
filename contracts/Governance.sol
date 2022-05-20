//SPDX-License-Identifier:MIT
pragma solidity ^0.8.7;
import "./SafeZen.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Governance is Ownable {
    SafeZen safeZen;

    uint256 public minPercVotes = 50;
    uint256 public tokenHolderCount;

    struct Claim {
        address Owner;
        uint256 Policy_ID;
        string Proof;
        uint256 claimAmount;
        uint256 No_of_Votes_for;
        uint256 No_of_Votes_against;
        uint256 Total_Votes;
        bool claimSuccessful;
    }

    mapping(uint256 => mapping(address => bool)) hasVoted;
    mapping(uint256 => Claim) claims;
    mapping(address => bool) isTokenHolder;

    constructor() {}

    /// @notice Function gives Governance Token Holder privileges
    /// @param _newHolder the address which will be added as the governance token holder
    function addGovHolder(address _newHolder) public onlyOwner {
        require(
            !checkIfTokenHolder(_newHolder),
            "Account already has governance token"
        );
        isTokenHolder[_newHolder] = true;
        tokenHolderCount++;
    }

    /// @notice Function removes governance token holder
    /// @param _newHolder the address which will be removed as the governance token holder
    function removeGovHolder(address _newHolder) public onlyOwner {
        require(
            checkIfTokenHolder(_newHolder),
            "Account does not have governance token"
        );
        isTokenHolder[_newHolder] = false;
        tokenHolderCount--;
    }

    /// @notice Function returns value from isTokenHolder mapping with key of @param
    /// @param _newHolder the address whose value from isTokenHolder will be returned
    function checkIfTokenHolder(address _newHolder)
        public
        view
        onlyOwner
        returns (bool)
    {
        return isTokenHolder[_newHolder];
    }

    /// @notice Function returns number of accounts with governance token
    function getTokeHolderCount() public view returns (uint256) {
        return tokenHolderCount;
    }

    /// @notice Function is used to Cast a Vote
    /// @param Voting_side : if true, then it votes for passing the claim
    ///if false, then it votes against passing the claim
    /// @param _claimID : ID that identifies a claim
    function Vote(bool Voting_side, uint256 _claimID) public {
        require(isTokenHolder[msg.sender], "NOT TOKEN HOLDER");
        Claim storage currentClaim = claims[_claimID];
        require(!hasVoted[_claimID][msg.sender], "USER HAS VOTED");
        require(!currentClaim.claimSuccessful, "CLAIM IS ALREADY APPROVED");

        if (Voting_side == true) {
            currentClaim.Total_Votes += 1;
            currentClaim.No_of_Votes_for += 1;
        }

        if (Voting_side == false) {
            currentClaim.Total_Votes += 1;
            currentClaim.No_of_Votes_against += 1;
        }

        hasVoted[_claimID][msg.sender] = true;

        if (checkDecision(_claimID)) {
            if (currentClaim.claimSuccessful == false) {
                // Call NFT contract to transfer ETH to user
                safeZen.sendInsuranceClaim(
                    currentClaim.Owner,
                    currentClaim.claimAmount
                );
                currentClaim.claimSuccessful = true;
            }
        }
    }

    /// @notice Function is used to Apply for a Claim by the user
    /// @param _policyID : policyID for the policy bought by the buyer
    ///_Proof : Document that user uploads as proof
    ///_claimAmount : Amount applied for claim

    function ApplyClaim(
        uint256 _policyID,
        string memory _Proof,
        uint256 _claimAmount
    ) public {
        address policyHolder = safeZen.getHolder(_policyID);
        require(msg.sender == policyHolder, "NOT POLICY HOLDER");

        Claim memory _claim = Claim(
            msg.sender,
            _policyID,
            _Proof,
            _claimAmount,
            0,
            0,
            0,
            false
        );
        claims[_policyID] = _claim;
    }

    /// @notice Function is used to check what decision is taken based on the number of votes for/against
    ///requires a minimum participation
    /// @param _claimID : ID that identifies the Claim
    function checkDecision(uint256 _claimID)
        public
        view
        returns (bool decision)
    {
        Claim storage currentClaim = claims[_claimID];
        require(
            currentClaim.Total_Votes >= tokenHolderCount / 2,
            "NOT ENOUGH HAS VOTED"
        );

        uint256 minRequiredVotes = (tokenHolderCount * minPercVotes) / 100;

        if (currentClaim.No_of_Votes_for >= minRequiredVotes) {
            return true;
        }

        if (currentClaim.No_of_Votes_against > minRequiredVotes) {
            return false;
        }
    }

    function setSafeZenCA(address _safeZenCA) public onlyOwner {
        safeZen = SafeZen(_safeZenCA);
    }
}
