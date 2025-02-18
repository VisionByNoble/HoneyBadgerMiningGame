// SPDX-License-Identifier: GPL-3.0 OR MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title Honey Badger NFT Contract
/// @notice This contract allows minting, staking, and unstaking of NFTs.
contract BadgeTokenWithNFT is ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 public nextTokenId = 1;
    uint256 public maxSupply = 5555; // Maximum supply of NFTs
    mapping(address => uint256[]) public stakedNFTs; // Tracks staked NFTs per user

    event NFTMinted(address indexed to, uint256 indexed tokenId, string tokenURI);
    event NFTStaked(address indexed user, uint256 indexed tokenId);
    event NFTUnstaked(address indexed user, uint256 indexed tokenId);

    /// @notice Constructor to initialize the NFT contract with a name and symbol.
    constructor() ERC721("Honey Badger NFT", "HBN") Ownable(msg.sender) {}

    /// @notice Mints a new NFT and assigns it to the specified address.
    /// @param to The address that will receive the NFT.
    /// @param tokenURI The URI pointing to the NFT metadata.
    function mintNFT(address to, string memory tokenURI) public onlyOwner nonReentrant {
        require(bytes(tokenURI).length > 0, "Token URI cannot be empty");
        require(nextTokenId <= maxSupply, "Max supply reached");
        _safeMint(to, nextTokenId);
        _setTokenURI(nextTokenId, tokenURI);
        emit NFTMinted(to, nextTokenId, tokenURI);
        nextTokenId++;
    }

    /// @notice Stakes an NFT by transferring it to the contract.
    /// @param tokenId The ID of the NFT to stake.
    function stakeNFT(uint256 tokenId) public nonReentrant {
        require(ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        _transfer(msg.sender, address(this), tokenId);
        stakedNFTs[msg.sender].push(tokenId);
        emit NFTStaked(msg.sender, tokenId);
    }

    /// @notice Unstakes an NFT by transferring it back to the owner.
    /// @param tokenId The ID of the NFT to unstake.
    function unstakeNFT(uint256 tokenId) public nonReentrant {
        require(ownerOf(tokenId) == address(this), "NFT is not staked");
        require(stakedNFTs[msg.sender].length > 0, "No staked NFTs found");
        _transfer(address(this), msg.sender, tokenId);
        removeStakedNFT(msg.sender, tokenId);
        emit NFTUnstaked(msg.sender, tokenId);
    }

    /// @notice Removes a staked NFT from the user's staked list.
    /// @param user The address of the user.
    /// @param tokenId The ID of the NFT to remove.
    function removeStakedNFT(address user, uint256 tokenId) internal {
        uint256[] storage staked = stakedNFTs[user];
        for (uint256 i = 0; i < staked.length; i++) {
            if (staked[i] == tokenId) {
                staked[i] = staked[staked.length - 1];
                staked.pop();
                return; // Exit early after removing the token
            }
        }
        revert("Token ID not found in staked list");
    }
}

/// @title BadgeToken (ERC-20) Contract
/// @notice This contract allows staking, unstaking, and reward distribution of BADGE tokens.
contract BadgeToken is Ownable, ReentrancyGuard {
    string public name = "BadgeToken";
    string public symbol = "BADGE";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1000000 * 10 ** uint256(decimals); // 1 million BADGE tokens

    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) public stakedAmount;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardDistributed(address indexed user, uint256 amount);
    event TotalStaked(uint256 totalStaked);

    /// @notice Constructor to initialize the ERC-20 contract and mint the total supply to the owner.
    constructor() Ownable(msg.sender) {
        balances[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    /// @notice Transfers tokens from the sender to another address.
    /// @param to The address to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transfer(address to, uint256 amount) public nonReentrant returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    /// @notice Stakes tokens by locking them in the contract.
    /// @param amount The amount of tokens to stake.
    function stake(uint256 amount) public nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        stakedAmount[msg.sender] += amount;
        emit Staked(msg.sender, amount);
        emit TotalStaked(stakedAmount[msg.sender]);
    }

    /// @notice Unstakes tokens by releasing them from the contract.
    /// @param amount The amount of tokens to unstake.
    function unstake(uint256 amount) public nonReentrant {
        require(stakedAmount[msg.sender] >= amount, "Insufficient staked balance");
        stakedAmount[msg.sender] -= amount;
        balances[msg.sender] += amount;
        emit Unstaked(msg.sender, amount);
        emit TotalStaked(stakedAmount[msg.sender]);
    }

    /// @notice Distributes rewards to a user from the owner's balance.
    /// @param user The address of the user to reward.
    /// @param amount The amount of tokens to distribute as rewards.
    function distributeRewards(address user, uint256 amount) public onlyOwner nonReentrant {
        require(user != address(0), "Invalid user address");
        require(amount > 0, "Invalid reward amount");
        require(balances[owner()] >= amount, "Insufficient balance for rewards");
        balances[owner()] -= amount;
        balances[user] += amount;
        emit RewardDistributed(user, amount);
    }

    /// @notice Approves another address to spend tokens on behalf of the sender.
    /// @param spender The address allowed to spend tokens.
    /// @param amount The amount of tokens to approve.
    function approve(address spender, uint256 amount) public returns (bool) {
        require(spender != address(0), "Invalid address");
        _allowances[msg.sender][spender] = 0; // Reset allowance to prevent double-spending
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /// @notice Transfers tokens from one address to another on behalf of the sender.
    /// @param from The address to transfer tokens from.
    /// @param to The address to transfer tokens to.
    /// @param amount The amount of tokens to transfer.
    function transferFrom(address from, address to, uint256 amount) public nonReentrant returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        require(_allowances[from][msg.sender] >= amount, "Not approved to spend");
        balances[from] -= amount;
        balances[to] += amount;
        _allowances[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
