// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol"; // library for access control
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; // library for reentrancy attack 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; // library for token standard NFT

contract ESCROW is ERC721, AccessControl, ReentrancyGuard{
    // define role
    bytes32 public constant BANK_ROLE = keccak256("BANK_ROLE");
    bytes32 public constant HERITAGE_ROLE = keccak256("HERITAGE_ROLE");
    bytes32 public constant SME_ROLE = keccak256("SME_ROLE");

    enum ProjectStatus{
        WAITING,
        FUNDED,
        COMPLETED
    }

    struct Project{
        string name; // project name
        uint256 fundingGoal; // amount of funding needed
        address payable beneficiary; //wallet address receive money -> address payable != address
        address funder;
        uint256 fundedAmount;
        ProjectStatus status;
        bytes32 evidenceHash;
    }

    // set project id only for each project and mapping 
    uint256 public nextProjectId = 1;
    mapping(uint256 => Project) public projects;

    // emit event
    event ProjectCreated(uint256 indexed projectId, string name, uint256 fundingGoal, address indexed beneficiary);
    event ProjectFunded(uint256 indexed projectId, address indexed funder, uint256 amount);
    event ProjectCompleted(uint256 indexed projectId, address indexed beneficiary, address indexed funder);
    event EvidenceSubmitted(uint256 indexed projectId, bytes32 evidenceHash);

    constructor(address bank) ERC721("Heritage ESG Certificate", "HESG"){
        _grantRole(DEFAULT_ADMIN_ROLE, bank);
        _grantRole(BANK_ROLE, bank);
    }

    // debug override multiple inheritance
    function supportsInterface(bytes4 interfaceID) public view override(ERC721, AccessControl) returns (bool){
        return super.supportsInterface(interfaceID);
    }

    // heritage unit registers a project that needs funding
    function createProject(
        string calldata name,
        uint256 fundingGoal,
        address payable beneficiary
    ) external onlyRole(HERITAGE_ROLE) returns (uint256 projectId){
        //condition
        require(bytes(name).length > 0, "Name required");
        require(fundingGoal > 0, "Funding Goal required");
        require(beneficiary != address(0), "Beneficiary required");// address(0) is null address

        //logic
        projectId = nextProjectId++;
        projects[projectId] = Project({
            name: name,
            fundingGoal: fundingGoal,
            beneficiary: beneficiary,
            funder: address(0),
            fundedAmount: 0,
            status: ProjectStatus.WAITING,
            evidenceHash: bytes32(0)
        });

        emit ProjectCreated(projectId, name, fundingGoal, beneficiary);
    }

    //SME funds the project; ETH is kept in escrow
    function fundProject(uint256 projectId) external payable onlyRole(SME_ROLE){
        Project storage project = projects[projectId];

        //condition for funding
        require(project.status == ProjectStatus.WAITING, "NOT WAITING");
        require(project.fundingGoal > 0, "Project missing funding goal");
        require(msg.value == project.fundingGoal, "Send exact funding");
        require(project.fundedAmount == 0, "Already funded");

        //logic
        project.funder = msg.sender; // address of SME -> msg.sender is show address of the account call that called the current function
        project.fundedAmount = msg.value;
        project.status = ProjectStatus.FUNDED;

        emit ProjectFunded(projectId, msg.sender, msg.value);
    }

    function submitEvidence(uint256 projectId, bytes32 evidenceHash) external onlyRole(HERITAGE_ROLE){
        Project storage project = projects[projectId];

        require(project.status == ProjectStatus.FUNDED, "NOT FUNDED");
        require(evidenceHash != bytes32(0), "Evidence required");

        project.evidenceHash = evidenceHash;

        emit EvidenceSubmitted(projectId, evidenceHash);
    }

    function approveAndDisburse(uint256 projectId) external onlyRole(BANK_ROLE) nonReentrant{
        Project storage project = projects[projectId];

        //condition
        require(project.status == ProjectStatus.FUNDED, "NOT FUNDED");
        require(project.evidenceHash != bytes32(0), "Evidence missing");

        project.status = ProjectStatus.COMPLETED; //logic the protect the contract from attacks

        (bool sent, ) = project.beneficiary.call{value: project.fundedAmount}("");
        require(sent, "Transfer failed");

        // mint NFT
        _safeMint(project.funder, projectId);

        emit ProjectCompleted(projectId, project.beneficiary, project.funder);

    }

}
