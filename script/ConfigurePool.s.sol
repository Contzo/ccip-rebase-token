//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import {Script, console} from "forge-std/Script.sol"; 
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";





contract ConfigurePoolScript is Script{
    function run(address _localPool, uint64 _remoteChainSelector, address _remotePool, address _remoteToken, bool _outBoundRateLimiterIsEnabled, uint128 _outboundRateLimiterCapacity, uint128 _outboundRateLimiterRate, bool _inBoundRateLimiterIsEnabled, uint128 _inboundRateLimiterCapacity, uint128 _inboundRateLimiterRate) public{
        vm.startBroadcast();
        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1); 
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: _remoteChainSelector,
            allowed: true,
            remotePoolAddress: abi.encode(_remotePool),
            remoteTokenAddress: abi.encode(_remoteToken), 
            outboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: _outBoundRateLimiterIsEnabled, 
                capacity: _outboundRateLimiterCapacity, 
                rate: _outboundRateLimiterRate
            }),
            inboundRateLimiterConfig: RateLimiter.Config({
                isEnabled: _inBoundRateLimiterIsEnabled,
                capacity: _inboundRateLimiterCapacity, 
                rate: _inboundRateLimiterRate
            })
        });

        TokenPool(_localPool).applyChainUpdates(chainsToAdd);
        vm.stopBroadcast();
    }
}