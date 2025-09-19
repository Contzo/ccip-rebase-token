//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol"
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol"; 

contract CrossChain is Test {
    RebaseToken public sepoliaRebaseToken;
    RebaseToken public arbitrumSepoliaRebaseToken;
    Vault public sepoliaVault;
    Vault public arbVault;
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbitrumPool;
    // accounts
    address public owner = makeAddr("Owner");
    address public user = makeAddr("User");
    uint256 private constant INITIAL_ETH_BALANCE = 10 ether;

    uint256 sepoliaFork;
    uint256 arbSepoliaFork;
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbitrumNetworkDetails;
    

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia-eth"); // both create and select the Sepolia fork
        arbSepoliaFork = vm.createFork("arb-sepolia"); // create the Arbitrum Sepolia fork ;

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork(); // deploy the CCIP local simulator contract
        vm.makePersistent(address(ccipLocalSimulatorFork)); // make tha address of the CCIP local simulator contract persistent across chain.

        //1. Deploy and configure on Sepolia
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // get the network details for the Sepolia chain
        vm.startPrank(owner);

        sepoliaRebaseToken = new RebaseToken();
        sepoliaVault = new Vault(IRebaseToken(address(sepoliaRebaseToken))); // only deploy the vault on Sepolia

        // Pool contract deploy
        address sepoliaRmnProxy = sepoliaNetworkDetails.rmnProxyAddress;
        address sepoliaRouter = sepoliaNetworkDetails.routerAddress;
        sepoliaPool =
            new RebaseTokenPool(IERC20(address(sepoliaRebaseToken)), new address[](0), sepoliaRmnProxy, sepoliaRouter);

        // Grant mint and burn role to the Pool contract and vaolt (just on Sepolia)
        sepoliaRebaseToken.grantMintAndBurnRole(address(vault));
        sepoliaRebaseToken.grantMintAndBurnRole(address(sepoliaPool));
        
        //Accept the admin role 
        address sepoliaRegistryModuleOwnerCustomAddress = sepoliaNetworkDetails.registryModuleOwnerCustomAddress; 
        RegistryModuleOwnerCustom sepoliaRegistryModuleOwnerCustom = RegistryModuleOwnerCustom(sepoliaRegistryModuleOwnerCustomAddress)
        sepoliaRegistryModuleOwnerCustom.registerAdminViaOwner(address(sepoliaRebaseToken)); 
        //Claim the admin role 
        address sepoliaTokenAdminRegistryAddress = sepoliaNetworkDetails.tokenAdminRegistryAddress ; 
        TokenAdminRegistry sepoliaTokenAdminRegistry = TokenAdminRegistry(sepoliaTokenAdminRegistryAddress); 
        sepoliaTokenAdminRegistry.acceptAdminRole(address(sepoliaRebaseToken)) ; 

        // Configure the pools for the tokens
        sepoliaTokenAdminRegistry.setPool(address(sepoliaRebaseToken), address(sepoliaPool)); 


        vm.stopPrank();

        //2. Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork); // change the chain to the Arbitrum Sepolia fork
        arbitrumNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // get the network details for the Sepolia chain
        vm.startPrank(owner);

        arbitrumSepoliaRebaseToken = new RebaseToken();
        address arbitrumRmnProxy = arbitrumNetworkDetails.rmnProxyAddress;
        address arbiturmRouter = arbitrumNetworkDetails.routerAddress;

        // Pool contract deploy
        arbitrumPool =
            new RebaseTokenPool(IERC20(address(arbitrumRebaseToken)), new address[](0), arbitrumRmnProxy, arbitrumRouter);
        // Grant the mint and burn role to the pool contract 
        arbitrumRebaseToken.grantMintAndBurnRole(address(arbitrumPool));

        // Accept the admin role 
        address arbitrumRegistryModuleOwnerCustomAddress = arbitrumNetworkDetails.registryModuleOwnerCustomAddress; 
        RegistryModuleOwnerCustom arbitrumRegistryModuleOwnerCustom = RegistryModuleOwnerCustom(arbitrumRegistryModuleOwnerCustomAddress)
        arbitrumRegistryModuleOwnerCustom.registerAdminViaOwner(address(arbitrumRebaseToken)); 
        //Claim the admin role 
        address arbitrumTokenAdminRegistryAddress = arbitrumNetworkDetails.tokenAdminRegistryAddress ; 
        TokenAdminRegistry arbitrumTokenAdminRegistry = TokenAdminRegistry(arbitrumTokenAdminRegistryAddress); 
        arbitrumTokenAdminRegistry.acceptAdminRole(address(arbitrumRebaseToken)) ; 

        // Configure the pools for the tokens
        arbitrumTokenAdminRegistry.setPool(address(arbitrumRebaseToken), address(arbitrumPool)); 



        vm.stopPrank();
    }
}
