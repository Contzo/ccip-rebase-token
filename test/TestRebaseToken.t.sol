//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

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
        (bool success,) = payable(address(vault)).call{value: 1 ether}(""); // add some reward to the vault
        vm.stopPrank();
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


    function testRedeemStraightAway(uint256 _amountToRedeem) public{
        //setup 
        _amountToRedeem= bound(_amountToRedeem, 1e5, type(uint96).max); 
        vm.startPrank(user);
        vm.deal(user, _amountToRedeem) ; 
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
}


