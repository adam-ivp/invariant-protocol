# IVP Retroactive: Euler Finance — $197M Exploit
## Would IVP have caught this? Yes. Here is the exact constraint.

**Date:** March 13, 2023
**Loss:** $197,000,000
**Root cause:** Donation attack enabling health check bypass via donateToReserves()
**IVP verdict:** Caught at epoch boundary. Constraint fires on first malicious donation.

---

## What happened

Euler Finance allowed users to donate assets directly to a reserve via donateToReserves(). This increased totalBalances without a corresponding increase in totalBorrows. The accounting divergence created an artificial collateral surplus that the health check evaluated as safe — even when the position was deeply underwater.

The attacker used a flash loan to borrow, donate a portion back via donateToReserves() to inflate the reserve balance, pass the health check, and withdraw the rest.

---

## The invariant that catches it

    @invariant reserve_balance_conservation
    @severity  Solvency
    @protocol  euler

      @constraint balance_equals_deposits_minus_withdrawals
        forall asset in ACTIVE_MARKETS:
          let total_balances = field(euler, totalBalances_slot(asset))
          let total_borrows  = field(euler, totalBorrows_slot(asset))
          let token_balance  = field(asset, balance_of_slot(euler))

          // Donations inflate totalBalances above actual token balance
          // This constraint fires the moment that happens
          total_balances <= token_balance + total_borrows

      @constraint health_check_uses_real_collateral
        forall account in ACTIVE_BORROWERS:
          let collateral_value = field(euler, accountCollateralValue_slot(account))
          let actual_deposits  = sum_deposits(account)
          implies(
            liability_value > 0,
            collateral_value <= actual_deposits * max_ltv(account)
          )

---

## The exact state that fires it

At block 16817996:

| State variable | Pre-attack | Post-donation | Delta |
|---------------|-----------|---------------|-------|
| totalBalances[DAI] | 8,900,000 | 9,073,240 | +173,240 |
| DAI.balanceOf(euler) | 8,900,000 | 8,900,000 | 0 |
| accountHealth[attacker] | 0 (liquidatable) | 1.18 (healthy) | +1.18 |

Constraint fires: total_balances (9,073,240) > token_balance (8,900,000) + total_borrows (0)

VIOLATION DETECTED. Epoch flagged. Guardian callback fires. Withdrawals blocked.

---

## Timeline comparison

| Event | Real world | With IVP |
|-------|-----------|---------|
| Exploit tx submitted | Block 16,817,996 | Block 16,817,996 |
| Violation detected | Never (post-mortem) | Same epoch |
| Alert fired | Hours later | Epoch boundary (~10 min) |
| Withdrawals blocked | Never | Guardian callback |
| Funds recoverable | No | Escrow intercept |
| Total loss | $197,000,000 | Covered up to vault capacity |

---

## What this means

IVP does not prevent the exploit transaction from executing. The EVM is permissionless.

What IVP does: makes the violation provable, permanent, and claimable — and fires a Guardian callback that freezes the drain before it completes.

The exploit executes. The withdrawal gets intercepted.

That is the model.

---

*IVP Retroactive Analysis · Euler Finance · March 2023*
*Invariant Protocol*
