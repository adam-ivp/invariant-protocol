# Invariant Protocol

**Are your security assumptions still true right now?**

Audits answer that question at deployment. Nothing answers it after.

IVP does.

---

## The wedge: Invariant Runtime + Guardian

Two things. That's the product.

**Invariant Runtime** — protocols specify security assumptions in ISL, a typed formal constraint language. Those specs are committed on-chain. A prover network verifies them against live state every epoch using SP1 ZK proofs. Violation produces a proof, not an alert.

**Guardian** — protocols register an on-chain emergency responder. When a violation is confirmed, Guardian fires: freeze the suspected account, pause withdrawals, redirect pending funds to escrow. The attacker's drain gets intercepted before it completes.

```
Invariant fires → ZK proof generated → Guardian callback →
Account frozen → Withdrawals blocked → Blast radius reduced
```

That's it. Everything else is a future module.

---

## What protocols actually buy

Not "a decentralized invariant ecosystem."

Five critical invariants and freeze capability for catastrophic state divergence:

- **Accounting conservation** — emitted amounts match actual balance deltas
- **Solvency** — total debt within liquidation threshold at all times
- **Collateralization** — global collateral ratio above minimum
- **Share/debt parity** — shares cannot exist without corresponding debt
- **Bridge escrow integrity** — locked + inflight covers outstanding liabilities

Each one is a real pain point. Each one has cost protocols millions in production.

---

## ISL — the constraint language

```isl
@invariant swap_event_integrity
@severity  Bridge
@protocol  bridge_src

  // The bug: contract emits user-supplied fromAmount, not actual received.
  // For fee-on-transfer tokens: fromAmount > received.
  // Relayer trusts the event → overpays → bridge drained.

  @constraint emitted_amount_matches_balance_delta
    forall swap_id in RECENT_SWAPS(100):
      event_field(SwapEvent, swap_id, "fromAmount") == balance_delta(swap_id)
```

Protocols write invariants in ISL. Specs are committed on-chain. The runtime verifies them continuously.

---

## Guardian integration

```solidity
contract MyGuardian is IVPGuardian {

    function onViolation(
        uint256 invariantId,
        uint256 epoch,
        uint8   violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external override onlyIVP returns (GuardianResponse memory) {

        protocol.freezeAccount(suspectedAccount);
        protocol.pauseWithdrawals();

        return GuardianResponse({
            action:        GuardianAction.AccountFrozen,
            frozenAccount: suspectedAccount,
            frozenAmount:  estimatedLoss,
            escrowAddress: escrowAddress,
            paused:        false,
            reason:        "IVP: invariant violation confirmed"
        });
    }

    function onViolationCleared(uint256 invariantId, uint256 epoch)
        external override onlyIVP {
        protocol.unpause(); // false positive — dispute succeeded
    }
}
```

Three steps to integrate:
1. Deploy a Guardian implementing `IIVPGuardian`
2. Register: `ivp guardian register --invariant 42 --guardian 0xYours`
3. Done — IVP calls `onViolation()` on every confirmed violation

---

## Run the demo

One vulnerable bridge. One invariant. One Guardian freeze. Fully runnable.

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Clone and install
git clone https://github.com/adam-ivp/invariant-protocol.git
cd invariant-protocol
forge install foundry-rs/forge-std

# Run the demo
forge test --match-test testGuardianDemoFlow -vvvv
```

Expected output:
```
=== IVP GUARDIAN DEMO ===
Invariant: swap_event_integrity

User sent:       1000 FOT
Bridge received: 900 FOT  (10% FoT tax)
Event emitted:   1000 FOT
Divergence:      100 FOT

Constraint: emitted_amount_matches_balance_delta
Result:     VIOLATED

Guardian:   onViolation() fired
Frozen:     0x2 (attacker)
Paused:     true

Withdrawal: BLOCKED — WithdrawalsArePaused

Spec → Witness → Violation → Guardian → Blocked → Claim
```

---

## What IVP is not

- Not real-time prevention — exploit transactions execute. Guardian intercepts the drain.
- Not autonomous protection — Guardian is a hook. Protocols define their own response.
- Not production-ready — SP1 verifier integration in progress. Pre-audit.
- Not a coverage market — CoverageVault exists but is a future product.

**What IVP is:** programmable runtime invariant verification with optional Guardian enforcement hooks.

---

## Repository

```
contracts/
  EpochManager.sol          Epoch lifecycle: commit, reveal, finality, dispute
  InvariantRegistry.sol     Versioned invariants, forking, composite specs
  ProverRegistry.sol        Stake-weighted selection, tiered slashing
  CoverageVault.sol         Coverage layer (future product)
  SpotChecker.sol           Cryptographic collusion resistance
  IVPToken.sol              Governance + staking (future product)
  IVPGuardian.sol           Reference Guardian + IVPEscrow
  IVPGuardianRegistry.sol   On-chain registry mapping invariants to guardians

examples/                   ISL specs — real exploit classes
specs/                      ISL reference, proof lifecycle, Guardian guide
demo/                       Vulnerable bridge + demo test
findings/                   Retroactive analyses (Euler $197M)
test/                       IVPGuardianDemo.t.sol — runnable demo
```

---

## Status

- [x] ISL constraint language designed
- [x] 36 invariants across 5 exploit classes
- [x] 8 contracts — security-patched
- [x] Guardian interface + reference implementation
- [x] Runnable Foundry demo
- [x] Active bug bounty submissions — multiple protocols
- [x] Invariant Protocol LLC — EIN 42-2616040
- [ ] SP1 verifier wired (architecture complete, ZK integration in progress)
- [ ] Testnet deploy
- [ ] First protocol integration

---

## Contact

Security researchers, audit firms, protocol engineers.

We are not optimizing for noise. We are building the standard.

**License:** BUSL-1.1 — converts to MIT after 3 years.
