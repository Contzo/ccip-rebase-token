//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {CCIPLocalSimulatorFork, Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";

contract TokenAndPoolDeployer is Script {
    function run() public returns (RebaseToken token, RebaseTokenPool pool) {
        CCIPLocalSimulatorFork ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        Register.NetworkDetails memory networkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        vm.startBroadcast();
        (token, pool) = deployTokenAndPool(networkDetails);
        vm.stopBroadcast();
    }

    function deployTokenAndPool(Register.NetworkDetails memory _networkDetails)
        public
        returns (RebaseToken token, RebaseTokenPool pool)
    {
        // get the network details  using local simulator
        address rnmProxy = _networkDetails.rmnProxyAddress;
        address router = _networkDetails.routerAddress;
        RegistryModuleOwnerCustom registryModuleOwnerCustom =
            RegistryModuleOwnerCustom(_networkDetails.registryModuleOwnerCustomAddress);
        TokenAdminRegistry tokenAdminRegistry = TokenAdminRegistry(_networkDetails.tokenAdminRegistryAddress);

        // 1. Deploy the token
        token = new RebaseToken();

        //2. Deploy the token pool contract
        pool = new RebaseTokenPool(IERC20(address(token)), new address[](0), rnmProxy, router);

        //3, grant the mint and burn role for the pool
        token.grantMintAndBurnRole(address(pool));

        // 4. Register admin via owner() since token does not implement getCCIPAdmin
        registryModuleOwnerCustom.registerAdminViaOwner(address(token));
        tokenAdminRegistry.acceptAdminRole(address(token));

        // 5. Link tokens to pool
        tokenAdminRegistry.setPool(address(token), address(pool));
    }
}

contract VaultDeployer is Script {
    function run(address _rebaseToken) public returns (Vault vault) {
        vm.startBroadcast();
        vault = deployVault(_rebaseToken);
        vm.stopBroadcast();
    }

    function deployVault(address _rebaseToken) public returns (Vault vault) {
        // deploy the vault
        vault = new Vault((IRebaseToken(_rebaseToken)));

        // claim the mint and burn role
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
    }
}
