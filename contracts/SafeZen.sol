//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./DateTime.sol";
import "./StakingContract.sol";
import "./GovContract.sol";

contract SafeZen is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;

    // MINTING
    // EXTRACTING METADATA 
    // SUPERFLUID -> FIGURE OUT TESTNET, FIGURE OUT SUPERTOKEN, 1. MINT, 2. START STREAM 3. CHECK ISACTIVE() 
    // GOVERNANCE -> BEING ABLE TO CLAIM
    // STAKING -> USER WILL BE ABLE TO CLAIM X AMOUNT OF TOKEN (OUR OWN TOKEN) FROM STAKING CONTRACT

    // SUPERFLUID PARAMETERS
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken public _acceptedToken; // accepted token

    StakingContract private stakingContract; 
    GovContract private govContract;

    mapping (uint256 => Policy) public policies;

    struct Policy {
        address policyHolder;
        uint256 policyID; // TokenID = PolicyID
        string policyType; // VEHICLE-CAR, VEHICLE-VAN
        uint256 coverageAmount; 
        string merchant;
        int96 minFlowRate;
        uint256 purchaseTime;
        bool isActive;
        uint256 amountPaid;
        uint256 baseAmount; // Amount excluding the minFlowRate during activation
        string textHue;
        string bgHue;
    }
 
    constructor(
        string memory _name,
        string memory _symbol,
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken,
        address stakingCA,
        address govCA
    ) ERC721(_name, _symbol) {
        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;

        assert(address(_host) != address(0));
        assert(address(_cfa) != address(0));
        assert(address(_acceptedToken) != address(0));

        stakingContract = StakingContract(stakingCA);
        govContract = GovContract(govCA);
    }

    function mint(string memory _policyType, uint256 _coverageAmount, string memory _merchant, int96 _minFlowRate, uint256 _purchaseTime, uint256 _baseAmount) public  payable{
        uint256 supply = totalSupply();

        Policy memory newPolicy = Policy(
            msg.sender,
            supply + 1, // tokenID
            _policyType,
            _coverageAmount,
            _merchant,
            _minFlowRate,
            _purchaseTime,
            false, // If policy is Active
            0, // Amount Paid
            _baseAmount,
            randomNum(361, block.difficulty, supply).toString(),
            randomNum(361, block.timestamp, supply).toString()
        );

        policies[supply+1] = newPolicy;
        _safeMint(msg.sender, supply+1);
    }


    /**************************************************************************
     * UTIL FUNCTIONS
     *************************************************************************/
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

    // Build the on-chain SVG for the policy
    function buildPolicy(uint256 _tokenId) public view returns(string memory) {
        // Retrieve policy 
        Policy memory currentPolicy = policies[_tokenId];
        
        // Formate date format for purchaseTime
        (uint256 purchaseYear, uint256 purchaseMonth, uint256 purchaseDay) = DateTime.timestampToDate(currentPolicy.purchaseTime);

        //TODO: fix the isActive function and use that in the on-chain svg
        // convert bool to string for isActive
        // string memory isPolicyActive = isActive(_tokenId) ? "True":"False";
        

        // ========== BUILDING POLICY ON-CHAIN SVG IMAG ========== /
        bytes memory p1 = abi.encodePacked(
            '<svg width="500" height="500" xmlns="http://www.w3.org/2000/svg">',
            '<rect y="0" fill="hsl(',currentPolicy.bgHue,',100%,80%)" stroke="#000" x="-0.5" width="500" height="500"/>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="14" y="50" x="50%" fill="#000000">','PolicyHolder: 0x',toAsciiString(currentPolicy.policyHolder),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="100" x="50%" fill="#000000">','Provider: ',currentPolicy.merchant,'</text>'
        );
        bytes memory p2 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="150" x="50%" fill="#000000">','PolicyID: ',Strings.toString(currentPolicy.policyID),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="200" x="50%" fill="#000000">','PolicyType: ',currentPolicy.policyType,'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="250" x="50%" fill="#000000">','Coverage: ',Strings.toString(currentPolicy.coverageAmount),'</text>'
        );
        bytes memory p3 = abi.encodePacked( 
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="300" x="50%" fill="#000000">','Price: ',Strings.toString(uint96(currentPolicy.minFlowRate)),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="350" x="50%" fill="#000000">','Purchase Date: ',Strings.toString(purchaseDay),'/',Strings.toString(purchaseMonth),'/',Strings.toString(purchaseYear),'</text>'
        );
        bytes memory p4 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="400" x="50%" fill="#000000">','isActive: ','True','</text>',
            '</svg>'
        );

        return Base64.encode(bytes.concat(p1,p2,p3,p4));
    }

    // build Metadata to return for TokenURI, returns the attributes of the policy as well
    function buildMetadata(uint256 _tokenId) public view returns(string memory) {
        Policy memory currentPolicy = policies[_tokenId];
        bytes memory m1 = abi.encodePacked(
            '{"name":"',
            currentPolicy.policyType,
            '", "description":"',
            'Insurance policy purchased from SafeZen, Pay as you Go!',
            '", "image": "',
            'data:image/svg+xml;base64,',
            buildPolicy(_tokenId),
            // adding policyHolder
            '", "attributes": [{"trait_type":"PolicyHolder",',
            '"value":"0x',
            toAsciiString(currentPolicy.policyHolder), 
            '"},',
            // policyID
            '{"trait_type":"PolicyID",',
            '"value":"',
            Strings.toString(currentPolicy.policyID),
            '"},'
        );

        bytes memory m2 = abi.encodePacked(// coverageAmount
            '{"trait_type":"CoverageAmount",',
            '"value":"',
            Strings.toString(currentPolicy.coverageAmount),
            '"},',
            // minFlowRate
            '{"trait_type":"MinFlowRate",',
            '"value":"',
            Strings.toString(uint96(currentPolicy.minFlowRate)),
            '"},',
            // purchaseTime
            '{"trait_type":"PurchaseTime",',
            '"value":"',
            Strings.toString(currentPolicy.purchaseTime),
            '"},'
        );

        bytes memory m3 = abi.encodePacked(// policyID
            '{"trait_type":"Active",',
            '"value":"',
            'False', // TODO: update with the isActive() function after debug
            '"},',
             // policyID
            '{"trait_type":"AmountPaid",',
            '"value":"',
            Strings.toString(currentPolicy.amountPaid), 
            '"},',
            // policyID
            '{"trait_type":"BaseAmount",',
            '"value":"',
            Strings.toString(currentPolicy.baseAmount), 
            '"},',
            ']}');
        return string(abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(bytes.concat(m1,m2,m3))));
    }

    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        return buildMetadata(_tokenId);
    }

    //TODO: getFlow is returning error with no error message, check from superFluid discord
    function isActive(uint256 _policyId) public view returns(bool) {
        (, int96 flowrate, , ) = _cfa.getFlow(  // gets details on whether the policy owner is streaming or not
            _acceptedToken, // superToken used
            getHolder(_policyId), // sender of the flow
            address(this) // receiver of the flow
        );
        return flowrate >= policies[_policyId].minFlowRate; // is flowrate more than the minimum required?
    }

    // getPolicies: do this off-chain with moralis

    // Get the current holder of a specific policy
    function getHolder(uint256 _policyID) public view returns (address) {
        Policy memory currentPolicy = policies[_policyID];
        address holder = currentPolicy.policyHolder;
        return holder;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        
        Policy storage currentPolicy = policies[tokenId];
        // Change policy holder wallet address
        currentPolicy.policyHolder = to; 
        // Reset necessary parameters for the policy
        currentPolicy.isActive = false;
    }
    
    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}




