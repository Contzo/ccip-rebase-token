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
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol"; 


/**
 * @title Rebase Token
 * @author Ilie Razvan 
 * @notice cross-chain rebase token that incentives users to deposit into a vault. 
 * @notice The Global interest rate can only decrease from the original value(at deployment) in order to reward early adopters.
 * @notice Each user will have its own interest rate based on the global interest rate at the time of depositing. 
 */
contract RebaseToken is ERC20{
    /*//////////////////////////////////////////////////////////////
                           STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_interestRate = 5e10 ; // 0.00005% per second global interest rate. 
    mapping (address user => uint256 interestRate) private s_userInterestRate; 

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event InterestRateSat(uint256 _newInterestRate);
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate); 

    constructor() ERC20("Rebase Token", "RBT") {}


    /*//////////////////////////////////////////////////////////////
                     EXTERNAL AND PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _newInterestRate The new interest rate
     * @notice Sets interest rate in the contract 
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if(_newInterestRate > s_interestRate){
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate); 
        }
        s_interestRate = _newInterestRate ;
        emit InterestRateSat(_newInterestRate); 
    }

    function mint(address _to, uint256 _amount) external {
        s_userInterestRate[_to] = s_interestRate ;
        _mint(_to, _amount);
    }

    /*//////////////////////////////////////////////////////////////
                       GETTERS AND VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @param _user - the user we want ot get the interest rate for
     * @notice get the interest rate of a user 
     */
    function getUserInterestRate(address _user) external view returns(uint256){
        return s_userInterestRate[_user] ;
    }
}
 