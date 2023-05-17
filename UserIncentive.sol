// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HealthToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract UserIncentivesToken is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    HLTHYTOKEN public immutable healthyToken;

    uint256 public constant USER_INCENTIVES_PERCENTAGE = 26;
    uint256 public incentivesLeft;
    uint256 public incentivesGivenOut;

    mapping(address => uint256) public incentivesRewarded;

    event IncentiveRewarded(address indexed recipient, uint256 amount);

    constructor(address tokenAddress) {
        healthyToken = HLTHYTOKEN(tokenAddress);
        incentivesLeft =
            (healthyToken.totalSupply() * USER_INCENTIVES_PERCENTAGE) /
            100;
    }

    function transferWithIncentive(
        address recipient,
        uint256 amount
    ) public onlyOwner nonReentrant returns (bool) {
        require(
            amount <= healthyToken.balanceOf(msg.sender),
            "Insufficient balance"
        );
        uint256 incentiveAmount = amount;
        require(
            incentiveAmount <= incentivesLeft,
            "Insufficient incentives left"
        );
        healthyToken.transfer(recipient, incentiveAmount);
        incentivesGivenOut = incentivesGivenOut.add(incentiveAmount);
        incentivesLeft = incentivesLeft.sub(incentiveAmount);
        incentivesRewarded[recipient] = incentivesRewarded[recipient].add(
            incentiveAmount
        );
        emit IncentiveRewarded(recipient, incentiveAmount);
        return true;
    }

    function withdraw(uint256 amount) public onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        payable(msg.sender).transfer(amount);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
}
