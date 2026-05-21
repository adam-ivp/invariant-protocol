# Bridge Event Integrity — Demo Walkthrough

**Invariant:** swap_event_integrity  
**Category:** Bridge  
**Severity:** High  
**Status:** Active finding — PoC verified on mainnet fork

---

## Problem

A bridge relayer on the destination chain reads the emitted Swap event to determine how many tokens to credit. If the event overstates the received amount, the relayer overpays. The difference comes from bridge liquidity.

---

## The invariant

```isl
@constraint emitted_amount_matches_balance_delta
  forall swap_id in RECENT_SWAPS(100):
    event_field(SwapEvent, swap_id, "fromAmount") == balance_delta(swap_id)
```

For every swap: the amount the event says was received must equal the actual change in the contract's token balance.

---

## The broken state

Fee-on-transfer tokens deduct a percentage on every transfer. 1000 tokens sent with 10% fee = 900 received.

```solidity
// Correct — measures actual received
uint256 received = token.balanceOf(address(this)) - balanceBefore;

// Wrong — emits user-supplied amount
emit Swap(fromToken, toToken, fromAmount, ...);
//                             ^^^^^^^^^^ not verified
```

| Variable | Value |
|----------|-------|
| event fromAmount | 1000 |
| balance_delta | 900 |

Constraint: `1000 == 900` → false. **Violation.**

---

## Why it matters

Relayer credits destination with 1000. Bridge received 900. 100 tokens per swap sourced from bridge liquidity. Silent. No revert. No alert.

---

## Proof path

1. **Spec committed** — swap_event_integrity registered on-chain, constraint hash committed
2. **State witness** — prover captures fromAmount=1000, balance_delta=900 at block 21,847,203
3. **ZK proof** — SP1 circuit confirms violation, 75,831 cycles, proof committed to EpochManager
4. **Epoch finalizes** — 256-block finality window, no counter-proof, epoch 4821 finalized VIOLATED
5. **Claim executable** — CoverageVault.fileClaim() open, junior tranche absorbs first, payout executes

---

## The fix

```solidity
// Replace fromAmount with received
emit Swap(fromToken, toToken, received, ...);
```

One word. The correct value is already computed on the line above.

---

## Try it

Open the ISL Playground → load Bridge template → hit Run Demo.

---

*IVP-003 · Invariant Protocol*
