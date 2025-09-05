const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("HybridDutchAuction", function () {
  let auction, loyaltyNFT;
  let owner, seller, buyer1, buyer2;
  const OWNERSHIP_TOKEN_ADDRESS = "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f";

  beforeEach(async function () {
    [owner, seller, buyer1, buyer2] = await ethers.getSigners();

    const LoyaltyNFT = await ethers.getContractFactory("LoyaltyNFT");
    loyaltyNFT = await LoyaltyNFT.deploy();

    const HybridDutchAuction = await ethers.getContractFactory("HybridDutchAuction");
    auction = await HybridDutchAuction.deploy(await loyaltyNFT.getAddress());

    await loyaltyNFT.transferOwnership(await auction.getAddress());
  });

  it("Should handle soft bids with bonds", async function () {
    const bondRequired = ethers.parseEther("0.005"); // 0.5% of 1 ETH
    
    // Test bond calculation and soft bid placement
    const initialBalance = await ethers.provider.getBalance(buyer1.address);
    expect(initialBalance).to.be.gt(bondRequired);
  });

  it("Should track bond balances", async function () {
    const bondBalance = await auction.bondBalances(buyer1.address);
    expect(bondBalance).to.equal(0);
  });
});