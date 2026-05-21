# ISL — Invariant Specification Language

**by Invariant Protocol**

ISL is a typed formal constraint language for DeFi state. Compiles to constraint expressions evaluated inside a SP1 ZK circuit. Every constraint is Merkle-committed on-chain, inclusion-provable, and version-controlled.

---

## Declarations

```isl
@protocol  name = env("CONTRACT_ADDRESS")
@invariant name
@severity  Solvency | Liquidity | Peg | Bridge | Governance | Composite
@constraint name
@composite [protocol_a, protocol_b]

## Field access

```isl
field(protocol, slot)
cross_field(chain_id, protocol, slot)
event_field(EventName, event_id, "key")
balance_delta(tx_id)
previously(expr, n)
current_block()
## Expressions

```isl
 a + b  a - b  a * b  a / b
mulDiv(a, b, c)
a == b  a != b  a < b  a <= b  a > b  a >= b
abs_diff(a, b)
and(a, b)  or(a, b)  not(a)
implies(a, b)
forall binding in SET: expr
exists binding in SET: expr
sum(binding in SET: expr)
previously(expr, n)
cat > ~/ivp-protocol/specs/ISL.md << 'EOF'
# ISL — Invariant Specification Language

**by Invariant Protocol**

ISL is a typed formal constraint language for DeFi state. Compiles to constraint expressions evaluated inside a SP1 ZK circuit. Every constraint is Merkle-committed on-chain, inclusion-provable, and version-controlled.

---

## Declarations

```isl
@protocol  name = env("CONTRACT_ADDRESS")
@invariant name
@severity  Solvency | Liquidity | Peg | Bridge | Governance | Composite
@constraint name
@composite [protocol_a, protocol_b]
```

## Field access

```isl
field(protocol, slot)
cross_field(chain_id, protocol, slot)
event_field(EventName, event_id, "key")
balance_delta(tx_id)
previously(expr, n)
current_block()
```

## Expressions

```isl
a + b  a - b  a * b  a / b
mulDiv(a, b, c)
a == b  a != b  a < b  a <= b  a > b  a >= b
abs_diff(a, b)
and(a, b)  or(a, b)  not(a)
implies(a, b)
forall binding in SET: expr
exists binding in SET: expr
sum(binding in SET: expr)
previously(expr, n)
```

## Severity levels

| Level | Meaning |
|-------|---------|
| `Solvency` | Accounting integrity — LTV, collateral ratios, share accounting |
| `Liquidity` | Reserve adequacy, cap enforcement |
| `Peg` | Stablecoin price bounds, oracle freshness |
| `Bridge` | Cross-chain balance conservation, event integrity, nonce ordering |
| `Governance` | Timelock enforcement, voting integrity, state machine |
| `Composite` | Multi-protocol invariant spanning two or more contracts |

## Coverage semantics

Coverage means specified properties held. Not total safety. See `specs/coverage-semantics.md`.
