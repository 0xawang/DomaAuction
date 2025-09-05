// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IOwnershipToken.sol";
import "./LoyaltyNFT.sol";

/**
 * @title HybridDutchAuction
 * @dev Implements batch Dutch auctions with gamified bidding and reverse royalties
 */
contract HybridDutchAuction is ReentrancyGuard, IERC721Receiver {
    /**
     * @dev Auction data structure
     * @param seller Address of the auction creator
     * @param tokenIds Array of NFT token IDs being auctioned
     * @param startPrice Initial auction price per token
     * @param reservePrice Minimum price floor per token
     * @param priceDecrement Price reduction per block per token
     * @param startBlock Block number when auction started
     * @param duration Auction duration in blocks
     * @param startedAt timestamp when auction started
     * @param endedAt timestamp when auction ended
     * @param active Whether auction is currently active
     * @param cleared Whether auction has been successfully cleared
     * @param rewardBudgetBps Basis points of proceeds allocated to rewards (0-500)
     * @param royaltyIncrement Reverse royalty increase per block (0 = disabled)
     * @param paymentToken ERC20 token for payments (address(0) = ETH)
     * @param totalConverted Total number of tokens that have been converted
     */
    struct Auction {
        address seller;
        uint256[] tokenIds;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 priceDecrement;
        uint256 startBlock;
        uint256 duration;
        uint256 startedAt;
        uint256 endedAt;
        bool active;
        bool cleared;
        uint256 rewardBudgetBps;
        uint256 royaltyIncrement;
        IERC20 paymentToken;
        uint256 totalConverted;
    }

    /**
     * @dev Soft bid data structure for intent-based bidding
     * @param bidder Address of the bidder
     * @param threshold Price per token at which bid auto-converts
     * @param desiredCount Number of tokens desired from bundle
     * @param bond Refundable deposit to prevent spam
     * @param blockNumber Block when bid was placed (for time-weighting)
     * @param converted Whether bid has been converted to purchase
     */
    struct SoftBid {
        address bidder;
        uint256 threshold;
        uint256 desiredCount;
        uint256 bond;
        uint256 blockNumber;
        bool converted;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => SoftBid[]) public softBids;
    mapping(address => uint256) public bondBalances;
    mapping(uint256 => mapping(address => uint256)) public fractionalOwnership;
    
    uint256 public auctionCounter;
    LoyaltyNFT public loyaltyNFT;
    IOwnershipToken public nftContract;
    uint256 public constant BOND_BPS = 20; // 0.2%

    event AuctionCreated(uint256 indexed auctionId, address seller, uint256 startPrice, uint256 reservePrice, bool hasReverseRoyalty);
    event SoftBidPlaced(uint256 indexed auctionId, address bidder, uint256 threshold, uint256 count, uint256 bond);
    event SoftBidConverted(uint256 indexed auctionId, address bidder, uint256 price, uint256 count);
    event AuctionCleared(uint256 indexed auctionId, uint256 clearingPrice, uint256 totalRewards, uint256 royaltyAmount);

    /**
     * @dev Contract constructor
     * @param _loyaltyNFT Address of the loyalty NFT contract for rewards
     */
    constructor(address _loyaltyNFT, address _nftContract) {
        loyaltyNFT = LoyaltyNFT(_loyaltyNFT);        
        nftContract = IOwnershipToken(_nftContract);
    }

    /**
     * @dev Creates a new batch Dutch auction
     * @param tokenIds Array of token IDs to include in batch
     * @param startPrice Initial price per token
     * @param reservePrice Minimum price floor per token
     * @param priceDecrement Price reduction per block per token
     * @param duration Auction duration in seconds
     * @param rewardBudgetBps Basis points for loyalty rewards (0-500 = 0-5%)
     * @param royaltyIncrement Reverse royalty increase per block (0 = disabled)
     * @param paymentToken ERC20 token address (address(0) for ETH)
     * @return auctionId The ID of the created auction
     */
    function createBatchAuction(
        uint256[] memory tokenIds,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 priceDecrement,
        uint256 duration,
        uint256 rewardBudgetBps,
        uint256 royaltyIncrement,
        address paymentToken
    ) external returns (uint256) {
        require(reservePrice < startPrice, "Invalid reserve");
        require(rewardBudgetBps <= 500, "Reward budget too high"); // max 5%
        
        uint256 auctionId = auctionCounter++;
        Auction storage auction = auctions[auctionId];
        
        auction.seller = msg.sender;
        auction.tokenIds = tokenIds;
        auction.startPrice = startPrice;
        auction.reservePrice = reservePrice;
        auction.priceDecrement = priceDecrement;
        auction.startBlock = block.number;
        auction.duration = duration / 2;
        auction.startedAt = block.timestamp;
        auction.endedAt = block.timestamp + duration;
        auction.rewardBudgetBps = rewardBudgetBps;
        auction.royaltyIncrement = royaltyIncrement;
        auction.paymentToken = IERC20(paymentToken);
        auction.active = true;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            nftContract.safeTransferFrom(msg.sender, address(this), tokenIds[i]);
        }

        emit AuctionCreated(auctionId, msg.sender, startPrice, reservePrice, royaltyIncrement > 0);
        return auctionId;
    }

    /**
     * @dev Gets current Dutch auction price per token
     * @param auctionId ID of the auction
     * @return Current price per token (decreases over time until reserve)
     */
    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (!auction.active) return 0;
        
        uint256 blocksElapsed = block.number - auction.startBlock;
        if (blocksElapsed >= auction.duration) return auction.reservePrice;
        
        uint256 priceReduction = blocksElapsed * auction.priceDecrement;
        uint256 currentPrice = auction.startPrice > priceReduction ? auction.startPrice - priceReduction : auction.reservePrice;
        return currentPrice > auction.reservePrice ? currentPrice : auction.reservePrice;
    }

    /**
     * @dev Gets current reverse royalty rate in basis points
     * @param auctionId ID of the auction
     * @return Current royalty rate (increases over time)
     */
    function getCurrentRoyalty(uint256 auctionId) external view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (!auction.active || auction.royaltyIncrement == 0) return 0;
        
        uint256 blocksElapsed = block.number - auction.startBlock;
        return blocksElapsed * auction.royaltyIncrement;
    }

    /**
     * @dev Places a soft bid with intent-based auto-conversion
     * @param auctionId ID of the auction to bid on
     * @param threshold Price per token at which bid should auto-convert
     * @param desiredCount Number of tokens desired from bundle
     */
    function placeSoftBid(uint256 auctionId, uint256 threshold, uint256 desiredCount) external payable {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(desiredCount > 0 && desiredCount <= auction.tokenIds.length, "Invalid count");
        
        uint256 maxPayment = threshold * desiredCount;
        uint256 bondRequired = (maxPayment * BOND_BPS) / 10000;
        
        if (address(auction.paymentToken) == address(0)) {
            require(msg.value >= maxPayment, "Insufficient ETH payment");
        } else {
            require(msg.value == 0, "ETH not accepted for ERC20 auction");
            auction.paymentToken.transferFrom(msg.sender, address(this), maxPayment);
        }
        
        softBids[auctionId].push(SoftBid({
            bidder: msg.sender,
            threshold: threshold,
            desiredCount: desiredCount,
            bond: bondRequired,
            blockNumber: block.number,
            converted: false
        }));
        
        bondBalances[msg.sender] += bondRequired;
        
        emit SoftBidPlaced(auctionId, msg.sender, threshold, desiredCount, bondRequired);
    }

    /**
     * @dev Places a hard bid for immediate purchase at current price
     * @param auctionId ID of the auction to bid on
     * @param desiredCount Number of tokens desired from bundle
     */
    function placeHardBid(uint256 auctionId, uint256 desiredCount) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(desiredCount > 0 && desiredCount <= auction.tokenIds.length, "Invalid count");
        require(auction.totalConverted + desiredCount <= auction.tokenIds.length, "Exceeds available capacity");
        
        uint256 currentPrice = getCurrentPrice(auctionId);
        require(currentPrice >= auction.reservePrice, "Below reserve");
        
        uint256 payment = currentPrice * desiredCount;
        
        if (address(auction.paymentToken) == address(0)) {
            require(msg.value >= payment, "Insufficient ETH payment");
            if (msg.value > payment) {
                payable(msg.sender).transfer(msg.value - payment);
            }
        } else {
            require(msg.value == 0, "ETH not accepted for ERC20 auction");
            auction.paymentToken.transferFrom(msg.sender, address(this), payment);
        }
        
        // Create and immediately convert a soft bid for tracking
        softBids[auctionId].push(SoftBid({
            bidder: msg.sender,
            threshold: currentPrice,
            desiredCount: desiredCount,
            bond: 0, // No bond for hard bids
            blockNumber: block.number,
            converted: true
        }));
        
        // Update auction state
        fractionalOwnership[auctionId][msg.sender] += desiredCount;
        auction.totalConverted += desiredCount;
        
        emit SoftBidConverted(auctionId, msg.sender, currentPrice, desiredCount);
        
        // Check if auction should clear
        if (auction.totalConverted >= auction.tokenIds.length) {
            _clearAuction(auctionId, currentPrice);
        }
    }

    /**
     * @dev Processes eligible soft bid conversions with pro-rata allocation
     * @param auctionId ID of the auction to process
     */
    function processConversions(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        
        uint256 currentPrice = getCurrentPrice(auctionId);
        require(currentPrice >= auction.reservePrice, "Below reserve");
        
        _processEligibleBids(auctionId, currentPrice);
        
        if (auction.totalConverted >= auction.tokenIds.length) {
            _clearAuction(auctionId, currentPrice);
        }
    }
    
    function _processEligibleBids(uint256 auctionId, uint256 currentPrice) internal {
        Auction storage auction = auctions[auctionId];
        SoftBid[] storage bids = softBids[auctionId];
        
        uint256 totalDemand = 0;
        for (uint256 i = 0; i < bids.length; i++) {
            if (!bids[i].converted && currentPrice <= bids[i].threshold) {
                totalDemand += bids[i].desiredCount;
            }
        }
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (!bids[i].converted && currentPrice <= bids[i].threshold) {
                uint256 allocated = bids[i].desiredCount;
                
                if (auction.totalConverted + totalDemand > auction.tokenIds.length) {
                    uint256 remaining = auction.tokenIds.length - auction.totalConverted;
                    allocated = (bids[i].desiredCount * remaining) / totalDemand;
                }
                
                if (allocated > 0) {
                    bids[i].converted = true;
                    fractionalOwnership[auctionId][bids[i].bidder] += allocated;
                    auction.totalConverted += allocated;
                    
                    uint256 refund = bids[i].threshold * bids[i].desiredCount - currentPrice * allocated;
                    if (refund > 0) {
                        _transferPayment(auction.paymentToken, bids[i].bidder, refund);
                    }
                    
                    emit SoftBidConverted(auctionId, bids[i].bidder, currentPrice, allocated);
                    
                    if (auction.tokenIds.length == 1) {
                        _clearAuction(auctionId, currentPrice);
                        return;
                    }
                }
            }
        }
    }

    /**
     * @dev Internal function to clear auction and distribute proceeds
     * @param auctionId ID of the auction to clear
     * @param clearingPrice Final price per token at which auction cleared
     */
    function _clearAuction(uint256 auctionId, uint256 clearingPrice) internal {
        Auction storage auction = auctions[auctionId];
        auction.active = false;
        auction.cleared = true;
        
        // Calculate total payment from all converted bids
        uint256 totalPayment = 0;
        SoftBid[] storage bids = softBids[auctionId];
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].converted) {
                totalPayment += clearingPrice * fractionalOwnership[auctionId][bids[i].bidder];
            }
        }
        
        uint256 royaltyAmount = 0;
        
        // Calculate reverse royalty if enabled
        if (auction.royaltyIncrement > 0) {
            uint256 blocksElapsed = block.number - auction.startBlock;
            uint256 royaltyBps = blocksElapsed * auction.royaltyIncrement;
            royaltyAmount = (totalPayment * royaltyBps) / 10000;
        }
        
        uint256 rewardPool = ((totalPayment - royaltyAmount) * auction.rewardBudgetBps) / 10000;
        uint256 sellerProceeds = totalPayment - royaltyAmount - rewardPool;
        
        // Distribute rewards (only if rewardBudgetBps > 0)
        if (auction.rewardBudgetBps > 0) {
            _distributeRewards(auctionId, rewardPool);
        } else {
            // Refund bonds for non-rewarded auctions
            _refundBonds(auctionId);
        }
        
        // Pay seller
        _transferPayment(auction.paymentToken, auction.seller, sellerProceeds);
        
        // Pay royalties to original creators
        if (royaltyAmount > 0) {
            _distributeRoyalties(auctionId, royaltyAmount);
        }
        
        emit AuctionCleared(auctionId, clearingPrice, rewardPool, royaltyAmount);
    }
    
    function _distributeRewards(uint256 auctionId, uint256 rewardPool) internal {
        SoftBid[] storage bids = softBids[auctionId];
        uint256 totalScore = _calculateTotalScore(auctionId);
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].converted && totalScore > 0) {
                uint256 score = _calculateBidScore(auctionId, i);
                uint256 reward = (rewardPool * score) / totalScore;
                uint256 points = (score * 1000) / totalScore;
                
                if (reward > 0) {
                    _transferPayment(auctions[auctionId].paymentToken, bids[i].bidder, reward);
                }
                loyaltyNFT.addPoints(bids[i].bidder, points);
                
                bondBalances[bids[i].bidder] -= bids[i].bond;
                _transferPayment(auctions[auctionId].paymentToken, bids[i].bidder, bids[i].bond);
            }
        }
    }
    
    function _calculateTotalScore(uint256 auctionId) internal view returns (uint256) {
        SoftBid[] storage bids = softBids[auctionId];
        uint256 totalScore = 0;
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].converted) {
                totalScore += _calculateBidScore(auctionId, i);
            }
        }
        return totalScore;
    }
    
    function _calculateBidScore(uint256 auctionId, uint256 bidIndex) internal view returns (uint256) {
        SoftBid storage bid = softBids[auctionId][bidIndex];
        Auction storage auction = auctions[auctionId];
        
        uint256 timeWeight = auction.startBlock + auction.duration - bid.blockNumber;
        uint256 priceMultiplier = bid.threshold > getCurrentPrice(auctionId) ? 150 : 100;
        uint256 stakeMultiplier = fractionalOwnership[auctionId][bid.bidder];
        
        return (timeWeight * priceMultiplier * stakeMultiplier) / 100;
    }
    
    function _refundBonds(uint256 auctionId) internal {
        SoftBid[] storage bids = softBids[auctionId];
        
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].converted) {
                bondBalances[bids[i].bidder] -= bids[i].bond;
                _transferPayment(auctions[auctionId].paymentToken, bids[i].bidder, bids[i].bond);
            }
        }
    }
    
    function _distributeRoyalties(uint256 auctionId, uint256 royaltyAmount) internal {
        Auction storage auction = auctions[auctionId];
        uint256 perTokenRoyalty = royaltyAmount / auction.tokenIds.length;
        
        for (uint256 i = 0; i < auction.tokenIds.length; i++) {
            (address royaltyReceiver,) = nftContract.royaltyInfo(auction.tokenIds[i], perTokenRoyalty);
            if (royaltyReceiver != address(0)) {
                _transferPayment(auction.paymentToken, royaltyReceiver, perTokenRoyalty);
            } else {
                _transferPayment(auction.paymentToken, auction.seller, perTokenRoyalty);
            }
        }
    }
    
    /**
     * @dev Refunds bonds for expired auctions that didn't clear
     * @param auctionId ID of the expired auction
     */
    function refundExpiredBonds(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];
        require(!auction.active && !auction.cleared, "Auction still active or cleared");
        
        // Check if auction expired (duration passed and price at reserve)
        uint256 blocksElapsed = block.number - auction.startBlock;
        require(blocksElapsed >= auction.duration, "Auction not expired");
        
        SoftBid[] storage bids = softBids[auctionId];
        for (uint256 i = 0; i < bids.length; i++) {
            if (!bids[i].converted && bids[i].bidder == msg.sender) {
                bondBalances[msg.sender] -= bids[i].bond;
                _transferPayment(auction.paymentToken, msg.sender, bids[i].bond);
            }
        }
    }
    
    /**
     * @dev Internal function to handle both ETH and ERC20 transfers
     * @param token ERC20 token (address(0) for ETH)
     * @param to Recipient address
     * @param amount Amount to transfer
     */
    function _transferPayment(IERC20 token, address to, uint256 amount) internal {
        if (address(token) == address(0)) {
            payable(to).transfer(amount);
        } else {
            token.transfer(to, amount);
        }
    }

    /**
     * this function is used in test-only case
     * @param receiver receiver address of OwnershipTokens locked in contract
     * @param tokenIds locked tokenIds
    */
    function transferOwnershipTokens(address receiver, uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            nftContract.transferFrom(address(this), receiver, tokenIds[i]);
        }            
    }

    /**
     * @dev Gets token count owned by a bidder
     * @param auctionId ID of the auction
     * @param owner Address of the bidder
     * @return Number of tokens owned by the bidder
     */
    function getFractionalOwnership(uint256 auctionId, address owner) external view returns (uint256) {
        return fractionalOwnership[auctionId][owner];
    }

    /**
     * @dev Gets token IDs for an auction
     * @param auctionId ID of the auction
     * @return Array of token IDs in the auction
     */
    function getAuctionTokenIds(uint256 auctionId) external view returns (uint256[] memory) {
        return auctions[auctionId].tokenIds;
    }

    /**
     * @dev Gets number of tokens filled (converted) in an auction
     * @param auctionId ID of the auction
     * @return filled Number of tokens filled (converted) in the auction
     */
    function getAuctionFilled(uint256 auctionId) external view returns (uint256 filled) {
        if (!auctions[auctionId].active) {
            return 0;
        }

        // Calculate filled amount based on bids
        SoftBid[] storage bids = softBids[auctionId];
        for (uint256 i = 0; i < bids.length; i++) {
            if (bids[i].converted || bids[i].threshold >= getCurrentPrice(auctionId)) {
                filled += bids[i].desiredCount;
            }
        }
    }
    
    /**
     * @dev Required function to receive ERC721 tokens safely
     * @return bytes4 selector confirming receipt capability
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}