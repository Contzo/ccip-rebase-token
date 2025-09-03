//SPDX-License-Identifier: MIT

/**
 * - Inside a sol file contract elements should be laid like this:
 * 	1. Pragma statements
 * 	2. Import statements
 * 	3. Events
 * 	4. Errors
 * 	5. Interfaces
 * 	6. Libraries
 * 	7. Contracts
 * - Inside each contract we have this order of declaration:
 * 	1. Type declaration
 * 	2. State variables
 * 	3. Events
 * 	4. Errors
 * 	5. Modifiers
 * 	6. Functions
 * - Also functions inside a contract should be declared like this:
 * 	1. constructor
 * 	2. receive function (if exists)
 * 	3. fallback function (if exists)
 * 	4. external
 * 	5. public
 * 	6. internal
 * 	7. private
 * 	8. view & pure functions
 */
pragma solidity ^0.8.20;


import {TokenPool} from "@chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol";
// lib/chainlink-ccip/chains/evm/contracts/pools/TokenPool.sol

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 token,
        uint8 localTokenDecimals,
        address[] memory allowlist,
        address rmnProxy,
        address router
    ) TokenPool(token, localTokenDecimals, allowlist, rmnProxy, router) {}
}