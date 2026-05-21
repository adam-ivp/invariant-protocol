// ISL — Stablecoin CDP Invariants
// Detects ghost shares, undercollateralization, peg breaks

@protocol cdp    = env("CDP_ENGINE")
@protocol oracle = env("PRICE_ORACLE")

@invariant debt_share_accounting
@severity  Solvency
@protocol  cdp

  // Ghost share: full repayment leaves mulDivDown rounding residual
  // totalShares non-zero, totalDebt zero
  // Next borrower gets undervalued shares — existing holders extract value
  @constraint no_ghost_shares
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      implies(total_shares(debt_class) > 0, total_debt(debt_class) > 0)
      implies(total_debt(debt_class) == 0,  total_shares(debt_class) == 0)

  @constraint share_value_non_decreasing
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      implies(
        and(total_shares(debt_class) > 0,
            previously(total_shares(debt_class), 1) > 0),
        mulDiv(total_debt(debt_class), prev_shares(debt_class), 1) >=
        mulDiv(prev_debt(debt_class), total_shares(debt_class), 1)
      )

@invariant global_collateral_ratio
@severity  Solvency
@protocol  cdp

  @constraint system_overcollateralized
    implies(total_debt() > 0,
      total_collateral() * 10000 >= total_debt() * 15000)

@invariant peg_stability
@severity  Peg
@protocol  oracle

  @constraint price_within_band
    and(stablecoin_price() >= 950000, stablecoin_price() <= 1050000)
