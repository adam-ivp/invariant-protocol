// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./interfaces/IIVPGuardian.sol";
import "./interfaces/IInvariantRegistry.sol";

/// @title IVPGuardianRegistry
/// @notice On-chain registry mapping invariant IDs to guardian callbacks.
///         EpochManager queries this before finalizing a violated epoch.
///         If a guardian is registered, the callback fires before finalization.
///
///         Gas safety: callbacks are called with a fixed gas limit.
///         A reverting or gas-griefing guardian cannot block epoch finalization.
///         Failed callbacks are logged and skipped — the epoch finalizes regardless.
///
///         This is the integration point. A protocol that wants IVP Guardian:
///         1. Deploys a contract implementing IIVPGuardian
///         2. Calls registerGuardian(invariantId, guardianAddress)
///         3. Done. IVP will call onViolation() on every confirmed violation.

contract IVPGuardianRegistry is IIVPGuardianRegistry {

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    /// @dev Gas forwarded to guardian callback.
    ///      Enough for a pause + freeze + event emission.
    ///      Not enough for complex computation — keeps callbacks lean.
    uint256 public constant CALLBACK_GAS_LIMIT = 200_000;

    /// @dev Max guardians per protocol address (prevents spam registration)
    uint256 public constant MAX_GUARDIANS_PER_OWNER = 50;

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    IInvariantRegistry public immutable invariantRegistry;
    address            public immutable epochManager;

    /// invariantId => guardian address
    mapping(uint256 => address) public guardians;

    /// owner => count of registered guardians
    mapping(address => uint256) public guardianCount;

    /// invariantId => paused state (set by guardian callback, cleared on violation cleared)
    mapping(uint256 => bool) public invariantPaused;

    /// invariantId => epoch => callback result
    mapping(uint256 => mapping(uint256 => GuardianResponse)) public callbackResults;

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _invariantRegistry, address _epochManager) {
        invariantRegistry = IInvariantRegistry(_invariantRegistry);
        epochManager      = _epochManager;
    }

    // -------------------------------------------------------------------------
    // Registration
    // -------------------------------------------------------------------------

    /// @notice Register a guardian for an invariant.
    ///         Guardian must implement IIVPGuardian.
    ///         Only the invariant owner can register.
    function registerGuardian(uint256 invariantId, address guardian) external {
        require(guardian != address(0), "Zero guardian");
        require(guardian.code.length > 0, "Guardian must be contract");

        // Verify caller owns this invariant
        address owner = invariantRegistry.getInvariant(invariantId).owner;
        require(msg.sender == owner, "Not invariant owner");

        // Verify guardian count
        require(guardianCount[msg.sender] < MAX_GUARDIANS_PER_OWNER, "Too many guardians");

        // Verify guardian implements the interface (basic check)
        try IIVPGuardian(guardian).guardianStatus() returns (GuardianStatus memory) {
            // interface check passed
        } catch {
            revert("Guardian does not implement IIVPGuardian");
        }

        if (guardians[invariantId] == address(0)) {
            guardianCount[msg.sender]++;
        }

        guardians[invariantId] = guardian;
        emit GuardianRegistered(invariantId, guardian, msg.sender);
    }

    function removeGuardian(uint256 invariantId) external {
        address owner = invariantRegistry.getInvariant(invariantId).owner;
        require(msg.sender == owner, "Not invariant owner");

        address guardian = guardians[invariantId];
        require(guardian != address(0), "No guardian registered");

        delete guardians[invariantId];
        if (guardianCount[msg.sender] > 0) guardianCount[msg.sender]--;

        emit GuardianRemoved(invariantId);
    }

    function getGuardian(uint256 invariantId) external view returns (address) {
        return guardians[invariantId];
    }

    function hasGuardian(uint256 invariantId) external view returns (bool) {
        return guardians[invariantId] != address(0);
    }

    // -------------------------------------------------------------------------
    // Callback dispatch — called by EpochManager on violation
    // -------------------------------------------------------------------------

    /// @notice Fire the guardian callback for a violated invariant.
    ///         Called by EpochManager.finalize() when violationCount > 0.
    ///         Gas-capped: a bad guardian cannot block epoch finalization.
    ///         Returns false if callback failed — epoch finalizes regardless.
    function fireCallback(
        uint256 invariantId,
        uint256 epoch,
        uint8   violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external returns (bool success) {
        require(msg.sender == epochManager, "Only epoch manager");

        address guardian = guardians[invariantId];
        if (guardian == address(0)) return false;

        // Fire callback with gas cap — cannot grief epoch finalization
        try IIVPGuardian(guardian).onViolation{gas: CALLBACK_GAS_LIMIT}(
            invariantId,
            epoch,
            violationType,
            suspectedAccount,
            estimatedLoss,
            proofHash
        ) returns (GuardianResponse memory response) {
            callbackResults[invariantId][epoch] = response;
            invariantPaused[invariantId] = response.paused;
            success = true;
            emit GuardianCallbackFired(invariantId, epoch, response.action);
        } catch (bytes memory reason) {
            success = false;
            emit GuardianCallbackFailed(invariantId, epoch, reason);
        }
    }

    /// @notice Fire the cleared callback when a disputed epoch is cleared.
    function fireClearedCallback(uint256 invariantId, uint256 epoch) external {
        require(msg.sender == epochManager, "Only epoch manager");

        address guardian = guardians[invariantId];
        if (guardian == address(0)) return;

        invariantPaused[invariantId] = false;

        try IIVPGuardian(guardian).onViolationCleared{gas: CALLBACK_GAS_LIMIT}(
            invariantId,
            epoch
        ) {} catch {}
    }

    // -------------------------------------------------------------------------
    // Views
    // -------------------------------------------------------------------------

    function getCallbackResult(uint256 invariantId, uint256 epoch)
        external view returns (GuardianResponse memory) {
        return callbackResults[invariantId][epoch];
    }

    function isInvariantPaused(uint256 invariantId) external view returns (bool) {
        return invariantPaused[invariantId];
    }
}
