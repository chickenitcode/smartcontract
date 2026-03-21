// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract WhitelistNFT is ERC721Enumerable, Ownable {
    uint256 public constant MAX_SUPPLY = 10_000;
    bytes32 public merkleRoot;
    string private baseTokenURI;
    string private hiddenURI;
    bool public revealed;
    uint256 private nextTokenId = 1;
    mapping(address => bool) public hasMinted;

    constructor(bytes32 _merkleRoot, string memory _hiddenURI)
        ERC721("Cyber-Samurai", "CYBER")
        Ownable(msg.sender)
    {
        merkleRoot = _merkleRoot;
        hiddenURI = _hiddenURI;
    }

    function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
    }

    function setHiddenURI(string calldata newHiddenURI) external onlyOwner {
        hiddenURI = newHiddenURI;
    }

    function reveal() external onlyOwner {
        revealed = true;
    }

    function mint(bytes32[] calldata proof) external {
        require(totalSupply() < MAX_SUPPLY, "Sold out");
        require(!hasMinted[msg.sender], "Already minted");

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Proof");

        hasMinted[msg.sender] = true;
        _safeMint(msg.sender, nextTokenId);
        nextTokenId += 1;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_ownerOf(tokenId) != address(0), "ERC721: invalid token ID");
        if (!revealed) {
            return hiddenURI;
        }
        return super.tokenURI(tokenId);
    }
}
