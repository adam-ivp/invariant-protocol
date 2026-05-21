# Proof Lifecycle
## 1. Spec
Protocol registers ISL invariant. Spec hash and constraint Merkle root committed on-chain via InvariantRegistry.register().

## 2. Constraint evaluation
Prover fetches live state, builds Merkle commitment, evaluates all constraints inside SP1 zkVM. Outputs EpochResult as ZK proof public output.

## 3. Commit-reveal
Prover commits hash of proof before revealing. Prevents front-running.

## 4. Finality window
256-block dispute window after reveal. Valid counter-proof slashes prover and re-evaluates epoch. No valid dispute = epoch finalizes.

## 5. Spot-check
10% of epochs get a secret second prover. Checker commits before primary reveals. Divergent results slash the primary. Makes silent collusion operationally expensive.

## 6. Claim
Epoch finalizes violated → CoverageVault.fileClaim() becomes executable. Junior tranche absorbs first. Senior covers remainder. No vote. No committee.

## Slash schedule
| Offense | Slash |
|---------|-------|
| Missed commit | 500 IVP |
| Missed reveal | 1,000 IVP |
| Invalid proof | 5,000 IVP + jail |
| Silent >30% of epochs | Anomaly flag, deprioritized |
