const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying AuctionBackedLending...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy AuctionBackedLending
  const AuctionBackedLending = await ethers.getContractFactory("AuctionBackedLending");
  const lending = await AuctionBackedLending.connect(deployer).deploy(
    "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f", // Doma OwnershipToken
    ethers.ZeroAddress // Use ETH for payments
  );
  await lending.waitForDeployment();
  console.log("AuctionBackedLending deployed to:", await lending.getAddress());

  console.log("Using existing OwnershipToken at:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");

  console.log("\n=== Deployment Summary ===");
  console.log("AuctionBackedLending:", await lending.getAddress());
  console.log("OwnershipToken:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");

  console.log("\n=== System Architecture ===");
  console.log("• AuctionBackedLending: Auction-backed lending with integrated Dutch auctions");
  console.log("• Single lender per loan with automatic repayment from auction proceeds");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });