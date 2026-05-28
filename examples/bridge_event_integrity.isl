// invariant-library/bridge/cross-chain.isl
// Cross-chain bridge invariants.
// These are composite invariants — they reference state on two chains simultaneously.
// The prover fetches snapshots from both source and destination chains,
// commits them into a single Merkle tree, and the circuit evaluates cross-chain
// constraints atomically within one ZK proof.
//
// Cross-chain reads use the CrossRef mechanism:
//   cross_field(chain_id, protocol, slot) — read from a snapshot on another chain

@protocol stargate_src  = env("STARGATE_ETH_MAINNET")
@protocol stargate_dst  = env("STARGATE_ARBITRUM")
@protocol cctp_src      = env("CCTP_TOKEN_MESSENGER_ETH")
@protocol cctp_dst      = env("CCTP_TOKEN_MESSENGER_ARB")

// ============================================================================
// INVARIANT 1: Bridge Balance Conservation
// Total value locked on source must equal total outstanding liabilities
// on destination (within a bounded in-flight window).
// ============================================================================

@invariant bridge_balance_conservation
@severity  Solvency
@composite [stargate_src, stargate_dst]

  let MAX_INFLIGHT_EPOCHS = 5  // messages take at most 5 epochs to settle

  @constraint tvl_covers_liabilities
    forall asset in BRIDGED_ASSETS:
      let src_locked       = cross_field(ETH_MAINNET, stargate_src, locked_slot(asset))
      let dst_outstanding  = cross_field(ARBITRUM,   stargate_dst, liabilities_slot(asset))
      let inflight         = cross_field(ETH_MAINNET, stargate_src, inflight_slot(asset))

      // Source locked >= destination liabilities - in-flight (which haven't settled yet)
      src_locked + inflight >= dst_outstanding

  @constraint no_double_mint
    forall message_id in RECENT_MESSAGES(MAX_INFLIGHT_EPOCHS):
      let src_sent    = cross_field(ETH_MAINNET, stargate_src, message_sent_slot(message_id))
      let dst_settled = cross_field(ARBITRUM,   stargate_dst, message_settled_slot(message_id))

      // A message can only settle once
      implies(dst_settled, src_sent)
      // dst_settled count must not exceed src_sent count per message
      dst_settled <= src_sent

// ============================================================================
// INVARIANT 2: CCTP Nonce Integrity
// Circle CCTP uses nonces to prevent replay attacks.
// A nonce used on source must be marked as used on destination.
// ============================================================================

@invariant cctp_nonce_integrity
@severity  Bridge
@composite [cctp_src, cctp_dst]

  @constraint nonce_not_replayable
    forall nonce in RECENT_NONCES(1000):
      let src_burned  = cross_field(ETH_MAINNET, cctp_src, burned_nonce_slot(nonce))
      let dst_minted  = cross_field(ARBITRUM,   cctp_dst, minted_nonce_slot(nonce))

      // If destination minted for a nonce, source must have burned
      implies(dst_minted, src_burned)

  @constraint mint_amount_matches_burn
    forall nonce in RECENT_NONCES(1000):
      let burned_amount = cross_field(ETH_MAINNET, cctp_src, burn_amount_slot(nonce))
      let minted_amount = cross_field(ARBITRUM,   cctp_dst, mint_amount_slot(nonce))

      implies(minted_amount > 0, minted_amount == burned_amount)

// ============================================================================
// INVARIANT 3: Bridge Liquidity Solvency
// Bridge liquidity pools must maintain minimum reserves at all times.
// Insufficient liquidity causes failed redemptions (de facto insolvency).
// ============================================================================

@invariant bridge_liquidity_solvency
@severity  Liquidity
@protocol  stargate_src

  let MIN_LIQUIDITY_RATIO_BPS = 1000  // 10% minimum at all times

  @constraint pool_maintains_minimum_reserves
    forall pool in ACTIVE_POOLS:
      let total_liquidity   = field(stargate_src, pool_liquidity_slot(pool))
      let total_liabilities = field(stargate_src, pool_liabilities_slot(pool))

      implies(
        total_liabilities > 0,
        total_liquidity * 10000 >= total_liabilities * MIN_LIQUIDITY_RATIO_BPS
      )

  @constraint delta_credits_non_negative
    forall pool in ACTIVE_POOLS:
      let delta_credits = field(stargate_src, delta_credit_slot(pool))
      delta_credits >= 0

// ============================================================================
// INVARIANT 4: Swap Event Integrity (OKX SWFT Bridge pattern)
// Emitted swap amounts must match actual balance deltas.
// Relayers using emitted values for payout must see accurate amounts.
// ============================================================================

@invariant swap_event_integrity
@severity  Bridge
@protocol  env("SWFT_SWAP_BSC")

  @constraint emitted_amount_matches_received
    forall swap_id in RECENT_SWAPS(100):
      let emitted_from_amount = event_field(SwapEvent, swap_id, "fromAmount")
      let actual_received     = balance_delta(swap_id)  // measured via pre/post balance

      // Emitted amount must equal actual received (accounting for fee-on-transfer tokens)
      emitted_from_amount == actual_received

  @constraint no_overpayment_on_fot_tokens
    forall swap_id in RECENT_SWAPS(100):
      let token          = event_field(SwapEvent, swap_id, "fromToken")
      let is_fot         = is_fee_on_transfer(token)
      let emitted_amount = event_field(SwapEvent, swap_id, "fromAmount")
      let actual_delta   = balance_delta(swap_id)

      implies(
        is_fot,
        emitted_amount == actual_delta  // must use balance delta, not user-supplied amount
      )

// ============================================================================
// INVARIANT 5: Bridge Admin Key Liveness
// Bridge admin key must not be a single EOA. Multisig or timelock required.
// Single-key control is a systemic risk on bridges securing billions.
// ============================================================================

@invariant bridge_admin_multisig
@severity  Governance
@protocol  stargate_src

  let MIN_SIGNERS = 3

  @constraint admin_is_not_eoa
    let admin = field(stargate_src, owner_slot())
    is_contract(admin) == true

  @constraint admin_has_sufficient_signers
    let admin       = field(stargate_src, owner_slot())
    let signer_count = field(admin, gnosis_owners_count_slot())
    signer_count >= MIN_SIGNERS

// ============================================================================
// INVARIANT 6: Message Queue Bounded
// Message queue depth must not exceed a safe bound.
// Unbounded queues can lead to out-of-gas failures on processing.
// ============================================================================

@invariant message_queue_bounded
@severity  Liquidity
@protocol  stargate_src

  let MAX_QUEUE_DEPTH = 1000

  @constraint queue_depth_within_bounds
    let queue_head  = field(stargate_src, queue_head_slot())
    let queue_tail  = field(stargate_src, queue_tail_slot())
    queue_tail - queue_head <= MAX_QUEUE_DEPTH
