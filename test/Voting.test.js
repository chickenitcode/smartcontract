import { expect } from "chai";
import { ethers } from "hardhat";

describe("Voting", function () {
  async function deployFixture() {
    const [owner, voter] = await ethers.getSigners();
    const Voting = await ethers.getContractFactory("Voting");
    const contract = await Voting.deploy();
    await contract.waitForDeployment();
    return { contract, owner, voter };
  }

  it("blocks double voting", async function () {
    const { contract, owner, voter } = await deployFixture();
    await contract.connect(owner).addCandidate("Alice");
    await contract.connect(owner).setVotingStatus(true);

    await contract.connect(voter).vote(0);
    await expect(contract.connect(voter).vote(0)).to.be.revertedWith("Already voted");
  });

  it("blocks voting when closed", async function () {
    const { contract, owner, voter } = await deployFixture();
    await contract.connect(owner).addCandidate("Alice");
    await contract.connect(owner).setVotingStatus(false);

    await expect(contract.connect(voter).vote(0)).to.be.revertedWith("Voting closed");
  });
});
