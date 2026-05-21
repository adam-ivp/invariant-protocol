// ISL — Lending Protocol Invariants
// Detects governance asymmetry, LTV bypass, ghost shares, oracle staleness

@protocol pool         = env("LENDING_POOL")
@protocol configurator = env("POOL_CONFIGURATOR")
@protocol oracle       = env("PRICE_ORACLE")

@invariant ltv_enforcement_consistency
@severity  Solvency
@protocol  pool, configurator

  // Two governance functions zero LTV — one updates bitmap, one doesn't
  // eMode users bypass restriction entirely
  @constraint ltv_zero_propagates_to_all_access_paths
    forall asset in ACTIVE_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        implies(
          and(base_ltv(asset) == 0,
              in_collateral_bitmap(asset, emode_id)),
          ltv_zero_bitmap_set(asset, emode_id)
        )

  @constraint frozen_asset_effective_ltv_zero
    forall asset in FROZEN_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        effective_ltv(asset, emode_id) == 0

@invariant reserve_solvency
@severity  Solvency
@protocol  pool

  @constraint total_debt_within_threshold
    forall asset in ACTIVE_ASSETS:
      let total_debt = total_variable_debt(asset) + total_stable_debt(asset)
      total_debt * 10000 <= total_liquidity(asset) * liquidation_threshold(asset)

  @constraint liquidity_index_non_decreasing
    forall asset in ACTIVE_ASSETS:
      liquidity_index(asset) >= previously(liquidity_index(asset), 1)

@invariant share_accounting_integrity
@severity  Solvency
@protocol  pool

  @constraint no_ghost_shares
    forall debt_class in [STABLE_DEBT, VARIABLE_DEBT]:
      implies(total_debt(debt_class) == 0, total_shares(debt_class) == 0)
