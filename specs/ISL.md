# ISL — Invariant Specification Language

**by Invariant Protocol**

ISL is a typed formal constraint language for DeFi state. It compiles to constraint expressions evaluated inside a SP1 ZK circuit. Every constraint is Merkle-committed on-chain, inclusion-provable, and version-controlled.

---

## Why a language

Audits produce findings. IVP produces enforcement. The gap between them is specification — a precise, machine-verifiable statement of what must always be true.

ISL is that specification layer. It is readable enough for a protocol engineer to write, formal enough for a ZK circuit to evaluate, and expressive enough to encode every exploit class we have found in production DeFi.

---

## Primitives

### Declarations

```isl
@protocol  name = env("CONTRACT_ADDRESS")
@invariant name
@severity  Solvency | Liquidity | Peg | Bridge | Governance | Composite
@constraint name
@composite [protocol_a, protocol_b]   // cross-chain invariant
```

### Field access

```isl
field(protocol, storage_slot)
cross_field(chain_id, protocol, slot)    // cross-chain read
event_field(EventName, event_id, "key") // emitted event field
balance_delta(tx_id)                    // pre/post balance difference
previously(expr, n)                     // value N epochs ago
current_block()
```

### Expressions

```isl
// Arithmetic
a + b   a - b   a * b   a / b
mulDiv(a, b, c)      // a * b / c without overflow

// Comparison
a == b   a != b   a < b   a <= b   a > b   a >= b
abs_diff(a, b)

// Logic
and(a, b)    or(a, b)    not(a)
implies(a, b)            // a → b (vacuously true if a is false)

// Quantifiers
forall binding in SET: expr
exists binding in SET: expr

// Aggregation
sum(binding in SET: expr)
```

### Temporal operators

```isl
previously(expr, n)        // expr was this value n epochs ago
always_since(expr, n)      // expr held every epoch for last n
```

---

## Severity levels

| Level | Meaning |
|-------|---------|
| `Solvency` | Protocol accounting integrity — LTV, collateral ratios, share accounting |
| `Liquidity` | Reserve adequacy, cap enforcement, withdrawal availability |
| `Peg` | Stablecoin price bounds, oracle freshness |
| `Bridge` | Cross-chain balance conservation, event integrity, nonce ordering |
| `Governance` | Timelock enforcement, voting integrity, state machine correctness |
| `Composite` | Multi-protocol invariant spanning two or more on-chain contracts |

---

## Example: governance function asymmetry

```isl
// Two governance functions both zero an asset's LTV.
// One updates the enforcement bitmap. The other doesn't.
// eMode users bypass the restriction entirely.

@invariant ltv_enforcement_consistency
@severity  Solvency
@protocol  pool, configurator

  @constraint ltv_zero_propagates_to_all_access_paths
    forall asset in ACTIVE_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        implies(
          and(base_ltv(asset) == 0,
              in_collateral_bitmap(asset, emode_id)),
          ltv_zero_bitmap_set(asset, emode_id)
        )
```

## Example: event integrity divergence

```isl
// Contract computes correct received amount via balance delta.
// Emits user-supplied amount in event instead.
// Bridge relayers trust the event for destination payout.

@invariant swap_event_integrity
@severity  Bridge
@protocol  bridge_src

  @constraint emitted_amount_matches_balance_delta
    forall swap_id in RECENT_SWAPS(100):
      event_field(SwapEvent, swap_id, "fromAmount") == balance_delta(swap_id)
```

## Example: ghost share pattern

```isl
// After full debt repayment, mulDivDown rounding leaves
// totalShares non-zero while totalDebt is zero.
// Next borrower gets undervalued shares.

@invariant debt_share_accounting
@severity  Solvency
@protocol  cdp

  @constraint no_ghost_shares
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      implies(total_debt(debt_class) == 0, total_shares(debt_class) == 0)
```

---

## Compilation

ISL specs compile to `CompiledInvariant` structs containing:

- Typed `ConstraintExpr` trees evaluated inside the SP1 zkVM
- A Merkle tree over all constraints — root committed on-chain
- Per-constraint inclusion proofs for on-chain verification

The compiler is internal. To register an invariant, submit the spec hash and constraint root to `InvariantRegistry.register()`. The prover fetches the full spec from the IPFS URI committed at registration.

---

## Coverage semantics

Coverage means: *the specified properties held every epoch.*

It does not mean total protocol safety. It does not mean the spec was complete. The protocol team signs the scope. Under-specified = under-covered.

See `specs/coverage-semantics.md` for the full coverage model.
