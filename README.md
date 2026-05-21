Invariant Protocol
The question every protocol should answer before launch:
What properties must always be true — and what happens when they aren't?
Most protocols can't answer that. Not because they haven't thought about it. Because nothing enforces it after the audit ends.
IVP is the enforcement layer.

The center of gravity: ISL
ISL — Invariant Specification Language — is the most important thing in this repository.
Not the contracts. Not the ZK prover. Not the token.
ISL is a typed formal constraint language designed for DeFi state. Protocols write their invariants in ISL. Audit firms encode exploit classes in ISL. Researchers publish shared specs in ISL. The compiler turns those specs into constraint expressions evaluated inside a ZK circuit — with every constraint Merkle-committed on-chain, inclusion-provable, and version-controlled.
If ISL becomes the language the security community uses to encode recurring DeFi failure modes, it becomes a standards layer. That's where protocol moats form.

What this is
Protocols specify their invariants in ISL. Those specs are committed on-chain. A prover network verifies them against live state every epoch using SP1 ZK proofs. If a specified property breaks, a ZK proof confirms it, the claim settles against the coverage vault, and the payout executes. No vote. No committee. No discretion.
Coverage means specified properties held. Not total safety.
That distinction is the entire design. IVP does not replace audits. It enforces what you commit to — continuously, trustlessly, in production.

Why this exists
Three patterns. Repeated across every protocol category. The library exists because the bugs are real.
Governance function asymmetry
Two functions with the same stated intent — one updates an enforcement bitmap, the other doesn't. The discrepancy is invisible at the call site. It surfaces in edge cases where the missing update silently bypasses the intended restriction. Active findings in this category across major lending deployments.
Incomplete fix propagation
A patch applied to one mirrored execution path but not its structural mirror. Ghost share pattern: rounding leaves total debt at zero while shares stay non-zero. The next borrower pays for it. Triggers through normal usage. No attack required. Active findings in this category across CDP stablecoin protocols.
Event integrity divergence
A contract computes the correct value internally but emits a different value in the event log. Bridge relayers use emitted events as the source of truth for destination-side settlement. When emitted amounts diverge from actual amounts, the difference is sourced from bridge liquidity. Active findings in this category with PoCs verified on mainnet forks.

Who this is for
Researchers, exploit analysts, audit firms, and protocol engineers.
Not retail. Not yet.
If you understand what a ghost share residual is, why bitmap desync is dangerous, or what fee-on-transfer accounting failure looks like in an event log — this is built for you.

Repository structure
contracts/     6 Solidity contracts — EpochManager, InvariantRegistry,
               ProverRegistry, CoverageVault, SpotChecker, IVPToken
examples/      ISL specs grounded in real exploit classes
specs/         ISL.md · proof-lifecycle.md · coverage-semantics.md
demo/          bridge-event-integrity-walkthrough.md
playground/    ISL Playground — live invariant editor with violation demo
dashboard/     Protocol monitoring dashboard

The stack
ComponentResponsibilityFailure modeEpochManager.solEpoch lifecycle: commit, reveal, finality, bonded disputeLiveness recovery if prover silentInvariantRegistry.solVersioned invariants, forking, composite specsUnder-specified = under-coveredProverRegistry.solStake-weighted selection, tiered slashing, anomaly detectionOff-chain bribery at high TVLCoverageVault.solSenior/junior tranches, epoch-locked LP, pro-rata settlementUnderfunded vault = partial payoutSpotChecker.solRandom spot-check epochs, hidden checker identityChecker window expiry if silentIVPToken.solGovernance + staking, coverage-growth-gated emissionFixed supply, no admin mintivp-prover/SP1 zkVM circuit, state fetching, batch aggregationInternalinvariant-library/36 ISL specs across 5 categoriesInternalsdk/TypeScript: register, fork, activate, monitor—cli/ivp register / activate / status / watch / vault / spec—

Architecture principles
ISL is the interface. The ZK circuit, the prover network, and the coverage vaults are all downstream of the spec. What gets enforced is determined entirely by what gets written.
Semantic honesty. Coverage means specified properties held. The protocol team owns spec completeness. IVP enforces what is committed, completely and continuously.
Adversary-designed. Liveness recovery, bonded disputes, proof size caps, anti-Sybil cooldowns, dispute limits. The SpotChecker makes prover-protocol collusion operationally expensive.
The unsolved economic problem. Slash amounts are finite. Exploit concealment value is not. For large protocols, off-chain bribery can economically dominate any slash. Watchdog markets, public replay bounties, and forced proof redundancy are the direction. We say this out loud.

Open problems
Slash amounts vs exploit value. Current model works when slash loss exceeds collusion profit. At scale it doesn't. Active research direction.
Prover-protocol collusion is operationally mitigated via SpotChecker. Not cryptographically eliminated.
Spec completeness is the protocol team's responsibility. Under-specified = under-covered.

Status

 SP1 zkVM prover operational
 ZK circuit verified
 ISL compiler and constraint evaluator built
 36 invariants across 5 categories
 Active bug bounty submissions — multiple categories
 Full contract suite — 6 contracts, hardened
 SpotChecker — collusion cost amplification
 SDK + CLI built
 Invariant Protocol LLC — EIN 42-2616040
 Testnet deploy
 First protocol integration
 Raise


Contact
Security researchers, audit firms, and protocol teams: reach out.
We are not optimizing for noise. We are building the standard.

License: BUSL-1.1 — 3 year commercial restriction, converts to MIT.

Hit Commit changes at the bottom. Done.
