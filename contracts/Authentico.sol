// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Authentico is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;
  using EnumerableSet for EnumerableSet.UintSet;

  event Sell(uint256 indexed tokenId, address indexed seller, uint256 price, SellType sellType);
  event Selled(
    uint256 indexed tokenId,
    address indexed seller,
    address indexed buyer,
    SellType sellType
  );
  event Update(uint256 indexed tokenId, uint256 price, SellType sellType);
  event RemovedFromMarketplace(uint256 indexed tokenId, address indexed seller);
  event NFTReverted(uint256 indexed tokenId, address indexed creator);

  enum SellType {
    WITHOUT_FEE,
    WITH_FEE
  }

  struct Marketplace {
    bool inSell;
    address seller;
    SellType sellType;
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

  function mintAndSell(
    string memory uri,
    uint256 price,
    SellType sellType
  ) public {
    address sender = msg.sender;
    uint256 tokenId = _tokenIdCounter.current();
    mint(sender, uri);
    _transfer(sender, address(this), tokenId);
    sell(tokenId, price, sellType);
  }

  function sell(
    uint256 tokenId,
    uint256 price,
    SellType sellType
  ) public {
    address sender = msg.sender;
    Marketplace storage marketplace = _marketplace[tokenId];
    require(ownerOf(tokenId) == sender, "Transfer caller is not owner");
    require(!marketplace.inSell, "Item is already on sell");
    if (sellType == SellType.WITH_FEE) {
      require(
        price >= minPriceForSellWithFee,
        "You should set price more than minPriceForSellWithFee"
      );
    }
    transferFrom(sender, address(this), tokenId);
    marketplace.inSell = true;
    marketplace.seller = sender;
    marketplace.price = price;
    marketplace.sellType = sellType;
    emit Sell(tokenId, sender, price, sellType);
  }

  function buy(uint256 tokenId) public payable {
    uint256 gasBefore = gasleft();
    address buyer = msg.sender;
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    uint256 value = msg.value;
    require(value >= marketplace.price, "Transferred value is less than token price");
    transferFrom(address(this), buyer, tokenId);
    marketplace.inSell = false;
    address seller = marketplace.seller;
    if (marketplace.sellType == SellType.WITH_FEE) {
      uint256 gasCost = gasBefore - gasleft();
      uint256 sellerTransfer = value - gasCost - 50000;
      (bool success, ) = payable(seller).call{ value: sellerTransfer }("");
      require(success, "Unable to send value, recipient may have reverted");
      (success, ) = payable(buyer).call{ value: value - sellerTransfer }("");
      require(success, "Unable to send value, recipient may have reverted");
    } else {
      (bool success, ) = payable(seller).call{ value: value }("");
      require(success, "Unable to send value, recipient may have reverted");
    }

    emit Selled(tokenId, seller, buyer, marketplace.sellType);
  }

  function updatePrice(uint256 tokenId, uint256 newPrice) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    uint256 oldPrice = marketplace.price;
    require(marketplace.inSell, "Item is not for sale");
    require(oldPrice != newPrice, "Given price is equal to previous price");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    if (marketplace.sellType == SellType.WITH_FEE) {
      require(
        newPrice >= minPriceForSellWithFee,
        "You should set price more than minPriceForSellWithFee"
      );
    }
    marketplace.price = newPrice;
    emit Update(tokenId, newPrice, marketplace.sellType);
  }

  function updateSellType(uint256 tokenId, SellType newSellType) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    SellType oldSellType = marketplace.sellType;
    require(marketplace.inSell, "Item is not for sale");
    require(oldSellType != newSellType, "Given sellType is already setted");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    if (newSellType == SellType.WITH_FEE) {
      require(
        marketplace.price >= minPriceForSellWithFee,
        "You cannot change sellType because token price is less than minimum required"
      );
    }
    marketplace.sellType = newSellType;
    emit Update(tokenId, marketplace.price, newSellType);
  }

  function updatePriceAndSellType(
    uint256 tokenId,
    uint256 newPrice,
    SellType newSellType
  ) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    uint256 oldPrice = marketplace.price;
    SellType oldSellType = marketplace.sellType;
    require(marketplace.inSell, "Item is not for sale");
    require(oldPrice != newPrice, "Given price is equal to previous price");
    require(oldSellType != newSellType, "Given sellType is already setted");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    if (marketplace.sellType == SellType.WITH_FEE) {
      require(
        newPrice >= minPriceForSellWithFee,
        "You should set price more than minPriceForSellWithFee"
      );
    }
    marketplace.price = newPrice;
    marketplace.sellType = newSellType;
    emit Update(tokenId, newPrice, newSellType);
  }

  function removeFromMarketplace(uint256 tokenId) public {
    Marketplace storage marketplace = _marketplace[tokenId];
    require(marketplace.inSell, "Item is not for sale");
    require(marketplace.seller == msg.sender, "You are not a seller of token");
    marketplace.inSell = false;
    transferFrom(address(this), msg.sender, tokenId);
    emit RemovedFromMarketplace(tokenId, msg.sender);
  }

  function setMinPriceForSellWithFee(uint256 newMinPrice) public onlyOwner {
    minPriceForSellWithFee = newMinPrice;
  }

  function revertNFT(uint256 tokenId) public {
    address creator = msg.sender;
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
