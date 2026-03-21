## NFT Whitelist Sale (Advanced) Guide

This guide explains how to build the NFT whitelist sale using Merkle proof verification and IPFS metadata. Implement the contract only after completing the steps below.

### 1) Off-chain whitelist & Merkle root
- Collect the whitelist wallet addresses (e.g., 5,000 addresses).
- Normalize them to checksum or lowercase and keep the same format consistently.
- Build a Merkle Tree using `merkletreejs` and `keccak256`:
  - Leaf = `keccak256(address)` (Solidity uses `keccak256(abi.encodePacked(address))`)
  - Sort pairs (use `sortPairs: true`) to make verification deterministic.
- Export the Merkle root and keep it in the contract as a `bytes32` value.

Example script outline:
- Read `addresses.json`
- Map to leaves
- Create tree
- Print `root` and `proof` for a sample address

### 2) IPFS metadata setup
- Prepare image assets and JSON metadata for 10,000 items.
- Upload the folder to IPFS via Pinata or NFT.storage.
- Save the CID for the metadata directory and use:
  - `baseURI = "ipfs://<CID>/"`.

### 3) Delayed reveal
- Before reveal: `tokenURI` should return a hidden JSON file (single URI).
- After sold out: owner updates `baseURI` to the real IPFS CID.

### 4) Smart contract requirements
- Use `ERC721Enumerable`.
- Store:
  - `bytes32 public merkleRoot`
  - `string private baseURI`
  - `string private hiddenURI`
- Mint function:
  - Accepts `bytes32[] calldata proof`
  - Validates with `MerkleProof.verify`
  - Revert with `Invalid Proof` when verification fails
- Optionally add max supply (10,000).

### 5) Test plan
- Generate a Merkle root in test with 2 addresses (1 whitelisted, 1 not).
- Valid address should mint successfully.
- Invalid address should revert with `Invalid Proof`.
- If using delayed reveal, test that `tokenURI` changes after owner updates `baseURI`.

