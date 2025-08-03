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

    function setUp() public {
        vm.deal(owner, 10 ether);
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

    function testDepositLinear() public{
        // Setup 

    }
}
