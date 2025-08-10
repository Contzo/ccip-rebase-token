//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("Owner");
    address public user = makeAddr("User");
    uint256 private constant INITIAL_ETH_BALANCE = 10 ether;

    function setUp() public {
        vm.deal(owner, INITIAL_ETH_BALANCE);
        vm.startPrank(owner);
        rebaseToken = new RebaseToken(); // deploy the rebase token contract
        vault = new Vault(IRebaseToken(address(rebaseToken))); // deploy the vault contract
        console.log("The address of the rebase token: ", vault.getRebaseTokenAddress());
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardToVault(uint256 _rewardAmount) public returns (bool) {
        (bool success,) = payable(address(vault)).call{value: _rewardAmount}(""); // add some reward to the vault
        return success;
    }

    function testGetRebaseAddress() external view {
        //Assert
        address expectedRebaseTokenAddress = address(rebaseToken);
        address rebaseTokenAddress = vault.getRebaseTokenAddress();
        assertEq(expectedRebaseTokenAddress, rebaseTokenAddress);
    }

    function testDepositLinear(uint256 _amountToDeposit) public {
        // Setup
        _amountToDeposit = bound(_amountToDeposit, 1e5, type(uint96).max); // bound the deposit amount between 1e4 and the max value of uint96, in order to avoid depositing 0 WEI
        uint256 timeSkipInterval = 1 hours;
        //Act  & Assert
        vm.startPrank(user);
        vm.deal(user, _amountToDeposit);
        vault.deposit{value: _amountToDeposit}();
        uint256 startingBalance = rebaseToken.balanceOf(user); // make the deposit
        console.log("User starting balance: ", startingBalance);
        assertApproxEqAbs(startingBalance, _amountToDeposit, 1); // For initial deposit
        vm.warp(block.timestamp + timeSkipInterval); // first time jump
        uint256 firstTimeSkipBalance = rebaseToken.balanceOf(user);
        console.log("First interest: ", (firstTimeSkipBalance - startingBalance));
        assertGt(firstTimeSkipBalance, startingBalance);
        vm.warp(block.timestamp + timeSkipInterval); // second time jump
        uint256 secondTimeSkipBalance = rebaseToken.balanceOf(user);
        console.log("Second interest: ", (secondTimeSkipBalance - firstTimeSkipBalance));
        assertGt(secondTimeSkipBalance, firstTimeSkipBalance);

        assertApproxEqAbs(secondTimeSkipBalance - firstTimeSkipBalance, firstTimeSkipBalance - startingBalance, 1); //check the interest has accumulated linearly
        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 _amountToRedeem) public {
        //setup
        _amountToRedeem = bound(_amountToRedeem, 1e5, type(uint96).max);
        vm.startPrank(user);
        vm.deal(user, _amountToRedeem);
        console.log("User funds: ", user.balance);
        vault.deposit{value: _amountToRedeem}();
        uint256 initialUserBalance = rebaseToken.balanceOf(user);
        assertEq(initialUserBalance, _amountToRedeem);
        //Act
        vault.redeem(type(uint256).max); // redeem all of the funds of hte user
        uint256 userBalanceAfterRedeem = rebaseToken.balanceOf(user);
        // Assert
        assertEq(userBalanceAfterRedeem, 0); // the balance RBT balance should be 0 after the user redeems all of its funds.
        assertEq(user.balance, _amountToRedeem); // check that the balance of the ETH balance of the user is back to the same one prior to depositing.
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 _depositAmount, uint256 _time) public {
        //Set up
        _time = bound(_time, 1 days, 365 days * 100); // bound the time interval.
        _depositAmount = bound(_depositAmount, 1e5, type(uint96).max);
        //Act
        //1. Deposit
        vm.deal(user, _depositAmount);
        vm.prank(user);
        vault.deposit{value: _depositAmount}();
        //2. Warp time
        vm.warp(block.timestamp + _time);
        uint256 balanceAfterTimeSkip = rebaseToken.balanceOf(user);
        uint256 accumulatedInterest = balanceAfterTimeSkip - _depositAmount;
        //2.b. add the required rewards
        vm.deal(owner, accumulatedInterest);
        vm.prank(owner);
        addRewardToVault(balanceAfterTimeSkip - _depositAmount); // add the accumulated rewards to the vault
        //3. Redeem
        vm.prank(user);
        vault.redeem(type(uint256).max);

        // Assert
        uint256 ethBalance = user.balance;
        assertGe(ethBalance, _depositAmount);
        assertEq(ethBalance, balanceAfterTimeSkip);
    }

    function testTransfer(uint256 _amountToSend, uint256 _amountToDeposit) public {
        // ── Setup ──────────────────────────────────────────────
        uint256 minAmount = 1e5;
        // bound the deposit and send amount, in such a way that the amount to deposit is always larger with at least one min amount
        _amountToDeposit = bound(_amountToDeposit, 2 * minAmount, type(uint96).max);
        _amountToSend = bound(_amountToSend, minAmount, _amountToDeposit - minAmount);
        // deposit
        vm.deal(user, _amountToDeposit);
        vm.prank(user);
        vault.deposit{value: _amountToDeposit}();

        // ── Act & Assert ──────────────────────────────────────────────
        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);
        // Assert starting balances
        assertEq(userBalance, _amountToDeposit);
        assertEq(user2Balance, 0);
        // set the new lower interest rate
        uint256 userInitialInterestRate = rebaseToken.getUserInterestRate(user);
        uint256 newInterestRate = (4 * rebaseToken.getPrecisionRate()) / 1e8; // 0.000005% per second global interest rate.
        vm.prank(owner);
        rebaseToken.setInterestRate(newInterestRate);
        // make the transfer
        vm.prank(user);
        rebaseToken.transfer(user2, _amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        // Assert the balances after transfer
        assertEq(userBalanceAfterTransfer, userBalance - _amountToSend);
        assertEq(user2BalanceAfterTransfer, _amountToSend);
        // Assert user 2 inherited the interest rate from user1 and they were not affected by the rate change.
        uint256 userInterestRate = rebaseToken.getUserInterestRate(user);
        uint256 user2InterestRate = rebaseToken.getUserInterestRate(user2);
        assertEq(userInitialInterestRate, userInterestRate);
        assertEq(userInitialInterestRate, user2InterestRate);
    }

    function testCannotSetInterestRateIfNotTheOwner(address _user, uint256 _newInterestRate) public {
        // ── Setup──────────────────────────────────────────────
        uint256 initialInterestRate = rebaseToken.getGlobalInterestRate();
        _newInterestRate = bound(_newInterestRate, 0, initialInterestRate);
        // ── Act & Assert ──────────────────────────────────────────────
        vm.prank(_user);
        bytes memory expectedRevertError = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, _user);
        vm.expectRevert(expectedRevertError);
        rebaseToken.setInterestRate(_newInterestRate);
    }

    function testCannotMintAndBurn() public {
        vm.prank(user);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(user, 100);
        vm.expectPartialRevert(bytes4(IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.burn(user, 100);
    }

    function testGetPrincipalAmount(uint256 _amount) public {
        // ── Setup ──────────────────────────────────────────────
        _amount = bound(_amount, 1e5, type(uint96).max);
        vm.deal(user, _amount);
        vm.prank(user);
        // ── Act & Assert ──────────────────────────────────────────────
        vault.deposit{value: _amount}();
        assertEq(rebaseToken.principleBalanceOf(user), _amount);
        uint256 timeSkip = 1 hours;
        vm.warp(block.timestamp + timeSkip);
        assertEq(rebaseToken.principleBalanceOf(user), _amount);
    }

    function testGetRebaseTokenAddress() public view {
        assertEq(vault.getRebaseTokenAddress(), address(rebaseToken));
    }

    function testInterestRateCanOnlyDecease(uint256 _newInterestRate) public {
        // ── Setup ──────────────────────────────────────────────
        uint256 currentInterestRate = rebaseToken.getGlobalInterestRate();
        _newInterestRate = bound(_newInterestRate, currentInterestRate + 1, type(uint96).max); // make sure that the new interest rate is higher then the current one.

        // ── Act & Assert ──────────────────────────────────────────────
        vm.prank(owner);
        bytes memory expectedError = abi.encodeWithSelector(
            RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, currentInterestRate, _newInterestRate
        );
        vm.expectRevert(expectedError);
        rebaseToken.setInterestRate(_newInterestRate);
        assertEq(currentInterestRate, rebaseToken.getGlobalInterestRate());
    }
}
