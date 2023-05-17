// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HLTHYTOKEN is
    ERC20,
    ReentrancyGuard,
    Pausable,
    Ownable,
    AccessControl
{
    using SafeMath for uint256;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    event TokensMinted(address indexed to, uint256 amount);
    event TokensBurned(address indexed from, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 totalSupply_
    ) ERC20(name_, symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
        _totalSupply = totalSupply_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _mint(msg.sender, _totalSupply);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function mint(
        address to,
        uint256 amount
    ) public onlyRole(MINTER_ROLE) nonReentrant {
        require(to != address(0), "HLTHYTOKEN: mint to the zero address");
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }

    function burn(uint256 amount) public nonReentrant {
        _burn(msg.sender, amount);
        emit TokensBurned(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) public nonReentrant {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(
            currentAllowance >= amount,
            "HLTHYTOKEN: burn amount exceeds allowance"
        );
        _approve(account, msg.sender, currentAllowance.sub(amount));
        _burn(account, amount);
        emit TokensBurned(account, amount);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            amount <= balanceOf(msg.sender),
            "HLTHYTOKEN: Insufficient balance"
        );
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            amount <= balanceOf(sender),
            "HLTHYTOKEN: Insufficient balance"
        );
        require(
            amount <= allowance(sender, msg.sender),
            "HLTHYTOKEN: Insufficient allowance"
        );
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, allowance(sender, msg.sender).sub(amount));
        return true;
    }
}
