//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";

contract SafeZen is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;
    
    string[] public policyTypes = ["Car","Medical","Travel"];

    mapping (uint256 => Policy) public policies;
    mapping(address => Policy[]) private AddressToPolicies;
    string private _baseURIextended;

    struct Policy {

        uint256 policyID;
        string policyType;
        uint256 coverageAmount;
        string merchant;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
    }

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {

    }
    
    function mint(string memory _policyType, uint256 _coverageAmount, string memory _merchant, uint256 _price, uint256 _startTime, uint256 _endTime) public payable {
        uint256 supply = totalSupply();
        require(supply + 1 <= 1000);

        Policy memory newPolicy = Policy(
            supply + 1,
            _policyType,
            _coverageAmount,
            _merchant,
            _price,
            _startTime,
            _endTime
        );

        policies[supply+1] = newPolicy;
        AddressToPolicies[msg.sender].push(newPolicy); 

        _safeMint(msg.sender, supply+1);
    }

    function randomNum(uint256 _mod, uint256 _seed, uint256 _salt) public view returns(uint256){
       uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;

       return num;
    }

    // buildImage
    function buildPolicy(uint256 _tokenId) public view returns(string memory) {
        Policy memory currentPolicy = policies[_tokenId];

        bytes memory p1 = abi.encodePacked('<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg">',
              '<rect y="0" fill="#00ffff" stroke="#000" x="-0.5" width="500" height="500"/>',
              '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="50" x="50%" fill="#000000">','Provider: ',currentPolicy.merchant,'</text>');
        bytes memory p2 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="100" x="50%" fill="#000000">','PolicyID: ',Strings.toString(currentPolicy.policyID),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="150" x="50%" fill="#000000">','PolicyType: ',currentPolicy.policyType,'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="200" x="50%" fill="#000000">','Coverage: ',Strings.toString(currentPolicy.coverageAmount),'</text>'
        );
        bytes memory p3 = abi.encodePacked( 
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="250" x="50%" fill="#000000">','Price: ',Strings.toString(currentPolicy.price),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="300" x="50%" fill="#000000">','Start Date: ',Strings.toString(currentPolicy.startTime),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="350" x="50%" fill="#000000">','End Date: ',Strings.toString(currentPolicy.endTime),'</text>',
            '</svg>'
        );
        return Base64.encode(bytes.concat(p1,p2,p3));
    }

    // build metadata
    function buildMetadata(uint256 _tokenId) public view returns(string memory) {
        Policy memory currentPolicy = policies[_tokenId];

        return string(abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(bytes(abi.encodePacked(
            '{"name":"',
            currentPolicy.policyType,
            '", "description":"',
            currentPolicy.merchant,
            '", "image": "',
            'data:image/svg+xml;base64,',
            buildPolicy(_tokenId),
            '"}'
        )))));
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        return buildMetadata(_tokenId);
    }

    // getPolicies: do this off-chain with moralis

    function getHolder(uint256 _policyID) public view returns (Policy memory) {
        return policies[_policyID];
    }

    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}