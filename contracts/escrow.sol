// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Escrow is ReentrancyGuard {
    enum State {
        AWAITING_PAYMENT,
        AWAITING_DELIVERY,
        COMPLETE,
        REFUNDED
    }

    address payable public buyer;
    address payable public seller;
    address public arbiter;
    uint256 public price;
    State public state;

    event Deposited(address indexed buyer, uint256 amount);
    event ReceiptConfirmed(address indexed buyer);
    event Refunded(address indexed arbiter);

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    constructor(address payable _buyer, address payable _seller, address _arbiter, uint256 _price) {
        require(_buyer != address(0) && _seller != address(0) && _arbiter != address(0), "Zero address");
        require(_price > 0, "Price required");
        buyer = _buyer;
        seller = _seller;
        arbiter = _arbiter;
        price = _price;
        state = State.AWAITING_PAYMENT;
    }

    function deposit() external payable onlyBuyer {
        require(state == State.AWAITING_PAYMENT, "Not awaiting payment");
        require(msg.value == price, "Incorrect amount");
        state = State.AWAITING_DELIVERY;
        emit Deposited(msg.sender, msg.value);
    }

    function confirmReceipt() external onlyBuyer nonReentrant {
        require(state == State.AWAITING_DELIVERY, "Not awaiting delivery");
        state = State.COMPLETE;
        (bool sent, ) = seller.call{value: address(this).balance}("");
        require(sent, "Transfer failed");
        emit ReceiptConfirmed(msg.sender);
    }

    function refund() external onlyArbiter nonReentrant {
        require(state == State.AWAITING_DELIVERY, "Not awaiting delivery");
        state = State.REFUNDED;
        (bool sent, ) = buyer.call{value: address(this).balance}("");
        require(sent, "Transfer failed");
        emit Refunded(msg.sender);
    }
}
