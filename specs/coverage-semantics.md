# Coverage Semantics

**Coverage means specified properties held. Not total safety.**

## What coverage means
If a registered invariant is violated in a given epoch and captured by the prover network: a ZK proof is generated, the epoch finalizes as violated, and a coverage claim becomes executable against the vault.

## What coverage does not mean
- The protocol is safe from all exploits
- The spec was complete
- The prover was honest
- The vault is solvent

## What determines scope
Coverage scope = the registered ISL spec. Anything not expressed in the spec is not covered. Scope is public, permanent, and auditable on-chain.

## Coverage vs audit

| | Audit | IVP Coverage |
|---|---|---|
| When | Point-in-time | Continuous, every epoch |
| What | Everything auditor finds | Only what is specified |
| Enforcer | Reputation | ZK proof + on-chain settlement |
| Upgrades | Requires re-audit | Requires re-registration |

IVP does not replace audits. Audits find bugs. IVP enforces specified properties after the audit ends.
