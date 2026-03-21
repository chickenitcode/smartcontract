## Staking Contract (Advanced) Guide

This guide describes a multi-reward staking vault with reward-per-token accounting, timelock multiplier, early-unstake penalty, and auto-compound.

### 1) Reward Per Token accounting
Use the standard formula to avoid per-user loops:

- `rewardPerTokenStored` tracks cumulative rewards per staked token.
- When time advances or reward is added, update:
  - `rewardPerTokenStored += (rewardRate * (timeDelta) * 1e18) / totalStaked`
  - Store `lastUpdateTime`
- For each user:
  - `rewards[account] += (balance * (rewardPerTokenStored - userRewardPerTokenPaid[account])) / 1e18`
  - Update `userRewardPerTokenPaid[account]`

### 2) Timelock & multiplier
- Allow users to stake with a lock duration.
- If user locks for 3 months, apply multiplier `1.5x` on rewards.
- Store per-user multiplier and lock end time.

### 3) Early unstake penalty
- If user unstakes before lock end, apply 10% penalty on principal.
- Send penalty to a treasury address or keep it in the contract.

### 4) Auto-compound
- Provide a function that claims reward and adds it to staked balance.
- This should call the same internal update flow to keep accounting correct.

### 5) Precision
- Use `1e18` for reward precision.
- Always update reward state before balance changes.

### 6) Test plan
- Use `evm_mine` to simulate block time passing.
- Verify `rewardPerTokenStored` increases as expected.
- Test multiplier path (3-month lock).
- Test early unstake: user receives 90%, penalty retained.
- Test auto-compound increases stake without breaking rewards.

