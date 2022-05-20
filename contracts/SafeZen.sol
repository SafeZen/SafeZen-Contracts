//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Base64.sol";
import "./DateTime.sol";
import "./StakingContract.sol";
import "./Governance.sol";

/// @title SafeZen NFT contract with Superfluid
/// @author Sean (@theLewBei)
/// @notice The project allows users to be able to mint a specific policy that they need and stream only when they need to. An aggregated insurance provider platform, each Insurance policy requires a baseAmount and also a minFlowRate. The baseAmount is automatically staked when the user buys a policy through us and it generates our own  ERC20 Utility Token. This token can then be redeemed by the user (different % depending on whether they have claimed the insurance): Token can be used to subsidize future policy purchases
/// @dev Only possible for a single policy for each wallet right now
contract SafeZen is ERC721Enumerable, Ownable, Pausable, ReentrancyGuard {
    using Strings for uint256;

    // SUPERFLUID PARAMETERS
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken public _acceptedToken; // accepted token

    address govContractCA;
    StakingContract private stakingContract; 
    Governance private govContract;

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
        bool hasClaimed;
        uint256 amountPaid;
        uint256 baseAmount; // Amount excluding the minFlowRate during activation
        string textHue;
        string bgHue;
    }
    
    /// @notice Constructor for ERC721
    /// @param _name Name of the ERC721 token
    /// @param _symbol Symbol of the ERC721 token
    /// @param host Superfluid host contract ( reference from Superfluid Docs )
    /// @param cfa Superfluid Central Flow Agreement Contract ( reference from Superfluid Docs )
    /// @param acceptedToken superToken that is accepted for stream ( reference from Superfluid Docs )
    /// @param stakingCA contract address of the staking contract that handles yield
    /// @param govCA contract address of the governance contract that handles the claim submission
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
        govContract = Governance(govCA);
    }

    /// @notice Constructor for ERC721
    /// @param _policyType A combination of the category + specific type (e.g. VEHICLE-CAR)
    /// @param _coverageAmount Amount that user wants to be insured
    /// @param _merchant Provider for the insurance package 
    /// @param _minFlowRate Min charges per second calculated from per day on the frontend
    /// @param _baseAmount Min fee that nuser needs to pay to own the policy (varies with coverage)
    function mint(string memory _policyType, uint256 _coverageAmount, string memory _merchant, int96 _minFlowRate, uint256 _baseAmount) public  payable{
        //TODO: user sends enought ETH for the baseAmount
        uint256 supply = totalSupply();

        //TODO: Add hasClaimed for each policy
        Policy memory newPolicy = Policy(
            msg.sender,
            supply + 1, // tokenID
            _policyType,
            _coverageAmount,
            _merchant,
            _minFlowRate,
            block.timestamp, // purchaseTime
            false, // If policy is Active
            false,
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
    // @dev Generates a random number (used for BG hue and text hue)
    function randomNum(uint256 _mod, uint256 _seed, uint256 _salt) public view returns(uint256){
       uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % _mod;

       return num;
    }
    
    // @dev Converts address type to string, remember to add 0x infront
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

    // @dev Helper function used in toAsciiString
    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    /// @notice Builds the on-chain SVG for the specific policy
    /// @param _tokenId Policy ID which will also be the NFT token ID
    /// @dev can change this to internal 
    function buildPolicy(uint256 _tokenId) public view returns(string memory) {
        // Retrieve policy 
        Policy memory currentPolicy = policies[_tokenId];
        
        // Formate date format for purchaseTime
        (uint256 purchaseYear, uint256 purchaseMonth, uint256 purchaseDay) = DateTime.timestampToDate(currentPolicy.purchaseTime);

        // convert bool to string for isActive
        string memory isPolicyActive = isActive(_tokenId) ? "True":"False";
        

        // ========== BUILDING POLICY ON-CHAIN SVG IMAGE ========== /
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
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="400" x="50%" fill="#000000">','isActive: ',isPolicyActive,'</text>',
            '</svg>'
        );

        return Base64.encode(bytes.concat(p1,p2,p3,p4));
    }

    /// @notice Builds the metadata required in accordance ot Opensea requirements
    /// @param _tokenId Policy ID which will also be the NFT token ID
    /// @dev Can change public to internal
    function buildMetadata(uint256 _tokenId) public view returns(string memory) {
        Policy memory currentPolicy = policies[_tokenId];
        string memory isPolicyActive = isActive(_tokenId) ? "True":"False";

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
            isPolicyActive,
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
            '"}',
            ']}');
        return string(abi.encodePacked(
        'data:application/json;base64,',
        Base64.encode(bytes.concat(m1,m2,m3))));
    }

    /// @notice Calls on BuildMetadata -> BuildPolicy and return required format 
    /// @param _tokenId Policy ID which will also be the NFT token ID
    function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
        require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
        return buildMetadata(_tokenId);
    }

    /// @notice Retrieves the active state of the policy based on incoming flowRate from holder 
    /// @param _policyId Policy ID which will also be the NFT token ID
    /// @dev We are only able to handle 1 policy per holder, transfers will not terminate stream if the user did not manually delete flow but once the holder changes it should be reflected as non-active since there is no flow from the new holder
    function isActive(uint256 _policyId) public view returns(bool) {

        (, int96 flowrate, , ) = _cfa.getFlow(  // gets details on whether the policy owner is streaming or not
            _acceptedToken, // superToken used
            getHolder(_policyId), // sender of the flow
            address(this) // receiver of the flow
        );
        return flowrate >= policies[_policyId].minFlowRate; 
    }

    /// @notice Retrieves the wallet address of the policy holder
    /// @param _policyId Policy ID which will also be the NFT token ID
    function getHolder(uint256 _policyId) public view returns (address) {
        Policy memory currentPolicy = policies[_policyId];
        address holder = currentPolicy.policyHolder;
        return holder;
    }

    function getRewardData(uint256 _policyId) public view returns (address policyHolder, uint256 purchaseTime, uint256 baseAmount, bool hasClaimed) {
        purchaseTime = policies[_policyId].purchaseTime;
        baseAmount = policies[_policyId].baseAmount;
        hasClaimed = policies[_policyId].hasClaimed;
        policyHolder = policies[_policyId].policyHolder;
    }

    function sendInsuranceClaim(address _receiver, uint256 _amount) external {
        require(msg.sender == govContractCA, "NOT GOV CONTRACT");

        (bool success, ) = _receiver.call{ value: _amount }("");
        require(success, "INSURANCE CLAIM TRANSFER FAILED");
    }

    /// @dev override logic to change policy holder when NFT is transferred between wallets
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
        
        Policy storage currentPolicy = policies[tokenId];
        // Change policy holder wallet address
        currentPolicy.policyHolder = to; 
    }
    
    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
}




