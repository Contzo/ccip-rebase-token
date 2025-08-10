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

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // we need to pass the rebase token address to the constructor, in order to have access to the token contract addresses
    // we need to create a deposit function that mints tokens the user equal to the amount of ETH deposited
    // create a redeem function that burns tokens from the user and sends the user ETH
    // create a way to add rewards to the vault

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IRebaseToken private immutable i_rebaseToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event Deposited(address indexed sender, uint256 value);
    event Redeem(address indexed sender, uint256 _amount);

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error Vault__RedeemFailed();
    /*//////////////////////////////////////////////////////////////
                       CONSTRUCTOR AND CALLBACKS
    //////////////////////////////////////////////////////////////*/

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice a function the will allow a user to deposit some amount of EHT and receive the same amount of rebase tokens.
     */
    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @notice this function will send some amount of eth to the user and will burn the same amount of rebase token
     * @param _amount the amount of eth one use wants to redeem
     */
    function redeem(uint256 _amount) external {
        // 1. burn the tokens from the user
        // 2. send the user the corresponding ETH.
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                       GETTERS AND PURE FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice get the address of the rebase token
     */
    function getRebaseTokenAddress() external view returns (address) {
        return address(i_rebaseToken);
    }
}
