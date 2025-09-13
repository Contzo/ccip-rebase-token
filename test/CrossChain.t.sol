//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

contract CrossChain is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    address public owner = makeAddr("Owner");
    address public user = makeAddr("User");
    uint256 private constant INITIAL_ETH_BALANCE = 10 ether;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth");
        arbSepoliaFork = vm.createSelectFork("arb-sepolia");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); // deploy the CCIP local simulator contract
        vm.makePersistent(address(ccipLocalSimulatorFork));
    }
}
