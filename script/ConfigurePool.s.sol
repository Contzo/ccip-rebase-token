//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ConfigurePoolLibrary} from "../src/libraries/ConfigurePoolLibrary.sol";

contract ConfigurePoolScript is Script {
    function run(
        address _localPool,
        uint64 _remoteChainSelector,
        address _remotePool,
        address _remoteToken,
        bool _outBoundRateLimiterIsEnabled,
        uint128 _outboundRateLimiterCapacity,
        uint128 _outboundRateLimiterRate,
        bool _inBoundRateLimiterIsEnabled,
        uint128 _inboundRateLimiterCapacity,
        uint128 _inboundRateLimiterRate
    ) public {
        vm.startBroadcast();
        ConfigurePoolLibrary.configurePool(
            _localPool,
            _remoteChainSelector,
            _remotePool,
            _remoteToken,
            _outBoundRateLimiterIsEnabled,
            _outboundRateLimiterCapacity,
            _outboundRateLimiterRate,
            _inBoundRateLimiterIsEnabled,
            _inboundRateLimiterCapacity,
            _inboundRateLimiterRate
        );
        vm.stopBroadcast();
    }
}
