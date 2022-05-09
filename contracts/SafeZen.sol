//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Base64.sol";

contract SafeZen is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    address public DefiContract; // TO UPDATE with LENDING PROTOCOL CONTRACT
    mapping (uint256 => string) private _tokenURIs;
    mapping(address => uint256) private AddressToPolicy;
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
    
    function mint() public payable {
        uint256 supply = totalSupply();
        require(supply + 1 <= 1000);

        _safeMint(msg.sender, supply+1);
    }

    function randomNum(uint256 _mod, uint256 _seed, uint256 _salt) public view returns(uint256){
       uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;

       return num;
    }

    // buildImage
    function buildPolicy() public view returns(string memory) {
        return Base64.encode(bytes(
            abi.encodePacked(
              '<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg">',
              '<rect height="500" width="501" y="0" x="-0.5" stroke="#000" fill="#00ffff"/>',
              '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="24" y="50%" x="50%" fill="#000000">Safe Zen</text>',
              '</svg>'
          ))); 
    }

    // BuyPolicy function

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }   

    // setTokenURI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(bytes(abi.encodePacked(
                '{"name":"',
                "REPLACE",
                '", "description":"',
                "REPLACE",
                '", "image": "',
                'data:image/svg+xml;base64,',
                buildPolicy(),
                '"}'
            )))
        ));
    }

    // Should return 
    function getPolicies(address _holder) public returns (uint256[] memory) {

    }


    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}