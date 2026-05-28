# Coverage Semantics

**Coverage means specified properties held. Not total safety.**

This document defines exactly what IVP coverage means, what it does not mean, and what determines the boundary.

---

## What coverage means

When a protocol registers an invariant and funds a coverage vault, IVP guarantees:

> *If the registered invariant is violated in a given epoch, and the violation is captured by the prover network, a ZK proof will be generated, the epoch will finalize as violated, and a coverage claim will become executable against the vault.*

That is the guarantee. Nothing more.

---

## What coverage does not mean

**Coverage does not mean the protocol is safe.**

A protocol can have IVP coverage and still be exploited via:

- A vulnerability not encoded in any registered invariant
- An invariant that was correct when written but became insufficient after an upgrade
- A governance attack that changes protocol parameters before the invariant fires
- An exploit that executes and completes within a single epoch (before the prover can capture it)

**Coverage does not mean the spec was complete.**

The protocol team writes the invariant. They decide what to specify. An under-specified invariant is an under-covered protocol. IVP enforces what is committed — no more.

**Coverage does not mean the prover was honest.**

The prover network is economically incentivized to report violations. The SpotChecker adds collusion resistance. But prover-protocol collusion at scale remains an open problem. See `specs/proof-lifecycle.md`.

---

## What determines coverage scope

Coverage scope is determined entirely by the registered ISL spec. The spec hash is committed on-chain at registration. Any property not expressed in the spec is not covered.

The coverage scope is public, permanent, and auditable. Anyone can read the InvariantRegistry to see exactly what a protocol has committed to.

---

## Coverage vs audit

| | Audit | IVP Coverage |
|---|---|---|
| **When** | Point-in-time, pre-launch | Continuous, every epoch |
| **What** | Everything the auditor can find | Only what is specified |
| **Enforcer** | Reputation, disclosure | ZK proof, on-chain settlement |
| **Output** | Report | On-chain proof + claim |
| **Upgrades** | Requires re-audit | Requires re-registration |

IVP does not replace audits. Audits find bugs. IVP enforces specified properties after the audit ends.

---

## Vault coverage limits

Coverage payouts are bounded by:

1. **Vault balance** — total assets in the CoverageVault at claim time
2. **Coverage ratio cap** — maximum 50% of vault TVL per claim (prevents single-claim drain)
3. **Tranche hierarchy** — junior absorbs first, senior absorbs remainder

If the vault is underfunded relative to the loss, payout is partial. Vault solvency is the LP's responsibility, not IVP's.

---

## The honest framing

Coverage is a credible commitment, not a guarantee of safety.

A protocol with IVP coverage has committed — on-chain, verifiably, permanently — to a set of properties. If those properties break, the record is immutable and the claim is executable.

That is strictly more than a protocol without coverage. It is not the same as a protocol that cannot be exploited.
