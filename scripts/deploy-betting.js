const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Doma Auction System...");
  
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy DomainAuctionBetting (independent single domain auctions + betting)
  const DomainAuctionBetting = await ethers.getContractFactory("DomainAuctionBetting");
  const singleAuction = await DomainAuctionBetting.connect(deployer).deploy(
    "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f"
  );
  await singleAuction.waitForDeployment();
  console.log("DomainAuctionBetting deployed to:", await singleAuction.getAddress());

  console.log("Using existing OwnershipToken at:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");

  console.log("\n=== Deployment Summary ===");
  console.log("DomainAuctionBetting (Single):", await singleAuction.getAddress());
  console.log("OwnershipToken:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");
  
  console.log("\n=== System Architecture ===");
  console.log("• DomainAuctionBetting: Independent single domain auctions + betting");
  console.log("• Complete separation: No dependencies between systems");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });