import { expect } from "chai";
import { ethers } from "hardhat";

describe("CoffeeToken", function () {
  async function deployFixture() {
    const [admin, minter, userA, userB] = await ethers.getSigners();
    const CoffeeToken = await ethers.getContractFactory("CoffeeToken");
    const token = await CoffeeToken.deploy(admin.address, minter.address);
    await token.waitForDeployment();
    return { token, admin, minter, userA, userB };
  }

  it("allows minter to mint and transfer", async function () {
    const { token, minter, userA, userB } = await deployFixture();

    await token.connect(minter).mint(userA.address, ethers.parseUnits("100", 18));
    await token.connect(userA).transfer(userB.address, ethers.parseUnits("50", 18));

    const balanceA = await token.balanceOf(userA.address);
    const balanceB = await token.balanceOf(userB.address);

    expect(balanceA).to.equal(ethers.parseUnits("50", 18));
    expect(balanceB).to.equal(ethers.parseUnits("50", 18));
  });

  it("blocks non-minter from minting", async function () {
    const { token, userA } = await deployFixture();
    await expect(token.connect(userA).mint(userA.address, 1)).to.be.revertedWithCustomError(
      token,
      "AccessControlUnauthorizedAccount"
    );
  });
});
