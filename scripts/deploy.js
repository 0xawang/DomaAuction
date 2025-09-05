const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying Doma Auction System...");
  const nftContract = "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f"
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy LoyaltyNFT first
  const LoyaltyNFT = await ethers.getContractFactory("LoyaltyNFT");
  const loyaltyNFT = await LoyaltyNFT.connect(deployer).deploy();
  await loyaltyNFT.waitForDeployment();
  console.log("LoyaltyNFT deployed to:", await loyaltyNFT.getAddress());

  // Deploy HybridDutchAuction
  const HybridDutchAuction = await ethers.getContractFactory("HybridDutchAuction");
  const auction = await HybridDutchAuction.connect(deployer).deploy(await loyaltyNFT.getAddress(), nftContract);
  await auction.waitForDeployment();
  console.log("HybridDutchAuction deployed to:", await auction.getAddress());

  console.log("ReverseRoyaltyEngine integrated into HybridDutchAuction");

  console.log("Using existing OwnershipToken at:", nftContract);

  // Set auction contract as owner of loyalty NFT
  await loyaltyNFT.connect(deployer).transferOwnership(await auction.getAddress());
  console.log("Ownership transferred to auction contract");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });