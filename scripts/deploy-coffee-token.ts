import { ethers } from "hardhat";

async function main() {
  const [admin, customerA, customerB] = await ethers.getSigners();

  const CoffeeToken = await ethers.getContractFactory("CoffeeToken");
  const token = await CoffeeToken.deploy(admin.address, admin.address);
  await token.waitForDeployment();

  const mintTx = await token.mint(customerA.address, ethers.parseUnits("100", 18));
  await mintTx.wait();

  const transferTx = await token
    .connect(customerA)
    .transfer(customerB.address, ethers.parseUnits("50", 18));
  await transferTx.wait();

  const balanceA = await token.balanceOf(customerA.address);
  const balanceB = await token.balanceOf(customerB.address);

  console.log("CoffeeToken deployed at:", await token.getAddress());
  console.log("Customer A balance:", ethers.formatUnits(balanceA, 18));
  console.log("Customer B balance:", ethers.formatUnits(balanceB, 18));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
