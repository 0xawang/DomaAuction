# 🌐 Hybrid Dutch Auction Protocol – Hackathon Proposal  

## 1. Batch Dutch Auctions for Domain Portfolios  

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

## 2. Gamified Dutch Auctions with Bidder Rewards  

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

## 3. Reverse Dutch Auctions for Royalties  

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

## 4. Unified Architecture  

**Flow:**  
1. **Seller** lists domain(s).  
2. **Auction Manager Contract**:  
   - Dutch price curve.  
   - Portfolio batching + fractionalization.  
   - Soft/hard bid engine with bonds.  
   - Reverse royalty tracker.  
   - Reward engine (points/NFTs).  
3. **Buyers** place soft/hard bids.  
4. **Settlement:**  
   - Clears once demand ≥ 100% or single bid wins.  
   - Rewards minted **only if auction clears**.  
   - Royalties adapt dynamically if secondary trades occur.  

---

## 5. Hackathon Benefits for Doma  

- 🚀 **Liquidity boost**: Batch + fractionalization increase volumes.  
- 🎮 **Engagement loop**: Rewards + gamification bring sticky bidders.  
- ⏱️ **Dynamic urgency**: Reverse royalties ensure fast decision-making.  
- 🔗 **Ecosystem fit**: Rewards tied to Doma Ambassador badges, NFTs, analytics.  

---

## 🔑 Takeaway  

This **Hybrid Dutch Auction Protocol** blends three innovations into one:  
- **Batch Auctions** for scale.  
- **Gamified Rewards** for engagement.  
- **Reverse Royalties** for urgency.  

👉 Result: **Higher liquidity, fairer access, and stronger community incentives** for domain trading.
