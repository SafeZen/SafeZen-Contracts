//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SafeZen.sol";
import "./ERC20RewardToken.sol";

contract Reward is Pausable, ReentrancyGuard {
    IERC20 public rewardToken;

    // TODO: Documentation

    constructor(address _rewardToken) {
        rewardToken = IERC20(_rewardToken);
    }

    event TokenTransfer(address indexed _to, uint256 _rewardTokensCount);
    error TransactionFailure();

    function eligibleRewardTokenCount(uint256 _tokenID)
        internal
        returns (uint256 _rewardTokenCounts)
    {
        require(policies[_tokenID].policyHolder == msg.sender);
        if (
            uint256(block.timestamp) <
            (policies[_tokenID].purchaseTime + 7 days)
        ) {
            _rewardTokenCounts = (policies[_tokenID].baseAmount * 10) / 100;
        } else if (
            (uint256(block.timestamp) <
                (policies[_tokenID].purchaseTime + 30 days)) &&
            (uint256(block.timestamp) >
                (policies[_tokenID].purchaseTime + 7 days))
        ) {
            _rewardTokenCounts = (policies[_tokenID].baseAmount * 20) / 100;
        } else {
            _rewardTokenCounts = policies[_tokenID].baseAmount / 2;
        }
        // hasClaimed needs to be defined in SafeZen.sol in the Policy struct section.
        if (_hasClaimed) {
            _rewardTokenCounts = _rewardTokenCounts / 2;
        }

        return _rewardTokenCounts;
    }

    function claimRewardTokens(uint256 _tokenID) external {
        _tokenCount = eligibleRewardTokenCount(_tokenID);
        bool isSuccess = rewardToken.mint(
            policies[_tokenID].policyHolder,
            _tokenCount
        );
        if (!isSuccess) {
            revert TransactionFailure();
        }
        emit TokenTransfer(policies[_tokenID].policyHolder, _tokenCount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}
