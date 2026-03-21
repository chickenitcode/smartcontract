// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Crowdfunding is ReentrancyGuard {
    struct Campaign {
        address creator;
        uint256 targetAmount;
        uint256 deadline;
        uint256 currentAmount;
        bool claimed;
    }

    uint256 public nextCampaignId = 1;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    event CampaignCreated(uint256 indexed campaignId, address indexed creator, uint256 targetAmount, uint256 deadline);
    event Contributed(uint256 indexed campaignId, address indexed contributor, uint256 amount);
    event Claimed(uint256 indexed campaignId, address indexed creator, uint256 amount);
    event Refunded(uint256 indexed campaignId, address indexed contributor, uint256 amount);

    function createCampaign(uint256 targetAmount, uint256 durationSeconds) external returns (uint256 campaignId) {
        require(targetAmount > 0, "Target required");
        require(durationSeconds > 0, "Duration required");

        campaignId = nextCampaignId++;
        campaigns[campaignId] = Campaign({
            creator: msg.sender,
            targetAmount: targetAmount,
            deadline: block.timestamp + durationSeconds,
            currentAmount: 0,
            claimed: false
        });

        emit CampaignCreated(campaignId, msg.sender, targetAmount, block.timestamp + durationSeconds);
    }

    function contribute(uint256 campaignId) external payable {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.creator != address(0), "Invalid campaign");
        require(block.timestamp <= campaign.deadline, "Campaign ended");
        require(msg.value > 0, "Amount required");

        campaign.currentAmount += msg.value;
        contributions[campaignId][msg.sender] += msg.value;

        emit Contributed(campaignId, msg.sender, msg.value);
    }

    function claim(uint256 campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.creator == msg.sender, "Only creator");
        require(!campaign.claimed, "Already claimed");
        require(campaign.currentAmount >= campaign.targetAmount, "Target not reached");

        campaign.claimed = true;
        uint256 amount = campaign.currentAmount;
        (bool sent, ) = payable(msg.sender).call{value: amount}("");
        require(sent, "Transfer failed");

        emit Claimed(campaignId, msg.sender, amount);
    }

    function withdrawRefund(uint256 campaignId) external nonReentrant {
        Campaign storage campaign = campaigns[campaignId];
        require(campaign.creator != address(0), "Invalid campaign");
        require(block.timestamp > campaign.deadline, "Campaign active");
        require(campaign.currentAmount < campaign.targetAmount, "Target reached");

        uint256 contributed = contributions[campaignId][msg.sender];
        require(contributed > 0, "Nothing to refund");

        contributions[campaignId][msg.sender] = 0;
        campaign.currentAmount -= contributed;
        (bool sent, ) = payable(msg.sender).call{value: contributed}("");
        require(sent, "Transfer failed");

        emit Refunded(campaignId, msg.sender, contributed);
    }
}
