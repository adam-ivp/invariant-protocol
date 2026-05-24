# SpotChecker: Cryptographic Collusion Resistance

## The problem

Every ZK prover network faces the same attack: a prover assigned to monitor a protocol colludes with that protocol to suppress violation reports. The prover absorbs slashes. The protocol conceals the exploit. Both profit.

Tiered slashing and anomaly tracking raise the cost. They do not eliminate it.

## The core insight

You cannot collude with someone you do not know exists.

If the primary prover does not know whether a spot-checker is watching their epoch, they cannot coordinate with the protocol to suppress a violation — because suppression requires knowing you will not be caught, and the SpotChecker makes that unknowable.

## The mechanism

### Epoch selection

With 10% probability per epoch, a spot-check is triggered:

    roll = keccak256(spotCheckSeed || epoch || blockhash(block.number - 1))
    isSpotCheck = uint256(roll) % 10000 < SPOT_CHECK_RATE_BPS

spotCheckSeed is a private value. Never on-chain. Rotates every 7 epochs.

The primary prover cannot predict which epochs are checked. Cannot reduce P(spotted) to zero. Cannot bribe a checker they cannot identify.

### Commit-before-reveal

The checker commits a hash of their proof before the primary reveals:

    checkerCommit = keccak256(abi.encode(proof, checker, epoch))

This prevents the checker from copying the primary's answer. The checker's proof is locked before they see the primary's result.

### Resolution

| Scenario | Result |
|----------|--------|
| Both clean | Both rewarded |
| Both find violation | Both rewarded |
| Primary clean, checker finds violation | Primary slashed 10,000 IVP |
| Primary finds violation, checker clean | Checker slashed |
| State roots differ | Both jailed pending review |

## The game theory

Without SpotChecker, collusion is a pure economic calculation. At high TVL, bribe > slash. Collusion is rational.

With SpotChecker:

    E[collude] = P(no spot-check) * E[economic gain]
               + P(spot-check) * (-COLLUSION_SLASH - reputation - jail)

P(spot-check) = 0.10, uncontrollable by the prover.

A prover who colludes across 100 epochs expects to be caught ~10 times. Each catch: 10,000 IVP slashed, reputation destroyed, jailed.

The information asymmetry is the mechanism. The prover sees the payoff matrix but not the current state. That uncertainty is what makes collusion irrational at scale.

## What SpotChecker does NOT guarantee

It does not eliminate collusion. At very high TVL a prover may still find collusion economically rational despite a 10% catch rate.

The full solution requires SpotChecker + slashing + anomaly tracking + watchdog markets + public replay bounties. SpotChecker is one layer. We say this out loud.

## The one-line summary

The SpotChecker makes prover-protocol collusion a game played under uncertainty against an opponent the prover cannot identify, in an epoch the prover cannot predict, with a commitment they cannot retract.

---

*SpotChecker Cryptographic Design · Invariant Protocol*
