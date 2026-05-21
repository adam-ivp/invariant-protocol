# Invariant Protocol

The question every protocol should answer before launch:

*What properties must always be true — and what happens when they aren't?*

Most protocols can't answer that. Not because they haven't thought about it. Because nothing enforces it after the audit ends.

IVP is the enforcement layer.

---

## The center of gravity: ISL

**ISL — Invariant Specification Language** — is the most important thing in this repository.

Not the contracts. Not the ZK prover. Not the token.

ISL is a typed formal constraint language designed for DeFi state. Protocols write their invariants in ISL. Audit firms encode exploit classes in ISL. Researchers publish shared specs in ISL. The compiler turns those specs into constraint expressions evaluated inside a ZK circuit — with every constraint Merkle-committed on-chain, inclusion-provable, and version-controlled.

If ISL becomes the language the security community uses to encode recurring DeFi failure modes, it becomes a standards layer. That's where protocol moats form.

The invariant library is the seed. Every entry is grounded in a real exploit class — found, documented, and encoded as a formally verifiable constraint.

---

## What this is

Protocols specify their invariants in ISL. Those specs are committed on-chain. A prover network verifies them against live state every epoch using SP1 ZK proofs. If a specified property breaks, a ZK proof confirms it, the claim settles against the coverage vault, and the payout executes. No vote. No committee. No discretion.

**Coverage means specified properties held. Not total safety.**

That distinction is the entire design. IVP does not replace audits. It enforces what you commit to — continuously, trustlessly, in production. The scope of coverage is exactly what the protocol team signs. Nothing implied.

---

## Why this exists

Three patterns. Repeated across every protocol category. The library exists because the bugs are real.

**Governance function asymmetry**
Two functions with the same stated intent — one updates an enforcement bitmap, accumulator, or mapping. The other doesn't. The discrepancy is invisible at the call site. It surfaces in edge cases where the missing update silently bypasses the intended restriction. Governance acts to reduce risk. The protocol continues as if it didn't. Active findings in this category across major lending deployments.

**Incomplete fix propagation**
A patch applied to one mirrored execution path but not its structural mirror. Free/paid, stable/variable, normal/emergency — whenever a codebase has two paths that should behave identically, a fix to one demands the same fix to the other. Ghost share pattern: rounding leaves total debt at zero while shares stay non-zero. The next borrower pays for it. Triggers through normal usage. No attack required. Active findings in this category across CDP stablecoin protocols.

**Event integrity divergence**
A contract computes the correct value internally — balance delta, actual received amount, true output. It then emits a different value in the event log. Bridge relayers use emitted events as the source of truth for destination-side settlement. When emitted amounts diverge from actual amounts, the difference is sourced from bridge liquidity. Active findings in this category with PoCs verified on mainnet forks.

These are the dominant failure patterns in production DeFi code. ISL encodes each one as a formally verifiable constraint that fires the epoch it occurs.

---

## Who this is for

Researchers, exploit analysts, audit firms, and protocol engineers.

Not retail. Not yet.

If you understand what a ghost share residual is, why bitmap desync is dangerous, or what fee-on-transfer accounting failure looks like in an event log — this is built for you.

---

## The invariant library

Five categories. Formally specified. Grounded in real exploit classes.

**Lending** — 8 invariants: governance function symmetry, reserve solvency ratio, liquidity index monotonicity, isolation mode debt ceiling, aToken supply conservation, borrow cap enforcement, supply cap enforcement, oracle staleness.

**Bridge** — 6 invariants: cross-chain balance conservation, nonce integrity, liquidity solvency, swap event integrity, admin key liveness, message queue bounds.

**Stablecoin** — 6 invariants: global collateral ratio, debt share accounting, peg stability, liquidation threshold enforcement, stability pool solvency, emergency circuit breakers.

**DEX** — 8 invariants: constant product non-decreasing, V3 sqrtPrice/tick consistency, price manipulation detection, LP supply consistency, fee accounting integrity, flash loan atomicity, position liquidity bounds, swap output correctness.

**Governance** — 8 invariants: timelock delay enforcement, voting power snapshot integrity, quorum integrity, proposal state machine, admin key controls, parameter change bounds, supply conservation during vote, execution uniqueness.

The library is internal. The specs are the product. Contact us to integrate.

---

## The stack
contracts/
EpochManager.sol       — epoch lifecycle: commit, reveal, finality, bonded dispute
InvariantRegistry.sol  — versioned invariants, forking, composite cross-protocol specs
ProverRegistry.sol     — stake-weighted selection, tiered slashing, anomaly detection
CoverageVault.sol      — senior/junior tranches, epoch-locked LP, pro-rata settlement
SpotChecker.sol        — random spot-check epochs, hidden checker identity, collusion cost amplification
IVPToken.sol           — governance + staking, coverage-growth-gated emission
ivp-prover/              — internal
invariant-library/       — internal
sdk/                     — TypeScript: register, fork, activate, monitor
cli/                     — ivp register / activate / status / watch / vault / spec
---

## Architecture principles

**ISL is the interface.** The ZK circuit, the prover network, and the coverage vaults are all downstream of the spec. What gets enforced is determined entirely by what gets written.

**Semantic honesty.** Coverage means specified properties held. The protocol team owns spec completeness. IVP enforces what is committed, completely and continuously.

**Adversary-designed.** Liveness recovery, bonded disputes, proof size caps, anti-Sybil cooldowns, dispute limits. The SpotChecker makes prover-protocol collusion operationally expensive.

**The unsolved economic problem.** Slash amounts are finite. Exploit concealment value is not. For large protocols, off-chain bribery can economically dominate any slash. Watchdog markets, public replay bounties, and forced proof redundancy are the direction. We say this out loud.

---

## Open problems

**Slash amounts vs exploit value.** Current model works when slash loss exceeds collusion profit. At scale it doesn't. Active research direction.

**Prover-protocol collusion** is operationally mitigated. Not cryptographically eliminated.

**Spec completeness** is the protocol team's responsibility. Under-specified = under-covered.

---

## Status

- [x] SP1 zkVM prover operational
- [x] ZK circuit verified
- [x] ISL compiler and constraint evaluator built
- [x] 36 invariants across 5 categories
- [x] Active bug bounty submissions — multiple categories
- [x] Full contract suite — 6 contracts, hardened
- [x] SpotChecker — collusion cost amplification
- [x] SDK + CLI built
- [x] Invariant Protocol LLC — EIN 42-2616040
- [ ] Testnet deploy
- [ ] First protocol integration
- [ ] Raise

---

## Contact

Security researchers, audit firms, and protocol teams: reach out.

We are not optimizing for noise. We are building the standard.

---

**License:** BUSL-1.1 — 3 year commercial restriction, converts to MIT.
