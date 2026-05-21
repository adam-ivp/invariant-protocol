// ISL — Bridge Protocol Invariants
// Detects balance desync, event integrity failure, nonce replay

@protocol src = env("BRIDGE_SOURCE")
@protocol dst = env("BRIDGE_DESTINATION")

@invariant bridge_balance_conservation
@severity  Solvency
@composite [src, dst]

  @constraint tvl_covers_liabilities
    forall asset in BRIDGED_ASSETS:
      cross_field(SRC, src, locked(asset)) + cross_field(SRC, src, inflight(asset)) >=
      cross_field(DST, dst, liabilities(asset))

  @constraint no_double_settlement
    forall msg_id in RECENT_MESSAGES(200):
      settled_count(msg_id) <= 1

@invariant swap_event_integrity
@severity  Bridge
@protocol  src

  // Event emits user-supplied amount instead of actual balance delta
  // Fee-on-transfer tokens cause systematic divergence
  // Relayer trusts event for destination payout — overpays by the difference
  @constraint emitted_amount_matches_balance_delta
    forall swap_id in RECENT_SWAPS(100):
      event_field(SwapEvent, swap_id, "fromAmount") == balance_delta(swap_id)

@invariant nonce_ordering
@severity  Bridge
@composite [src, dst]

  @constraint burn_before_mint
    forall nonce in RECENT_NONCES(1000):
      implies(minted(nonce) > 0, burned(nonce) > 0)

  @constraint mint_amount_matches_burn
    forall nonce in RECENT_NONCES(1000):
      implies(minted(nonce) > 0, minted(nonce) == burned_amount(nonce))
