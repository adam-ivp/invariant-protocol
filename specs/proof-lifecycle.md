# Proof Lifecycle

How a violation travels from ISL spec to on-chain claim settlement.

---

```
Spec → Constraint → State Witness → ZK Proof → Finality → Claim
```

---

## 1. Spec

A protocol registers an ISL invariant. The spec hash and constraint Merkle root are committed on-chain via `InvariantRegistry.register()`. The full spec is stored on IPFS. The registry stores the hash — not the spec itself. The spec is the protocol team's commitment.

```solidity
InvariantRegistry.register(
  protocol:       0xLendingPool,
  vault:          0xCoverageVault,
  category:       Solvency,
  specHash:       keccak256(spec),
  constraintRoot: merkleRoot(constraints),
  checkInterval:  50,
  uri:            "ipfs://Qm..."
)
```

---

## 2. Constraint evaluation

Each epoch, the assigned prover fetches live protocol state, builds a Merkle state commitment, and evaluates all active constraints inside the SP1 zkVM.

The circuit:
1. Verifies the Merkle state commitment matches the prover's snapshot
2. Evaluates every `ConstraintExpr` against the state
3. Records violations with inclusion proofs against the constraint Merkle root
4. Outputs an `EpochResult` — committed as the public output of the ZK proof

---

## 3. Commit-reveal

The prover commits a hash of the proof before revealing. This prevents front-running and ensures the prover cannot copy another's result.

```
commit_hash = keccak256(abi.encode(proof_bytes, prover_addr, epoch))

EpochManager.commit(epoch, commit_hash)   // block N
EpochManager.reveal(epoch, state_root, violations, proof)  // block N+10..N+30
```

---

## 4. Finality window

After reveal, a 256-block dispute window opens. Any party can submit a counter-proof with a bond. If the counter-proof is valid, the prover is slashed and the epoch is re-evaluated. If no valid dispute arrives, the epoch finalizes.

```
Finality block = reveal_block + 256
```

---

## 5. Spot-check

With probability 10% per epoch, a second prover (the checker) is secretly assigned to re-prove the same epoch. The checker commits before the primary reveals. Checker identity is hidden until after both proofs are submitted.

If results diverge — primary missed a violation the checker caught — the primary is slashed for collusion. This makes silent collusion operationally expensive.

---

## 6. Claim

Once an epoch finalizes as violated, a coverage claim becomes eligible. The claimant files against the `CoverageVault` with the proof hash and requested amount.

```solidity
CoverageVault.fileClaim(
  epoch:           4821,
  proofHash:       0x9a7f3c2e...,
  requestedAmount: coverage
)
```

Junior tranche absorbs losses first. Senior tranche absorbs remainder. Payout executes within 256 blocks of claim filing. No committee. No vote. No discretion.

---

## Invariants about the proof lifecycle itself

The proof lifecycle has its own invariants enforced by the contracts:

- A prover who misses commit is slashed 500 IVP
- A prover who misses reveal is slashed 1,000 IVP  
- A prover who submits an invalid proof is slashed 5,000 IVP and jailed
- A prover silent on >30% of assigned epochs in a rolling window is anomaly-flagged and deprioritized
- If no prover commits within the liveness grace period, anyone can advance the epoch (liveness recovery)

---

## What the proof does not guarantee

- That the spec was complete. The protocol team owns spec completeness.
- That the prover network is free of collusion at scale. Slash amounts are finite. This is an open problem.
- That the coverage vault is solvent. Vault solvency depends on LP liquidity and correct tranche sizing.
