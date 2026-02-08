// library declaration
const {expect} = require("chai");
const {ethers} = require("hardhat");

describe("Escrow", function(){
    const fundingGoal = ethers.parseEther("1");// doi don vi -> 1ether
    const evidenceHash = ethers.keccak256(ethers.toUtf8Bytes("progress-proof")); // mock hash evidence for submit function

    //mock deploy -> setup
    async function deployFixture(){
        const [bank, heritage, sme, outsider] = await ethers.getSigners();
        const HeritageESG = await ethers.getContractFactory("escrow");
        const contract = await HeritageESG.connect(bank).deploy(bank.address);

        a
    }

});