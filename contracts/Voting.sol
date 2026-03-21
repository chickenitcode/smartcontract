// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {
    struct Candidate {
        string name;
        uint256 voteCount;
    }

    Candidate[] public candidates;
    mapping(address => bool) public hasVoted;
    bool public votingStatus;

    event CandidateAdded(uint256 indexed candidateId, string name);
    event VotingStatusChanged(bool isOpen);
    event Voted(address indexed voter, uint256 indexed candidateId);

    constructor() Ownable(msg.sender) {}

    function addCandidate(string calldata name) external onlyOwner {
        require(bytes(name).length > 0, "Name required");
        candidates.push(Candidate({name: name, voteCount: 0}));
        emit CandidateAdded(candidates.length - 1, name);
    }

    function setVotingStatus(bool isOpen) external onlyOwner {
        votingStatus = isOpen;
        emit VotingStatusChanged(isOpen);~
    }

    function vote(uint256 candidateId) external {
        require(votingStatus, "Voting closed");
        require(!hasVoted[msg.sender], "Already voted");
        require(candidateId < candidates.length, "Invalid candidate");

        hasVoted[msg.sender] = true;
        candidates[candidateId].voteCount += 1;

        emit Voted(msg.sender, candidateId);
    }
}
