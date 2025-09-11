// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IOwnershipToken.sol";

/**
 * @title DomainAuctionBetting
 * @dev Independent commit-reveal betting system for single-domain auctions
 */
contract DomainAuctionBetting is ReentrancyGuard, Ownable {
    struct SingleDomainAuction {
        address seller;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 priceDecrement;
        uint256 startedAt;
        uint256 endedAt;
        uint256 highPrice;
        uint256 lowPrice;
        bool active;
        bool cleared;
        address winner;
        uint256 finalPrice;
    }

    struct Bet {
        address bettor;
        bytes32 commitHash;
        uint256 amount;
        bool revealed;
        uint8 choice; // 3=above high, 2=high~low, 1=below low, 0=uncleared
        uint256 revealedAmount;
    }

    struct BettingPool {
        uint256 auctionId;
        uint256 totalPool;
        uint256 aboveHighPool;
        uint256 highLowPool;
        uint256 belowLowPool;
        uint256 unclearedPool;
        uint256 commitDeadline;
        uint256 revealDeadline;
        bool settled;
        uint8 auctionResult;
    }

    mapping(uint256 => SingleDomainAuction) public auctions;
    mapping(uint256 => BettingPool) public bettingPools;
    mapping(uint256 => Bet[]) public bets;
    mapping(uint256 => mapping(address => uint256)) public bettorIndex;
    
    IOwnershipToken public nftContract;
    // IERC20 public bettingToken; TODO: - Only Native Token for Test only
    
    uint256 public auctionCounter;
    uint256 public sellerCut = 500; // 5%
    uint256 public buyerCut = 300; // 3%
    uint256 public protocolCut = 200; // 2%
    uint256 public winnerCut = 9000; // 90%

    event AuctionCreated(uint256 indexed auctionId, address seller, uint256 tokenId, uint256 startPrice);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 price);
    event AuctionEnded(uint256 indexed auctionId, bool cleared, address winner, uint256 finalPrice);
    event BettingPoolCreated(uint256 indexed auctionId, uint256 commitDeadline, uint256 revealDeadline);
    event BetCommitted(uint256 indexed auctionId, address indexed bettor, bytes32 commitHash, uint256 amount);
    event BetRevealed(uint256 indexed auctionId, address indexed bettor, uint8 choice, uint256 amount);
    event BettingSettled(uint256 indexed auctionId, uint8 auctionResult, uint256 totalPool);
    event CutsUpdated(uint256 sellerCut, uint256 buyerCut, uint256 protocolCut, uint256 winnerCut);

    constructor(address _nftContract) Ownable(msg.sender) {
        nftContract = IOwnershipToken(_nftContract);
    }

    function createAuctionBetting(
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 priceDecrement,
        uint256 duration,
        uint256 highPrice,
        uint256 lowPrice,
        uint256 commitDuration,
        uint256 revealDuration
    ) external returns (uint256) {
        require(reservePrice < startPrice, "Invalid reserve");
        require(lowPrice < highPrice, "Invalid price range");
        
        uint256 auctionId = auctionCounter++;
        
        auctions[auctionId] = SingleDomainAuction({
            seller: msg.sender,
            tokenId: tokenId,
            startPrice: startPrice,
            reservePrice: reservePrice,
            priceDecrement: priceDecrement,
            startedAt: block.timestamp,
            endedAt: block.timestamp + duration,
            highPrice: highPrice,
            lowPrice: lowPrice,
            active: true,
            cleared: false,
            winner: address(0),
            finalPrice: 0
        });

        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
        
        emit AuctionCreated(auctionId, msg.sender, tokenId, startPrice);

        bettingPools[auctionId] = BettingPool({
            auctionId: auctionId,
            totalPool: 0,
            aboveHighPool: 0,
            highLowPool: 0,
            belowLowPool: 0,
            unclearedPool: 0,
            commitDeadline: block.timestamp + commitDuration,
            revealDeadline: block.timestamp + commitDuration + revealDuration,
            settled: false,
            auctionResult: 0
        });

        emit BettingPoolCreated(auctionId, bettingPools[auctionId].commitDeadline, bettingPools[auctionId].revealDeadline);
        return auctionId;
    }

    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        SingleDomainAuction storage auction = auctions[auctionId];
        if (!auction.active) return 0;
        
        if (block.timestamp >= auction.endedAt) return auction.reservePrice;
        
        uint256 timeElapsed = block.timestamp - auction.startedAt;
        uint256 priceReduction = timeElapsed * auction.priceDecrement;
        uint256 currentPrice = auction.startPrice > priceReduction ? 
            auction.startPrice - priceReduction : auction.reservePrice;
        return currentPrice > auction.reservePrice ? currentPrice : auction.reservePrice;
    }

    function placeBid(uint256 auctionId) external payable nonReentrant {
        SingleDomainAuction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        
        uint256 currentPrice = getCurrentPrice(auctionId);
        require(msg.value >= currentPrice, "Insufficient payment");
        require(currentPrice >= auction.reservePrice, "Below reserve");
        
        auction.active = false;
        auction.cleared = true;
        auction.winner = msg.sender;
        auction.finalPrice = currentPrice;
        
        nftContract.safeTransferFrom(address(this), msg.sender, auction.tokenId);
        
        if (msg.value > currentPrice) {
            payable(msg.sender).transfer(msg.value - currentPrice);
        }
        
        payable(auction.seller).transfer(currentPrice);
        
        emit BidPlaced(auctionId, msg.sender, currentPrice);
        emit AuctionEnded(auctionId, true, msg.sender, currentPrice);
    }

    function endAuction(uint256 auctionId) external {
        SingleDomainAuction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endedAt, "Auction not expired");
        
        auction.active = false;
        auction.cleared = false;
        
        nftContract.safeTransferFrom(address(this), auction.seller, auction.tokenId);
        
        emit AuctionEnded(auctionId, false, address(0), 0);
    }

    function commitBet(uint256 auctionId, bytes32 commitHash, uint256 amount) external payable nonReentrant {
        BettingPool storage pool = bettingPools[auctionId];
        require(pool.auctionId != 0, "Pool does not exist");
        require(block.timestamp <= pool.commitDeadline, "Commit phase ended");
        require(amount > 0, "Amount must be positive");
        require(amount == msg.value, "Amount must be token value");
        require(bettorIndex[auctionId][msg.sender] == 0, "Already committed");

        bets[auctionId].push(Bet({
            bettor: msg.sender,
            commitHash: commitHash,
            amount: amount,
            revealed: false,
            choice: 0,
            revealedAmount: 0
        }));

        bettorIndex[auctionId][msg.sender] = bets[auctionId].length;
        pool.totalPool += amount;

        emit BetCommitted(auctionId, msg.sender, commitHash, amount);
    }

    function revealBet(uint256 auctionId, uint8 choice, uint256 amount, uint256 secret) external {
        BettingPool storage pool = bettingPools[auctionId];
        require(pool.auctionId != 0, "Pool does not exist");
        require(block.timestamp > pool.commitDeadline, "Commit phase not ended");
        require(block.timestamp <= pool.revealDeadline, "Reveal phase ended");
        require(choice <= 3, "Invalid choice");

        uint256 index = bettorIndex[auctionId][msg.sender];
        require(index > 0, "No bet found");

        Bet storage bet = bets[auctionId][index - 1];
        require(!bet.revealed, "Already revealed");
        require(bet.bettor == msg.sender, "Not your bet");

        bytes32 hash = keccak256(abi.encodePacked(choice, amount, secret));
        require(hash == bet.commitHash, "Invalid reveal");
        require(amount == bet.amount, "Amount mismatch");

        bet.revealed = true;
        bet.choice = choice;
        bet.revealedAmount = amount;

        if (choice == 3) {
            pool.aboveHighPool += amount;
        } else if (choice == 2) {
            pool.highLowPool += amount;
        } else if (choice == 1) {
            pool.belowLowPool += amount;
        } else {
            pool.unclearedPool += amount;
        }

        emit BetRevealed(auctionId, msg.sender, choice, amount);
    }

    function _getPriceCategory(uint256 auctionId) internal view returns (uint8) {
        SingleDomainAuction storage auction = auctions[auctionId];
        
        if (!auction.cleared) {
            return 0; // Uncleared
        }
        
        if (auction.finalPrice > auction.highPrice) {
            return 3; // Above high price
        } else if (auction.finalPrice >= auction.lowPrice) {
            return 2; // High ~ Low price
        } else {
            return 1; // Below low price
        }
    }

    function settleBetting(uint256 auctionId) external nonReentrant {
        BettingPool storage pool = bettingPools[auctionId];
        SingleDomainAuction storage auction = auctions[auctionId];
        
        require(pool.auctionId != 0, "Pool does not exist");
        require(block.timestamp > pool.revealDeadline, "Reveal phase not ended");
        require(!pool.settled, "Already settled");
        require(!auction.active, "Auction still active");

        pool.auctionResult = _getPriceCategory(auctionId);
        pool.settled = true;

        _distributePayout(auctionId);

        emit BettingSettled(auctionId, pool.auctionResult, pool.totalPool);
    }

    function _distributePayout(uint256 auctionId) internal {
        BettingPool storage pool = bettingPools[auctionId];
        SingleDomainAuction storage auction = auctions[auctionId];
        Bet[] storage poolBets = bets[auctionId];

        uint256 winnerPool;
        if (pool.auctionResult == 3) {
            winnerPool = pool.aboveHighPool;
        } else if (pool.auctionResult == 2) {
            winnerPool = pool.highLowPool;
        } else if (pool.auctionResult == 1) {
            winnerPool = pool.belowLowPool;
        } else {
            winnerPool = pool.unclearedPool;
        }
        
        if (winnerPool == 0) {
            _refundRevealedBets(auctionId);
            return;
        }

        uint256 winnerAmount = (pool.totalPool * winnerCut) / 10000;
        uint256 sellerAmount = (pool.totalPool * sellerCut) / 10000;
        uint256 buyerAmount = (pool.totalPool * buyerCut) / 10000;

        for (uint256 i = 0; i < poolBets.length; i++) {
            if (poolBets[i].revealed && poolBets[i].choice == pool.auctionResult) {
                uint256 payout = (winnerAmount * poolBets[i].revealedAmount) / winnerPool;
                payable(poolBets[i].bettor).transfer(payout);
            }
        }

        payable(auction.seller).transfer(sellerAmount);
        
        if (auction.cleared && auction.winner != address(0)) {
            payable(auction.winner).transfer(buyerAmount);
        }
    }

    function _refundRevealedBets(uint256 auctionId) internal {
        Bet[] storage poolBets = bets[auctionId];
        
        for (uint256 i = 0; i < poolBets.length; i++) {
            if (poolBets[i].revealed) {
                payable(poolBets[i].bettor).transfer(poolBets[i].revealedAmount);
            }
        }
    }

    function getBettingPool(uint256 auctionId) external view returns (BettingPool memory) {
        return bettingPools[auctionId];
    }

    function getBetCount(uint256 auctionId) external view returns (uint256) {
        return bets[auctionId].length;
    }

    function getBet(uint256 auctionId, uint256 betIndex) external view returns (Bet memory) {
        return bets[auctionId][betIndex];
    }

    function setCuts(uint256 _sellerCut, uint256 _buyerCut, uint256 _protocolCut, uint256 _winnerCut) external onlyOwner {
        require(_sellerCut + _buyerCut + _protocolCut + _winnerCut == 10000, "Cuts must sum to 100%");
        
        sellerCut = _sellerCut;
        buyerCut = _buyerCut;
        protocolCut = _protocolCut;
        winnerCut = _winnerCut;
        
        emit CutsUpdated(_sellerCut, _buyerCut, _protocolCut, _winnerCut);
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}