# SpotChecker: Cryptographic Collusion Resistance

## The problem with economic incentives alone

Every ZK prover network faces the same attack: a prover assigned to monitor a protocol colludes with that protocol to suppress violation reports. The prover absorbs slashes. The protocol conceals the exploit. Both profit.

Tiered slashing, reputation scoring, and anomaly tracking all raise the cost of collusion. None of them eliminate it. At sufficient TVL, the expected profit from concealment exceeds any finite slash amount.

This is not a flaw in IVP's design. It's a fundamental limit of purely economic deterrence.

The SpotChecker is the cryptographic layer on top of the economic layer.

---

## The core insight

**You cannot collude with someone you don't know exists.**

If the primary prover doesn't know whether a spot-checker is watching their epoch, they cannot coordinate with the protocol to suppress a violation — because suppression requires knowing you won't be caught, and the SpotChecker makes that unknowable.

This shifts the attack from an economic calculation to a cryptographic one. The prover must now collude despite uncertainty. The expected cost of collusion goes up. The viable TVL threshold for profitable collusion goes up with it.

---

## The mechanism

### Epoch selection

With probability `SPOT_CHECK_RATE_BPS / 10000` (currently 10%), an epoch is designated as a spot-check epoch. The selection is determined by:

```
roll = keccak256(spotCheckSeed || epoch || blockhash(block.number - 1))
isSpotCheck = uint256(roll) % 10000 < SPOT_CHECK_RATE_BPS
```

`spotCheckSeed` is a private value held by the SpotChecker contract owner. It rotates every `SEED_ROTATION_EPOCHS` (7) epochs. It is never revealed on-chain.

**Critical property:** The primary prover cannot predict which epochs are spot-checked. The seed is private. Even if the prover monitors the chain for the `SpotCheckScheduled` event, the event only emits a commitment to the checker's identity — not whether a given epoch is being checked.

### Checker assignment

When a spot-check epoch is selected, a checker is assigned using a different derivation from the same seed:

```
checkerSeed = keccak256(spotCheckSeed || epoch || "checker")
checker = activeProvers[checkerSeed % activeProverCount]
// excluding primary prover
```

The checker is selected independently of the primary. Neither prover knows the other's assignment.

### Identity commitment

The checker's identity is committed on-chain before the primary reveals:

```
salt = keccak256(spotCheckSeed || epoch || checker)
commitment = keccak256(checker || epoch || salt)
```

This commitment is posted when the spot-check epoch opens. The checker's actual address is not revealed until after both proofs are submitted and the finality window closes.

**Critical property:** The primary prover sees the commitment but cannot derive the checker's identity from it without knowing the private seed. The commitment is a one-way function.

### Commit-before-reveal

The checker must commit a hash of their proof before the primary reveals:

```
checkerCommit = keccak256(abi.encode(proof, checker, epoch))
```

This prevents the checker from copying the primary's answer after the primary reveals. The checker's proof is locked in before they can see the primary's result.

**Critical property:** If the checker could wait for the primary to reveal, a colluding checker could simply echo the primary's output. The commit-before-reveal eliminates this.

### Resolution

After the primary reveals, the checker has `CHECKER_SUBMIT_WINDOW` (100) blocks to reveal their independent proof. The resolution logic:

| Scenario | Result |
|----------|--------|
| Primary clean, checker clean | Both rewarded (1.5x base for checker) |
| Primary violated, checker violated | Both rewarded |
| Primary clean, checker violated | Primary slashed (`COLLUSION_SLASH = 10,000 IVP`) |
| Primary violated, checker clean | Checker slashed (missed violation) |
| State roots differ, same violation count | Both jailed pending review |
| Checker no-show | Checker slashed for missed reveal |

---

## The game theory

### Without SpotChecker

Primary prover decides whether to suppress a violation based on:

```
E[collude] = P(caught) × slash_amount - P(not caught) × (bribe + slash_avoided)
```

With only economic deterrence:
- `P(caught)` is low (depends on reputation tracking catching statistical anomalies)
- `slash_amount` is finite and known
- At high TVL: `bribe >> slash_amount` → collusion is rational

### With SpotChecker

The primary prover now faces:

```
E[collude] = P(no spot-check) × E[economic_collude]
           + P(spot-check) × (−COLLUSION_SLASH − reputation_loss − jail)
```

Where `P(spot-check) = 0.10` and is **uncontrollable** by the prover.

The prover cannot reduce `P(spot-check)` to zero. They cannot bribe the checker because they don't know who the checker is. They cannot observe whether a spot-check is happening until it's too late.

**The expected cost of collusion is now:**

```
E[cost] = 0.10 × (COLLUSION_SLASH + reputation_loss + jail_cost)
        + 0.90 × 0  // (if collusion goes undetected in non-check epochs)
```

At 10% check rate, a prover who colludes across 100 epochs expects to be caught ~10 times. Each catch: 10,000 IVP slashed, reputation destroyed, jailed.

### The asymmetry

The prover knows:
- The check rate (10%)
- The collusion slash (10,000 IVP)
- That they cannot predict check epochs
- That they cannot identify the checker

The prover does NOT know:
- Whether the current epoch is a spot-check
- Who the checker is
- Whether the checker has already committed

This information asymmetry is the mechanism. The prover is playing a game where they can see the payoff matrix but not the current state. That uncertainty is what makes collusion irrational at scale.

---

## Seed rotation

The private seed rotates every 7 epochs. This means:

1. Even if a prover somehow infers information about the seed from observed behavior, that information expires in ~7 epochs
2. The rotation is on-chain but the new seed value is off-chain — only the seed hash is stored
3. An adversary who compromises one seed cannot predict future check epochs

The rotation cadence (7 epochs) is chosen to be:
- Short enough that a compromised seed causes limited damage
- Long enough that rotation overhead doesn't dominate gas costs

---

## What SpotChecker does NOT guarantee

**It does not eliminate collusion.** A prover who is willing to absorb expected slashes can still collude — they simply accept a 10% chance of being caught each epoch. At very high TVL, even a 10% expected catch rate may be economically rational.

**It does not handle checker-prover collusion.** If the primary and checker are operated by the same entity, the commitment scheme still prevents the checker from copying the primary's answer (commit-before-reveal) — but it cannot prevent them from submitting coordinated false results. This is why the checker is selected independently and cannot be predicted by the primary.

**The full solution requires:**
- SpotChecker (cryptographic uncertainty layer) ← this
- Tiered slashing (economic deterrence) ← EpochManager
- Anomaly tracking (statistical detection) ← ProverRegistry
- Watchdog markets (third-party incentivized monitoring) ← future
- Public replay bounties (crowd-sourced violation detection) ← future

SpotChecker is one layer of a defense-in-depth model. It is not a complete solution. We say this out loud.

---

## Implementation reference

```solidity
// Epoch selection — cannot be predicted without private seed
bytes32 roll = keccak256(abi.encode(spotCheckSeed, epoch, blockhash(block.number - 1)));
bool isSpotCheck = uint256(roll) % 10000 < SPOT_CHECK_RATE_BPS;

// Checker commitment — identity hidden until resolution
bytes32 salt = keccak256(abi.encode(spotCheckSeed, epoch, checker));
bytes32 commitment = keccak256(abi.encode(checker, epoch, salt));
emit SpotCheckScheduled(epoch, commitment); // checker identity NOT revealed

// Commit-before-reveal — checker cannot copy primary
bytes32 checkerCommit = keccak256(abi.encode(proof, msg.sender, epoch));
// checker submits this BEFORE primary reveals
// after primary reveals, checker submits full proof
// contract verifies: keccak256(proof, checker, epoch) == checkerCommit
```

---

## The one-line summary

The SpotChecker makes prover-protocol collusion a game played under uncertainty against an opponent the prover cannot identify, in an epoch the prover cannot predict, with a commitment they cannot retract.

That's the mechanism. That's the moat.

---

*SpotChecker Cryptographic Design · Invariant Protocol*  
*invariantprotocol.xyz*
