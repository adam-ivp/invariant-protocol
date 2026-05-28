// invariant-library/stablecoin/generic-cdp.isl
// Generic CDP stablecoin invariants.
// Covers collateral ratio, peg bounds, debt share accounting,
// liquidation threshold enforcement, and emergency circuit breakers.

@protocol cdp_engine    = env("CDP_ENGINE")
@protocol price_oracle  = env("PRICE_ORACLE")
@protocol stability_pool = env("STABILITY_POOL")

// ============================================================================
// INVARIANT 1: Global Collateral Ratio
// System-wide CR must exceed minimum at all times.
// Breach means the stablecoin is undercollateralized — critical.
// ============================================================================

@invariant global_collateral_ratio
@severity  Solvency

  let MIN_GLOBAL_CR_BPS = 15000  // 150% minimum

  @constraint system_overcollateralized
    let total_collateral_usd = field(cdp_engine, total_collateral_slot())
    let total_debt_usd       = field(cdp_engine, total_debt_slot())

    implies(
      total_debt_usd > 0,
      total_collateral_usd * 10000 >= total_debt_usd * MIN_GLOBAL_CR_BPS
    )

  @constraint cr_not_decreasing_above_threshold
    let current_cr  = mulDiv(field(cdp_engine, total_collateral_slot()), 10000, field(cdp_engine, total_debt_slot()))
    let previous_cr = previously(mulDiv(field(cdp_engine, total_collateral_slot()), 10000, field(cdp_engine, total_debt_slot())), 1)

    implies(
      current_cr < 20000,  // only enforce when CR < 200% (approaching danger zone)
      current_cr >= previous_cr - 500  // CR cannot drop more than 5% per epoch
    )

// ============================================================================
// INVARIANT 2: Debt Share Accounting (Ghost Share Pattern)
// When total shares > 0 but total debt = 0, new borrowers get undervalued shares.
// Existing shareholders profit at next borrower's expense.
// Catches the rounding residual pattern.
// ============================================================================

@invariant debt_share_accounting
@severity  Solvency

  @constraint shares_and_debt_consistent
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      let total_shares = field(cdp_engine, total_shares_slot(debt_class))
      let total_debt   = field(cdp_engine, total_debt_slot(debt_class))

      // If shares exist, debt must exist
      implies(total_shares > 0, total_debt > 0)

      // Equivalently: if debt is zero, shares must be zero
      implies(total_debt == 0, total_shares == 0)

  @constraint share_value_non_decreasing
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      let total_shares  = field(cdp_engine, total_shares_slot(debt_class))
      let total_debt    = field(cdp_engine, total_debt_slot(debt_class))
      let prev_shares   = previously(field(cdp_engine, total_shares_slot(debt_class)), 1)
      let prev_debt     = previously(field(cdp_engine, total_debt_slot(debt_class)), 1)

      implies(
        and(total_shares > 0, prev_shares > 0),
        // share value (debt/shares) must not decrease
        // total_debt / total_shares >= prev_debt / prev_shares
        // cross-multiply: total_debt * prev_shares >= prev_debt * total_shares
        mulDiv(total_debt, prev_shares, 1) >= mulDiv(prev_debt, total_shares, 1)
      )

  @constraint mulDiv_rounding_residual_zero
    forall debt_class in [FREE_DEBT, PAID_DEBT]:
      // After a full repayment (debt goes to 0), shares must also be zero.
      // This is the exact ghost share bug: mulDivDown leaves shares non-zero.
      let prev_debt   = previously(field(cdp_engine, total_debt_slot(debt_class)), 1)
      let curr_debt   = field(cdp_engine, total_debt_slot(debt_class))
      let curr_shares = field(cdp_engine, total_shares_slot(debt_class))

      implies(
        and(prev_debt > 0, curr_debt == 0),
        curr_shares == 0
      )

// ============================================================================
// INVARIANT 3: Peg Stability
// Stablecoin price must remain within acceptable bounds around $1.
// ============================================================================

@invariant peg_stability
@severity  Peg

  let PEG_TARGET     = 1_000_000   // $1.00 in 6-decimal terms
  let MAX_DEVIATION  = 50_000      // $0.05 — 5% max deviation

  @constraint price_within_peg_band
    let stablecoin_price = field(price_oracle, price_slot(env("STABLECOIN_ADDR")))

    and(
      stablecoin_price >= PEG_TARGET - MAX_DEVIATION,
      stablecoin_price <= PEG_TARGET + MAX_DEVIATION
    )

  @constraint peg_not_breached_multiple_epochs
    let stablecoin_price = field(price_oracle, price_slot(env("STABLECOIN_ADDR")))

    // If peg was already breached last epoch, must not still be breached
    // (forces emergency action within one epoch window)
    implies(
      previously(
        or(
          field(price_oracle, price_slot(env("STABLECOIN_ADDR"))) < PEG_TARGET - MAX_DEVIATION,
          field(price_oracle, price_slot(env("STABLECOIN_ADDR"))) > PEG_TARGET + MAX_DEVIATION
        ),
        1
      ),
      and(
        stablecoin_price >= PEG_TARGET - MAX_DEVIATION * 2,  // allow wider band in recovery
        stablecoin_price <= PEG_TARGET + MAX_DEVIATION * 2
      )
    )

// ============================================================================
// INVARIANT 4: Liquidation Threshold Enforcement
// Underwater vaults must be eligible for liquidation.
// Vaults with CR below liquidation threshold must not be allowed new borrows.
// ============================================================================

@invariant liquidation_threshold_enforced
@severity  Solvency

  let LIQ_THRESHOLD_BPS = 13000  // 130%

  @constraint underwater_vaults_not_borrowing
    forall vault_id in ACTIVE_VAULTS:
      let vault_cr = field(cdp_engine, vault_cr_slot(vault_id))

      implies(
        vault_cr < LIQ_THRESHOLD_BPS,
        field(cdp_engine, vault_new_borrow_epoch_slot(vault_id)) < current_epoch()
      )

  @constraint vault_cr_above_minimum
    forall vault_id in ACTIVE_VAULTS:
      let vault_collateral = field(cdp_engine, vault_collateral_slot(vault_id))
      let vault_debt       = field(cdp_engine, vault_debt_slot(vault_id))
      let collateral_price = field(price_oracle, price_slot(vault_collateral_asset(vault_id)))

      let vault_cr = mulDiv(
        vault_collateral * collateral_price,
        10000,
        vault_debt
      )

      implies(vault_debt > 0, vault_cr >= LIQ_THRESHOLD_BPS)

// ============================================================================
// INVARIANT 5: Stability Pool Solvency
// Stability pool must have enough funds to absorb liquidations.
// Pool depletion with active underwater vaults = systemic failure.
// ============================================================================

@invariant stability_pool_solvency
@severity  Liquidity

  @constraint pool_can_cover_underwater_vaults
    let pool_balance        = field(stability_pool, total_deposits_slot())
    let total_underwater_debt = sum(vault_id in UNDERWATER_VAULTS: field(cdp_engine, vault_debt_slot(vault_id)))

    pool_balance >= total_underwater_debt

  @constraint pool_not_draining_without_liquidations
    let current_pool = field(stability_pool, total_deposits_slot())
    let previous_pool = previously(field(stability_pool, total_deposits_slot()), 1)
    let liquidation_events = field(cdp_engine, liquidation_count_epoch_slot(current_epoch()))

    implies(
      current_pool < previous_pool,
      liquidation_events > 0  // pool should only drain during actual liquidations
    )

// ============================================================================
// INVARIANT 6: Emergency Circuit Breaker
// If any critical invariant is violated, minting must halt.
// This prevents compounding a bad state.
// ============================================================================

@invariant emergency_circuit_breaker
@severity  Governance

  @constraint minting_halted_when_cr_critical
    let global_cr     = mulDiv(field(cdp_engine, total_collateral_slot()), 10000, field(cdp_engine, total_debt_slot()))
    let minting_paused = field(cdp_engine, minting_paused_slot())

    implies(global_cr < 12000, minting_paused == true)

  @constraint borrowing_paused_when_peg_broken
    let stablecoin_price = field(price_oracle, price_slot(env("STABLECOIN_ADDR")))
    let borrow_paused    = field(cdp_engine, borrow_paused_slot())

    implies(
      stablecoin_price < 900_000,  // below $0.90
      borrow_paused == true
    )
