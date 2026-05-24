// ISL — mulDiv Rounding Conservation
// The constraint class that catches hundreds of millions in DeFi losses.
//
// Every share-based accounting system in DeFi has the same vulnerability:
// mulDivDown rounding leaves a residual when debt goes to zero.
// totalShares stays non-zero. totalDebt hits zero.
// Next borrower enters the wrong branch. Existing holders extract value.
//
// Eight lines. Every lending protocol. Every CDP. Every yield vault.

@protocol lending = env("LENDING_POOL")

@invariant mulDiv_rounding_conservation
@severity  Solvency
@protocol  lending

  // After full repayment: debt zero means shares must be zero
  @constraint repayment_convergence
    forall debt_class in DEBT_CLASSES:
      let debt_prev  = previously(total_debt(debt_class), 1)
      let debt_now   = total_debt(debt_class)
      let shares_now = total_shares(debt_class)
      implies(
        and(debt_prev > 0, debt_now == 0),
        shares_now == 0
      )

  // Share value must never decrease epoch-over-epoch
  @constraint share_value_non_decreasing
    forall debt_class in DEBT_CLASSES:
      let shares_now  = total_shares(debt_class)
      let debt_now    = total_debt(debt_class)
      let shares_prev = previously(total_shares(debt_class), 1)
      let debt_prev   = previously(total_debt(debt_class), 1)
      implies(
        and(shares_now > 0, shares_prev > 0, debt_prev > 0),
        mulDiv(debt_now, shares_prev, 1) >= mulDiv(debt_prev, shares_now, 1)
      )

  // Ghost share impossibility: shares exist iff debt exists
  @constraint ghost_share_impossibility
    forall debt_class in DEBT_CLASSES:
      let shares = total_shares(debt_class)
      let debt   = total_debt(debt_class)
      implies(shares > 0, debt > 0)
      implies(debt == 0, shares == 0)

  // New borrower share fairness: cannot receive undervalued shares
  @constraint new_borrower_share_fairness
    forall debt_class in DEBT_CLASSES:
      let shares_before = previously(total_shares(debt_class), 0)
      let debt_before   = previously(total_debt(debt_class), 0)
      let shares_after  = total_shares(debt_class)
      let debt_after    = total_debt(debt_class)
      let new_shares    = shares_after - shares_before
      let new_debt      = debt_after - debt_before
      implies(
        and(new_debt > 0, debt_before > 0, shares_before > 0),
        abs_diff(
          mulDiv(new_shares, debt_before, 1),
          mulDiv(new_debt, shares_before, 1)
        ) <= debt_before
      )
