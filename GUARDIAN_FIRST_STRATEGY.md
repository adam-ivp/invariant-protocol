# IVP Guardian-First Strategy
## Centralized Operational Proof → Raise → Decentralization

**Status:** Pivot from distributed prover + ZK-first to Guardian-first + operational proof  
**Timeline:** 30 days  
**Goal:** One real protocol running Guardian, logged violations, measured value, operational confidence

---

## Phase 1: Guardian Deployment (Days 1–7)

### Contracts to deploy on Base Sepolia

**Stripped down. Minimal scope. No prover complexity yet.**

```
1. IVPGuardian.sol
   - Reference implementation
   - Can be manually triggered by you (admin)
   - Logs all violations to events
   - Implements freeze/pause/redirect

2. IVPGuardianRegistry.sol
   - Maps invariant ID → Guardian address
   - Single protocol per registry initially

3. IVPEscrow.sol
   - Holds frozen funds
   - Protocol admin controls release
   - Two paths only: release to victims OR return to owner

4. MockEpochManager.sol
   - Stub that you manually call with violation proof
   - Does NOT do actual ZK verification
   - You manually trigger: finalizeEpoch() + fireGuardianCallbacks()
   - This is honest — you're proving Guardian works, not proving proofs work

5. TargetProtocol adapter (Silo-specific)
   - Silo's state reader
   - Silo's Guardian callback handler
   - Silo's escrow configuration
```

**What we're NOT deploying yet:**
- SP1 verifier
- Distributed prover network
- Coverage vaults
- Dispute system
- Slashing economics

**Deployment order:**
```bash
# Day 1
forge deploy IVPEscrow --network base_sepolia
forge deploy IVPGuardian --network base_sepolia
forge deploy IVPGuardianRegistry --network base_sepolia

# Day 2
forge deploy MockEpochManager --network base_sepolia

# Day 3
forge deploy SiloGuardianAdapter --network base_sepolia
forge register --guardian 0x... --protocol silo --invariant solvency_breach

# Day 4 — testnet verification
cast call 0x... "getGuardianForInvariant(uint256)(address)" 1
```

### Invariant to start with

**Not five invariants. One.**

`solvency_breach` — global solvency ratio drops below 110% liquidation threshold

Why this one:
- Silo has public state for this (easy to read)
- Clear binary violation (ratio either is or isn't above threshold)
- High operational stakes (actual protocol risk)
- Easy to log and measure

**ISL spec for the invariant:**

```isl
@invariant solvency_breach
@severity  Critical
@protocol  silo

  @constraint global_solvency_above_minimum
    forall collateral_token in ACTIVE_COLLATERALS:
      let total_debt_value = sum(user_debt(token) * oracle_price(token))
      let total_collateral_value = sum(user_collateral(token) * oracle_price(token))
      (total_collateral_value * 10000) >= (total_debt_value * 11000)  // 110%
```

That's it. One constraint. One check. Binary pass/fail.

---

## Phase 2: Silo outreach (Days 2–4)

### Who to contact

**Silo Finance security team.** Not the founder. Find them:
- GitHub contributors: github.com/silo-finance
- Twitter: search "silo finance security" or "silo protocol"
- Discord: silo-finance Discord, security channel

### The message (email or Discord DM)

```
Subject: Guardian prototype — invariant-based solvency enforcement for Silo

Built a runtime Guardian that monitors critical protocol invariants
and intercepts breach scenarios before they cascade.

Started with solvency as the first signal — when global solvency ratio
drops below 110% threshold, Guardian fires a callback that:

1. Freezes accounts that are net liquidation-ineligible
2. Pauses withdrawals temporarily
3. Redirects pending transfers to an escrow

Designed it specifically for isolated lending protocols like Silo.

Live on Base Sepolia testnet right now. Happy to:
- Walk through the code
- Run a demo
- Answer questions about architectural decisions

GitHub: github.com/adam-ivp/invariant-protocol
Playground: [your Netlify URL]

Looking for feedback and a 30-day operational test. Interest?
```

**Tone:** Not a sales pitch. Not a partnership ask. "We built this, it's live, want to look?"

### Expected response

Good response: "Interesting, let's see the code" or "We've been thinking about this"

Bad response: Silence or "Send deck"

If silence after 5 days, follow up once. If still no response, move to Morpho.

---

## Phase 3: Live operation (Days 8–30)

### Daily operational checklist

**Every day for 30 days:**

```
[ ] 08:00 — Check Base Sepolia RPC for new blocks
[ ] 09:00 — Query MockEpochManager for current epoch
[ ] 10:00 — Read Silo state: total debt, total collateral, solvency ratio
[ ] 12:00 — Log to operational journal: solvency ratio at time T
[ ] 18:00 — Review daily violations: any threshold breaches?
[ ] 20:00 — If breach detected: manually trigger Guardian, log response
[ ] 22:00 — Update metrics dashboard
```

### Operational logging (daily, in a git-tracked spreadsheet)

Create `/logs/guardian-operations.csv`:

```csv
date,time,epoch,solvency_ratio,breach_detected,guardian_fired,accounts_frozen,escrow_balance,false_positive,notes
2026-05-28,08:15,4821,112.5%,no,no,0,0,no,baseline healthy
2026-05-28,14:32,4821,111.8%,no,no,0,0,no,minor volatility
2026-05-29,09:44,4822,109.2%,yes,yes,3,2500000,no,"oracle spike — correctly detected and contained"
2026-05-29,11:20,4822,110.5%,no,no,3,2500000,no,"recovered after rebalancing — Guardian held"
2026-05-30,16:33,4823,111.1%,no,no,0,0,no,"frozen accounts unfrozen by protocol admin"
```

**Columns that matter:**

- `breach_detected` — did the invariant trigger?
- `guardian_fired` — did your callback execute?
- `false_positive` — was the breach actually valid or a calculation error?
- `accounts_frozen` — how many addresses were frozen?
- `escrow_balance` — how much TVL did Guardian capture?
- `notes` — what actually happened?

**Why this format:**

Spreadsheets are honest. They show you patterns. By day 20, you'll see:
- False positive rate (should be <5%)
- Average response time (should be <1 block)
- How often does solvency actually breach? (critical question)
- What's the escrow capture rate? (% of losses prevented)

That data is worth more than any technical writeup.

---

## Phase 4: Metrics to track (30-day report)

**By day 30, you need these numbers:**

```
OPERATIONAL METRICS
├─ Violations detected: X
├─ False positives: Y (aim for <5%)
├─ Guardian response time: Z ms
├─ Total accounts frozen: A
├─ Total TVL captured: B
├─ Unfreeze speed (after protocol validation): C hours
└─ Operational uptime: D%

PROTOCOL IMPACT
├─ Estimated losses prevented: E (USD)
├─ Insurance premium reduction potential: F%
├─ User trust signal: G (qualitative)
└─ Protocol team feedback: H (direct quote)

TECHNICAL STABILITY
├─ Contract bugs found: I
├─ Guardian callback failures: J
├─ State sync failures: K
└─ Oracle read errors: L

BUSINESS SIGNALS
├─ Silo (or partner) statement of support: Y/N
├─ LOI or commitment to production test: Y/N
├─ Other protocols requesting demos: X
└─ Investor meetings requested: Y/N
```

**This becomes your raise deck.**

Not "here's our whitepaper."

**"Here's 30 days of live operational data showing Guardian prevented $X in losses with <5% false positive rate. We want $2-4M to wire SP1 proof infrastructure and ship mainnet. Here's Silo's endorsement."**

That lands different.

---

## Phase 5: What happens after 30 days

### Decision tree

```
IF solvency_breach invariant had < 3 real violations:
  → Invariant was too conservative
  → Loosen threshold or add more invariants
  → 15 more days of operation

IF false_positive_rate > 10%:
  → Guardian is too trigger-happy
  → Protocol admin feedback is critical
  → Refine logic or implement dispute window
  → 15 more days

IF false_positive_rate < 5% AND violations detected > 0 AND Silo engaged:
  → You have proof of concept
  → You have a willing protocol
  → You have operational data
  → Time to raise
  → Hire ZK cofounder
  → Build SP1 verifier + distributed infrastructure

IF false_positive_rate < 5% AND no violations BUT Silo still engaged:
  → You have a working system
  → Just hasn't been stress-tested
  → Deploy 60 more days OR
  → Raise and build ZK layer
  → Let distributed provers stress-test in testnet
```

---

## What you DO NOT do for 30 days

❌ Don't tweet about IVP  
❌ Don't reach out to investors  
❌ Don't write a token spec  
❌ Don't hire the ZK cofounder yet  
❌ Don't apply to accelerators  
❌ Don't build the coverage vault  
❌ Don't build the dispute system  
❌ Don't optimize SP1 integration  
❌ Don't talk about decentralization  

**Your job:** Keep Guardian working. Log everything. Build trust with Silo.

---

## The repo changes needed right now

**Add to `/contracts`:**
```
MockEpochManager.sol ← manually triggered, no proving
SiloGuardianAdapter.sol ← Silo-specific state reader + callback handler
BaseGuardianAdapter.sol ← template for future protocols
```

**Add to `/scripts`:**
```
deploy-base-sepolia.sh ← deploys only Guardian + Registry + Escrow
manual-epoch-trigger.sh ← you manually call this when you log a violation
silo-state-reader.js ← reads Silo's solvency ratio from RPC
```

**Add to `/logs`:**
```
guardian-operations.csv ← daily operational journal
guardian-metrics.json ← daily aggregated metrics
violations-log.json ← detailed per-violation records
```

---

## Why this is smarter than the ZK path right now

1. **Removes technical blocker** — no SP1 cofounder search, no 2-month ZK integration
2. **Proves market fit first** — data beats thesis every time
3. **De-risks false positives** — you discover the hard operational problems manually before automating
4. **Builds protocol relationships** — Silo sees you're serious by deploying and running the system
5. **Shortens raise conversation** — "here's 30 days of operational data" closes faster than "here's our vision"
6. **Can still decentralize later** — nothing you build here prevents SP1 integration in month 2 post-raise

---

## The next 24 hours

**Tomorrow:**

1. Review the one-constraint solvency invariant spec
2. Create `/logs/guardian-operations.csv` with headers
3. Write the Silo outreach email
4. Start the Base Sepolia deployment checklist
5. Find a Silo security team member on GitHub or Discord

**The message that starts it all:**

"We built a runtime Guardian that caught solvency breaches. It's live on testnet. Want to see?"

That's enough.

---

## Success looks like (end of 30 days)

- Guardian running live for 30 days with <5% false positive rate
- At least one real solvency breach detected and correctly intercepted
- Silo Finance team has seen it, tested it, given feedback
- You have a spreadsheet of operational metrics
- You have a quote from Silo's security lead: "This would have caught the scenarios we worry about"
- You're ready to raise on that data

That's it. That's the whole play.

Everything else is secondary.
