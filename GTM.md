# IVP Go-To-Market Plan — GUARDIAN-FIRST STRATEGY
## Prove Guardian value operationally → Then decentralize the prover

**Version:** 2.0 (PIVOTED)  
**Status:** Pre-deployment  
**Goal:** 30 days of live operational Guardian → 1 protocol endorsement → Raise → Build ZK infrastructure

---

## The thesis

Audits validate assumptions at deployment. Nothing enforces them after.

Protocols don't care about formal methods academically. They care about:
- Preventing bank runs
- Stopping bridge drains
- Reducing blast radius
- Minimizing TVL loss
- Lowering insurance premiums
- Calming users during incidents

**Guardian turns IVP from "interesting monitoring" into "economic damage reduction infrastructure."**

---

## The pivot (what changed)

**Old path:**
ZK cofounder → wire SP1 → testnet → first integration → raise

**New path:**
Centralized Guardian → 30 days operational proof → Silo endorsement → raise → hire ZK cofounder → decentralize

**Why:**
- Removes 2-month ZK bottleneck
- Proves Guardian actually works
- Discovers false positive problems early
- Builds protocol trust on data, not thesis
- Shortens raise conversation from "here's our vision" to "here's 30 days of operational data"

---

## Phase 0 — Guardian Deployment (Days 1–7)

**Deliverables:**

```
✓ MockEpochManager.sol — manually-triggered epoch finalization
✓ SiloGuardianAdapter.sol — Silo-specific state reader + Guardian callbacks
✓ IVPGuardian.sol + IVPGuardianRegistry.sol + IVPEscrow.sol — already exist
✓ Deploy script for Base Sepolia
✓ Silo state reader (daily monitoring script)
✓ Operational logging template
```

**Deployment checklist:**

```bash
# Day 1
forge deploy IVPEscrow --rpc base_sepolia

# Day 2
forge deploy IVPGuardian --rpc base_sepolia

# Day 3
forge deploy IVPGuardianRegistry --rpc base_sepolia

# Day 4
forge deploy MockEpochManager --rpc base_sepolia

# Day 5
forge deploy SiloGuardianAdapter --rpc base_sepolia

# Day 6 — register
cast send <REGISTRY> "register(uint256,address)" 1 <GUARDIAN_ADDRESS>

# Day 7 — verify
cast call <REGISTRY> "getGuardianForInvariant(uint256)(address)" 1
```

**Success metric:** All contracts deployed, no gas issues, Guardian callable.

---

## Phase 1 — Operational Proof (Days 8–38)

### The invariant

**One invariant. One protocol. One metric.**

```isl
@invariant solvency_breach
@severity  Critical

  @constraint global_solvency_above_minimum
    forall collateral in ACTIVE_COLLATERALS:
      (collateral_value * 10000) >= (debt_value * 11000)  // 110%
```

### Daily operations

**Every day for 30 days:**

```
08:00 — Query Silo state: global solvency ratio
09:00 — Log to CSV: solvency_ratio, breach_detected, false_positive
12:00 — If breach: manually call finalizeEpochManual()
15:00 — Guardian callback fires (or doesn't) — log result
18:00 — Update operational metrics
```

**Operational log (CSV):**

```csv
date,time,epoch,solvency_ratio,breach_detected,guardian_fired,accounts_frozen,escrow_balance,false_positive,notes
2026-05-28,08:15,4821,112.5%,no,no,0,0,no,baseline healthy
2026-05-29,14:32,4822,109.2%,yes,yes,3,2500000,no,oracle spike — correctly detected
2026-05-30,09:44,4823,110.5%,no,no,3,2500000,no,accounts remain frozen pending dispute
```

### Silo outreach (Days 2–4)

**Message:**

```
Built a Guardian that monitors solvency invariants and freezes accounts 
when breaches happen — before cascades.

Live on Base Sepolia. Looking for a 30-day operational test with a protocol
that actually needs this.

Interested in being first?

GitHub: github.com/adam-ivp/invariant-protocol
Testnet deploy: <Base Sepolia addresses>
```

**Target:** Silo Finance security team  
**Success metric:** Silo says "we'll try it" or "we've been thinking about this"

---

## Phase 2 — Metrics compilation (Day 31–38)

**By day 30, you need:**

```
Operational metrics
├─ Violations detected: X
├─ False positives: Y (aim for <5%)
├─ Guardian response time: Z ms
├─ Accounts frozen: A
├─ Total TVL captured: B
└─ Operational uptime: C%

Business signals
├─ Silo statement of interest: Y/N
├─ Other protocols requesting demos: X
└─ Ready to raise: Y/N

Technical stability
├─ Contract bugs: 0
├─ Callback failures: 0
├─ State sync errors: 0
└─ Oracle read errors: 0
```

**This becomes your raise deck.**

Not: "Here's our whitepaper."  
Yes: "Here's 30 days of live data showing Guardian prevented $X in losses with <5% false positives. Silo endorsed it. We want $2-4M to wire SP1 and ship mainnet."

---

## Phase 3 — Raise (Week 6+)

### Prerequisites

- ✓ 30 days operational Guardian
- ✓ <5% false positive rate
- ✓ At least 1 real violation detected + correctly handled
- ✓ Silo (or equivalent) statement of support
- ✓ Operational metrics compiled
- ✓ Data shows reduced blast radius

### Raise pitch

**Opening:** "We built Guardian — runtime protection that stops protocol insolvency cascades. Ran it live for 30 days on testnet. Here's the data."

**The data:** Spreadsheet showing daily operations, false positive rate, violations detected, capital protected.

**The endorsement:** Silo's security lead: "This would have caught scenarios we worry about."

**The ask:** $2-4M to:
1. Wire SP1 verifier (ZK cofounder hire)
2. Ship mainnet Guardian
3. Build distributed prover infrastructure
4. Achieve 3+ paying protocol integrations

### Target investors

- Paradigm (infrastructure thesis)
- Robot Ventures (DeFi focus, fast decisions)
- Multicoin (infrastructure believers)
- A16z crypto (if warm intro available)

**Note:** Do NOT reach out until you have:
1. Working Guardian (week 2)
2. Protocol using it (week 4)
3. 30 days of operational data (week 6)

Raising before that is premature. You have more leverage after.

---

## What you do NOT do for 30 days

❌ Tweet about IVP  
❌ Cold email investors  
❌ Write a token spec  
❌ Search for ZK cofounders  
❌ Apply to accelerators  
❌ Talk to the press  
❌ Build the coverage vault  
❌ Build the dispute system  
❌ Optimize SP1 integration  
❌ Over-engineer anything  

**Your job:** Get Guardian working. Keep a clean log. Get Silo interested.

---

## Why this sequence is right

**Removes technical blocker** — no ZK cofounder search  
**Proves market fit** — data beats thesis  
**De-risks false positives** — you find the hard problems manually  
**Builds protocol trust** — Silo sees you're serious by running it  
**Shortens raise** — "here's operational data" closes faster than "here's our vision"  
**Can still decentralize** — nothing you build prevents SP1 integration later  

---

## Success criteria by phase

**Phase 0 (Day 7):** All contracts deployed, no issues  
**Phase 1 (Day 38):** <5% false positive rate, 1+ real violation detected correctly, Silo engaged  
**Phase 2 (Day 38):** Metrics compiled, raise deck ready  
**Phase 3 (Week 10):** $2-4M raised, ZK cofounder hired  

---

## The most important thing

**You are not building a product for today.**

You are building proof that the product works. For 30 days. With one protocol. One invariant. One metric.

Everything else is noise until that's done.

Ship the Guardian. Keep the logs. Get Silo to care. Then raise.

That's the entire plan.
