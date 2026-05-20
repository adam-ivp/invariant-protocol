# Invariant Protocol

DeFi protocols get exploited because nobody enforces their invariants after deploy.

IVP fixes that. Protocols register their invariants on-chain. A prover network verifies them against live state every 50 blocks. Invariant breaks — ZK proof on-chain, payout executes in 256 blocks. No committees. No claims process. Math closes it.

---

## Stack
contracts/           InvariantRegistry, ProverRegistry, CoverageVault, IVPToken
ivp-prover/
lib/               Core types — StateSnapshot, ConstraintExpr, EpochInput/Result
program/           SP1 zkVM program — RISC-V, runs inside ZK circuit
script/            Prover node
invariant-library/   153 invariants — lending, DEX, stablecoin, bridge, governance
---

## Run it

```bash
curl -L https://raw.githubusercontent.com/succinctlabs/sp1/main/sp1up/install | bash
source ~/.bashrc && sp1up

cd ivp-prover/program && cargo prove build
cd .. && cargo run --release --bin ivp
```
=== IVP EXECUTION RESULT ===
Epoch:    1
Violated: true
*** INVARIANT VIOLATION DETECTED ***
Invariant: PaidDebtGhostShareGuard
Total instructions: 75831
---

## Status

- [x] SP1 zkVM prover running
- [x] Invariant evaluation inside ZK circuit confirmed
- [x] 153-invariant library
- [x] Contracts written
- [ ] Testnet deploy
- [ ] First protocol partner
- [ ] Raise

---

**License:** BUSL-1.1 — 3 year commercial restriction, converts to MIT.
