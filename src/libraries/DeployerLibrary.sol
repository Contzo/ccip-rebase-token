//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Vault} from "../Vault.sol";
import {IRebaseToken} from "../interfaces/IRebaseToken.sol";
import {Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {RebaseToken} from "../RebaseToken.sol";
import {RebaseTokenPool} from "../RebaseTokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

library DeployerLibrary {
    function deployVault(address _rebaseToken) internal returns (Vault vault) {
        // deploy the vault
        vault = new Vault((IRebaseToken(_rebaseToken)));

        // claim the mint and burn role
        IRebaseToken(_rebaseToken).grantMintAndBurnRole(address(vault));
    }

    function deployTokenAndPool(Register.NetworkDetails memory _networkDetails)
        internal
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
