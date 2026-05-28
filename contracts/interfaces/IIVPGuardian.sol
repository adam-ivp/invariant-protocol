// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

// ============================================================================
// IVP Guardian Interface
// ============================================================================
//
// The prevention layer.
//
// When a protocol integrates IVP Guardian, invariant violations don't just
// produce proofs and payouts — they trigger immediate on-chain emergency
// responses in the same epoch the violation is detected.
//
// The attack pattern IVP Guardian breaks:
//
//   Block N:   Attacker submits exploit transaction
//   Block N:   Invariant fires — state property violated
//   Block N+1: IVP prover detects violation
//   Block N+2: Guardian callback fires — protocol FREEZES
//   Block N+?: Attacker attempts withdrawal — BLOCKED
//   Block N+?: ZK proof finalizes — funds released to victims
//
// Most exploits require multiple transactions to fully drain a protocol.
// A single epoch (~10 minutes) is enough to freeze them mid-flight.
//
// This is not theoretical. This is the integration that makes IVP
// genuinely dangerous to attackers — not just financially compensatory
// to victims.
//
// ============================================================================

/// @title IIVPGuardian
/// @notice Interface that protocols implement to receive violation callbacks.
///         When an invariant violation is detected, EpochManager calls
///         onViolation() on the registered guardian address.
///         The protocol decides what to do: pause, freeze, redirect, alert.
interface IIVPGuardian {

    /// @notice Called by IVP when a registered invariant is violated.
    ///         Executes in the epoch the violation is detected.
    ///         Must not revert — reversion silently fails the callback.
    ///
    /// @param invariantId      The violated invariant's on-chain ID
    /// @param epoch            The epoch in which violation occurred
    /// @param violationType    Encoded violation category (see ViolationType)
    /// @param suspectedAccount Address most likely associated with violation (0 if unknown)
    /// @param estimatedLoss    Estimated value at risk in asset decimals (0 if unknown)
    /// @param proofHash        Hash of the ZK proof confirming the violation
    ///
    /// @return response        Guardian's response — what action was taken
    function onViolation(
        uint256 invariantId,
        uint256 epoch,
        uint8   violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external returns (GuardianResponse memory response);

    /// @notice Called by IVP when a previously violated epoch is cleared
    ///         (e.g. successful dispute proved the violation was a false positive).
    ///         Protocols should use this to unpause if they paused on violation.
    ///
    /// @param invariantId  The invariant that was cleared
    /// @param epoch        The epoch that was cleared
    function onViolationCleared(uint256 invariantId, uint256 epoch) external;

    /// @notice Returns the guardian's current status and configuration.
    function guardianStatus() external view returns (GuardianStatus memory);
}

/// @notice What action the guardian took in response to a violation.
struct GuardianResponse {
    GuardianAction action;          // what was done
    address        frozenAccount;   // account frozen (if any)
    uint256        frozenAmount;    // amount frozen (if any)
    address        escrowAddress;   // where frozen funds are held (if any)
    bool           paused;          // whether the protocol is now paused
    string         reason;          // human-readable reason
}

/// @notice Actions a guardian can take.
enum GuardianAction {
    None,           // no action taken (monitoring only)
    Paused,         // protocol-wide pause
    AccountFrozen,  // specific account frozen
    WithdrawalBlocked, // withdrawals blocked for affected assets
    FundsEscrowed,  // funds redirected to IVP escrow
    AlertOnly       // alert fired, no on-chain action
}

/// @notice Current guardian status.
struct GuardianStatus {
    bool    active;
    bool    paused;
    uint256 lastViolationEpoch;
    uint256 totalViolationsHandled;
    address escrowAddress;
}

/// @notice Violation categories passed to onViolation().
library ViolationType {
    uint8 public constant SOLVENCY   = 0;
    uint8 public constant LIQUIDITY  = 1;
    uint8 public constant PEG        = 2;
    uint8 public constant BRIDGE     = 3;
    uint8 public constant GOVERNANCE = 4;
    uint8 public constant COMPOSITE  = 5;
}


// ============================================================================
// IVPGuardianRegistry
// ============================================================================
//
// Protocols register their Guardian address here.
// EpochManager queries this registry before firing callbacks.
// One guardian per invariant — protocols can use the same guardian
// for multiple invariants or deploy separate ones per category.

interface IIVPGuardianRegistry {

    /// @notice Register a guardian for an invariant.
    ///         Only callable by the invariant owner.
    function registerGuardian(uint256 invariantId, address guardian) external;

    /// @notice Remove a guardian.
    function removeGuardian(uint256 invariantId) external;

    /// @notice Get the guardian for an invariant.
    function getGuardian(uint256 invariantId) external view returns (address);

    /// @notice Check if an invariant has a guardian registered.
    function hasGuardian(uint256 invariantId) external view returns (bool);

    event GuardianRegistered(uint256 indexed invariantId, address indexed guardian, address indexed owner);
    event GuardianRemoved(uint256 indexed invariantId);
    event GuardianCallbackFired(uint256 indexed invariantId, uint256 epoch, GuardianAction action);
    event GuardianCallbackFailed(uint256 indexed invariantId, uint256 epoch, bytes reason);
}
