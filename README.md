# CCIP Rebase Token

Cross-chain ERC-20 with linear, per-user interest (rebase-like) and Chainlink CCIP bridging. Users deposit into a `Vault` to mint `RBT`, balances grow over time, and tokens can move across chains via a CCIP-enabled `RebaseTokenPool`.

## Features
- Linear, per-user interest accrual; global rate can only decrease
- Role-gated mint/burn for protocol actors (`Vault`, `RebaseTokenPool`)
- CCIP-enabled token pool and simple peering configuration
- Fork-based, two-chain integration test with local CCIP simulator

## Structure
- `src/RebaseToken.sol`: ERC-20 with interest accrual and role-based mint/burn
- `src/interfaces/IRebaseToken.sol`: Token interface
- `src/libraries/DeployerLibrary.sol`: Deploy token, pool, vault; register with CCIP admin registry
- `src/libraries/ConfigurePoolLibrary.sol`: Allow remote pool/token, optional rate limiters
- `script/*.s.sol`: Deployment, configuration, and bridging scripts
- `test/CrossChain.t.sol`: Two-chain CCIP test (Sepolia ↔ Arbitrum Sepolia)

## Quick start
```bash
# Install deps
make install

# Build
make build

# Test (fork-based cross-chain flow)
forge test -vvv
```

## Scripts (Foundry)
Use `--broadcast` and a funded deployer key for live networks.

- Deploy Token + Pool
```bash
forge script script/Deployer.s.sol:TokenAndPoolDeployer --rpc-url $RPC_URL --broadcast
```
- Deploy Vault (for existing token)
```bash
forge script script/Deployer.s.sol:VaultDeployer --rpc-url $RPC_URL --broadcast \
  --sig "run(address)" <REBASE_TOKEN_ADDRESS>
```
- Configure Pool Peering
```bash
forge script script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url $LOCAL_RPC_URL --broadcast \
  --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" \
  <LOCAL_POOL> <REMOTE_SELECTOR> <REMOTE_POOL> <REMOTE_TOKEN> \
  <OUTBOUND_ENABLED> <OUTBOUND_CAP> <OUTBOUND_RATE> <INBOUND_ENABLED> <INBOUND_CAP> <INBOUND_RATE>
```
- Bridge Tokens via CCIP
```bash
forge script script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url $SOURCE_RPC_URL --broadcast \
  --sig "run(address,address,address,uint256,address,uint64)" \
  <ROUTER> <RECEIVER> <TOKEN> <AMOUNT> <LINK> <DEST_SELECTOR>
```

## End-to-end flow (summary)
1) Deploy token+pool on Chain A; deploy token+pool on Chain B
2) Configure pool peering both ways with `ConfigurePoolScript`
3) Deploy `Vault` on Chain A and grant role automatically via `DeployerLibrary`
4) Deposit into `Vault` to mint `RBT`; balances begin accruing interest
5) Bridge `RBT` from A → B with `BridgeTokensScript`; verify on B

## RebaseToken essentials
- Name/Symbol: `Rebase Token (RBT)`
- `balanceOf(user)` includes accrued interest; `principleBalanceOf(user)` excludes it
- Transfers settle accrued interest for both parties; recipient inherits rate if new
- `MINT_AND_BURN_ROLE` is granted to `Vault` and `RebaseTokenPool`

## CCIP notes
- `DeployerLibrary.deployTokenAndPool` links token⇄pool via `TokenAdminRegistry`
- `ConfigurePoolLibrary.configurePool` sets remote pool/token and rate limiter configs

## Config
- Remappings: `@openzeppelin/`, `@ccip/`, `@chainlink/local/`
- RPCs in `foundry.toml`: `sepolia-eth`, `arb-sepolia`

## License
SPDX-License-Identifier: MIT
