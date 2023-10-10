// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestNFT is ERC721("TestNFT", "TFT") {
    function tokenURI(
        uint256 tokenID
    ) public view virtual override returns (string memory) {
        return "Scam";
    }

    function mint(address recipient, uint256 tokenId) public payable {
        _mint(recipient, tokenId);
    }
}
