// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDealer.sol";
import "./IPerpetual.sol";

contract JOJOTrader {
    IDealer public jojoDealer;
    IPerpetual public perpetualContract;
    IERC20 public primaryAsset;  // e.g., USDC
    IERC20 public secondaryAsset; // Optional e.g., JUSD if needed

    address public operator;

    constructor(
        address _jojoDealer,
        address _perpetualContract,
        address _primaryAsset
    ) {
        jojoDealer = IDealer(_jojoDealer);
        perpetualContract = IPerpetual(_perpetualContract);
        primaryAsset = IERC20(_primaryAsset);
    }

    // Approve JOJODealer to use tokens on behalf of the user
    function approvePrimaryAsset(uint256 amount) external {
        primaryAsset.approve(address(jojoDealer), amount);
    }

       // Dealer Functions
    function setOperator(address _operator, bool isValid) external {
        IDealer(jojoDealer).setOperator(_operator, isValid);
        operator = _operator;
    }

    // Deposit funds to JOJODealer
    function deposit(uint256 primaryAmount, uint256 secondaryAmount) external  {
        jojoDealer.deposit(primaryAmount, secondaryAmount, address(this));
    }

    // Encode the order into bytes for trading
    function encodeOrder(
        address perp,            // Address of the perpetual market (e.g., BTC/USDC)
        int128 paperAmount,      // Long position (positive value)
        int128 creditAmount,     // Amount of collateral (USDC)
        bytes32 info             // Additional information (can be empty if not needed)
    ) public view returns (bytes memory) {
        return abi.encode(
            perp,
            operator,        // Address of this contract acting as the trader address.this
            paperAmount,          // Amount of the asset in position (e.g., 1 BTC)
            creditAmount,         // Credit amount (e.g., 30,000 USDC)
            info                  // Additional trade info
        );
    }

    // Open a long position by interacting with Perpetual.sol
    function openLongPosition(
        int128 paperAmount,   // e.g., 1 BTC
        int128 creditAmount   // e.g., 30,000 USDC
    ) external {
        // Create trade data
        bytes memory tradeData = encodeOrder(
            address(perpetualContract),   // The perpetual contract
            paperAmount,                  // Paper amount for the long position
            creditAmount,                 // Credit amount as collateral (USDC)
            bytes32(0)                    // Empty info for this example
        );

        // Execute the trade on the Perpetual contract
        perpetualContract.trade(tradeData);
    }

    // Close the long position by reversing the trade (negative paper amount)
    function closeLongPosition(
        int128 paperAmount,   // Should be negative of the amount used to open the position
        int128 creditAmount
    ) external {
        // Create trade data to close the position
        bytes memory tradeData = encodeOrder(
            address(perpetualContract),   // The perpetual contract
            -paperAmount,                 // Negative paper amount to close the long
            creditAmount,                 // Same credit amount (or whatever matches your setup)
            bytes32(0)                    // Empty info for this example
        );

        // Execute the trade to close the position
        perpetualContract.trade(tradeData);
    }

    // Request withdrawal (pending)
    function requestWithdraw(uint256 primaryAmount, uint256 secondaryAmount) external  {
        jojoDealer.requestWithdraw(address(this), primaryAmount, secondaryAmount);
    }

    // Execute withdrawal after timelock
    function executeWithdraw(bool isInternal, bytes memory param) external  {
        jojoDealer.executeWithdraw(address(this), msg.sender, isInternal, param);
    }

    // Fast withdrawal (no timelock)
    function fastWithdraw(
        uint256 primaryAmount,
        uint256 secondaryAmount,
        bool isInternal,
        bytes memory param
    ) external  {
        jojoDealer.fastWithdraw(address(this), msg.sender, primaryAmount, secondaryAmount, isInternal, param);
    }
}
