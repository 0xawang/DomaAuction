// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/IOwnershipToken.sol";

/**
 * @title VotingContest
 * @dev Domain voting contest with staking-based voting mechanism
 */
contract VotingContest is ReentrancyGuard, IERC721Receiver {
    IERC20 public stakingToken;
    IOwnershipToken public nftContract;

    struct Contest {
        uint256 startTime;
        uint256 endTime;
        uint256 minStake;
        uint256 multiplier;
        bool active;
        bool ended;
        uint256 totalVoted;
        uint256 totalStaked;
    }

    mapping(uint256 => Contest) public contests;
    address public sponsor;
    uint256 public currentContestId;

    struct Voter {
        uint256 stakeAmount;
        uint256 voteTime;
        uint256[] domainIds;
    }

    // Per contest data
    mapping(uint256 => mapping(uint256 => address)) public contestDomainOwners; // contestId => domainId => owner
    mapping(uint256 => mapping(uint256 => uint256)) public contestDomainVotes; // contestId => domainId => votes
    mapping(uint256 => mapping(address => Voter)) public contestVoters; // contestId => user => voter
    mapping(uint256 => mapping(address => bool)) public contestHasVoted; // contestId => user => hasVoted

    event ContestCreated(uint256 indexed contestId, uint256 startTime, uint256 endTime, uint256 minStake, uint256 multiplier);
    event DomainListed(uint256 indexed domainId, address indexed owner);
    event Voted(address indexed user, uint256[] domainIds, uint256 stakeAmount);
    event ContestEnded(uint256 indexed contestId, uint256[] rankedDomains, uint256[] scores);
    event Unstaked(address indexed user, uint256 amount);

    /**
     * @dev Contract constructor
     * @param _stakingToken Address of the ERC20 token for staking
     * @param _nftContract Address of the NFT contract
     */
    constructor(address _stakingToken, address _nftContract, address _sponsor) {
        stakingToken = IERC20(_stakingToken);
        nftContract = IOwnershipToken(_nftContract);
        sponsor = _sponsor;
    }

    /**
     * @dev List a domain for the contest (lock it)
     * @param domainId Domain token ID to list
     */
    function listDomain(uint256 domainId) external {
        require(contests[currentContestId].active, "No active contest");
        require(contestDomainOwners[currentContestId][domainId] == address(0), "Domain already listed");
        require(nftContract.ownerOf(domainId) == msg.sender, "Not domain owner");

        // Transfer NFT to contract (lock it)
        nftContract.safeTransferFrom(msg.sender, address(this), domainId);
        contestDomainOwners[currentContestId][domainId] = msg.sender;
        emit DomainListed(domainId, msg.sender);
    }

    /**
     * @dev Create a new contest (only if no active contest)
     * @param startTime Contest start timestamp
     * @param endTime Contest end timestamp
     * @param minStake Minimum stake amount
     * @param multiplier Stake multiplier for max stake
     */
    function createContest(
        uint256 startTime,
        uint256 endTime,
        uint256 minStake,
        uint256 multiplier
    ) external {
        require(msg.sender == sponsor, "Only sponsor");
        require(currentContestId == 0 || !contests[currentContestId].active, "Contest already active");
        require(startTime < endTime, "Invalid times");
        require(minStake > 0, "Invalid min stake");
        require(multiplier >= 1 && multiplier < 6, "Invalid multiplier");

        currentContestId++;
        contests[currentContestId] = Contest({
            startTime: startTime,
            endTime: endTime,
            minStake: minStake,
            multiplier: multiplier,
            active: true,
            ended: false,
            totalVoted: 0,
            totalStaked: 0
        });

        emit ContestCreated(currentContestId, startTime, endTime, minStake, multiplier);
    }

    /**
     * @dev Vote for domains
     * @param domainIds Array of domain IDs to vote for (max 3)
     * @param stakeAmount Amount to stake for voting
     */
    function vote(uint256[] calldata domainIds, uint256 stakeAmount) external nonReentrant {
        require(contests[currentContestId].active, "No active contest");
        require(block.timestamp >= contests[currentContestId].startTime, "Contest not started");
        require(block.timestamp <= contests[currentContestId].endTime, "Contest ended");
        require(!contestHasVoted[currentContestId][msg.sender], "Already voted");
        require(domainIds.length > 0 && domainIds.length <= 3, "Invalid domain count");

        require(stakeAmount >= contests[currentContestId].minStake, "Stake below minimum");
        require(stakeAmount <= contests[currentContestId].minStake * contests[currentContestId].multiplier, "Stake above maximum");

        // Check that all domainIds are listed for the contest
        for (uint256 i = 0; i < domainIds.length; i++) {
            require(contestDomainOwners[currentContestId][domainIds[i]] != address(0), "Domain not listed for contest");
        }

        // Transfer tokens to contract (staking)
        require(stakingToken.transferFrom(msg.sender, address(this), stakeAmount), "Staking transfer failed");

        // Record vote
        for (uint256 i = 0; i < domainIds.length; i++) {
            contestDomainVotes[currentContestId][domainIds[i]] += stakeAmount;
        }

        // Record voter
        contestVoters[currentContestId][msg.sender] = Voter({
            stakeAmount: stakeAmount,
            voteTime: block.timestamp,
            domainIds: domainIds
        });

        contestHasVoted[currentContestId][msg.sender] = true;
        contests[currentContestId].totalVoted += domainIds.length;
        contests[currentContestId].totalStaked += stakeAmount;
        emit Voted(msg.sender, domainIds, stakeAmount);
    }

    /**
     * @dev End the current contest
     */
    function endContest() external nonReentrant {
        require(contests[currentContestId].active, "No active contest");
        require(block.timestamp > contests[currentContestId].endTime, "Contest not ended");
        require(!contests[currentContestId].ended, "Contest already ended");

        contests[currentContestId].active = false;
        contests[currentContestId].ended = true;

        emit ContestEnded(currentContestId, new uint256[](0), new uint256[](0));
    }

    /**
     * @dev Unlist a domain and return it to the owner
     * @param contestId ID of the contest
     * @param domainId Domain token ID to unlist
     */
    function unlistDomain(uint256 contestId, uint256 domainId) external nonReentrant {
        require(contestDomainOwners[contestId][domainId] == msg.sender, "Not domain owner");
        require(
            contests[contestId].ended || block.timestamp > contests[contestId].endTime,
            "Contest not ended yet"
        );

        // Transfer NFT back to owner
        nftContract.safeTransferFrom(address(this), msg.sender, domainId);
        delete contestDomainOwners[contestId][domainId];
    }

    /**
     * @dev Get contest details
     * @param contestId ID of the contest
     * @return startTime Contest start timestamp
     * @return endTime Contest end timestamp
     * @return minStake Minimum stake amount
     * @return multiplier Stake multiplier
     * @return active Whether contest is active
     * @return ended Whether contest has ended
     * @return totalVoted Total votes cast
     * @return totalStaked Total staked amount
     */
    function getContestDetails(uint256 contestId) external view returns (
        uint256 startTime,
        uint256 endTime,
        uint256 minStake,
        uint256 multiplier,
        bool active,
        bool ended,
        uint256 totalVoted,
        uint256 totalStaked
    ) {
        Contest memory contest = contests[contestId];
        return (
            contest.startTime,
            contest.endTime,
            contest.minStake,
            contest.multiplier,
            contest.active,
            contest.ended,
            contest.totalVoted,
            contest.totalStaked
        );
    }

    /**
     * @dev Get domain vote count for a contest
     * @param contestId ID of the contest
     * @param domainId Domain ID
     * @return Total votes for the domain
     */
    function getDomainVotes(uint256 contestId, uint256 domainId) external view returns (uint256) {
        return contestDomainVotes[contestId][domainId];
    }

    /**
     * @dev Get all domain votes for a contest
     * @param contestId ID of the contest
     * @return domainIds Array of domain IDs that received votes
     * @return votes Array of corresponding vote counts
     */
    function getAllDomainVotes(uint256 contestId) external view returns (uint256[] memory domainIds, uint256[] memory votes) {
        uint256 maxDomainId = 100; // Assume max 100 domains
        uint256[] memory tempDomains = new uint256[](maxDomainId);
        uint256[] memory tempVotes = new uint256[](maxDomainId);
        uint256 count = 0;

        for (uint256 i = 0; i < maxDomainId; i++) {
            uint256 voteCount = contestDomainVotes[contestId][i];
            if (voteCount > 0) {
                tempDomains[count] = i;
                tempVotes[count] = voteCount;
                count++;
            }
        }

        // Resize arrays
        domainIds = new uint256[](count);
        votes = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            domainIds[i] = tempDomains[i];
            votes[i] = tempVotes[i];
        }
    }

    /**
     * @dev Get staking points for a user in a contest
     * @param contestId ID of the contest
     * @param user Address of the user
     * @return Staking points (stakeAmount * timeStaked)
     */
    function getStakingPoints(uint256 contestId, address user) external view returns (uint256) {
        Voter memory voter = contestVoters[contestId][user];
        if (voter.stakeAmount == 0) return 0;

        uint256 endTime = contests[contestId].ended ? contests[contestId].endTime : block.timestamp;
        uint256 timeStaked = endTime - voter.voteTime;
        return voter.stakeAmount * timeStaked;
    }

    /**
     * @dev Unstake tokens after contest ends
     * @param contestId ID of the contest
     */
    function unstake(uint256 contestId) external nonReentrant {
        require(contests[contestId].ended, "Contest not ended");
        require(contestHasVoted[contestId][msg.sender], "Not voted");

        Voter memory voter = contestVoters[contestId][msg.sender];
        require(voter.stakeAmount > 0, "Already unstaked");

        // Clear voter data
        delete contestVoters[contestId][msg.sender];
        delete contestHasVoted[contestId][msg.sender];

        // Transfer back tokens
        require(stakingToken.transfer(msg.sender, voter.stakeAmount), "Unstake transfer failed");

        emit Unstaked(msg.sender, voter.stakeAmount);
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