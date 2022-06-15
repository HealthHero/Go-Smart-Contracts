// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GOBOTS721 is Ownable, Pausable, AccessControlEnumerable, ERC721{
    using Counters for Counters.Counter;
    using Strings for *;

    Counters.Counter internal ids;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public totalSupply;
    string private baseURI;

    event Created(address account, uint256 id);
    event CreatedBatch(address account, uint256 FirstMintedId, uint256 LastMintedId);
    event Deleted(uint256 id);
    event DeletedBatch(uint256[] ids);
    event TransferredBatch(address from, address[] to, uint256[] ids);

    constructor(
        address _newOwner,
        address _minter,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        uint256 _totalSupply
    )
    ERC721(_name, _symbol)
    {
        transferOwnership(_newOwner);

        _setupRole(DEFAULT_ADMIN_ROLE, _newOwner);
        _setupRole(MINTER_ROLE, _newOwner);
        _setupRole(MINTER_ROLE, _minter);

        _setBaseURI(_baseURI);

        totalSupply = _totalSupply;
    }

    function createToken(
        address account
    )
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 id)
    {
        require(ids.current() < totalSupply, "GO!BOTS: NFT token limit reached");

        uint256 _id = ids.current();
        ids.increment();
        _safeMint(account, _id);
        emit Created(account, _id);
        return _id;
    }

    function createTokens(
        address account,
        uint256 numberOfTokens
    )
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 LastId)
    {
        require(ids.current() < totalSupply, "GO!BOTS: NFT token limit reached");

        uint256 i = 0;
        uint256 _id;
        uint256 FirstMintedId = ids.current();

        while (gasleft() > 50000 && i < numberOfTokens && ids.current() < totalSupply){ //
            _id = ids.current();
            _safeMint(account, _id);
            ids.increment();
            i++;
        }

        uint256 LastMintedId = ids.current() - 1;

        emit CreatedBatch(account, FirstMintedId, LastMintedId);
        return LastMintedId;
    }

    function deleteToken(uint256 id) external {
        require(
            _msgSender() == ownerOf(id) || hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Must be owner of Token or Admin to delete Token"
        );

        _burn(id);
        emit Deleted(id);
    }

    function deleteTokens(uint256[] calldata _ids) external onlyRole(DEFAULT_ADMIN_ROLE){

        for(uint256 i = 0; i < _ids.length; i++){
            _burn(_ids[i]);
        }

        emit DeletedBatch(_ids);
    }

    function transferBatch(address[] calldata _accounts, uint256[] calldata _ids) external {
        require(_accounts.length == _ids.length, "array lengths aren't equal");

        for(uint256 i = 0; i < _accounts.length; i++){
            safeTransferFrom(_msgSender(),_accounts[i],_ids[i]);
        }

        emit TransferredBatch(_msgSender(), _accounts, _ids);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function setBaseURI(string memory _baseURI) external onlyRole(MINTER_ROLE) {
        _setBaseURI(_baseURI);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "GO!BOTS: URI query for nonexistent token");

        string memory _tokenId = tokenId.toString();
        string memory uri = string(abi.encodePacked(baseURI, _tokenId));
        return uri;
    }


    function getCurrentId() external view returns(uint256){
        return ids.current();
    }

    function _setBaseURI(string memory _baseURI) internal {
        baseURI = _baseURI;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public view override(AccessControlEnumerable, ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC721).interfaceId
        || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused{}
}
