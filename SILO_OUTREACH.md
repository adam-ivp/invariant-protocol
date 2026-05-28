# Silo Finance Outreach — Email Template

**Send to:** Silo Finance security team  
**Subject:** Guardian prototype — invariant-based solvency enforcement  
**Tone:** Technical. Not a pitch. Just "we built this, it's live, want to see?"

---

## Email

Subject: **Guardian — Runtime Solvency Enforcement for Silo**

---

Built a runtime Guardian that monitors solvency invariants and intercepts breach scenarios before they cascade.

Started with solvency as the first signal — when global solvency ratio drops below 110% LTV, Guardian fires a callback that:

1. Freezes accounts that are net liquidation-ineligible
2. Pauses withdrawals temporarily  
3. Redirects pending transfers to an escrow

Designed it specifically for isolated lending protocols like Silo.

**Live on Base Sepolia testnet right now.** Happy to:
- Walk through the code
- Run a demo  
- Answer questions about architectural decisions
- Get your feedback on the approach

**GitHub:** github.com/adam-ivp/invariant-protocol  
**Contracts:** Base Sepolia deployment available on request

**Operative spec:**
```
Invariant: solvency_breach
Trigger: (collateral_value * 10000) < (debt_value * 11000)
Response: account freeze + withdrawal pause + escrow redirect
Latency: <1 block
```

Looking for feedback and interest in a 30-day operational test on testnet.

---

Alternatively, if you want to be more casual:

**Subject:** solvency Guardian prototype — Silo testnet demo

Been working on runtime invariant enforcement for lending protocols.

Basically: protocol writes a solvency constraint, we monitor it live, and when it breaches, we automatically freeze accounts + pause withdrawals before a cascade happens.

Built a demo that works on Base Sepolia. Silo's isolated lending model makes it a clean invariant case.

Curious if you'd want to see it / test it.

repo: github.com/adam-ivp/invariant-protocol

---

## After they respond

**If they say "show us":**
- Send them the GitHub link
- Tell them to run the Foundry demo: `forge test --match-test testGuardianDemoFlow -vvvv`
- Give them the testnet addresses

**If they ask "why not just...":**
- "Traditional monitoring alerts after the fact. Guardian acts before. The math can't be gamed."

**If they ask about false positives:**
- "Day 30 of operational testing will answer that. Right now we're being honest: we want to find the edge cases with you before mainnet."

**If they ask about decentralization:**
- "Running centralized for now. Proves value first. Can decentralize the prover later."

**If they ask about cost:**
- "Free testnet. If mainnet happens, we'd price based on TVL like any other service."

---

## Where to find them

**GitHub contributors:**
- Navigate to github.com/silo-finance/silo-core
- Click "Contributors"
- Look for security-related commits
- Follow their GitHub, check their Twitter

**Twitter:**
- Search "silo-finance security"
- Look for mentions of Silo in security research
- Check who's engaged with their posts

**Discord:**
- Join silo-finance Discord
- Find #security or #engineering channel
- Post there as a question: "Who's working on security?"

**Worst case:**
- Email: security@silolend.com (if available)
- Or DM Paul on Twitter: @paulsokolov (Silo founder — might redirect you to security team)

---

## Timeline

**Send:** Tomorrow  
**Follow up if no response:** 5 days later (once)  
**If still no response:** Move to Morpho

The goal is not to close a deal. It's to get one protocol team to say "yeah, we'll try this."

That's enough.
