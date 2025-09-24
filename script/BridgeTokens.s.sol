//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract BridgeTokensScript is Script {
    function run(
        address _routerAddress,
        address _receiver,
        address _tokenToPass,
        uint256 _amountToSend,
        address _linkTokenAddress,
        uint64 _destinationChainSelector
    ) public {
        vm.startBroadcast();
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({token: _tokenToPass, amount: _amountToSend});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: _linkTokenAddress, // fees paid in link
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0})) // no gas limit
        });
        uint256 fee = IRouterClient(_routerAddress).getFee(_destinationChainSelector, message);
        IERC20(_linkTokenAddress).approve(_routerAddress, fee);
        IERC20(_tokenToPass).approve(_routerAddress, _amountToSend);
        IRouterClient(_routerAddress).ccipSend(_destinationChainSelector, message);
        vm.stopBroadcast();
    }
}
