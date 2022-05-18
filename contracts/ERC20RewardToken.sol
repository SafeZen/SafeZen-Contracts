pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20RewardToken is ERC20 {
    constructor() ERC20("Safe Zen Rewards", "ZEN") {}

    function mint(address to, uint256 amount) internal {
        _mint(to, amount);
}
