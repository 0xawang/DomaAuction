const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying VotingContest...");

  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // Deploy VotingContest
  const VotingContest = await ethers.getContractFactory("VotingContest");
  const votingContest = await VotingContest.connect(deployer).deploy(
    "0x2f3463756C59387D6Cd55b034100caf7ECfc757b", // Staking token - replace with actual ERC20 address (e.g., USDC)
    "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f", // Doma OwnershipToken
    "0x075Fee80E95ff922Ec067AEd2657b11359990479"
  );
  await votingContest.waitForDeployment();
  console.log("VotingContest deployed to:", await votingContest.getAddress());

  console.log("Using existing OwnershipToken at:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");
  console.log("NOTE: Replace staking token address with actual ERC20 token address");

  console.log("\n=== Deployment Summary ===");
  console.log("VotingContest:", await votingContest.getAddress());
  console.log("OwnershipToken:", "0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f");
  console.log("StakingToken: Replace ethers.ZeroAddress with actual ERC20");

  console.log("\n=== System Architecture ===");
  console.log("• VotingContest: Domain voting contests with staking-based voting");
  console.log("• Integrated staking and NFT locking for contest participation");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });