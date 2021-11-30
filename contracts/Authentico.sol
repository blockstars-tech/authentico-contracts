// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract Authentico is ERC721Enumerable, Ownable {
  event Sell(uint256 indexed tokenId, address indexed seller, uint256 price);
  event Selled(uint256 indexed tokenId, address indexed seller, address indexed buyer);
  event PriceUpdate(uint256 indexed tokenId, uint256 oldPrice, uint256 newPrice);
  event RemovedFromMarketplace(uint256 indexed tokenId, address indexed seller);

  struct Marketplace {
    bool inSell;
    address seller;
    uint256 price;
  }

  uint256 public mintingPrice = 0.01 ether;

  mapping(uint256 => Marketplace) private _marketplace;

  // solhint-disable-next-line no-empty-blocks
  constructor() ERC721("Authentico", "ATO") {}

  function mintAndSell(uint256 tokenId, uint256 price) public payable {
    mint(tokenId);
    transferFrom(msg.sender, address(this), tokenId);
    _marketplace[tokenId].inSell = true;
    _marketplace[tokenId].price = price;
    emit Sell(tokenId, msg.sender, price);
  }

  function sell(uint256 tokenId, uint256 price) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    require(!marketplace.inSell, "Item is already on sell");
    require(ownerOf(tokenId) == msg.sender, "Transfer caller is not owner");
    transferFrom(msg.sender, address(this), tokenId);
    marketplace.inSell = true;
    marketplace.seller = msg.sender;
    marketplace.price = price;
    emit Sell(tokenId, msg.sender, price);
  }

  function buy(uint256 tokenId) public payable {
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    require(msg.value >= marketplace.price, "Transferred value is less than token price");
    transferFrom(address(this), msg.sender, tokenId);
    marketplace.inSell = false;
    address seller = marketplace.seller;
    (bool success, ) = payable(seller).call{ value: msg.value }("");
    require(success, "Unable to send value, recipient may have reverted");
    emit Selled(tokenId, seller, msg.sender);
  }

  function updatePrice(uint256 tokenId, uint256 newPrice) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    uint256 oldPrice = marketplace.price;
    require(oldPrice != newPrice, "Given price is equal to previous price");
    require(marketplace.inSell, "Item is not for sale");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    marketplace.price = newPrice;
    emit PriceUpdate(tokenId, oldPrice, newPrice);
  }

  function removeFromMarketplace(uint256 tokenId) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    marketplace.inSell = false;
    transferFrom(address(this), msg.sender, tokenId);
    emit RemovedFromMarketplace(tokenId, msg.sender);
  }

  function mint(uint256 tokenId) public payable {
    require(msg.value >= mintingPrice, "Transferred value is less than minting price");
    _safeMint(msg.sender, tokenId);
    // transfer ETH to owner address
    (bool success, ) = payable(owner()).call{ value: msg.value }("");
    require(success, "Unable to send value, recipient may have reverted");
  }

  function _baseURI() internal pure override returns (string memory) {
    return "http://ipfs.com/";
  }

  function setMintngPrice(uint256 mintingPrice_) public onlyOwner {
    mintingPrice = mintingPrice_;
  }

  function tokenIsInSell(uint256 tokenId) public view returns (bool) {
    require(_exists(tokenId), "Token with this ID does not exist");
    return _marketplace[tokenId].inSell;
  }

  function tokenSeller(uint256 tokenId) public view returns (address) {
    require(_exists(tokenId), "Token with this ID does not exist");
    require(_marketplace[tokenId].inSell, "Token with this ID is not for sale");
    return _marketplace[tokenId].seller;
  }

  function tokenPrice(uint256 tokenId) public view returns (uint256) {
    require(_exists(tokenId), "Token with this ID does not exist");
    require(_marketplace[tokenId].inSell, "Token with this ID is not for sale");
    return _marketplace[tokenId].price;
  }

  function tokenInfo(uint256 tokenId) public view returns (Marketplace memory) {
    require(_exists(tokenId), "Token with this ID does not exist");
    require(_marketplace[tokenId].inSell, "Token with this ID is not for sale");
    return _marketplace[tokenId];
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    return string(abi.encodePacked(_baseURI(), Strings.toHexString(tokenId, 32)));
  }
}
