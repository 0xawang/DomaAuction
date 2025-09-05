// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IOwnershipToken is IERC721 {
    function expirationOf(uint256 id) external view returns (uint256);
    function registrarOf(uint256 id) external view returns (uint256);
    function lockStatusOf(uint256 id) external view returns (bool);
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}