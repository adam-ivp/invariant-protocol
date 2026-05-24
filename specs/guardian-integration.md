# IVP Guardian — Integration Guide

The prevention layer.

Most DeFi security tools are reactive. IVP Guardian fires before the attacker can finish.

---

## How it works

    Block N:     Attacker submits exploit transaction
    Block N:     Invariant property violated
    Block N+1:   IVP prover detects violation at epoch boundary
    Block N+2:   EpochManager.finalize() fires Guardian callback
    Block N+2:   Guardian.onViolation() executes:
                   - Suspected account frozen
                   - Withdrawals blocked
                   - Funds redirected to IVP Escrow
    Block N+?:   Attacker attempts withdrawal — BLOCKED
    Block N+256: ZK proof finalizes — Escrow releases to victims

---

## Integration — three steps

### Step 1: Deploy your Guardian

    import "@ivp/contracts/IVPGuardian.sol";

    contract MyProtocolGuardian is IVPGuardian {

        IMyProtocol public immutable protocol;

        constructor(address _registry, address _admin, address _escrow, address _protocol)
            IVPGuardian(_registry, _admin, _escrow) {
            protocol = IMyProtocol(_protocol);
        }

        function onViolation(
            uint256 invariantId, uint256 epoch, uint8 violationType,
            address suspectedAccount, uint256 estimatedLoss, bytes32 proofHash
        ) external override onlyIVP returns (GuardianResponse memory) {

            protocol.freezeAccount(suspectedAccount);
            protocol.pauseWithdrawals();

            return GuardianResponse({
                action:        GuardianAction.AccountFrozen,
                frozenAccount: suspectedAccount,
                frozenAmount:  estimatedLoss,
                escrowAddress: escrowAddress,
                paused:        false,
                reason:        "IVP Guardian: account frozen on solvency violation"
            });
        }

        function onViolationCleared(uint256 invariantId, uint256 epoch)
            external override onlyIVP {
            protocol.unfreezeAll();
            protocol.unpauseWithdrawals();
        }

        function _pauseProtocol() internal override { protocol.pause(); }
        function _unpauseProtocol() internal override { protocol.unpause(); }
    }

### Step 2: Register

    ivp guardian register --invariant 42 --guardian 0xYourGuardian --network base-sepolia

### Step 3: Configure

    // Auto-pause on Solvency violations
    guardian.setAutoPause(invariantId, ViolationType.SOLVENCY, true);

---

## The Escrow flow

    Attacker withdrawal attempt
        → Guardian intercepts
        → IVPEscrow.escrow(token, amount, attacker, invariantId, epoch)
        → Funds locked
        → ZK proof finalizes (256 blocks)
        → IVPEscrow.releaseToVictims([victims], [amounts])
        → Victims paid directly from escrow

If false positive: IVPEscrow.returnToOwner(escrowId)

---

## What Guardian cannot do

- Cannot prevent the exploit transaction from executing
- Cannot freeze funds already in an EOA
- Cannot act faster than one epoch (~10 minutes)

What Guardian protects: the withdrawal/drain phase — which is where most exploits complete.

---

## The full stack

Spec → Witness → Proof → Finality → Guardian → Escrow → Victims

No committee. No vote. No human in the loop.

---

*IVP Guardian · Invariant Protocol*
