//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {
    ISuperfluid,
    ISuperToken,
    ISuperAgreement,
    SuperAppDefinitions
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

import {
    IConstantFlowAgreementV1
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

import {
    CFAv1Library
} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFAv1Library.sol";

import {
    SuperAppBase
} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperAppBase.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Base64.sol";
import "./DateTime.sol";

contract SafeZen is ERC721Enumerable, Ownable, Pausable, SuperAppBase {
    using Strings for uint256;

    // SUPERFLUID PARAMETERS
    ISuperfluid private _host; // host
    IConstantFlowAgreementV1 private _cfa; // the stored constant flow agreement class address
    ISuperToken private _acceptedToken; // accepted token

    using CFAv1Library for CFAv1Library.InitData;
    CFAv1Library.InitData public cfaV1; //initialize cfaV1 variable

    mapping (uint256 => Policy) public policies;
    string private _baseURIextended;

    struct Policy {
        address policyHolder;
        uint256 policyID;
        string policyType;
        uint256 coverageAmount;
        string merchant;
        uint256 flowRate;
        uint256 purchaseTime;
        uint256 activatedTime;
        uint256 amountPaid;
        bool isActive;
        string textHue;
        string bgHue;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        ISuperfluid host,
        IConstantFlowAgreementV1 cfa,
        ISuperToken acceptedToken
    ) ERC721(_name, _symbol) {
        require(address(host) != address(0), "host is nil");
        require(address(cfa) != address(0), "cfa is nil");
        require(address(acceptedToken) != address(0), "superToken1 is nil");

        _host = host;
        _cfa = cfa;
        _acceptedToken = acceptedToken;

        uint256 configWord =
            SuperAppDefinitions.APP_LEVEL_FINAL |
            SuperAppDefinitions.BEFORE_AGREEMENT_CREATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_UPDATED_NOOP |
            SuperAppDefinitions.BEFORE_AGREEMENT_TERMINATED_NOOP;

        host.registerApp(configWord); // Enable your Super App to be registered within Superfluid host contract's Super App manifest
        cfaV1 = CFAv1Library.InitData(
        host,
        //here, we are deriving the address of the CFA using the host contract
        IConstantFlowAgreementV1(
            address(host.getAgreementClass(
                    keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1")
                ))
            )
        );
    }

    /**************************************************************************
     * INSURANCE POLICY FUNCTIONS
     *************************************************************************/
    function activatePolicy(uint256 _policyId) public {
        address storage currentPolicy = policies[_policyId];
        require(currentPolicy.policyHolder == msg.sender, "NOT POLICY HOLDER");
        require(currentPolicy.purchaseTime <= block.timestamp, "POLICY NOT ELIGIBLE FOR ACTIVATION");
        require(currentPolicy.isActive == false, "POLICY IS ALREADY ACTIVE");

        // Update policy's activatedtime and create new Superfluid flow from User to SmartContract 
        currentPolicy.activatedTime = block.timestamp;
        currentPolicy.isActive = true;
        _cfa.createFlow(_acceptedToken, address(this), currentPolicy.flowRate);
    }

    //TODO: figure out how flowrate works and calculation with default timestamp 
    function deactivatePolicy(uint256 _policyId) public {
        address storage currentPolicy = policies[_policyId];
        require(currentPolicy.policyHolder == msg.sender, "NOT POLICY HOLDER");
        require(currentPolicy.isActive == true, "POLICY IS NOT ACTIVATED");

        currentPolicy.isActive = false;
        currentPolicy.amountPaid += (block.timestamp - currentPolicy.activatedTime) * currentPolicy.flowRate;

        _cfa.deleteFlow(_acceptedToken, msg.sender, address(this));
    }


    function mint(string memory _policyType, uint256 _coverageAmount, string memory _merchant, int96 _flowRate, uint256 _purchaseTime) public payable {
        uint256 supply = totalSupply();

        Policy memory newPolicy = Policy(
            msg.sender,
            supply + 1, // tokenID
            _policyType,
            _coverageAmount,
            _merchant,
            _flowRate,
            _purchaseTime,
            0, // Active Duration
            false, // If policy is Active
            0, // amountPaid
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

    // buildImage
    function buildPolicy(uint256 _tokenId) public view returns(string memory) {
        // Retrieve policy 
        Policy memory currentPolicy = policies[_tokenId];
        
        // Formate date format for purchaseTime
        (uint256 startYear, uint256 startMonth, uint256 startDay) = DateTime.timestampToDate(currentPolicy.purchaseTime);
       
        // Calculating activeDuration of the policy
        uint256 activatedDuration = 0;
        if (currentPolicy.activatedTime != 0) { 
            activatedDuration = block.timestamp - currentPolicy.activatedTime;
        }
        
        // Calculating amountPaid for policy
        uint256 memory totalAmtPaid;
        if (currentPolicy.isActive) {
            totalAmtPaid = currentPolicy.amountPaid + (block.timestamp - currentPolicy.activatedTime) * currentPolicy.flowRate;
        } else {
            totalAmtPaid = currentPolicy.amountPaid;
        }

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
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="300" x="50%" fill="#000000">','Price: ',Strings.toString(currentPolicy.flowRate),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="350" x="50%" fill="#000000">','Purchase Date: ',Strings.toString(startDay),'/',Strings.toString(startMonth),'/',Strings.toString(startYear),'</text>'
        );
        bytes memory p4 = abi.encodePacked(
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="400" x="50%" fill="#000000">','Duration: ',Strings.toString(activatedDuration),'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="400" x="50%" fill="#000000">','isActive: ',currentPolicy.isActive,'</text>',
            '<text dominant-baseline="middle" text-anchor="middle" font-family="Noto Sans JP" font-size="20" y="400" x="50%" fill="#000000">','Amount Paid: ',totalAmtPaid.toString(),'</text>',
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
        
        // TODO: Deactivate Deactivate flow from old holder
        Policy storage currentPolicy = policies[tokenId];
        currentPolicy.policyHolder = to; 
    }
    
    // ================= OWNER FUNCTIONS ================= //
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    /**************************************************************************
     * SuperApp callbacks
     *************************************************************************/
    // Run before the call to the agreement contract contract will be run.
    // If there is logic inside this function, it will run before teh stream is created by the user
    function beforeAgreementCreated(
        ISuperToken superToken, // the protocol will pass the SUperToken that's being used in the call to the constant flow agreement contract here
        address agreementClass, // constant flow agreement contract
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        bytes calldata ctx // contains data about the call ot the constant flow agreement contract
    )
        external view override
        onlyHost
        onlyExpected(superToken, agreementClass)
        returns (bytes memory cbdata)
    {
        cbdata = _beforePlay(ctx); // TO EDIT
    }

    function afterAgreementCreated(
        ISuperToken /* superToken */,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        return _play(ctx, agreementClass, agreementId, cbdata); // TO EDIT
    }

    function beforeAgreementUpdated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        bytes calldata ctx
    )
        external view override
        onlyHost
        onlyExpected(superToken, agreementClass)
        returns (bytes memory cbdata)
    {
        cbdata = _beforePlay(ctx); // TO EDIT
    }

    function afterAgreementUpdated(
        ISuperToken /* superToken */,
        address agreementClass,
        bytes32 agreementId,
        bytes calldata /*agreementData*/,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        return _play(ctx, agreementClass, agreementId, cbdata); // TO EDIT
    }

    function beforeAgreementTerminated(
        ISuperToken superToken,
        address agreementClass,
        bytes32 /*agreementId*/,
        bytes calldata /*agreementData*/,
        bytes calldata /*ctx*/
    )
        external view override
        onlyHost
        returns (bytes memory cbdata)
    {
        // According to the app basic law, we should never revert in a termination callback
        if (!_isSameToken(superToken) || !_isCFAv1(agreementClass)) return abi.encode(true);
        return abi.encode(false);
    }

    ///
    function afterAgreementTerminated(
        ISuperToken /* superToken */,
        address /* agreementClass */,
        bytes32 /* agreementId */,
        bytes calldata agreementData,
        bytes calldata cbdata,
        bytes calldata ctx
    )
        external override
        onlyHost
        returns (bytes memory newCtx)
    {
        // According to the app basic law, we should never revert in a termination callback
        (bool shouldIgnore) = abi.decode(cbdata, (bool));
        if (shouldIgnore) return ctx;
        // note that msgSender can be either flow sender, receiver or liquidator
        // one must decode agreementData to determine who is the actual player
        (address player, ) = abi.decode(agreementData, (address, address));
        return _quit(player, ctx); // TO EDIT
    }

    function _isSameToken(ISuperToken superToken) private view returns (bool) {
        return address(superToken) == address(_acceptedToken);
    }

    function _isCFAv1(address agreementClass) private view returns (bool) {
        return ISuperAgreement(agreementClass).agreementType()
            == keccak256("org.superfluid-finance.agreements.ConstantFlowAgreement.v1");
    }

    modifier onlyHost() {
        require(msg.sender == address(_host), "LotterySuperApp: support only one host");
        _;
    }

    modifier onlyExpected(ISuperToken superToken, address agreementClass) {
        require(_isSameToken(superToken), "LotterySuperApp: not accepted token");
        require(_isCFAv1(agreementClass), "LotterySuperApp: only CFAv1 supported");
        _;
    }
}