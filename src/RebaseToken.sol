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
                           STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private s_interestRate = 5e10 ; // 0.00005% per second global interest rate. 
    mapping (address user => uint256 interestRate) private s_userInterestRate; 
    mapping (address user => uint256) private s_lastUpdated; 
    uint256 private constant PRECISION = 1e18 ; 

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

    /**
     * @notice - mint the user tokens when they deposit into the vault
     * @param _to - the user to mint the tokens to
     * @param _amount - tha amount of users to mint.
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate ;
        _mint(_to, _amount);
    }

    /**
     * @notice - calculate the balance of the user including the accumulated interest
     * @param _user - the user we want to get the balance of 
     */
    function balanceOf(address _user) public view override returns(uint256){
        // get the current balance of the user, held by the ERC20 parent contract, the principle balance
        // and multiply it by the interest that has accumulated, since the last update 
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION; 
    }

    /**
     * @notice Burn the RBT tokens 
     * @param _from - the account that will burn the tokens
     * @param _amount - the amount of tokens to burn
     */
    function burn(address _from, uint256 _amount) external{
        if(_amount == type(uint256).max){
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount); 
    }

    /**
     * @notice transfer tokens between one user to another 
     * @notice This transfer function accounts for and accumulated interest by first minting any pending interest to both the recipient and the sender. 
     * @param _recipient - the recipient of the transaction 
     * @param _amount - the amount the sender wants to send.
     * @return a boolean that indicates if the transfer was successful 
     */
    function transfer(address _recipient, uint256 _amount) public override returns(bool){
       //1. Mint any accrued interest to the sender and recipient of the transaction 
       _mintAccruedInterest(msg.sender); 
       _mintAccruedInterest(_recipient); 
       //2.Check if the sender wants to transfer all of their funds
       if(_amount == type(uint256).max){
        _amount = balanceOf(msg.sender);
       }
       //3. Recipient inherits the interest rate of the sender if recipient doesn't already has a deposit.
        if(super.balanceOf(_recipient) == 0){
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender]; 
        }
       //4. Transfer the tokens 
       return super.transfer(_recipient, _amount); 
    }

    /**
     * @notice Transfers tokens from one address to another, on behalf of the sender,
     * provided an allowance is in place.
     * Accrued interest for both sender and recipient is minted before the transfer.
     * If the recipient is new, they inherit the sender's interest rate.
     * @param _sender The address to transfer tokens from.
     * @param _recipient The address to transfer tokens to.
     * @param _amount The amount of tokens to transfer. Can be type(uint256).max to transfer full balance.
     * @return A boolean indicating whether the operation succeeded.
     */
    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_sender); // Use the interest-inclusive balance of the _sender
        }
        // Set recipient's interest rate if they are new
        if (super.balanceOf(_recipient) == 0 && _amount > 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }
    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice - mint the accrued interest to the user 
     * @param _user - the user we want to mint to the accrued interest 
     */
    function _mintAccruedInterest(address _user) internal{
        //1. Find the current balance of rebase token that the user has.
        //2. Calculate the current ballance of the user including the interest. 
        //3. Calculate the number of tokens that need to be minted to the user 2. - 1. 
        //4. update the last updated timestamp for the user. 
        uint256 previousPrincipleBalance = super.balanceOf(_user) ; 
        uint256 currentBalance = balanceOf(_user);
        if(previousPrincipleBalance >= currentBalance) return ; 
        uint256 interestToMint = currentBalance - previousPrincipleBalance; 
        s_lastUpdated[_user] = block.timestamp; 
        _mint(_user, interestToMint);
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(address user) internal view returns(uint256 _accumulatedLinearInterest){
        // we need to calculate the linear growth with time.
        uint256 timeElapsed = block.timestamp - s_lastUpdated[user] ; 
        _accumulatedLinearInterest = PRECISION + s_userInterestRate[user] * timeElapsed; 
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

    /**
     * @notice - this function will return the principle balance of the user, without any accumulated interest since the last transaction 
     * @param _user - the user we want to get the principle balance of 
     * @return - the principle balance of the user 
     */
    function principleBalanceOf(address _user) external view returns(uint256){
        return super.balanceOf(_user);
    }

    /**
     * @notice - get the interest rate that is currently set for the contract
     * @return - returns the global interest rate
     */
    function getGlobalInterestRate() external view returns(uint256){
        return s_interestRate; 
    }
}
 