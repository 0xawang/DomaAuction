<div align="center">
    <a href="https://ixfi.network.com">
        <img alt="logo" src="https://github.com/0xawang/DomaAuction/blob/main/domain-auction-banner.png" style="width: 100%;">
    </a>
</div>

# DomaAuction - Tri Auction Protocol

A comprehensive auction ecosystem for domain NFTs featuring three specialized systems: Hybrid Batch Auctions for portfolios, Premium Single Domain Auctions with betting, and Auction-Backed Lending for liquidity.

## Three Specialized Auction Systems

## 🎯 System 1: Hybrid Batch Auctions (HybridDutchAuction)

### Batch Dutch Auctions
- Auction multiple domain NFTs as a portfolio
- Fractional ownership support (buy specific token counts)
- Linear price decay over time
- Reserve price protection

### Gamified Bidding System
- **Soft Bids**: Intent-based bidding with auto-conversion
- **Hard Bids**: Immediate purchase at current price
- **Bonds**: 0.2% refundable deposit prevents spam
- **Loyalty Rewards**: Time-weighted points for early engagement
- **Sale-Gated**: Rewards only distributed on successful auctions

### Reverse Royalty Engine
- Dynamic royalties starting at 0%
- Increases per block to incentivize quick trades
- Optional feature for secondary sales
- Automatic distribution to original creators

## 🏦 System 3: Auction-Backed Lending (ABL) for Domain Auctions

### Auction-Backed Lending
- Sellers borrow stablecoins against their domain NFTs locked in auctions
- Lenders fund loans up to 50% of reserve price
- Automatic repayment from auction proceeds if successful
- NFT liquidation to lenders if auction fails

### Lending Workflow
- **Request Loan**: Seller requests loan against active auction (up to 50% of reserve)
- **Fund Loan**: Lenders contribute stablecoins to fulfill the loan
- **Auction Settlement**: Loan auto-repaid from proceeds, or NFT liquidated on failure
- **Repayment Terms**: Configurable interest rates and durations (1-30 days)

## 🗳️ Domain Voting Contest

### Gamified Social Layer
- Community voting for favorite domains through token staking
- Earn staking rewards while boosting domain visibility
- Anti-Sybil measures ensure fair participation

### Contest Features
- **Single Active Contest**: Only one contest runs at a time
- **Staking-Based Voting**: Vote weight equals staked amount
- **Bounded Stakes**: minStake ≤ stake ≤ minStake × multiplier
- **Multiple Votes**: Up to 3 domains per participant
- **Time-Cumulated Rewards**: StakingPoints = StakeAmount × TimeStaked

### Voting Mechanism
- **Domain Ranking**: Score = sum of all vote stakes
- **Locked Votes**: Stakes locked until contest ends
- **Fair Distribution**: Rewards for fee discounts and priority access

## 🏆 System 2: Premium Domain Auctions with Betting (DomainAuctionBetting)

### Single Domain Dutch Auctions
- Independent auction system for premium domains
- First bid wins and ends auction immediately
- Timestamp-based duration
- Configurable price thresholds for betting

### 4-Tier Price Betting Mechanism
- **Commit-Reveal Betting**: Hidden bets on auction price outcomes
- **Price Categories**: Above High (3), High~Low Range (2), Below Low (1), Uncleared (0)
- **Seller-Defined Thresholds**: High price and low price boundaries
- **Anti-Manipulation**: Prevents sniping with secret commitments
- **Configurable Distribution**: Owner can adjust cuts (default: 90% winners, 5% seller, 3% buyer, 2% protocol)
- **Penalty System**: Unrevealed bets redistributed to winners

## Contract Architecture

### Core Contracts

**System 1 - Hybrid Batch Auctions:**
- `HybridDutchAuction.sol` - Batch auction logic with gamification
- `LoyaltyNFT.sol` - Gamification rewards and loyalty points

**System 2 - Premium Domain + Betting:**
- `DomainAuctionBetting.sol` - Independent single-domain auctions with 4-tier betting

**System 3 - Auction-Backed Lending:**
- `AuctionBackedLending.sol` - Lending protocol integrated with batch auctions

**System 4 - Domain Voting Contest:**
- `VotingContest.sol` - Contest management, voting, and staking logic

**Shared:**
- `IOwnershipToken.sol` - Interface for Doma domain NFTs

### Key Functions

#### System 1: Hybrid Batch Auction Functions
```solidity
function createBatchAuction(
    IOwnershipToken nftContract,
    uint256[] memory tokenIds,
    uint256 startPrice,
    uint256 reservePrice,
    uint256 priceDecrement,
    uint256 duration,
    uint256 rewardBudgetBps,
    uint256 royaltyIncrement,
    address paymentToken
) external returns (uint256)

function placeSoftBid(uint256 auctionId, uint256 threshold, uint256 desiredCount) external payable
function placeHardBid(uint256 auctionId, uint256 desiredCount) external payable
function processConversions(uint256 auctionId) external
```

#### System 2: Premium Single Domain + Betting Functions
```solidity
// Create single domain auction with betting price thresholds
function createSingleDomainAuction(uint256 tokenId, uint256 startPrice, uint256 reservePrice, uint256 priceDecrement, uint256 duration, uint256 highPrice, uint256 lowPrice) external

// Place bid on single domain (ends auction immediately)
function placeBid(uint256 auctionId) external payable

// Create betting pool with 4 price categories
function createBettingPool(uint256 auctionId, uint256 commitDuration, uint256 revealDuration) external

// Commit bet with hash of (choice, amount, secret)
function commitBet(uint256 auctionId, bytes32 commitHash, uint256 amount) external

// Reveal committed bet (choice: 3=Above High, 2=High~Low, 1=Below Low, 0=Uncleared)
function revealBet(uint256 auctionId, uint8 choice, uint256 amount, uint256 secret) external

// Settle betting after auction ends
function settleBetting(uint256 auctionId) external

// Owner functions
function setCuts(uint256 _sellerCut, uint256 _buyerCut, uint256 _protocolCut, uint256 _winnerCut) external onlyOwner
```

#### System 3: Auction-Backed Lending Functions
```solidity
function createAuction(
    uint256 tokenId,
    uint256 startPrice,
    uint256 reservePrice,
    uint256 priceDecrement,
    uint256 duration,
    uint256 loanAmount,
    uint256 interestBps,
    uint256 loanDurationDays
) external returns (uint256)

function getCurrentPrice(uint256 auctionId) external view returns (uint256)
function bid(uint256 auctionId) external payable
function fundLoan(uint256 auctionId) external payable
function repayLoan(uint256 auctionId) external payable
function checkAndLiquidate(uint256 auctionId) external
```

#### System 4: Domain Voting Contest Functions
```solidity
function listDomain(uint256 domainId) external
function createContest(uint256 startTime, uint256 endTime, uint256 minStake, uint256 multiplier) external
function vote(uint256[] calldata domainIds, uint256 stakeAmount) external
function endContest() external
function unlistDomain(uint256 contestId, uint256 domainId) external
function getStakingPoints(uint256 contestId, address user) external view returns (uint256)
function unstake(uint256 contestId) external
function getDomainVotes(uint256 contestId, uint256 domainId) external view returns (uint256)
function getAllDomainVotes(uint256 contestId) external view returns (uint256[] memory, uint256[] memory)
```

## Examples

### Example 1: Hybrid Batch Portfolio Auction with Gamification

**Setup:**
- Item: 100-domain bundle
- Start price: 1,000 USDC (Dutch, linearly down)
- Reserve floor: 700 USDC
- Reward budget: 1% of final sale, only if cleared
- Bond: 0.2% of intended spend

**Early Phase:**
- Alice: soft bid for 10% of bundle, threshold = 900 → bond posted
- Bob: soft bid 5%, threshold = 860 → bond posted
- Carol: soft bid 40%, threshold = 820 → bond posted
- Dana: soft bid 50%, threshold = 780 → bond posted

**Price Progression:**
- At 900: Alice auto-converts (10%). Cumulative = 10% — continue
- At 860: Bob auto-converts (5%). Cumulative = 15% — continue
- At 820: Carol auto-converts (40%). Cumulative = 55% — continue
- At 780: Dana auto-converts (50%). Cumulative = 105% ≥ 100% → auction clears at 780

**Settlement:**
- Pro-rata fill at clearing price (if over-subscribed)
- Bonds returned
- Rewards minted (since sale cleared):
  - Alice (earliest, highest price distance) gets largest share of points
  - Dana gets less (later threshold), even though she cleared the auction

```solidity
// Create batch auction
createBatchAuction(
    ownershipToken,
    [1,2,3,...,100],  // 100 domain token IDs
    1000e18,          // 1000 USDC start price
    700e18,           // 700 USDC reserve
    1e18,             // 1 USDC per block decrement
    300,              // 300 blocks duration
    100,              // 1% reward budget (100 bps)
    0,                // No reverse royalty
    address(0)        // ETH payments
);

// Alice places early soft bid
placeSoftBid{value: 1.8e18}(auctionId, 900e18, 10); // 10 tokens at 900, bond = 1.8 USDC
```

### Example 2: Premium Domain Auction with 4-Tier Betting

**Setup:**
- Single premium domain with price range betting
- Bettors wager on final price category
- 4 betting tiers: Above High, High~Low Range, Below Low, Uncleared

```solidity
// Create single domain auction with betting thresholds
createSingleDomainAuction(tokenId, 100e18, 50e18, 0.5e18, 3600, 80e18, 60e18);
// highPrice = 80 ETH, lowPrice = 60 ETH

// Create betting pool
createBettingPool(auctionId, 3600, 1800); // 1hr commit, 30min reveal

// Commit bets (hidden)
bytes32 hash1 = keccak256(abi.encodePacked(uint8(3), 100e18, 12345)); // bet >80 ETH
bytes32 hash2 = keccak256(abi.encodePacked(uint8(2), 50e18, 67890)); // bet 60-80 ETH
commitBet(auctionId, hash1, 100e18);
commitBet(auctionId, hash2, 50e18);

// Someone bids on auction
placeBid{value: 75e18}(auctionId); // Auction clears at 75 ETH (category 2)

// Reveal after auction ends
revealBet(auctionId, 3, 100e18, 12345); // Wrong prediction
revealBet(auctionId, 2, 50e18, 67890); // Correct prediction (60-80 ETH range)

// Settle betting
settleBetting(auctionId); // Category 2 bettors win 90% of pool
```

**Betting Categories:**
- **Category 3**: Final price > High Price (above 80 ETH)
- **Category 2**: Low Price ≤ Final price ≤ High Price (60-80 ETH)
- **Category 1**: Final price < Low Price (below 60 ETH)
- **Category 0**: Auction fails to clear (no sale)

### Example 3: Auction-Backed Lending

**Setup:**
- Seller creates auction for premium domain with reserve price 10 ETH
- Requests 4 ETH loan (40% of reserve) at 5% APR for 7 days

```solidity
// Create auction with loan
uint256 auctionId = createAuction(
    tokenId,      // Domain token ID
    10e18,        // Start price: 10 ETH
    8e18,         // Reserve price: 8 ETH
    0.01e18,      // 0.01 ETH per second decrement
    3600,         // 1 hour duration
    4e18,         // 4 ETH loan
    500,          // 5% APR
    7             // 7 days loan duration
);

// Lenders fund the loan
fundLoan{value: 4e18}(loanId); // Single lender funds full amount

// Auction runs with decreasing price
// At current price, someone bids
bid{value: 9e18}(auctionId); // Auction ends, loan repaid from proceeds

// If no bids and time expires
checkAndLiquidate(loanId); // NFT transferred to lender
```

### Example 4: Domain Voting Contest

**Setup:**
- Contest: 10 days, minStake = 100 tokens, multiplier = 5
- Domains: A (ID 0), B (ID 1), C (ID 2) listed for voting

```solidity
// Domain owners list their domains
listDomain(0); // Owner of domain A lists it
listDomain(1); // Owner of domain B lists it
listDomain(2); // Owner of domain C lists it

// Create contest
createContest(block.timestamp, block.timestamp + 10 days, 100e18, 5);

// Users vote (staking happens automatically)
vote([0, 1, 2], 300e18); // Alice votes for A, B, C with 300 stake
vote([0, 1], 200e18); // Bob votes for A, B with 200 stake
vote([2], 500e18); // Carol votes for C with 500 stake

// After 10 days, end contest
endContest();

// Rankings: A=500, B=500, C=800
// Staking points: Alice=300*10=3000, Bob=200*10=2000, Carol=500*10=5000
// Domains returned to owners

// Users can unstake after contest
unstake(); // Return staked tokens
```

## Deployment

### Prerequisites
```bash
npm install
```

### Compile
```bash
npx hardhat compile
```

### Deploy to Doma Testnet
```bash
# Set PRIVATE_KEY in .env
cp .env.example .env

# Deploy contracts
npx hardhat run scripts/deploy.js --network doma
```

## Contract Addresses

- **Doma OwnershipToken**: `0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f`

**System 1 - Hybrid Batch Auctions:**
- **HybridDutchAuction**: Deployed via script
- **LoyaltyNFT**: Deployed via script

**System 2 - Premium Single Domain + Betting:**
- **DomainAuctionBetting**: Deployed via script

## Events

### System 1: Batch Auction Events
```solidity
event AuctionCreated(uint256 indexed auctionId, address seller, uint256 startPrice, uint256 reservePrice, bool hasReverseRoyalty);
event SoftBidPlaced(uint256 indexed auctionId, address bidder, uint256 threshold, uint256 count, uint256 bond);
event SoftBidConverted(uint256 indexed auctionId, address bidder, uint256 price, uint256 count);
event AuctionCleared(uint256 indexed auctionId, uint256 clearingPrice, uint256 totalRewards, uint256 royaltyAmount);
```

### System 2: Premium Auction + Betting Events
```solidity
event AuctionCreated(uint256 indexed auctionId, address seller, uint256 tokenId, uint256 startPrice);
event BidPlaced(uint256 indexed auctionId, address bidder, uint256 price);
event AuctionEnded(uint256 indexed auctionId, bool cleared, address winner, uint256 finalPrice);
event BettingPoolCreated(uint256 indexed auctionId, uint256 commitDeadline, uint256 revealDeadline);
event BetCommitted(uint256 indexed auctionId, address indexed bettor, bytes32 commitHash, uint256 amount);
event BetRevealed(uint256 indexed auctionId, address indexed bettor, uint8 choice, uint256 amount);
event BettingSettled(uint256 indexed auctionId, uint8 auctionResult, uint256 totalPool);
```

### System 3: Auction-Backed Lending Events
```solidity
event LoanRequested(uint256 indexed loanId, uint256 indexed auctionId, address borrower, uint256 amount, uint256 interestBps);
event LoanFunded(uint256 indexed loanId, address lender, uint256 amount);
event LoanRepaid(uint256 indexed loanId, uint256 totalRepayment);
event LoanLiquidated(uint256 indexed loanId, address liquidator);
```

### System 4: Domain Voting Contest Events
```solidity
event ContestCreated(uint256 indexed contestId, uint256 startTime, uint256 endTime, uint256 minStake, uint256 multiplier);
event DomainListed(uint256 indexed domainId, address indexed owner);
event Voted(address indexed user, uint256[] domainIds, uint256 stakeAmount);
event ContestEnded(uint256 indexed contestId, uint256[] rankedDomains, uint256[] scores);
event Unstaked(address indexed user, uint256 amount);
```

## License

MIT License