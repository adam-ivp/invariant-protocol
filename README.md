# Invariant Protocol (IVP)

## Continuous On-Chain Invariant Enforcement. Trustless Claim Settlement.

> Math closes the claim.

---

### The Problem

Every significant DeFi exploit follows the same pattern:

1. Protocol has an invariant — something that must always be true
2. A code path violates it silently  
3. Attacker finds the violation before anyone else
4. Funds drain. Post-mortem written. Audit blamed.

Audits are point-in-time. Code changes after audit. Nothing enforces invariants continuously post-deploy. When something breaks, insurance pays out via human committee — weeks of deliberation, contested claims, political decisions.

### What IVP Does

Protocols commit their invariants on-chain before deploy. A decentralized prover network verifies them continuously against live state every epoch. When an invariant breaks — a ZK proof is submitted on-chain. After a 256-block dispute window, coverage executes automatically.

No committees. No judgment calls. No claims process. Math closes the claim.

### Origin

Built by a bug bounty hunter who found four live vulnerabilities in week one — Aave V3, Monolith Stablecoin Factory, OKX SWFT Bridge, and Circle Arc Network. Every vulnerability was an invariant violation. Three lines of ISL would have caught each one before deploy.

The ghost share invariant that catches the Monolith finding:

```isl
invariant PaidDebtGhostShareGuard:
    read(Lender, slot(totalPaidDebt)) == 0
    implies
    read(Lender, slot(totalPaidDebtShares)) == 0
```

This invariant executes inside the SP1 zkVM and correctly detects the violation.

### Architecture
contracts/          — InvariantRegistry, ProverRegistry, CoverageVault, IVPToken
ivp-prover/
lib/              — Core types: StateSnapshot, ConstraintExpr, EpochInput/Result
program/          — SP1 zkVM program (compiles to RISC-V, runs inside ZK circuit)
script/           — Host node (prover operator software)
invariant-library/  — 153 invariants across lending, DEX, stablecoin, bridge, governance

### Status

- [x] SP1 zkVM prover program compiled and executing
- [x] PaidDebtGhostShareGuard detects ghost share violation inside zkVM
- [x] 153-invariant library covering every major DeFi protocol class
- [x] Smart contracts written (InvariantRegistry, ProverRegistry, CoverageVault)
- [x] Invariant Protocol LLC formed — EIN 42-2616040
- [ ] Contracts deployed to testnet
- [ ] First protocol partner registered
- [ ] Pre-seed raise

### Running the Prover

```bash
# Install SP1
curl -L https://raw.githubusercontent.com/succinctlabs/sp1/main/sp1up/install | bash
source ~/.bashrc && sp1up

# Build the zkVM program
cd ivp-prover/program && cargo prove build

# Run invariant evaluation inside zkVM
cd .. && cargo run --release --bin ivp
```

Expected output:
IVP Prover Node starting...
Executing program inside zkVM...
=== IVP EXECUTION RESULT ===
Epoch:    1
Violated: true
*** INVARIANT VIOLATION DETECTED ***
Invariant: PaidDebtGhostShareGuard
Details:   Invariant 'PaidDebtGhostShareGuard' violated at block 22418441
Total instructions: 75831

### License

Business Source License 1.1 — commercial use restricted 3 years, converts to MIT.

---

*Invariant Protocol — Math closes the claim.*
