<div align="center">
    <a href="https://ixfi.network.com">
        <img alt="logo" src="https://github.com/0xawang/DomaAuction/blob/main/domain-auction-banner.png" style="width: 100%;">
    </a>
</div>

# DomaAuction - Hybrid Dutch Auction Protocol

A next-generation auction system for domain NFTs featuring batch auctions, gamified bidding, and dynamic royalties.

## Features

### 1. Batch Dutch Auctions
- Auction multiple domain NFTs as a portfolio
- Fractional ownership support (buy 10%, 25%, etc.)
- Linear price decay over time
- Reserve price protection

### 2. Gamified Bidding System
- **Soft Bids**: Intent-based bidding with auto-conversion
- **Bonds**: 0.2% refundable deposit prevents spam
- **Loyalty Rewards**: Time-weighted points for early engagement
- **Sale-Gated**: Rewards only distributed on successful auctions

### 3. Reverse Royalty Engine
- Dynamic royalties starting at 0%
- Increases per block to incentivize quick trades
- Optional feature for secondary sales
- Automatic distribution to original creators

## Contract Architecture

### Core Contracts
- `HybridDutchAuction.sol` - Main auction logic
- `LoyaltyNFT.sol` - Gamification rewards
- `IOwnershipToken.sol` - Interface for Doma domain NFTs

### Key Functions

#### Creating Auctions
```solidity
function createBatchAuction(
    IOwnershipToken nftContract,
    uint256[] memory tokenIds,
    uint256 startPrice,
    uint256 reservePrice,
    uint256 priceDecrement,
    uint256 duration,
    uint256 rewardBudgetBps,  // 0-500 (0-5%)
    uint256 royaltyIncrement  // 0 = no reverse royalty
) external returns (uint256 auctionId)
```

#### Bidding
```solidity
// Place soft bid with bond
function placeSoftBid(
    uint256 auctionId,
    uint256 threshold,        // Auto-buy when price <= threshold
    uint256 desiredFraction   // Percentage of bundle (1-100)
) external payable

// Convert eligible soft bids to purchases
function processConversions(uint256 auctionId) external
```

#### View Functions
```solidity
function getCurrentPrice(uint256 auctionId) external view returns (uint256)
function getCurrentRoyalty(uint256 auctionId) external view returns (uint256)
function getFractionalOwnership(uint256 auctionId, address owner) external view returns (uint256)
```

## Examples

### Example 1: Batch Portfolio Auction with Gamification

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
    0                 // No reverse royalty
);

// Alice places early soft bid
placeSoftBid{value: 1.8e18}(auctionId, 900e18, 10); // 10% at 900, bond = 1.8 USDC

// Bob places soft bid
placeSoftBid{value: 0.86e18}(auctionId, 860e18, 5); // 5% at 860, bond = 0.86 USDC

// Process conversions when price drops
processConversions(auctionId);
```

### Example 2: Single Domain Auction

**Setup:**
- Single premium domain
- First threshold hit auto-converts and ends auction immediately
- Only converting bidders get rewards

```solidity
// Create single domain auction
createBatchAuction(
    ownershipToken,
    [42],             // Single domain token ID
    100e18,           // 100 ETH start
    50e18,            // 50 ETH reserve
    0.5e18,           // 0.5 ETH per block
    200,              // 200 blocks
    200,              // 2% reward budget
    0                 // No reverse royalty
);

// Multiple bidders compete
placeSoftBid{value: 0.2e18}(auctionId, 85e18, 100);  // Alice: 100% at 85 ETH
placeSoftBid{value: 0.18e18}(auctionId, 80e18, 100); // Bob: 100% at 80 ETH

// When price hits 85 ETH, Alice wins immediately
processConversions(auctionId); // Alice gets the domain + loyalty points
```

### Example 3: Secondary Sale with Reverse Royalty

**Setup:**
- Reselling acquired domains
- No loyalty rewards (rewardBudgetBps = 0)
- Reverse royalty starts at 0%, increases 0.1% per block
- Creates urgency for buyers

```solidity
// Create secondary auction with reverse royalty
createBatchAuction(
    ownershipToken,
    [5,6,7],          // 3 domains for resale
    50e18,            // 50 ETH start
    30e18,            // 30 ETH reserve
    0.2e18,           // 0.2 ETH per block
    250,              // 250 blocks
    0,                // No loyalty rewards
    10                // 0.1% per block royalty (10 bps)
);

// Buyers face trade-off: wait for lower price vs pay higher royalty
placeSoftBid{value: 0.1e18}(auctionId, 45e18, 50);   // 50% at 45 ETH
placeSoftBid{value: 0.08e18}(auctionId, 40e18, 50);  // 50% at 40 ETH

// At block 50: royalty = 5%, price = 40 ETH
// Buyer pays 40 ETH + 5% royalty to original creators
processConversions(auctionId);
```

### Example 4: Failed Auction (Bond Refunds)

**Setup:**
- Auction fails to reach 100% conversion
- Price hits reserve but insufficient demand
- Bonds are refunded

```solidity
// After auction expires without clearing
refundExpiredBonds(auctionId); // Bidders reclaim their bonds
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

### Test
```bash
npx hardhat test
```

## Configuration

### Network Settings (hardhat.config.js)
```javascript
networks: {
  doma: {
    url: "https://fraa-dancebox-3043-rpc.a.dancebox.tanssi.network",
    chainId: 3043
  }
}
```

### Contract Addresses
- **Doma OwnershipToken**: `0x424bDf2E8a6F52Bd2c1C81D9437b0DC0309DF90f`

## Key Parameters

- **Bond Rate**: 0.2% of intended spend
- **Max Reward Budget**: 5% of sale proceeds
- **Price Multipliers**: Early bids get 1.5x, late bids get 1.0x
- **Royalty Cap**: No hardcoded limit (market-driven)

## Security Features

- **ReentrancyGuard**: Prevents reentrancy attacks
- **IERC721Receiver**: Safe NFT handling
- **Bond System**: Spam prevention
- **Reserve Price**: Seller protection
- **Overflow Protection**: SafeMath patterns

## Events

```solidity
event AuctionCreated(uint256 indexed auctionId, address seller, uint256 startPrice, uint256 reservePrice, bool hasReverseRoyalty);
event SoftBidPlaced(uint256 indexed auctionId, address bidder, uint256 threshold, uint256 fraction, uint256 bond);
event SoftBidConverted(uint256 indexed auctionId, address bidder, uint256 price, uint256 fraction);
event AuctionCleared(uint256 indexed auctionId, uint256 clearingPrice, uint256 totalRewards, uint256 royaltyAmount);
```

## License

MIT License
