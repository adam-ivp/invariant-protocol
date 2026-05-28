# IVP-003: Swap Event Amount Integrity Failure in OKX SWFT Bridge

**Protocol:** OKX SWFT Bridge (`SwftSwap.sol`)  
**Chain:** BSC Mainnet  
**Severity:** TBD (submitted to OKX security)  
**Discovery:** Week 1, pre-IVP deployment  
**Category:** Event integrity — emitted value diverges from on-chain reality

---

## Summary

`SwftSwap.swap()` correctly calculates actual tokens received via pre/post balance delta. It then emits the user-supplied `fromAmount` parameter in the `Swap` event rather than the actual received amount. For standard ERC20 tokens, these values are identical. For fee-on-transfer tokens, they diverge. If the relayer uses the emitted value to determine destination-side payouts — which is the standard relayer architecture — users receive payouts based on an overstated input amount. The excess is sourced from the bridge's liquidity.

---

## Background: Fee-on-Transfer Tokens

Fee-on-transfer (FoT) tokens deduct a percentage on every transfer. The sender specifies an amount, but the recipient receives `amount * (1 - fee_rate)`. Common examples: SAFEMOON, REFLECTION tokens, and any token with built-in redistribution mechanics.

For bridge contracts, FoT tokens create an accounting problem: the contract receives less than the user specified. If the contract records the specified amount (not the received amount) and uses that for destination-side settlement, the difference is a loss to the bridge or an overpayment to the user.

---

## Root Cause

```solidity
function swap(
    address fromToken,
    address toToken,
    uint256 fromAmount,   // user-supplied — NOT validated against actual receipt
    uint256 minReturnAmount,
    bytes32 destChainHash,
    string  calldata receiver
) external payable {

    // Correct: balance delta captures actual received amount
    uint256 balanceBefore = IERC20(fromToken).balanceOf(address(this));
    IERC20(fromToken).transferFrom(msg.sender, address(this), fromAmount);
    uint256 received = IERC20(fromToken).balanceOf(address(this)) - balanceBefore;

    // Incorrect: event emits fromAmount, not received
    emit Swap(
        msg.sender,
        fromToken,
        toToken,
        fromAmount,    // ← should be: received
        minReturnAmount,
        destChainHash,
        receiver
    );
}
```

The `received` value is computed correctly and used for some internal accounting. The event emission uses `fromAmount` — the user-supplied value — which for FoT tokens overstates what was actually deposited.

---

## Impact Path

Standard bridge relayer architecture:

1. User calls `swap()` with `fromAmount = 1000 TOKEN` (10% FoT, actual received: 900)
2. Contract emits `Swap(... fromAmount=1000 ...)`
3. Relayer on destination chain reads the `Swap` event
4. Relayer processes payout based on emitted `fromAmount = 1000`
5. User receives destination-side value equivalent to 1000 tokens
6. Bridge is short by 100 tokens per swap for every FoT token

The severity depends entirely on whether the destination relayer uses the emitted value or performs its own accounting. If the relayer trusts the event (standard architecture), this is a bridge drain vector for FoT tokens.

---

## Proof of Concept

Built in Foundry against a BSC mainnet fork:

```solidity
// MockFoTToken: 10% transfer tax
contract MockFoTToken is ERC20 {
    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 fee = amount / 10;
        super._transfer(from, address(this), fee);  // 10% to contract
        super._transfer(from, to, amount - fee);    // 90% to recipient
    }
}

contract TestSwftEventIntegrity is Test {
    SwftSwap swap = SwftSwap(SWFT_BSC_MAINNET);
    MockFoTToken token;

    function setUp() public {
        vm.createSelectFork("bsc");
        token = new MockFoTToken();
        token.mint(address(this), 1000e18);
        token.approve(address(swap), type(uint256).max);
    }

    function testEventAmountOverstated() public {
        uint256 fromAmount = 1000e18;

        vm.recordLogs();
        swap.swap(address(token), USDT, fromAmount, 0, destHash, "receiver");

        Vm.Log[] memory logs = vm.getRecordedLogs();
        SwapEvent memory swapEvent = parseSwapEvent(logs);

        // Contract actually received 900e18 (10% FoT)
        uint256 actualReceived = token.balanceOf(address(swap));
        assertEq(actualReceived, 900e18);

        // Event claims 1000e18 was received
        assertEq(swapEvent.fromAmount, 1000e18);

        // Divergence: 100e18 overstated in event
        assertGt(swapEvent.fromAmount, actualReceived);
    }
}
```

---

## IVP Invariant

Encoded in `invariant-library/bridge/cross-chain.isl` as `swap_event_integrity`:

```
@invariant swap_event_integrity
@severity  Bridge

  @constraint emitted_amount_matches_received
    forall swap_id in RECENT_SWAPS(100):
      let emitted_from_amount = event_field(SwapEvent, swap_id, "fromAmount")
      let actual_received     = balance_delta(swap_id)

      emitted_from_amount == actual_received

  @constraint no_overpayment_on_fot_tokens
    forall swap_id in RECENT_SWAPS(100):
      let token     = event_field(SwapEvent, swap_id, "fromToken")
      let is_fot    = is_fee_on_transfer(token)

      implies(
        is_fot,
        event_field(SwapEvent, swap_id, "fromAmount") == balance_delta(swap_id)
      )
```

This invariant fires on any epoch containing a swap where the emitted amount exceeds the balance delta — directly encoding the failure mode.

---

## Recommended Fix

```solidity
// Replace:
emit Swap(msg.sender, fromToken, toToken, fromAmount, ...);

// With:
emit Swap(msg.sender, fromToken, toToken, received, ...);
```

One word change. The `received` variable is already computed correctly on the line above. The fix is a matter of using the right variable in the event emission.

---

## Hunting pattern

This finding exemplifies **event integrity divergence**: a contract computes the correct value internally but surfaces a different value externally. The pattern is especially dangerous in bridge architectures where relayers on another chain use emitted events as the source of truth for settlement. The contract and the event are telling two different stories about the same transaction.

The general form: for any function that (1) accepts a user-supplied amount, (2) computes an actual received amount via balance delta, and (3) emits an event — verify that the event uses the computed value, not the user-supplied value.

---

*IVP-003 · Invariant Protocol · invariantprotocol.xyz*
