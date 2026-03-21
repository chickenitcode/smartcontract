import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Crowdfunding", function () {
  const target = ethers.parseEther("10");
  const duration = 7 * 24 * 60 * 60;

  async function deployFixture() {
    const [creator, donor] = await ethers.getSigners();
    const Crowdfunding = await ethers.getContractFactory("Crowdfunding");
    const contract = await Crowdfunding.deploy();
    await contract.waitForDeployment();
    return { contract, creator, donor };
  }

  it("allows refunds after deadline when target not reached", async function () {
    const { contract, creator, donor } = await deployFixture();
    const tx = await contract.connect(creator).createCampaign(target, duration);
    await tx.wait();
    const campaignId = (await contract.nextCampaignId()) - 1n;

    await contract.connect(donor).contribute(campaignId, { value: ethers.parseEther("8") });
    await time.increase(duration + 1);

    const donorBalanceBefore = await ethers.provider.getBalance(donor.address);
    await contract.connect(donor).withdrawRefund(campaignId);
    const donorBalanceAfter = await ethers.provider.getBalance(donor.address);

    expect(donorBalanceAfter).to.be.gt(donorBalanceBefore);
    expect(await contract.contributions(campaignId, donor.address)).to.equal(0n);
  });

  it("allows creator to claim when target reached", async function () {
    const { contract, creator } = await deployFixture();
    const tx = await contract.connect(creator).createCampaign(target, duration);
    await tx.wait();
    const campaignId = (await contract.nextCampaignId()) - 1n;

    await contract.connect(creator).contribute(campaignId, { value: target });
    const creatorBalanceBefore = await ethers.provider.getBalance(creator.address);

    await contract.connect(creator).claim(campaignId);
    const creatorBalanceAfter = await ethers.provider.getBalance(creator.address);

    expect(creatorBalanceAfter).to.be.gt(creatorBalanceBefore);
  });
});
