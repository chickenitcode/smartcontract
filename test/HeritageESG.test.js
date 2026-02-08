const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HeritageESG", function () {
  const fundingGoal = ethers.parseEther("1");
  const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes("progress-proof"));

  async function deployFixture() {
    const [bank, heritage, sme, outsider] = await ethers.getSigners();
    const HeritageESG = await ethers.getContractFactory("HeritageESG");
    const contract = await HeritageESG.connect(bank).deploy(bank.address);

    await contract.grantRole(await contract.HERITAGE_ROLE(), heritage.address);
    await contract.grantRole(await contract.SME_ROLE(), sme.address);

    return { contract, bank, heritage, sme, outsider };
  }

  async function createFundedProject() {
    const context = await deployFixture();
    const { contract, heritage, sme } = context;

    const tx = await contract
      .connect(heritage)
      .createProject("Ancient Temple", fundingGoal, heritage.address);
    await tx.wait();
    const projectId = (await contract.nextProjectId()) - 1n;

    await contract.connect(sme).fundProject(projectId, { value: fundingGoal });

    return { ...context, projectId };
  }

  it("runs the full happy path with escrow and NFT minting", async function () {
    const { contract, heritage, sme, bank } = await deployFixture();

    const createTx = await contract
      .connect(heritage)
      .createProject("Ancient Temple", fundingGoal, heritage.address);
    await createTx.wait();
    const projectId = (await contract.nextProjectId()) - 1n;

    const contractAddress = await contract.getAddress();
    const contractBalanceBefore = await ethers.provider.getBalance(contractAddress);
    const fundTx = await contract.connect(sme).fundProject(projectId, { value: fundingGoal });
    const fundReceipt = await fundTx.wait();
    const gasPriceFunding = fundReceipt.effectiveGasPrice ?? 0n;
    const gasCostFunding = fundReceipt.gasUsed * gasPriceFunding;
    const contractBalanceAfter = await ethers.provider.getBalance(contractAddress);

    expect(contractBalanceAfter - contractBalanceBefore).to.equal(fundingGoal);

    const projectAfterFunding = await contract.projects(projectId);
    expect(projectAfterFunding.status).to.equal(1n); // FUNDED
    expect(projectAfterFunding.funder).to.equal(sme.address);
    expect(projectAfterFunding.fundedAmount).to.equal(fundingGoal);

    await expect(contract.connect(heritage).submitEvidence(projectId, evidenceHash))
      .to.emit(contract, "EvidenceSubmitted")
      .withArgs(projectId, evidenceHash);

    const heritageBalanceBefore = await ethers.provider.getBalance(heritage.address);
    const disburseTx = await contract.connect(bank).approveAndDisburse(projectId);
    const disburseReceipt = await disburseTx.wait();
    const gasPriceDisburse = disburseReceipt.effectiveGasPrice ?? 0n;
    const gasCostDisburse = disburseReceipt.gasUsed * gasPriceDisburse;
    // bank pays gas, heritage should receive full amount
    const heritageBalanceAfter = await ethers.provider.getBalance(heritage.address);
    expect(heritageBalanceAfter - heritageBalanceBefore).to.equal(fundingGoal);

    expect(await contract.ownerOf(projectId)).to.equal(sme.address);
    const projectAfterComplete = await contract.projects(projectId);
    expect(projectAfterComplete.status).to.equal(2n); // COMPLETED
  });

  it("prevents non-heritage from creating projects", async function () {
    const { contract, sme } = await deployFixture();
    await expect(
      contract.connect(sme).createProject("Invalid", fundingGoal, sme.address)
    )
      .to.be.revertedWithCustomError(contract, "AccessControlUnauthorizedAccount")
      .withArgs(sme.address, await contract.HERITAGE_ROLE());
  });

  it("blocks heritage evidence submission before funding", async function () {
    const { contract, heritage } = await deployFixture();
    const tx = await contract
      .connect(heritage)
      .createProject("Ancient Temple", fundingGoal, heritage.address);
    await tx.wait();
    const projectId = (await contract.nextProjectId()) - 1n;

    await expect(
      contract.connect(heritage).submitEvidence(projectId, evidenceHash)
    ).to.be.revertedWith("Not FUNDED");
  });

  it("blocks non-bank from disbursing funds", async function () {
    const { contract, heritage, sme, outsider } = await createFundedProject();
    const projectId = (await contract.nextProjectId()) - 1n;
    await contract.connect(heritage).submitEvidence(projectId, evidenceHash);

    await expect(
      contract.connect(outsider).approveAndDisburse(projectId)
    )
      .to.be.revertedWithCustomError(contract, "AccessControlUnauthorizedAccount")
      .withArgs(outsider.address, await contract.BANK_ROLE());
  });

  it("prevents funding when not in WAITING state", async function () {
    const { contract, heritage, sme } = await createFundedProject();
    const projectId = (await contract.nextProjectId()) - 1n;

    await expect(
      contract.connect(sme).fundProject(projectId, { value: fundingGoal })
    ).to.be.revertedWith("Not WAITING");

    await contract.connect(heritage).submitEvidence(projectId, evidenceHash);
    const bank = (await ethers.getSigners())[0];
    await contract.connect(bank).approveAndDisburse(projectId);
    await expect(
      contract.connect(sme).fundProject(projectId, { value: fundingGoal })
    ).to.be.revertedWith("Not WAITING");
  });
});

