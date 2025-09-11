const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Doma Auction System...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy LoyaltyNFT first
  const LoyaltyNFT = await ethers.getContractFactory("LoyaltyNFT");
  const loyaltyNFT = await LoyaltyNFT.connect(deployer).deploy();
  await loyaltyNFT.waitForDeployment();
  console.log("LoyaltyNFT deployed to:", await loyaltyNFT.getAddress());

  // Deploy HybridDutchAuction (for batch auctions)
  const HybridDutchAuction = await ethers.getContractFactory("HybridDutchAuction");
  const batchAuction = await HybridDutchAuction.connect(deployer).deploy(
    await loyaltyNFT.getAddress(),
    "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f" // Doma OwnershipToken
  );
  await batchAuction.waitForDeployment();
  console.log("HybridDutchAuction deployed to:", await batchAuction.getAddress());

  // Deploy DomainAuctionBetting (independent single domain auctions + betting)
  const DomainAuctionBetting = await ethers.getContractFactory("DomainAuctionBetting");
  const singleAuction = await DomainAuctionBetting.connect(deployer).deploy(
    "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f", // Doma OwnershipToken
    ethers.ZeroAddress // Use ETH as betting token for demo, replace with USDC/USDT address
  );
  await singleAuction.waitForDeployment();
  console.log("DomainAuctionBetting deployed to:", await singleAuction.getAddress());

  console.log("Using existing OwnershipToken at:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");

  // Set batch auction contract as owner of loyalty NFT
  await loyaltyNFT.connect(deployer).transferOwnership(await batchAuction.getAddress());
  console.log("LoyaltyNFT ownership transferred to HybridDutchAuction contract");

  console.log("\n=== Deployment Summary ===");
  console.log("LoyaltyNFT:", await loyaltyNFT.getAddress());
  console.log("HybridDutchAuction (Batch):", await batchAuction.getAddress());
  console.log("DomainAuctionBetting (Single):", await singleAuction.getAddress());
  console.log("OwnershipToken:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");
  
  console.log("\n=== System Architecture ===");
  console.log("• HybridDutchAuction: Batch portfolio auctions with gamification");
  console.log("• DomainAuctionBetting: Independent single domain auctions + betting");
  console.log("• Complete separation: No dependencies between systems");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });