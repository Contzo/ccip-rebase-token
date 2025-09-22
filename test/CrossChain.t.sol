//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol"; 
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";

contract CrossChain is Test {
    RebaseToken public sepoliaRebaseToken;
    RebaseToken public arbitrumRebaseToken;
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

        // Grant mint and burn role to the Pool contract and vault(just on Sepolia)
        sepoliaRebaseToken.grantMintAndBurnRole(address(sepoliaVault));
        sepoliaRebaseToken.grantMintAndBurnRole(address(sepoliaPool));
        
        //Accept the admin role 
        address sepoliaRegistryModuleOwnerCustomAddress = sepoliaNetworkDetails.registryModuleOwnerCustomAddress; 
        RegistryModuleOwnerCustom sepoliaRegistryModuleOwnerCustom = RegistryModuleOwnerCustom(sepoliaRegistryModuleOwnerCustomAddress);
        sepoliaRegistryModuleOwnerCustom.registerAdminViaOwner(address(sepoliaRebaseToken)); 
        //Claim the admin role 
        address sepoliaTokenAdminRegistryAddress = sepoliaNetworkDetails.tokenAdminRegistryAddress ; 
        TokenAdminRegistry sepoliaTokenAdminRegistry = TokenAdminRegistry(sepoliaTokenAdminRegistryAddress); 
        sepoliaTokenAdminRegistry.acceptAdminRole(address(sepoliaRebaseToken)) ; 

        // Configure the pools for the tokens
        sepoliaTokenAdminRegistry.setPool(address(sepoliaRebaseToken), address(sepoliaPool)); 
        configureTokenPool(sepoliaFork, address(sepoliaPool), arbitrumNetworkDetails.chainSelector, address(arbitrumPool), address(arbitrumRebaseToken));


        vm.stopPrank();

        //2. Deploy and configure on Arbitrum Sepolia
        vm.selectFork(arbSepoliaFork); // change the chain to the Arbitrum Sepolia fork
        arbitrumNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid); // get the network details for the Sepolia chain
        vm.startPrank(owner);

        arbitrumRebaseToken = new RebaseToken();
        address arbitrumRmnProxy = arbitrumNetworkDetails.rmnProxyAddress;
        address arbitrumRouter = arbitrumNetworkDetails.routerAddress;

        // Pool contract deploy
        arbitrumPool =
            new RebaseTokenPool(IERC20(address(arbitrumRebaseToken)), new address[](0), arbitrumRmnProxy, arbitrumRouter);
        // Grant the mint and burn role to the pool contract 
        arbitrumRebaseToken.grantMintAndBurnRole(address(arbitrumPool));

        // Accept the admin role 
        address arbitrumRegistryModuleOwnerCustomAddress = arbitrumNetworkDetails.registryModuleOwnerCustomAddress; 
        RegistryModuleOwnerCustom arbitrumRegistryModuleOwnerCustom = RegistryModuleOwnerCustom(arbitrumRegistryModuleOwnerCustomAddress); 
        arbitrumRegistryModuleOwnerCustom.registerAdminViaOwner(address(arbitrumRebaseToken)); 
        //Claim the admin role 
        address arbitrumTokenAdminRegistryAddress = arbitrumNetworkDetails.tokenAdminRegistryAddress ; 
        TokenAdminRegistry arbitrumTokenAdminRegistry = TokenAdminRegistry(arbitrumTokenAdminRegistryAddress); 
        arbitrumTokenAdminRegistry.acceptAdminRole(address(arbitrumRebaseToken)) ; 

        // Configure the pools for the tokens
        arbitrumTokenAdminRegistry.setPool(address(arbitrumRebaseToken), address(arbitrumPool)); 
        configureTokenPool(arbSepoliaFork, address(arbitrumPool), sepoliaNetworkDetails.chainSelector, address(sepoliaPool), address(sepoliaRebaseToken));



        vm.stopPrank();
    }

    function configureTokenPool(uint256 fork, address localPool, uint64 remoteChianSelector, address remotePool, address remoteTokenAddress) public{
        vm.selectFork(fork);
        vm.prank(owner); 

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1); 
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChianSelector,
            allowed: true,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteTokenAddress), 
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, 
                capacity: 0, 
                rate: 0
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: false, 
                capacity: 0, 
                rate: 0
            })
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }

    function bridgeTokens(uint256 _amountToBridge, uint256 _localFork, uint256 _remoteFork, Register.NetworkDetails memory _localNetworkDetails, Register.NetworkDetails memory _remoteNetworkDetails, RebaseToken _localToken, RebaseToken _remoteToken) public{
        vm.selectFork(_localFork); // initiate the transfer fro the local chain
        // Construct the EVM2AnyMessage struct
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: address(_localToken), amount: _amountToBridge});
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
           receiver: abi.encode(user),  
           data: "", 
           tokenAmounts:tokenAmounts,
           feeToken: _localNetworkDetails.linkAddress,  // fees paid in link
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) // no gas limit
        });
        // Get the fees. 
        uint256 fee = IRouterClient(_localNetworkDetails.routerAddress).getFee(_remoteNetworkDetails.chainSelector, message);
        // Approve the link amount.
        ccipLocalSimulatorFork.requestLinkFromFaucet(user, fee);
        vm.prank(user); 
        IERC20(_localNetworkDetails.linkAddress).approve(_localNetworkDetails.routerAddress, fee); 
        // Approve the local token
        vm.prank(user); 
        _localToken.approve(_localNetworkDetails.routerAddress, _amountToBridge); 

        // Send the CCIP message across chains and assert token balance
        uint256 userLocalBalanceBefore = _localToken.balanceOf(user); 
        uint256 localUserInterestRate = _localToken.getUserInterestRate(user); 
        vm.prank(user); 
        IRouterClient(_localNetworkDetails.routerAddress).ccipSend(_remoteNetworkDetails.chainSelector, message);
        uint256 userLocalBalanceAfter = _localToken.balanceOf(user); 
        assertEq(userLocalBalanceAfter, userLocalBalanceBefore - _amountToBridge);

        // Switch forks
        vm.selectFork(_remoteFork); 
        vm.warp(block.timestamp+ 20 minutes); 
        uint256 userRemoteBalanceBefore = _remoteToken.balanceOf(user); 
        // Propagate the chain across 
        ccipLocalSimulatorFork.switchChainAndRouteMessage(_remoteFork); // this will change the fork and simulate the CCIP message sending
        uint256 userRemoteBalanceAfter = _remoteToken.balanceOf(user); 
        uint256 remoteUserInterestRate = _remoteToken.getUserInterestRate(user); 
        assertEq(userRemoteBalanceAfter, userRemoteBalanceBefore + _amountToBridge); 
        assertEq(localUserInterestRate, remoteUserInterestRate); 
    }
}
