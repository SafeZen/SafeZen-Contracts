//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./DateTime.sol";

contract SafeZen is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;
    
    mapping (uint256 => Policy) public policies;
    string private _baseURIextended;

    struct Policy {
        address policyHolder;
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

        Policy memory newPolicy = Policy(
            msg.sender,
            supply + 1,
            _policyType,
            _coverageAmount,
            _merchant,
            _price,
            _startTime,
            _endTime
        );

        policies[supply+1] = newPolicy;
        _safeMint(msg.sender, supply+1);
    }

    function randomNum(uint256 _mod, uint256 _seed, uint256 _salt) public view returns(uint256){
       uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;

       return num;
    }
    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2**(8*(19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = char(hi);
            s[2*i+1] = char(lo);            
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    // buildImage
    function buildPolicy(uint256 _tokenId) public view returns(string memory) {
        Policy memory currentPolicy = policies[_tokenId];
        (uint256 startYear, uint256 startMonth, uint256 startDay) = DateTime.timestampToDate(currentPolicy.startTime);
        (uint256 endYear, uint256 endMonth, uint256 endDay) = DateTime.timestampToDate(currentPolicy.endTime);
        console.log(toAsciiString(currentPolicy.policyHolder));

        bytes memory p1 = abi.encodePacked(
            '<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg">',
            '<rect y="0" fill="#00ffff" stroke="#000" x="-0.5" width="500" height="500"/>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="50" x="50%" fill="#000000">','PolicyHolder: 0x',toAsciiString(currentPolicy.policyHolder),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="100" x="50%" fill="#000000">','Provider: ',currentPolicy.merchant,'</text>'
        );
        bytes memory p2 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="150" x="50%" fill="#000000">','PolicyID: ',Strings.toString(currentPolicy.policyID),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="200" x="50%" fill="#000000">','PolicyType: ',currentPolicy.policyType,'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="250" x="50%" fill="#000000">','Coverage: ',Strings.toString(currentPolicy.coverageAmount),'</text>'
        );
        bytes memory p3 = abi.encodePacked( 
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="300" x="50%" fill="#000000">','Price: ',Strings.toString(currentPolicy.price),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="350" x="50%" fill="#000000">','Start Date: ',Strings.toString(startDay),'/',Strings.toString(startMonth),'/',Strings.toString(startYear),'</text>'
        );
        bytes memory p4 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="400" x="50%" fill="#000000">','Start Date: ',Strings.toString(endDay),'/',Strings.toString(endMonth),'/',Strings.toString(endYear),'</text>',
            '</svg>'
        );

        return Base64.encode(bytes.concat(p1,p2,p3,p4));
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);

        Policy storage currentPolicy = policies[tokenId];
        currentPolicy.policyHolder = to; 
        // do stuff before every transfer
        // e.g. check that vote (other than when minted) 
        // being transferred to registered candidate
    }
    
    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}