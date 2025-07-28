# Cross chian Rebase Token

1. A protocol that allows users to deposit into a vault and in return, receive a rebase token that represents their underlying balance.
2. Rebase token -> the balance is dynamic.
   - Balance increases linearly with time.
   - mint tokens to our users every time they perform an action (minting, burning, transfers, or bridging) .
3. Interest rate.
   - Set an individual interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault.
   - This global interest rate can only decrease to reward early adopters.
   - Regardless of how much the global interest rate drops, each previous users interest rates remain constant.
4. There has to be a real source of yield like staking, loans or fees.
