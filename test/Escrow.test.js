import { expect } from "chai";
import { ethers } from "hardhat";

describe("Escrow", function () {
  const price = ethers.parseEther("0.5");

  async function deployFixture() {
    const [buyer, seller, arbiter] = await ethers.getSigners();
    const Escrow = await ethers.getContractFactory("Escrow");
    const contract = await Escrow.deploy(buyer.address, seller.address, arbiter.address, price);
    await contract.waitForDeployment();
    return { contract, buyer, seller, arbiter };
  }

  it("allows arbiter to refund when buyer complains", async function () {
    const { contract, buyer, arbiter } = await deployFixture();

    await contract.connect(buyer).deposit({ value: price });
    const buyerBalanceBeforeRefund = await ethers.provider.getBalance(buyer.address);

    await contract.connect(arbiter).refund();

    const buyerBalanceAfterRefund = await ethers.provider.getBalance(buyer.address);
    expect(buyerBalanceAfterRefund - buyerBalanceBeforeRefund).to.equal(price);
    expect(await contract.state()).to.equal(3n); // REFUNDED
  });
});

