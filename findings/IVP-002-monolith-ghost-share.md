# IVP-002: Ghost Share Residual in Monolith Stablecoin Factory Paid Debt Path

**Protocol:** Monolith Stablecoin Factory  
**Severity:** Critical  
**Status:** Reported to Monolith dev team pre-launch · Sherlock bounty #287  
**Bounty potential:** $20,000  
**Discovery:** Week 1, pre-IVP deployment  
**Category:** Incomplete fix propagation — patch applied to one code path, not its mirror

---

## Summary

A critical bug was identified and fixed in the `increaseDebt` free debt path (commit 952e3c5). The fix was not applied to the paid debt path. The two paths are structurally mirrored but diverge in handling the zero-debt, non-zero-shares edge case. After a full repayment of paid debt, `mulDivDown` rounding leaves `totalPaidDebt` at zero while `totalPaidDebtShares` remains non-zero. The next borrower to take on paid debt enters the wrong branch, receives undervalued shares, and transfers value to existing shareholders. No attack required — the condition triggers through normal usage.

---

## Background: Free vs Paid Debt

Monolith's stablecoin factory separates borrower debt into two categories:

- **Free debt**: zero-interest borrowing, typically protocol-subsidized
- **Paid debt**: interest-bearing borrowing, priced per epoch

Both paths use a share-based accounting model: borrowers receive shares proportional to their debt contribution, and the share-to-debt ratio accrues over time. This is standard vault accounting — the same model used by Yearn, ERC-4626, and most yield-bearing DeFi systems.

The critical property of share accounting: **if total shares is non-zero, total assets must also be non-zero.** The inverse — shares exist but no assets — means the next depositor gets an incorrect share price.

---

## Root Cause

The original bug was in the free debt share issuance logic:

```solidity
// BEFORE fix (vulnerable free debt path)
function _issueFreeDeptShares(uint256 debt) internal returns (uint256 shares) {
    if (totalFreeDebtShares == 0) {
        shares = debt; // 1:1 on first borrow
    } else {
        shares = mulDivDown(debt, totalFreeDebtShares, totalFreeDebt);
        // If totalFreeDebt == 0 but totalFreeDebtShares != 0:
        // mulDivDown produces 0 shares for non-zero debt
        // or division by zero — either way, accounting error
    }
}
```

The fix applied in commit 952e3c5:

```solidity
// AFTER fix (free debt path — CORRECT)
function _issueFreeDeptShares(uint256 debt) internal returns (uint256 shares) {
    if (totalFreeDebtShares == 0 || totalFreeDebt == 0) {
        shares = debt; // 1:1 if no existing shares OR no existing debt
    } else {
        shares = mulDivDown(debt, totalFreeDebtShares, totalFreeDebt);
    }
}
```

The fix adds `|| totalFreeDebt == 0` — if debt is zero but shares exist (the residual state), treat it as a fresh start.

**The paid debt path was not updated:**

```solidity
// Paid debt path — NOT FIXED (vulnerable)
function _issuePaidDeptShares(uint256 debt) internal returns (uint256 shares) {
    if (totalPaidDebtShares == 0) {
        shares = debt; // only checks shares, not debt
    } else {
        shares = mulDivDown(debt, totalPaidDebtShares, totalPaidDebt);
        // totalPaidDebt can be 0 here — mulDivDown rounds down
        // result: 0 shares issued for non-zero debt
        // OR: existing shareholders extract value from next borrower
    }
}
```

---

## Trigger Condition

The ghost share state is produced through normal repayment:

1. Borrower A takes on 100 units of paid debt → receives 100 shares. `totalPaidDebt = 100`, `totalPaidDebtShares = 100`.
2. Interest accrues. `totalPaidDebt = 110`, `totalPaidDebtShares = 100`.
3. Borrower A repays all paid debt.
4. Repayment burns shares proportionally: `sharesToBurn = mulDivDown(repayAmount, totalPaidDebtShares, totalPaidDebt)`.
5. With `repayAmount = 110`, `totalPaidDebtShares = 100`, `totalPaidDebt = 110`: `sharesToBurn = mulDivDown(110, 100, 110) = 99` (rounds down).
6. Result: `totalPaidDebt = 0`, `totalPaidDebtShares = 1`. **Ghost share.**

---

## Exploitation

No active exploitation required. The next borrower triggers the incorrect path:

```solidity
// State: totalPaidDebt = 0, totalPaidDebtShares = 1
// Borrower B takes on 100 units of paid debt:

shares = mulDivDown(100, 1, 0); // division by zero OR:
// if totalPaidDebt was 1 due to rounding: mulDivDown(100, 1, 1) = 100 shares
// but existing 1 share is now worth 100 units of debt
// → Borrower A's residual share extracts 99% of Borrower B's debt
```

The value extraction is proportional to the ghost share residual. In a high-volume protocol with many borrow/repay cycles, residuals accumulate.

---

## Recommended Fix

Mirror the free debt fix exactly:

```solidity
function _issuePaidDeptShares(uint256 debt) internal returns (uint256 shares) {
    if (totalPaidDebtShares == 0 || totalPaidDebt == 0) {
        shares = debt;
    } else {
        shares = mulDivDown(debt, totalPaidDebtShares, totalPaidDebt);
    }
}
```

Five lines. Identical to the existing fix. The asymmetry is purely an oversight in fix propagation.

---

## IVP Invariant

Encoded in `invariant-library/stablecoin/generic-cdp.isl` as `debt_share_accounting`:

```
@constraint shares_and_debt_consistent
  forall debt_class in [FREE_DEBT, PAID_DEBT]:
    let total_shares = field(cdp_engine, total_shares_slot(debt_class))
    let total_debt   = field(cdp_engine, total_debt_slot(debt_class))

    implies(total_shares > 0, total_debt > 0)
    implies(total_debt == 0,  total_shares == 0)

@constraint mulDiv_rounding_residual_zero
  forall debt_class in [FREE_DEBT, PAID_DEBT]:
    let prev_debt   = previously(field(cdp_engine, total_debt_slot(debt_class)), 1)
    let curr_debt   = field(cdp_engine, total_debt_slot(debt_class))
    let curr_shares = field(cdp_engine, total_shares_slot(debt_class))

    implies(
      and(prev_debt > 0, curr_debt == 0),
      curr_shares == 0
    )
```

The second constraint fires specifically on the epoch where debt transitions from non-zero to zero with a non-zero share residual remaining — the exact trigger condition.

---

## Hunting pattern

This finding exemplifies **incomplete fix propagation**: a patch applied to one code path that has a structural mirror. The free debt and paid debt paths are nearly identical — same accounting model, same share issuance logic, same repayment mechanism. A fix that addresses the invariant in one must be applied to the other.

The general form: whenever a codebase has mirrored execution paths (free/paid, stable/variable, normal/emergency), any fix to one path should immediately prompt the question: *does the other path have the same vulnerability?*

---

*IVP-002 · Invariant Protocol · invariantprotocol.xyz*
