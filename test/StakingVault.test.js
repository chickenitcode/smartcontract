import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("StakingVault", function () {
  async function deployFixture() {
    const [owner, alice, treasury] = await ethers.getSigners();
    const CoffeeToken = await ethers.getContractFactory("CoffeeToken");
    const token = await CoffeeToken.deploy(owner.address, owner.address);
    await token.waitForDeployment();

    const StakingVault = await ethers.getContractFactory("StakingVault");
    const vault = await StakingVault.deploy(
      await token.getAddress(),
      await token.getAddress(),
      treasury.address
    );
    await vault.waitForDeployment();

    await token.mint(alice.address, ethers.parseUnits("1000", 18));
    await token.mint(owner.address, ethers.parseUnits("1000", 18));

    return { token, vault, owner, alice, treasury };
  }

  it("updates rewardPerToken over time", async function () {
    const { token, vault, owner, alice } = await deployFixture();

    await token.connect(alice).approve(await vault.getAddress(), ethers.parseUnits("100", 18));
    await vault.connect(alice).stake(ethers.parseUnits("100", 18), false);

    await token.connect(owner).approve(await vault.getAddress(), ethers.parseUnits("100", 18));
    await vault.connect(owner).notifyRewardAmount(
      await token.getAddress(),
      ethers.parseUnits("100", 18),
      100
    );

    await time.increase(10);
    const rpt = await vault.rewardPerToken(await token.getAddress());
    expect(rpt).to.be.gt(0n);
  });

  it("applies early-unstake penalty", async function () {
    const { token, vault, alice, treasury } = await deployFixture();

    await token.connect(alice).approve(await vault.getAddress(), ethers.parseUnits("100", 18));
    await vault.connect(alice).stake(ethers.parseUnits("100", 18), true);

    const treasuryBefore = await token.balanceOf(treasury.address);
    await vault.connect(alice).withdraw(ethers.parseUnits("100", 18));
    const treasuryAfter = await token.balanceOf(treasury.address);

    expect(treasuryAfter - treasuryBefore).to.equal(ethers.parseUnits("10", 18));
  });

  it("compounds rewards into stake", async function () {
    const { token, vault, owner, alice } = await deployFixture();

    await token.connect(alice).approve(await vault.getAddress(), ethers.parseUnits("100", 18));
    await vault.connect(alice).stake(ethers.parseUnits("100", 18), false);

    await token.connect(owner).approve(await vault.getAddress(), ethers.parseUnits("100", 18));
    await vault.connect(owner).notifyRewardAmount(
      await token.getAddress(),
      ethers.parseUnits("100", 18),
      100
    );

    await time.increase(10);
    const balanceBefore = await vault.balances(alice.address);
    await vault.connect(alice).compound();
    const balanceAfter = await vault.balances(alice.address);

    expect(balanceAfter).to.be.gt(balanceBefore);
  });
});
