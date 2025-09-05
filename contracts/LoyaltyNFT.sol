// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LoyaltyNFT is ERC721, Ownable {
    uint256 private _tokenIdCounter;
    mapping(address => uint256) public loyaltyPoints;

    constructor() ERC721("DomaAmbassador", "AMBASSADOR") Ownable(msg.sender) {}

    function addPoints(address user, uint256 points) external onlyOwner {
        loyaltyPoints[user] += points;
    }

    function mintAmbassador(address to) external onlyOwner returns (uint256) {
        require(loyaltyPoints[to] >= 100, "Insufficient points");
        uint256 tokenId = _tokenIdCounter++;
        _mint(to, tokenId);
        return tokenId;
    }
}