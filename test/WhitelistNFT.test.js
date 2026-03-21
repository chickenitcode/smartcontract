import { expect } from "chai";
import { ethers } from "hardhat";
import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";

describe("WhitelistNFT", function () {
  async function deployFixture() {
    const [owner, whitelisted, nonWhitelisted] = await ethers.getSigners();

    const whitelist = [whitelisted.address];
    const leaves = whitelist.map((addr) =>
      Buffer.from(
        ethers.solidityPackedKeccak256(["address"], [addr]).slice(2),
        "hex"
      )
    );
    const tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
    const root = tree.getHexRoot();

    const WhitelistNFT = await ethers.getContractFactory("WhitelistNFT");
    const contract = await WhitelistNFT.deploy(root, "ipfs://hidden/metadata.json");
    await contract.waitForDeployment();

    return { contract, owner, whitelisted, nonWhitelisted, tree };
  }

  it("mints for a valid whitelist address", async function () {
    const { contract, whitelisted, tree } = await deployFixture();

    const leaf = Buffer.from(
      ethers.solidityPackedKeccak256(["address"], [whitelisted.address]).slice(2),
      "hex"
    );
    const proof = tree.getHexProof(leaf);

    await contract.connect(whitelisted).mint(proof);
    expect(await contract.totalSupply()).to.equal(1n);
  });

  it("reverts for invalid proof", async function () {
    const { contract, nonWhitelisted } = await deployFixture();
    await expect(contract.connect(nonWhitelisted).mint([])).to.be.revertedWith("Invalid Proof");
  });
});
