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
    // TODO: Documentation  
    mapping(uint256 => bool) hasClaimedRewards;

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        
    }

    event TokenTransfer(address indexed _to, uint256 _rewardTokensCount);
    error TransactionFailure();

    function eligibleRewardTokenCount(uint256 _tokenID)
        public
        view
        returns (uint256 _rewardTokenCounts)
    {
        (,uint256 purchaseTime, uint256 baseAmount, bool hasClaimed) = safeZen.getRewardData(_tokenID);

        if (
            uint256(block.timestamp) <
            (purchaseTime + 7 days)
        ) {
            _rewardTokenCounts = (baseAmount * 10) / 100;
        } else if (
            (uint256(block.timestamp) <
                (purchaseTime + 30 days)) &&
            (uint256(block.timestamp) >
                (purchaseTime + 7 days))
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

    function claimRewardTokens(uint256 _tokenID) public {
        (address policyHolder,,,) = safeZen.getRewardData(_tokenID);
        require(policyHolder == msg.sender);

        uint256 rewardTokenAmt = eligibleRewardTokenCount(_tokenID);
        _mint(msg.sender, rewardTokenAmt);
        hasClaimedRewards[_tokenID] = true; //makes sure that each policy can only be claimed once

        emit TokenTransfer(policyHolder, rewardTokenAmt);
    }
    
    function setSafeZenCA(address _safeZenCA) public onlyOwner{
        safeZen = SafeZen(_safeZenCA);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
