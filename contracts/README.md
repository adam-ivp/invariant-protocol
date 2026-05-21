# Contracts

Pre-audit. Do not deploy to mainnet without independent review.

| Contract | Responsibility | Failure mode |
|----------|---------------|--------------|
| EpochManager.sol | Epoch lifecycle: commit, reveal, finality, dispute | Liveness recovery if prover silent |
| InvariantRegistry.sol | Versioned invariants, forking, composite specs | Under-specified = under-covered |
| ProverRegistry.sol | Stake-weighted selection, slashing, anomaly detection | Off-chain bribery at high TVL |
| CoverageVault.sol | Senior/junior tranches, epoch-locked LP, pro-rata settlement | Underfunded vault = partial payout |
| SpotChecker.sol | Random spot-check epochs, hidden checker identity | Checker window expiry if checker silent |
| IVPToken.sol | Governance + staking, coverage-growth-gated emission | Fixed supply, no admin mint |

**License:** BUSL-1.1
