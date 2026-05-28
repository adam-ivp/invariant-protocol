# IVP Guardian-First Strategy
## START HERE — Your Next 7 Days

You're pivoting from ZK-first to Guardian-first. This means:

**Don't** search for a ZK cofounder right now.  
**Don't** wire SP1 verifier.  
**Don't** tweet about IVP.  
**Don't** email investors.

**Do** prove Guardian works operationally. For 30 days. With one protocol.

---

## Tomorrow (Day 1)

### 1. Read the new strategy document

```
/ivp-v2/GUARDIAN_FIRST_STRATEGY.md
```

This is the bible for the next 30 days. It tells you exactly what to build, deploy, monitor, and log.

### 2. Get the new contracts

```
/ivp-v2/contracts/MockEpochManager.sol       ← NEW
/ivp-v2/contracts/SiloGuardianAdapter.sol    ← NEW
/ivp-v2/contracts/IVPGuardian.sol            (already exists)
/ivp-v2/contracts/IVPGuardianRegistry.sol    (already exists)
/ivp-v2/contracts/IVPEscrow.sol              (already exists)
```

The two new ones are stripped down, no prover complexity. You'll understand them in 10 minutes.

### 3. Check the deploy script

```
/ivp-v2/scripts/deploy-guardian-first.sh
```

This deploys only what you need. Minimal. Clean.

---

## Days 2–4: Silo Outreach

### Find Silo's security team

GitHub: github.com/silo-finance/silo-core (find contributors)  
Twitter: search "silo finance security"  
Discord: silo-finance Discord, #security or #engineering

### Send the email

Use the template:

```
/ivp-v2/SILO_OUTREACH.md
```

Copy-paste, customize slightly, send.

Subject: "Guardian — Runtime Solvency Enforcement for Silo"

Message: "Built a Guardian that monitors solvency invariants and intercepts breach scenarios before they cascade. Live on Base Sepolia. Want to see?"

That's enough.

---

## Days 5–7: Deploy to Base Sepolia

### Prerequisites

```bash
# Install Foundry if you don't have it
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Set your deployer key
export DEPLOYER_KEY=0x...

# Set RPC (optional, default is Base Sepolia)
export RPC_URL=https://sepolia.base.org
```

### Deploy

```bash
cd ivp-v2
bash scripts/deploy-guardian-first.sh
```

That's it. All five contracts deploy. You get addresses.

**Save these addresses.** You'll use them for 30 days.

---

## Days 8–30: Run Guardian

### Start daily monitoring

```bash
node scripts/silo-state-reader.js \
  --rpc https://sepolia.base.org \
  --silo 0x... \
  --oracle 0x... \
  --epochManager 0x... \
  --interval 300
```

This reads Silo state every 5 minutes. Logs to:

```
/logs/guardian-operations.csv
```

### When you see a breach

The script will print: `⚠️ BREACH DETECTED`

Then:

1. Note the time, epoch, solvency ratio
2. Call `finalizeEpochManual()` manually:

```bash
cast send 0xEPOCH_MANAGER \
  'finalizeEpochManual(bool,uint256,uint8,address,uint256,bytes32,string)' \
  true 1 0 0x0000000000000000000000000000000000000000 100000000 0x0000000000000000000000000000000000000000000000000000000000000000 "solvency breach detected"
```

3. Guardian fires, accounts freeze
4. Log the result in CSV

### Daily rhythm (30 days)

```
08:00 — Monitor reads state
09:00 — Check CSV for violations
12:00 — If breach detected, manually trigger Guardian
15:00 — Log the Guardian response
18:00 — Update metrics
22:00 — Review daily summary
```

---

## Day 31: Compile metrics

By day 30, you'll have a CSV with 30 rows. Extract:

```
Total violations: X
False positives: Y (target: <5%)
Guardian response time: Z ms
Accounts frozen: A
Total TVL captured: B
Operational uptime: C%
```

Put these in a summary doc.

---

## If Silo engages

Great. You now have:
1. Working Guardian (running live)
2. One protocol interested
3. 30 days of operational data
4. Proof that Guardian prevents losses

That's enough to raise.

---

## If Silo doesn't respond

Follow up once after 5 days. If still nothing, move to Morpho or Pendle.

The goal isn't Silo specifically. It's **any protocol saying "we'll try this."**

---

## The files you need RIGHT NOW

```
GUARDIAN_FIRST_STRATEGY.md       ← Your roadmap
SILO_OUTREACH.md                 ← Your email template
scripts/deploy-guardian-first.sh  ← Your deployment
scripts/silo-state-reader.js     ← Your monitoring
contracts/MockEpochManager.sol   ← NEW contract
contracts/SiloGuardianAdapter.sol ← NEW contract
GTM.md                           ← Updated strategy (read after deploying)
logs/guardian-operations.csv     ← Your daily log (create Day 1)
```

---

## What success looks like at each milestone

**Day 7:** Guardian deployed, all addresses saved  
**Day 14:** Silo responded (even if "we'll think about it")  
**Day 30:** <5% false positive rate, 1+ real violation caught, log complete  
**Day 38:** Metrics compiled, raise deck ready  

---

## What NOT to do for 30 days

- Don't search for ZK cofounders
- Don't tweet about IVP
- Don't reach out to investors
- Don't over-engineer anything
- Don't build the coverage vault
- Don't write a token spec
- Don't talk to the press
- Don't optimize SP1 integration

Just: deploy, monitor, log, and get Silo interested.

---

## TL;DR

1. **Tomorrow:** Read GUARDIAN_FIRST_STRATEGY.md
2. **Days 2–4:** Email Silo Finance
3. **Days 5–7:** Deploy to Base Sepolia
4. **Days 8–38:** Run Guardian, keep logs
5. **Day 38:** Raise

That's it. That's the plan.

Everything else is secondary.

Go.
