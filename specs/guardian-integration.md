# IVP Guardian — Integration Guide

**The prevention layer.**

Most DeFi security tools are reactive. They tell you what happened after the fact.

IVP Guardian fires before the attacker can finish.

---

## How it works

```
Block N:     Attacker submits exploit transaction
Block N:     Invariant property violated — state diverges
Block N+1:   IVP prover detects violation at epoch boundary
Block N+2:   EpochManager.finalize() fires Guardian callback
Block N+2:   Guardian.onViolation() executes:
               → Suspected account frozen
               → Withdrawals blocked
               → Funds redirected to IVP Escrow
Block N+?:   Attacker attempts withdrawal — BLOCKED
Block N+256: ZK proof finalizes — IVP Escrow releases to victims
```

Most exploits require multiple transactions to fully drain a protocol. The window between violation detection and final drain is enough to intercept.

---

## Integration — three steps

### Step 1: Deploy your Guardian

```solidity
import "@ivp/contracts/IVPGuardian.sol";

contract MyProtocolGuardian is IVPGuardian {

    IMyProtocol public immutable protocol;

    constructor(
        address _registry,
        address _admin,
        address _escrow,
        address _protocol
    ) IVPGuardian(_registry, _admin, _escrow) {
        protocol = IMyProtocol(_protocol);
    }

    // Override: what happens when IVP detects a violation
    function onViolation(
        uint256 invariantId,
        uint256 epoch,
        uint8   violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external override onlyIVP returns (GuardianResponse memory) {

        // 1. Freeze the suspected account immediately
        protocol.freezeAccount(suspectedAccount);

        // 2. Block all withdrawals for affected assets
        protocol.pauseWithdrawals();

        // 3. Return response — IVP logs this on-chain
        return GuardianResponse({
            action:        GuardianAction.AccountFrozen,
            frozenAccount: suspectedAccount,
            frozenAmount:  estimatedLoss,
            escrowAddress: escrowAddress,
            paused:        false,
            reason:        "IVP Guardian: account frozen on solvency violation"
        });
    }

    // Override: what happens when violation is cleared (false positive)
    function onViolationCleared(uint256 invariantId, uint256 epoch)
        external override onlyIVP {
        protocol.unfreezeAll();
        protocol.unpauseWithdrawals();
    }

    // Override: implement pause in your protocol
    function _pauseProtocol() internal override {
        protocol.pause();
    }

    function _unpauseProtocol() internal override {
        protocol.unpause();
    }
}
```

### Step 2: Register with IVP

```bash
# CLI
ivp guardian register \
  --invariant 42 \
  --guardian 0xYourGuardianAddress \
  --network base-sepolia
```

```typescript
// SDK
await ivp.registerGuardian({
  invariantId:     42,
  guardianAddress: "0xYourGuardianAddress",
});
```

```solidity
// Direct contract call
IVPGuardianRegistry(registry).registerGuardian(invariantId, guardianAddress);
```

### Step 3: Configure auto-pause thresholds

```solidity
// Auto-pause entire protocol on Solvency violations
guardian.setAutoPause(
    invariantId,
    ViolationType.SOLVENCY,
    true  // enable
);

// Alert only for Peg violations
guardian.setAutoPause(
    invariantId,
    ViolationType.PEG,
    false // disable — just freeze suspected account
);
```

---

## The IVP Escrow flow

When Guardian redirects funds to IVP Escrow:

```
Attacker's pending withdrawal
    ↓
Guardian intercepts
    ↓
IVPEscrow.escrow(token, amount, attacker, invariantId, epoch)
    ↓
Funds locked — attacker cannot withdraw
    ↓
ZK proof finalizes (256 blocks)
    ↓
IVPEscrow.releaseToVictims([victims], [amounts])
    ↓
Victims receive funds directly from escrow
```

If the violation was a false positive (successful dispute):
```
IVPEscrow.returnToOwner(escrowId)
    ↓
Funds returned to original account
```

---

## What Guardian cannot do

**Guardian cannot prevent the exploit transaction from executing.**
The EVM is permissionless. The attacker's transaction runs. The invariant fires after.

**Guardian cannot freeze funds that have already left the protocol.**
Once tokens are in the attacker's EOA, they're gone. Guardian only intercepts pending withdrawals and in-protocol balances.

**Guardian cannot act faster than one epoch (~10 minutes).**
The violation is detected at epoch boundary. Guardian fires at finalization.

**The window Guardian protects:**
Most large exploits require multiple transactions across multiple blocks:
- Flash loan setup
- State manipulation
- Position opening
- Withdrawal attempts (often multiple)

Guardian fires after the invariant violation — typically catching the withdrawal phase before completion.

---

## Gas costs

| Action | Gas estimate |
|--------|-------------|
| onViolation() callback | ~50,000–150,000 gas |
| Account freeze | ~30,000 gas |
| Protocol pause | ~20,000 gas |
| Escrow redirect | ~60,000 gas |

Guardian callbacks are capped at 200,000 gas by EpochManager. Design your Guardian to fit within this budget.

---

## Security considerations

**Guardian is trusted by the protocol.** It can pause the protocol, freeze accounts, and redirect funds. Deploy it carefully. Use a multisig as admin.

**False positives exist.** A misconfigured invariant could trigger Guardian on legitimate activity. The onViolationCleared() callback handles this — dispute the epoch, prove it was a false positive, Guardian unpauses automatically.

**The escrow is non-custodial from IVP's perspective.** IVP does not control the escrow. The protocol's admin controls fund release. IVP provides the infrastructure. The protocol governs the response.

---

## Example: Bridge Guardian

```solidity
contract BridgeGuardian is IVPGuardian {

    IBridge public immutable bridge;

    function onViolation(...) external override onlyIVP
        returns (GuardianResponse memory) {

        // Pause all bridge withdrawals immediately
        bridge.pauseWithdrawals();

        // Freeze the suspected relayer
        if (suspectedAccount != address(0)) {
            bridge.freezeRelayer(suspectedAccount);
        }

        return GuardianResponse({
            action:        GuardianAction.Paused,
            frozenAccount: suspectedAccount,
            frozenAmount:  estimatedLoss,
            escrowAddress: escrowAddress,
            paused:        true,
            reason:        "IVP: bridge event integrity violation detected"
        });
    }
}
```

This is the Guardian for the bridge event integrity invariant in `examples/bridge_event_integrity.isl`. The same invariant that catches the fee-on-transfer event mismatch — the one the demo is built around.

With Guardian registered: the moment the prover detects a swap where `emittedAmount != balanceDelta`, the bridge pauses withdrawals for the suspected relayer. The attacker cannot complete the drain.

**That's the full stack.**

Spec → Witness → Proof → Finality → Guardian → Escrow → Victims.

---

*IVP Guardian · Invariant Protocol · invariantprotocol.xyz*
