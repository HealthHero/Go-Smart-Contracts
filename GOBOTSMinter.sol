// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/security/PullPaymentUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "hardhat/console.sol";


interface IGOBOTS {
    function createToken(address account, uint256 blobId) external returns (uint256 id);
    function createTokens(address account, uint256 numberOfTokens) external returns (uint256 lastId);
    function getCurrentId() external view returns(uint256);
    function balanceOf(address account) external view returns(uint256 tokens);
}


contract GOBOTSMinter is OwnableUpgradeable, UUPSUpgradeable, PullPaymentUpgradeable {

    uint256 public mintFee;
    address public feeRecipient;
    uint16[] public reservedBlobs;
    uint16[] public mintedBlobIds;
    mapping(uint16 => bool) public isReserved;
    mapping(uint16 => bool) public mintedBlobs;
    mapping(uint16 => uint256) public blobIdToPrice;
    mapping(address => bool) public whitelistedAddresses;
    mapping(address => uint16) public whitelistedAddressesBalance;
    IGOBOTS public goBots;

    event GOBOTminted (address indexed minter, uint256 indexed tokenId, uint256 indexed blobId);
    event WhitelistGOBOTminted (address indexed minter, uint256 indexed tokenId, uint256 indexed blobId);
    event GOBOTSminted (address indexed minter, uint256 indexed firstTokenId, uint256 indexed lastTokenId);
    event FeeRecipientUpdated (address indexed newRecipient);
    event MintFeeUpdated (uint256[] indexed newFees);
    event AddressWhitelisted (address indexed whitelistedAddress, uint256 indexed balance);

    function initialize(
        IGOBOTS _goBotAddress,
        address _feeRecipient,
        uint16[] calldata _blobIds,
        uint256[] calldata _prices
    )
    external initializer
    {
        //blobIdToPrice = bool[](_blobIds.length);
        goBots = _goBotAddress;
        for (uint256 i = 0; i < _blobIds.length; i++) {
            blobIdToPrice[_blobIds[i]] = _prices[i];
        }
        feeRecipient = _feeRecipient;
        __Ownable_init();
        __UUPSUpgradeable_init();
        __PullPayment_init();
    }

    function mintWhitelistGOBOT(uint16 blobId) external payable virtual {
        require(whitelistedAddresses[_msgSender()], "Address Not Whitelisted");
        require(whitelistedAddressesBalance[_msgSender()] > 0, "No More Whitelist Tokens Available");
        require(goBots.getCurrentId() < 8088, "All gobots for sale have been minted!");
        // ADD IN BURN ON ADMIN PAGE
        require(blobId < 8888 && blobId >= 0, "GOBOTSMinter: invalid blobId");
        // Ensures Blob Is Not Reserved
        require(!isReserved[blobId], "This Parcel Is Reserved");
        // enusres that the user is not minting an nft with a different set of attributes or cheating.
        require(!mintedBlobs[blobId], "GOBOTSMinter: Blob Already Minted");
        // returns tokenId of goBot minted
        uint16 balance = whitelistedAddressesBalance[_msgSender()];
        whitelistedAddressesBalance[_msgSender()] = balance - 1;
        mintedBlobs[blobId] = true;
        mintedBlobIds.push(blobId);
        uint256 tokenId = goBots.createToken(_msgSender(), blobId);
        emit WhitelistGOBOTminted(_msgSender(), tokenId, blobId);
    }

    function mintGOBOT(uint16 blobId) external payable virtual {
        // making sure that the contract doesn't break.
        require(goBots.getCurrentId() < 8088, "All gobots for sale have been minted!");
        require(blobId < 8888 && blobId >= 0, "GOBOTSMinter: invalid blobId");
        // Ensures Blob Is Not Reserved
        require(!isReserved[blobId], "This Parcel Is Reserved");
        // enusres that the user is not minting an nft with a different set of attributes or cheating.
        require(!mintedBlobs[blobId], "GOBOTSMinter: Blob Already Minted");
        // Checks that the wallet owner has a maximum of 10
        require(goBots.balanceOf(_msgSender()) < 10, "You can Only Mint 10 Bots Per Wallet");
        // checks that caller sends enough MATIC to cover fee
        require(msg.value >= 225, "GOBOTSMinter: insufficient fee");
        // transfers fee to escrow contract
        require(_transferFee(feeRecipient, msg.value), "GOBOTSMinter: fee transfer failed");
        // returns tokenId of goBot minted
        mintedBlobs[blobId] = true;
        mintedBlobIds.push(blobId);
        uint256 tokenId = goBots.createToken(_msgSender(), blobId);
        emit GOBOTminted(_msgSender(), tokenId, blobId);
    }

    function adminMintGOBOT(uint16 blobId) external payable virtual onlyOwner {
        require(blobId < 8888 && blobId >= 0, "GOBOTSMinter: invalid blobId");
        // enusres that the user is not minting an nft with a different set of attributes or cheating.
        require(!mintedBlobs[blobId], "GOBOTSMinter: Blob Already Minted");
        // returns tokenId of goBot minted
        mintedBlobs[blobId] = true;
        mintedBlobIds.push(blobId);
        uint256 tokenId = goBots.createToken(_msgSender(), blobId);
        emit GOBOTminted(_msgSender(), tokenId, blobId);
    }

    function mintGOBOTS(uint256 numberOfTokens) external payable virtual {
        // checks that caller sends enough MATIC to cover fee
        //require(msg.value >= mintFee * numberOfTokens, "GOBOTSMinter: insufficient fee");
        require((msg.value >= mintFee * numberOfTokens), "GOBOTSMinter: insufficient fee");
        // transfers fee to escrow contract
        require(_transferFee(feeRecipient, msg.value), "GOBOTSMinter: fee transfer failed");

        // returns ID of the first token to get minted
        uint256 firstTokenId = goBots.getCurrentId() + 1;
        // returns ID of last token minted
        uint256 lastTokenId = goBots.createTokens(_msgSender(), numberOfTokens);

        emit GOBOTSminted(_msgSender(), firstTokenId, lastTokenId);
    }

    function updateMintRecipient(address newRecipient) external onlyOwner {
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function updateMintFees(uint16[] calldata _blobIds, uint256[] calldata _prices) external onlyOwner {

        require(_blobIds.length == _prices.length, "array lengths are not equal");

        for (uint256 i = 0; i < _blobIds.length; i++) {
            blobIdToPrice[_blobIds[i]] = _prices[i];
        }
        //TODO: update this mint fee update event
        emit MintFeeUpdated(_prices);
    }

    function version() external pure virtual returns(string memory) {
        return "1.0.1";
    }

    function whitelistAddress(address _addressToWhitelist, uint16 availableBalance) public onlyOwner {
        whitelistedAddresses[_addressToWhitelist] = true;
        whitelistedAddressesBalance[_addressToWhitelist] = availableBalance;
        emit AddressWhitelisted(_addressToWhitelist, availableBalance);
    }

    function whitelistAddresses(address[] calldata _addressesToWhitelist, uint16[] calldata _balances)
    public onlyOwner {
        for (uint i = 0; i < _addressesToWhitelist.length; i++) {
            whitelistAddress(_addressesToWhitelist[i], _balances[i]);
        }
    }

    function reserveBlobs( uint16[] calldata reserved) public onlyOwner {
        for (uint i = 0; i < reserved.length; i++) {
            isReserved[reserved[i]] = true;
            reservedBlobs.push(reserved[i]);
        }
    }

    function setMintedBlobs( uint16[] calldata minted) public onlyOwner {
        for (uint i = 0; i < minted.length; i++) {
            uint16 blobId = minted[i];
            mintedBlobs[blobId] = true;
            mintedBlobIds.push(blobId);
        }
    }

    function getMintedBlobArray() public view returns(uint16[] memory) {
        return mintedBlobIds;
    }

    function getReservedBlobs() public view returns(uint16[] memory) {
        return reservedBlobs;
    }

    function _transferFee(address dest, uint256 amount) internal virtual returns(bool) {
        _asyncTransfer(dest, amount);
        return true;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}
}
