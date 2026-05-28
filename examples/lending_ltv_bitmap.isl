// invariant-library/lending/aave-v3.isl
// Aave V3 lending invariants.
// Compiled by the ISL compiler to CompiledInvariant structs for the ZK circuit.
// All storage slots are keccak256-derived from the Aave V3 PoolStorage layout.
//
// Notation:
//   field(slot)           — read a storage slot from the monitored contract
//   emode_field(id, slot) — read eMode category storage
//   user_field(user, slot)— read user-account storage (bounded range)
//   @invariant            — invariant declaration
//   @constraint           — named constraint within an invariant
//   @severity             — Solvency | Liquidity | Peg | Bridge | Governance
//   @protocol             — monitored contract address (filled at registration)

@protocol aave_v3_pool     = env("AAVE_V3_POOL_MAINNET")
@protocol aave_v3_config   = env("AAVE_V3_POOL_CONFIGURATOR_MAINNET")

// ============================================================================
// INVARIANT 1: eMode LTV Consistency
// Every asset's LTV must be zero in ALL eMode categories where
// setReserveFreeze or setReserveLtvZero was applied.
// Catching the asymmetry between setReserveFreeze (updates ltvZeroBitmap)
// and setReserveLtvZero (does not).
// ============================================================================

@invariant emode_ltv_consistency
@severity  Solvency
@protocol  aave_v3_pool, aave_v3_config

  // Storage slots (Aave V3 PoolStorage layout)
  let reserve_config    = field(aave_v3_pool, 0x0)   // ReserveConfigurationMap per asset
  let ltv_zero_bitmap   = field(aave_v3_config, 0x1)  // ltvZeroBitmap per eMode category
  let emode_ltv         = field(aave_v3_pool, 0x2)    // eMode category LTV

  // For every asset A and every eMode category E:
  // if A.ltv == 0 in base config, then A must not appear in E.collateralBitmap
  // OR E.ltv must also be forced to 0 for A via the ltvZeroBitmap

  @constraint ltv_zero_implies_emode_exclusion
    forall asset in ACTIVE_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        let base_ltv     = reserve_config[asset].ltv
        let in_bitmap    = emode_ltv_zero_bitmap[emode_id] & (1 << asset_index(asset))
        let emode_ltv_v  = emode_category[emode_id].ltv

        // If base LTV is zeroed and asset is in eMode collateral bitmap,
        // ltvZeroBitmap must reflect this for that eMode
        implies(
          and(base_ltv == 0, collateral_bitmap[emode_id] & asset_bit(asset) != 0),
          in_bitmap != 0
        )

  @constraint emode_ltv_not_bypassing_freeze
    forall asset in FROZEN_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        // A frozen asset's effective LTV through eMode must be 0
        let emode_effective_ltv = effective_ltv(asset, emode_id)
        emode_effective_ltv == 0

// ============================================================================
// INVARIANT 2: Reserve Solvency Ratio
// Total debt (stable + variable) must never exceed total available liquidity
// scaled by the configured liquidation threshold.
// ============================================================================

@invariant reserve_solvency
@severity  Solvency
@protocol  aave_v3_pool

  @constraint total_debt_within_threshold
    forall asset in ACTIVE_ASSETS:
      let total_variable_debt = field(aave_v3_pool, variable_debt_slot(asset))
      let total_stable_debt   = field(aave_v3_pool, stable_debt_slot(asset))
      let total_liquidity     = field(aave_v3_pool, liquidity_slot(asset))
      let liq_threshold       = reserve_config[asset].liquidationThreshold  // BPS

      let total_debt = total_variable_debt + total_stable_debt

      // Utilization must be <= liquidation threshold (in BPS, 10000 = 100%)
      // total_debt / total_liquidity <= liq_threshold / 10000
      // equivalent to: total_debt * 10000 <= total_liquidity * liq_threshold
      total_debt * 10000 <= total_liquidity * liq_threshold

  @constraint variable_rate_not_exceeding_cap
    forall asset in ACTIVE_ASSETS:
      let variable_borrow_rate = field(aave_v3_pool, variable_rate_slot(asset))
      let rate_cap             = reserve_config[asset].interestRateCap
      variable_borrow_rate <= rate_cap

// ============================================================================
// INVARIANT 3: Liquidity Index Monotonicity
// The liquidity index must be non-decreasing across epochs.
// A decreasing index would allow extracting value from depositors.
// ============================================================================

@invariant liquidity_index_monotonic
@severity  Solvency
@protocol  aave_v3_pool

  @constraint index_non_decreasing
    forall asset in ACTIVE_ASSETS:
      let current_liquidity_index  = field(aave_v3_pool, liquidity_index_slot(asset))
      let previous_liquidity_index = previously(field(aave_v3_pool, liquidity_index_slot(asset)), 1)
      current_liquidity_index >= previous_liquidity_index

  @constraint variable_borrow_index_non_decreasing
    forall asset in ACTIVE_ASSETS:
      let current  = field(aave_v3_pool, variable_borrow_index_slot(asset))
      let previous = previously(field(aave_v3_pool, variable_borrow_index_slot(asset)), 1)
      current >= previous

// ============================================================================
// INVARIANT 4: Isolation Mode Debt Ceiling
// Assets in isolation mode must have total debt <= their configured ceiling.
// ============================================================================

@invariant isolation_mode_ceiling
@severity  Solvency
@protocol  aave_v3_pool

  @constraint debt_within_ceiling
    forall asset in ISOLATED_ASSETS:
      let isolation_debt   = field(aave_v3_pool, isolation_debt_slot(asset))
      let debt_ceiling     = reserve_config[asset].debtCeiling
      isolation_debt <= debt_ceiling

// ============================================================================
// INVARIANT 5: aToken Supply Conservation
// Total aToken supply must equal total underlying deposits.
// Supply inflation would be an accounting error / exploit.
// ============================================================================

@invariant atoken_supply_conservation
@severity  Solvency
@protocol  aave_v3_pool

  @constraint atoken_supply_equals_deposits
    forall asset in ACTIVE_ASSETS:
      let atoken_supply    = field(atoken_address(asset), total_supply_slot())
      let underlying_bal   = field(asset, balance_of_slot(aave_v3_pool))
      let accrued_interest = field(aave_v3_pool, accrued_interest_slot(asset))

      // aToken supply must equal deposits + accrued interest
      // (scaled by liquidity index for precision)
      atoken_supply <= underlying_bal + accrued_interest

// ============================================================================
// INVARIANT 6: Borrow Cap Enforcement
// Total borrows must not exceed configured borrow cap per asset.
// ============================================================================

@invariant borrow_cap_enforced
@severity  Liquidity
@protocol  aave_v3_pool

  @constraint total_borrows_under_cap
    forall asset in CAPPED_ASSETS:
      let total_variable  = field(aave_v3_pool, variable_debt_slot(asset))
      let total_stable    = field(aave_v3_pool, stable_debt_slot(asset))
      let borrow_cap      = reserve_config[asset].borrowCap * (10 ** asset_decimals(asset))

      total_variable + total_stable <= borrow_cap

// ============================================================================
// INVARIANT 7: Supply Cap Enforcement
// Total aToken supply must not exceed configured supply cap.
// ============================================================================

@invariant supply_cap_enforced
@severity  Liquidity
@protocol  aave_v3_pool

  @constraint total_supply_under_cap
    forall asset in CAPPED_ASSETS:
      let atoken_supply = field(atoken_address(asset), total_supply_slot())
      let supply_cap    = reserve_config[asset].supplyCap * (10 ** asset_decimals(asset))

      atoken_supply <= supply_cap

// ============================================================================
// INVARIANT 8: Price Oracle Staleness
// Reported oracle prices must not be stale (updated within acceptable window).
// Stale prices create liquidation / borrowing asymmetries.
// ============================================================================

@invariant oracle_not_stale
@severity  Solvency
@protocol  aave_v3_pool

  let MAX_STALENESS_BLOCKS = 300  // ~1 hour on mainnet

  @constraint price_updated_recently
    forall asset in ACTIVE_ASSETS:
      let last_update_block = field(oracle_address(asset), last_update_slot())
      let current_block     = block_number()

      current_block - last_update_block <= MAX_STALENESS_BLOCKS
