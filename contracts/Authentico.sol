// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Authentico is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;
  using EnumerableSet for EnumerableSet.UintSet;

  event Sell(uint256 indexed tokenId, address indexed seller, uint256 price);
  event Selled(uint256 indexed tokenId, address indexed seller, address indexed buyer);
  event Update(uint256 indexed tokenId, uint256 price);
  event RemovedFromMarketplace(uint256 indexed tokenId, address indexed seller);
  event NFTReverted(uint256 indexed tokenId, address indexed creator);

  struct Marketplace {
    bool inSell;
    address seller;
    uint256 price;
  }

  Counters.Counter private _tokenIdCounter;
  mapping(address => EnumerableSet.UintSet) private _creatorNFTs;
  mapping(uint256 => Marketplace) private _marketplace;

  uint256 public minPriceForSellWithFee = 0.0001 ether;

  // solhint-disable-next-line no-empty-blocks
  constructor() ERC721("Authentico", "ATO") {}

  function mint(address to, string memory uri) public {
    uint256 tokenId = _tokenIdCounter.current();
    _tokenIdCounter.increment();
    _safeMint(to, tokenId);
    _setTokenURI(tokenId, uri);
    _creatorNFTs[to].add(tokenId);
  }

  function mintAndSell(string memory uri, uint256 price) public {
    uint256 tokenId = _tokenIdCounter.current();
    mint(_msgSender(), uri);
    sell(tokenId, price);
  }

  function sell(uint256 tokenId, uint256 price) public {
    address seller = _msgSender();
    Marketplace storage marketplace = _marketplace[tokenId];
    require(ownerOf(tokenId) == seller, "Transfer caller is not owner");
    require(!marketplace.inSell, "Item is already on sell");
    require(
      price >= minPriceForSellWithFee,
      "You should set price more than minPriceForSellWithFee"
    );
    marketplace.inSell = true;
    marketplace.seller = seller;
    marketplace.price = price;
    emit Sell(tokenId, seller, price);
  }

  function buy(uint256 tokenId) public payable {
    uint256 gasBefore = gasleft();
    address buyer = _msgSender();
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    uint256 value = msg.value;
    require(value >= marketplace.price, "Transferred value is less than token price");
    address seller = marketplace.seller;
    _transfer(seller, buyer, tokenId);
    marketplace.inSell = false;
    uint256 gasCost = gasBefore - gasleft();
    uint256 sellerTransfer = value - gasCost - 50000;
    (bool success, ) = payable(seller).call{ value: sellerTransfer }("");
    require(success, "Unable to send value, recipient may have reverted");
    (success, ) = payable(buyer).call{ value: value - sellerTransfer }("");
    require(success, "Unable to send value, recipient may have reverted");
    emit Selled(tokenId, seller, buyer);
  }

  function updatePrice(uint256 tokenId, uint256 newPrice) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    uint256 oldPrice = marketplace.price;
    require(marketplace.inSell, "Item is not for sale");
    require(oldPrice != newPrice, "Given price is equal to previous price");
    require(marketplace.seller == _msgSender(), "You are not a seller of token");
    require(
      newPrice >= minPriceForSellWithFee,
      "You should set price more than minPriceForSellWithFee"
    );
    marketplace.price = newPrice;
    emit Update(tokenId, newPrice);
  }

  function removeFromMarketplace(uint256 tokenId) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    require(marketplace.seller == _msgSender(), "You are not a seller of token");
    marketplace.inSell = false;
    emit RemovedFromMarketplace(tokenId, _msgSender());
  }

  function setMinPriceForSellWithFee(uint256 newMinPrice) public onlyOwner {
    minPriceForSellWithFee = newMinPrice;
  }

  function revertNFT(uint256 tokenId) public {
    address creator = _msgSender();
    require(_creatorNFTs[creator].contains(tokenId), "You are not creator of NFT");
    address tokenOwner = ownerOf(tokenId);
    require(tokenOwner != creator, "You are already owner of NFT");
    _transfer(tokenOwner, creator, tokenId);
    emit NFTReverted(tokenId, creator);
  }

  function getCreatorNFTs(address creator) public view returns (uint256[] memory) {
    return _creatorNFTs[creator].values();
  }

  function tokenIsInSell(uint256 tokenId) public view returns (bool) {
    require(_exists(tokenId), "Token with this ID does not exist");
    return _marketplace[tokenId].inSell;
  }

  function tokenInfo(uint256 tokenId) public view returns (Marketplace memory) {
    require(_exists(tokenId), "Token with this ID does not exist");
    require(_marketplace[tokenId].inSell, "Token with this ID is not for sale");

    return _marketplace[tokenId];
  }

  function _baseURI() internal pure override returns (string memory) {
    return "https://ipfs.io/ipfs/";
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721, ERC721Enumerable) {
    super._beforeTokenTransfer(from, to, tokenId);
    if (_marketplace[tokenId].inSell) {
      _marketplace[tokenId].inSell = false;
    }
  }

  function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721, ERC721URIStorage)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC721, ERC721Enumerable)
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
