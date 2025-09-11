<div align="center">
    <a href="https://ixfi.network.com">
        <img alt="logo" src="https://github.com/0xawang/DomaAuction/blob/main/domain-auction-banner.png" style="width: 100%;">
    </a>
</div>

# DomaAuction - Dual Auction Protocol

A comprehensive auction ecosystem for domain NFTs featuring two specialized systems: Hybrid Batch Auctions for portfolios and Premium Single Domain Auctions with sophisticated betting mechanisms.

## Two Specialized Auction Systems

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

## License

MIT License