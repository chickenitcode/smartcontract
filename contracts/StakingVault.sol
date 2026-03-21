// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakingVault is Ownable {
    using SafeERC20 for IERC20;

    struct RewardData {
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
        uint256 periodFinish;
    }

    uint256 public constant PRECISION = 1e18;
    uint256 public constant THREE_MONTHS = 90 days;
    uint256 public constant MULTIPLIER_LOCK = 15e17; // 1.5x
    uint256 public constant MULTIPLIER_DEFAULT = 1e18; // 1.0x
    uint256 public constant PENALTY_BPS = 1000; // 10%

    IERC20 public immutable stakingToken;
    address public immutable treasury;
    address public immutable primaryRewardToken;

    uint256 public totalSupply;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public lockEnd;
    mapping(address => uint256) public rewardMultiplier;

    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;
    mapping(address => RewardData) public rewardData;
    mapping(address => mapping(address => uint256)) public userRewardPerTokenPaid;
    mapping(address => mapping(address => uint256)) public rewards;

    event Staked(address indexed user, uint256 amount, bool locked);
    event Withdrawn(address indexed user, uint256 amount, uint256 penalty);
    event RewardAdded(address indexed token, uint256 amount, uint256 duration);
    event RewardPaid(address indexed user, address indexed token, uint256 reward);
    event Compounded(address indexed user, uint256 amount);

    constructor(address _stakingToken, address _primaryRewardToken, address _treasury)
        Ownable(msg.sender)
    {
        require(_stakingToken != address(0), "Stake token required");
        require(_primaryRewardToken != address(0), "Reward token required");
        require(_treasury != address(0), "Treasury required");

        stakingToken = IERC20(_stakingToken);
        primaryRewardToken = _primaryRewardToken;
        treasury = _treasury;

        rewardTokens.push(_primaryRewardToken);
        isRewardToken[_primaryRewardToken] = true;
    }

    modifier updateReward(address account) {
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address token = rewardTokens[i];
            RewardData storage data = rewardData[token];
            data.rewardPerTokenStored = rewardPerToken(token);
            data.lastUpdateTime = lastTimeRewardApplicable(token);
            if (account != address(0)) {
                rewards[account][token] = earned(account, token);
                userRewardPerTokenPaid[account][token] = data.rewardPerTokenStored;
            }
        }
        _;
    }

    function addRewardToken(address token) external onlyOwner {
        require(token != address(0), "Token required");
        require(!isRewardToken[token], "Already added");
        isRewardToken[token] = true;
        rewardTokens.push(token);
    }

    function lastTimeRewardApplicable(address token) public view returns (uint256) {
        uint256 finish = rewardData[token].periodFinish;
        return block.timestamp < finish ? block.timestamp : finish;
    }

    function rewardPerToken(address token) public view returns (uint256) {
        RewardData storage data = rewardData[token];
        if (totalSupply == 0) {
            return data.rewardPerTokenStored;
        }
        uint256 timeDelta = lastTimeRewardApplicable(token) - data.lastUpdateTime;
        return data.rewardPerTokenStored + ((timeDelta * data.rewardRate * PRECISION) / totalSupply);
    }

    function earned(address account, address token) public view returns (uint256) {
        uint256 multiplier = rewardMultiplier[account] == 0 ? MULTIPLIER_DEFAULT : rewardMultiplier[account];
        uint256 balanceWithMultiplier = (balances[account] * multiplier) / PRECISION;
        uint256 accrued = (balanceWithMultiplier * (rewardPerToken(token) - userRewardPerTokenPaid[account][token])) /
            PRECISION;
        return rewards[account][token] + accrued;
    }

    function stake(uint256 amount, bool lockForThreeMonths) external updateReward(msg.sender) {
        require(amount > 0, "Amount required");

        totalSupply += amount;
        balances[msg.sender] += amount;
        stakingToken.safeTransferFrom(msg.sender, address(this), amount);

        if (lockForThreeMonths) {
            uint256 newLockEnd = block.timestamp + THREE_MONTHS;
            if (newLockEnd > lockEnd[msg.sender]) {
                lockEnd[msg.sender] = newLockEnd;
            }
            rewardMultiplier[msg.sender] = MULTIPLIER_LOCK;
        } else if (lockEnd[msg.sender] < block.timestamp) {
            rewardMultiplier[msg.sender] = MULTIPLIER_DEFAULT;
        }

        emit Staked(msg.sender, amount, lockForThreeMonths);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) {
        require(amount > 0, "Amount required");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        balances[msg.sender] -= amount;
        totalSupply -= amount;

        uint256 penalty = 0;
        if (lockEnd[msg.sender] > block.timestamp) {
            penalty = (amount * PENALTY_BPS) / 10000;
            if (penalty > 0) {
                stakingToken.safeTransfer(treasury, penalty);
            }
        }

        uint256 payout = amount - penalty;
        stakingToken.safeTransfer(msg.sender, payout);

        emit Withdrawn(msg.sender, payout, penalty);
    }

    function getReward(address token) external updateReward(msg.sender) {
        require(isRewardToken[token], "Invalid reward token");
        uint256 reward = rewards[msg.sender][token];
        if (reward > 0) {
            rewards[msg.sender][token] = 0;
            IERC20(token).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, token, reward);
        }
    }

    function compound() external updateReward(msg.sender) {
        require(primaryRewardToken == address(stakingToken), "Reward not stake token");
        uint256 reward = rewards[msg.sender][primaryRewardToken];
        require(reward > 0, "No reward");

        rewards[msg.sender][primaryRewardToken] = 0;
        balances[msg.sender] += reward;
        totalSupply += reward;

        emit Compounded(msg.sender, reward);
    }

    function notifyRewardAmount(address token, uint256 reward, uint256 duration)
        external
        onlyOwner
        updateReward(address(0))
    {
        require(isRewardToken[token], "Invalid reward token");
        require(reward > 0, "Reward required");
        require(duration > 0, "Duration required");

        RewardData storage data = rewardData[token];
        if (block.timestamp >= data.periodFinish) {
            data.rewardRate = reward / duration;
        } else {
            uint256 remaining = data.periodFinish - block.timestamp;
            uint256 leftover = remaining * data.rewardRate;
            data.rewardRate = (reward + leftover) / duration;
        }

        data.lastUpdateTime = block.timestamp;
        data.periodFinish = block.timestamp + duration;
        IERC20(token).safeTransferFrom(msg.sender, address(this), reward);

        emit RewardAdded(token, reward, duration);
    }
}
