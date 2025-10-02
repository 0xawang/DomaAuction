# 🌐 Quad Auction Protocol

## System 1: Hybrid Batch Auctions for Domain Portfolios

**Problem:**  
Traditional auctions handle domains individually, making it hard for large holders to liquidate portfolios and excluding small buyers.  

**Solution:**  
- Group multiple domains into one Dutch auction curve.  
- Buyers can:  
  - Bid for **full bundles**, or  
  - Commit to **fractions** (e.g., 1% of bundle).  

**Example:**  
- Portfolio of 100 domains.  
- Dutch curve: starts at 1,000 USDC → ticks down to 700 USDC reserve.  
- Buyers commit fractions:  
  - Alice 10%  
  - Bob 5%  
  - Carol 40%  
  - Dana 50%  
- At **780 USDC**, cumulative demand ≥ 100% → bundle clears.  

✅ **Benefits:**  
- Liquidity for big sellers.  
- Smaller buyers access premium bundles fractionally.  
- Higher transaction volume & participation.  

---

### Gamified Dutch Auctions with Bidder Rewards  

**Problem:**  
In standard Dutch auctions, bidders wait until the price drops → low early engagement.  

**Solution (Auction Mining):**  
- **Soft bids = Intent + Auto-convert threshold + Bond.**  
  - Example: “Buy if price ≤ 900, size = 10%, bond = 0.5%.”  
  - Auto-converts to a hard bid when price hits threshold.  
- **Hard bids = Binding purchase.**  
- **Rewards = Sale-gated** → only minted if auction clears.  

**Reward formula:**  
`Time-weighted score × Price-distance multiplier × Stake multiplier`  

**Example:**  
- Alice (threshold 900, 10%) auto-converts earliest → earns highest score.  
- Bob (860, 5%) converts later → earns medium score.  
- Carol (820, 40%) adds significant demand → good score.  
- Dana (780, 50%) clears auction.  

Auction clears at **780 USDC**, bundle sold.  
- Loyalty rewards distributed from seller rebate (e.g., 1% of sale).  
- Alice gets most points, even though she didn’t “win.”  

❌ If auction **fails to clear**, bonds refunded, **no rewards minted**.  

✅ **Benefits:**  
- Encourages early engagement, prevents point farming.  
- Builds community loyalty (NFT badges, fee discounts).  
- Stops “last-minute sniping.”  

---

### Reverse Dutch Auctions for Royalties  

**Problem:**  
Static royalties don’t adapt to urgency. Sellers either undercharge or scare away buyers.  

**Solution:**  
- Royalties **start at 0%** and **increase each block** until buyer accepts.  
- Buyers face trade-off: wait for lower price but pay higher royalty.  

**Example:**  
- NFT domain starts at 1,000 USDC, 0% royalties.  
- Price drops to 900 → royalties now 2%.  
- Drops to 850 → royalties 4%.  
- If buyer waits too long, royalties outweigh price savings.  

✅ **Benefits:**  
- Dynamic royalty capture.  
- Creates urgency.  
- Aligns protocol incentives with seller and community.  

---

## System 2: Premium Single-Domain Auctions + Betting System

**Problem:**  
Batch auctions serve portfolios well, but premium single domains need focused attention and additional engagement mechanisms.

**Solution (Separate Contract System):**
- **Independent Single-Domain Auctions**: Dedicated Dutch auctions for premium domains
- **First-Bid-Wins Mechanism**: Immediate auction completion for efficiency
- **Commit–Reveal Betting**: Parallel betting system on auction outcomes
- **Complete Separation**: Independent operation from batch auction system

**4-Tier Price Betting Mechanism:**  
- **Price Categories**: Above High (3), High~Low Range (2), Below Low (1), Uncleared (0)
- **Seller Sets Thresholds**: High price and low price boundaries for betting
- **Commit Phase**: Bettors submit `hash(choice, amount, secret)` with stablecoin stakes
- **Reveal Phase**: Bettors reveal their bets after auction closes
- **Anti-Spam**: Unrevealed bets are redistributed to winners
- **Fair Odds**: Hidden commitments prevent manipulation/sniping

**Pool Distribution:**  
- **90%** → Winning Bettors (pro-rata by stake)
- **5%** → Seller (liquidity premium)
- **3%** → Winning Buyer (price discovery bonus)
- **2%** → Protocol Treasury

**Example:**  
- Create single domain auction: `premium.doma` (High: 80 ETH, Low: 60 ETH)
- Betting pool: 10,000 USDC total across 4 categories
- 30% bet "Above High" (>80 ETH), 40% bet "High~Low" (60-80 ETH)
- 20% bet "Below Low" (<60 ETH), 10% bet "Uncleared"
- Someone bids at 75 ETH → auction clears in High~Low range (category 2)
- High~Low bettors win: 9,000 USDC (90% of total pool)
- Seller gets: 500 USDC bonus, Buyer gets: 300 USDC bonus

✅ **Benefits:**
- **Independence**: Separate system for different use cases
- **Fairness**: Hidden commitments prevent market manipulation
- **Incentives**: All participants rewarded for market activity
- **Engagement**: Creates yield opportunities around premium domains

---

## System 3: Auction-Backed Lending (ABL) for Domain Auctions

**Problem:**
Sellers often need liquidity upfront before an auction ends. Buyers sometimes hesitate to bid if they don&apos;t know the seller will follow through. Existing NFT auctions don&apos;t integrate credit or loan markets.

**Solution: Auction-Backed Lending**
Our protocol allows sellers to borrow stablecoins upfront, collateralized by their domain NFT. The NFT is locked in the auction contract. The protocol or external lenders fund up to 30-50% of the estimated floor price.

**Workflow:**
1. **List & Collateralize:** Seller lists a domain for Dutch auction. Domain NFT is locked in smart contract. Seller optionally requests an advance loan (e.g., 40% of reserve price).
2. **Funding:** Lenders or protocol treasury provide stablecoin liquidity. Loan terms (APR, repayment deadline, liquidation trigger) are encoded.
3. **Auction Runs:** Dutch auction proceeds as usual. Buyers bid without worrying about seller default (since NFT is already collateralized).
4. **Settlement:**
   - If auction clears: Loan + interest auto-repaid from sale proceeds. Remainder to seller.
   - If auction fails: Loan defaults → NFT ownership transferred to lenders.

**Benefits:**
- **Sellers:** Get immediate liquidity instead of waiting for auction results. Confidence to list high-value domains without cashflow pressure.
- **Lenders:** Gain yield if auction succeeds. Gain NFT at discounted price if auction fails.
- **Buyers:** More secure: auction integrity guaranteed by collateralized domain.
- **Protocol:** Introduces new credit layer around domain auctions. Higher liquidity → higher auction participation.

**Example Scenario:**
Seller lists premium.eth with reserve price = 10,000 USDC. Seller requests 4,000 USDC upfront loan. Auction begins: lenders fund loan, NFT locked. Auction clears at 12,000 USDC. Loan repaid = 4,000 + 200 interest. Seller receives 7,800 USDC. If auction fails → lenders get premium.eth NFT as repayment.

---

## System 4: Domain Voting Contest

**Problem:**
Domain marketplaces lack community engagement and social discovery mechanisms. Users need ways to discover trending domains while earning rewards for participation.

**Solution: Gamified Social Layer**
Introduce a voting contest where community members stake tokens to vote for favorite domains, earning long-term staking rewards while boosting domain visibility.

**Key Features:**

1. **Contest Lifecycle**
- Only one contest active at any given time
- Contest created by hoster with: startTime, endTime, minStake (e.g., 100 tokens), stakeMultiplier (e.g., 5 → maxStake = minStake × 5)

2. **Voting Mechanism**
- Users vote for up to 3 domains
- Vote weight = staking amount (not time-cumulated)
- Stake per user bounded: minStake ≤ stake ≤ minStake × multiplier
- Votes locked until contest ends

3. **Anti-Sybil & Fairness**
- Token staking required to vote
- Staking cap prevents whales from dominating
- Each wallet participates only once per contest

4. **Voter Rewards**
- **Staking Points (time-cumulated)**: StakingPoints = StakeAmount × TimeStaked
- Encourages early participation and long-term engagement
- **Rewards distributed after contest**: Fee discounts in future domain auctions/sales, priority whitelists for next contests

5. **Contest Ranking**
- Domain score = sum of votes (stake amounts)
- Rankings public and verifiable on-chain

**Example Flow:**
1. Hoster launches contest (10 days, minStake = 100, multiplier = 5)
2. Alice stakes 300 → votes for 3 domains
3. Bob stakes 200 → votes for 2 domains
4. Carol stakes 500 → votes for 1 domain
5. Contest ends: Domain A = 500, B = 500, C = 300
6. Staking points: Alice 3,000, Bob 2,000, Carol 5,000
7. Users redeem rewards in next auction round

**Benefits:**
- **Domain Owners**: Visibility, ranking-based promotion, higher sale chances
- **Voters**: Tangible rewards (NFTs, discounts, points)
- **Marketplace**: Increased engagement, token utility, fair ecosystem governance

---

## Quad Architecture System

**Batch Auction Flow (HybridDutchAuction):**  
1. **Seller** lists domain portfolio  
2. **Batch Auction Contract**:  
   - Dutch price curve  
   - Portfolio fractionalization  
   - Soft/hard bid engine with bonds  
   - Reverse royalty tracker  
   - Reward engine (points/NFTs)  
3. **Buyers** place fractional bids  
4. **Settlement**: Clears when demand ≥ 100%  

**Single Domain + Betting Flow (DomainAuctionBetting):**
1. **Seller** lists premium single domain with high/low price thresholds
2. **Single Auction Contract**:
    - Dutch price curve
    - First bid wins immediately
    - 4-tier parallel betting system
3. **Buyers** bid directly, **Bettors** wager on final price category
4. **Settlement**: Auction + betting resolved independently based on price ranges

**Auction-Backed Lending Flow (AuctionBackedLending):**
1. **Seller** lists domain in batch auction and requests loan against it
2. **Lending Contract**:
     - Loan terms encoded (amount, interest, duration)
     - Lenders fund loan in stablecoins
     - NFT remains locked in auction contract
3. **Auction runs** with collateralized domain
4. **Settlement**: Loan auto-repaid from proceeds, or NFT liquidated to lenders on failure

**Domain Voting Contest Flow (VotingContest):**
1. **Hoster** creates contest with parameters (startTime, endTime, minStake, multiplier)
2. **Domain Owners** list their domains for voting consideration
3. **Voters** stake tokens and vote for up to 3 domains
4. **Contest Runs** with real-time ranking updates
5. **Settlement**: Winners receive rewards, staking points calculated, domains returned to owners

---

## Protocol Economics & Market Efficiency

### Participation Amplification

**Traditional Domain Auctions:**
- Single-domain, single-bidder model
- Winner-takes-all dynamics
- Limited engagement beyond direct buyers
- High barriers for small participants

**Tri Protocol Advantages:**
- **10x Participation**: Batch fractionalization enables small buyers to participate in premium portfolios
- **Continuous Engagement**: Soft bids create ongoing market activity vs. last-minute sniping
- **Betting Multiplier**: Each premium auction generates 2 markets (direct bidding + price betting)
- **Loyalty Stickiness**: Gamified rewards create repeat participants vs. one-time buyers

### Transaction Volume Growth

**Volume Drivers:**
- **Batch Efficiency**: 100 domains → 1 auction (vs. 100 separate auctions)
- **Fractional Access**: $1M portfolio accessible to $10K buyers (10% stakes)
- **Betting Layer**: Premium domains generate additional betting transaction volume
- **Lending Layer**: Loans create additional capital flow and NFT liquidation opportunities
- **Reward Claiming**: Loyalty point distributions create secondary transaction flow

**Conservative Estimates:**
- **3-5x** transaction volume from batch consolidation
- **2-3x** unique participants from fractional access
- **1.5-2x** total volume from betting layer on premium domains

### Fee Revenue Optimization

**Revenue Streams:**
1. **Auction Fees**: Standard platform fees on clearing prices
2. **Betting Pool Fees**: 2% protocol cut from all betting pools
3. **Lending Interest**: Interest payments from successful loan repayments
4. **Loyalty Rewards**: Seller-funded rewards create fee-generating activity
5. **Reverse Royalties**: Dynamic royalty capture on secondary sales

**Fee Efficiency:**
- **Batch Consolidation**: Collect fees on larger transaction sizes
- **Betting Premiums**: Additional revenue without diluting core auction fees
- **Engagement Fees**: Loyalty activities generate micro-transaction fees

### Information Asymmetry Reduction

**Seller Benefits:**
- **Price Discovery**: Soft bids reveal demand curves before clearing
- **Liquidity Assurance**: Batch auctions aggregate demand for better clearing rates
- **Fair Valuation**: Betting markets provide independent price validation
- **Reduced Timing Risk**: Dutch curves eliminate guessing optimal auction timing

**Buyer Benefits:**
- **Transparent Bidding**: Soft bid thresholds visible, reducing strategic uncertainty
- **Fractional Access**: Participate in premium portfolios without full capital commitment
- **Betting Intelligence**: Price betting provides market sentiment data
- **Loyalty Rewards**: Early participation rewarded vs. penalized

**Market Efficiency:**
- **Reduced Spreads**: Batch auctions narrow bid-ask spreads through aggregation
- **Better Price Discovery**: Multiple bidding mechanisms reveal true market value
- **Lower Transaction Costs**: Batch processing reduces per-domain transaction overhead
- **Increased Liquidity**: Fractional ownership creates deeper, more liquid markets

### Network Effects

**Participation Flywheel:**
1. **More Sellers** → Larger batch auctions → Better fractional opportunities
2. **More Buyers** → Higher clearing rates → More seller participation
3. **More Betting** → Better price discovery → More accurate valuations
4. **More Lending** → Better liquidity → More auctions and higher participation
5. **More Rewards** → Stickier participants → Higher lifetime value

**Result**: Self-reinforcing ecosystem where each participant type benefits from growth in others

---

## Benefits for Doma

- 🚀 **Liquidity boost**: Batch + fractionalization + lending increase volumes.
- 💰 **Capital access**: Sellers get upfront liquidity, enabling more auctions.
- 🎮 **Engagement loop**: Rewards + gamification + lending bring sticky participants.
- ⏱️ **Dynamic urgency**: Reverse royalties ensure fast decision-making.
- 🔗 **Ecosystem fit**: Rewards tied to Protocol's NFTs, analytics.

---

## 🔑 Takeaway

This **Quad Auction Protocol** provides four specialized systems:

**🎯 System 1 - Hybrid Batch Auctions:**
- **Portfolio Trading** for scale and liquidity
- **Gamified Rewards** for community engagement
- **Reverse Royalties** for trading urgency
- **Fractional Ownership** for accessibility

**🏆 System 2 - Premium Single Domain + Betting:**
- **Premium Domain Focus** for high-value assets
- **4-Tier Price Betting** for sophisticated wagering
- **First-Bid-Wins Mechanism** for efficient completion
- **Commit-Reveal Protocol** for fair betting
- **Independent Operation** for specialized use cases

**🏦 System 3 - Auction-Backed Lending:**
- **Liquidity Provision** for sellers needing upfront capital
- **Collateralized Loans** against domain NFTs
- **Automatic Settlement** from auction proceeds
- **NFT Liquidation** on auction failure

**🗳️ System 4 - Domain Voting Contest:**
- **Community Engagement** through token staking
- **Social Discovery** for trending domains
- **Gamified Voting** with reward incentives
- **Anti-Sybil Measures** ensuring fair participation
- **Staking Rewards** for long-term engagement

👉 Result: **Complete domain trading ecosystem - from bulk portfolio liquidation to premium single-domain auctions with betting, lending, and community voting contests**

---

