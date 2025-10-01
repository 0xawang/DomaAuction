// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IOwnershipToken.sol";

/**
 * @title AuctionBackedLending
 * @dev Implements auction-backed lending with integrated simple Dutch auctions for domain NFTs
 * Sellers can borrow stablecoins against their NFTs and create auctions
 */
contract AuctionBackedLending is ReentrancyGuard, IERC721Receiver {
    /**
     * @dev Auction data structure
     * @param seller Address of the auction creator
     * @param tokenId NFT token ID being auctioned
     * @param startPrice Initial auction price
     * @param reservePrice Minimum price floor
     * @param priceDecrement Price reduction per second
     * @param startTime Timestamp when auction started
     * @param duration Auction duration in seconds
     * @param active Whether auction is currently active
     * @param winner Address of the winner (0 if no winner)
     * @param finalPrice Final sale price
     * @param hasLoan Whether this auction has an associated loan
     * @param loanAmount Loan amount (0 if no loan)
     * @param loanDuration Loan duration in days (0 if no loan)
     * @param loanInterest Loan interest rate in basis points (0 if no loan)
     * @param lender Address of the lender (address(0) if not funded)
     * @param loanRepaid Whether the loan has been repaid
     * @param loanLiquidated Whether the loan has been liquidated
     */
    struct Auction {
        address seller;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 priceDecrement;
        uint256 startTime;
        uint256 duration;
        bool active;
        address winner;
        uint256 finalPrice;
        uint256 loanAmount;
        uint256 loanDuration;
        uint256 loanInterest;
        address lender;
        bool loanRepaid;
        bool loanLiquidated;
    }

    mapping(uint256 => Auction) public auctions;
    uint256 public auctionCounter;

    IOwnershipToken public nftContract;
    IERC20 public stablecoin; // e.g., USDC

    uint256 public constant MAX_LOAN_PERCENT = 5000; // 50% of reserve price
    uint256 public constant MIN_LOAN_DURATION = 1 days;
    uint256 public constant MAX_LOAN_DURATION = 90 days;

    event AuctionCreated(uint256 indexed auctionId, address seller, uint256 tokenId, uint256 startPrice, uint256 reservePrice);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 price);
    event AuctionEnded(uint256 indexed auctionId, address winner, uint256 finalPrice);
    event LoanRequested(uint256 indexed loanId, uint256 indexed auctionId, address borrower, uint256 amount, uint256 interestBps);
    event LoanFunded(uint256 indexed loanId, address lender, uint256 amount);
    event LoanRepaid(uint256 indexed loanId, uint256 totalRepayment);
    event LoanLiquidated(uint256 indexed loanId, address liquidator);

    /**
     * @dev Contract constructor
     * @param _nftContract Address of the NFT contract
     * @param _stablecoin Address of the stablecoin ERC20 token
     */
    constructor(address _nftContract, address _stablecoin) {
        nftContract = IOwnershipToken(_nftContract);
        stablecoin = IERC20(_stablecoin);
    }

    /**
     * @dev Creates an auction with optional loan
     * @param tokenId NFT token ID to auction
     * @param startPrice Starting price
     * @param reservePrice Minimum price
     * @param priceDecrement Price decrease per second
     * @param startedAt Timestamp when auction starts (should be >= block.timestamp)
     * @param duration Auction duration in seconds
     * @param loanAmount Loan amount (0 for no loan)
     * @param interestBps Interest rate in basis points (if loan)
     * @param loanDurationDays Loan duration in days (if loan)
     * @return auctionId The ID of the created auction
     */
    function createAuction(
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 priceDecrement,
        uint256 startedAt,
        uint256 duration,
        uint256 loanAmount,
        uint256 interestBps,
        uint256 loanDurationDays
    ) external returns (uint256) {
        require(startPrice >= reservePrice, "Invalid prices");
        require(startedAt >= block.timestamp, "Invalid start time");
        require(duration > 0, "Invalid duration");
        require(nftContract.ownerOf(tokenId) == msg.sender, "Not token owner");

        require(loanAmount > 0, "Loan amount must be greater than 0");
        require(loanDurationDays >= MIN_LOAN_DURATION && loanDurationDays <= MAX_LOAN_DURATION, "Invalid loan duration");
        require(interestBps > 0 && interestBps <= 10000, "Invalid interest rate");

        uint256 auctionId = auctionCounter++;
        Auction storage auction = auctions[auctionId];
        auction.seller = msg.sender;
        auction.tokenId = tokenId;
        auction.startPrice = startPrice;
        auction.reservePrice = reservePrice;
        auction.priceDecrement = priceDecrement;
        auction.startTime = startedAt;
        auction.duration = duration;
        auction.active = true;

        // Transfer NFT to contract
        nftContract.safeTransferFrom(msg.sender, address(this), tokenId);
        emit AuctionCreated(auctionId, msg.sender, tokenId, startPrice, reservePrice);

        // Check loan amount doesn't exceed max percentage of reserve price
        uint256 maxLoan = (reservePrice * MAX_LOAN_PERCENT) / 10000;
        require(loanAmount <= maxLoan, "Loan amount exceeds maximum");

        auction.loanAmount = loanAmount;
        auction.loanDuration = loanDurationDays;
        auction.loanInterest = interestBps;
        auction.loanRepaid = false;
        auction.loanLiquidated = false;

        emit LoanRequested(auctionId, auctionId, msg.sender, loanAmount, interestBps);
        return auctionId;
    }

    /**
     * @dev Gets current Dutch auction price
     * @param auctionId ID of the auction
     * @return Current price (decreases over time until reserve)
     */
    function getCurrentPrice(uint256 auctionId) public view returns (uint256) {
        Auction storage auction = auctions[auctionId];
        if (!auction.active) return 0;

        uint256 elapsed = block.timestamp - auction.startTime;
        if (elapsed >= auction.duration) return auction.reservePrice;

        uint256 priceReduction = elapsed * auction.priceDecrement;
        uint256 currentPrice = auction.startPrice > priceReduction ? auction.startPrice - priceReduction : auction.reservePrice;
        return currentPrice > auction.reservePrice ? currentPrice : auction.reservePrice;
    }

    /**
     * @dev Places a bid on an auction
     * @param auctionId ID of the auction to bid on
     */
    function bid(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(auction.winner == address(0), "Auction already ended");

        uint256 currentPrice = getCurrentPrice(auctionId);
        require(msg.value >= currentPrice, "Bid too low");

        // End auction
        auction.active = false;
        auction.winner = msg.sender;
        auction.finalPrice = currentPrice;

        // Transfer NFT to winner
        nftContract.safeTransferFrom(address(this), msg.sender, auction.tokenId);

        // Handle payments
        if (!auction.loanRepaid && !auction.loanLiquidated && auction.lender != address(0)) {
            uint256 interest = (auction.loanAmount * auction.loanInterest) / 10000;
            uint256 totalRepayment = auction.loanAmount + interest;

            if (currentPrice >= totalRepayment) {
                // Repay loan
                auction.loanRepaid = true;

                // Pay to lender
                payable(auction.lender).transfer(totalRepayment);

                // Remainder to seller
                uint256 remainder = currentPrice - totalRepayment;
                payable(auction.seller).transfer(remainder);
            } else {
                // Not enough to repay, seller gets all
                payable(auction.seller).transfer(currentPrice);
            }
        } else {
            // No loan or already handled
            payable(auction.seller).transfer(currentPrice);
        }

        // Refund excess bid
        if (msg.value > currentPrice) {
            payable(msg.sender).transfer(msg.value - currentPrice);
        }

        emit BidPlaced(auctionId, msg.sender, currentPrice);
        emit AuctionEnded(auctionId, msg.sender, currentPrice);
    }

    /**
     * @dev Funds a loan request (single lender only)
     * @param auctionId ID of the auction with the loan
     */
    function fundLoan(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(!auction.loanRepaid && !auction.loanLiquidated, "Loan already settled");
        require(auction.lender == address(0), "Loan already funded"); // Only one lender
        require(msg.value >= auction.loanAmount, "Must fund full amount");

        // Set single lender
        auction.lender = msg.sender;

        emit LoanFunded(auctionId, msg.sender, auction.loanAmount);

        // Disburse to borrower
        payable(auction.seller).transfer(auction.loanAmount);

        // Refund excess
        if (msg.value > auction.loanAmount) {
            payable(msg.sender).transfer(msg.value - auction.loanAmount);
        }
    }

    /**
     * @dev Repays a loan
     * @param auctionId ID of the auction with the loan
     */
    function repayLoan(uint256 auctionId) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.seller == msg.sender, "Only borrower can repay");
        require(!auction.loanRepaid && !auction.loanLiquidated, "Loan already settled");

        uint256 interest = (auction.loanAmount * auction.loanInterest) / 10000;
        uint256 totalRepayment = auction.loanAmount + interest;

        require(msg.value >= totalRepayment, "Insufficient payment");

        auction.loanRepaid = true;

        // Pay to lender
        payable(auction.lender).transfer(totalRepayment);

        // Refund excess
        if (msg.value > totalRepayment) {
            payable(msg.sender).transfer(msg.value - totalRepayment);
        }

        emit LoanRepaid(auctionId, totalRepayment);
    }

    /**
     * @dev Checks and liquidates a loan if auction failed and loan is due
     * @param auctionId ID of the auction with the loan
     */
    function checkAndLiquidate(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(!auction.loanRepaid && !auction.loanLiquidated, "Loan already settled");
        require(block.timestamp >= auction.startTime + auction.loanDuration * 1 days, "Loan not yet due");
        require(!auction.active && auction.winner == address(0), "Auction not failed");

        auction.loanLiquidated = true;

        // Transfer NFT to lender
        nftContract.safeTransferFrom(address(this), auction.lender, auction.tokenId);

        emit LoanLiquidated(auctionId, msg.sender);
    }

    /**
     * @dev Gets loan details for an auction
     * @param auctionId ID of the auction
     * @return borrower The borrower address
     * @return lender The lender address
     * @return loanAmount The requested loan amount
     * @return dueTimestamp The timestamp when the loan is due
     * @return repaid Whether the loan has been repaid
     * @return liquidated Whether the loan has been liquidated
     */
    function getLoanDetails(uint256 auctionId) external view returns (
        address borrower,
        address lender,
        uint256 loanAmount,
        uint256 dueTimestamp,
        bool repaid,
        bool liquidated
    ) {
        Auction storage auction = auctions[auctionId];
        return (
            auction.seller,
            auction.lender,
            auction.loanAmount,
            auction.startTime + auction.loanDuration * 1 days,
            auction.loanRepaid,
            auction.loanLiquidated
        );
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