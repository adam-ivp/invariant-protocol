// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title MockEpochManager
 * @notice Simplified epoch manager for 30-day operational proof.
 *
 * This is NOT the full EpochManager. It's a manual-trigger version that lets
 * you fire Guardian callbacks without requiring a full prover network.
 *
 * You call finalizEpochManual() to simulate an epoch finality event.
 * Pass the actual violation data. Guardian fires. You log the result.
 *
 * Purpose: Prove Guardian works operationally before building decentralized prover.
 */

interface IIVPGuardian {
    struct GuardianResponse {
        uint8 action;
        address frozenAccount;
        uint256 frozenAmount;
        address escrowAddress;
        bool paused;
        string reason;
    }

    function onViolation(
        uint256 invariantId,
        uint256 epoch,
        uint8 violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external returns (GuardianResponse memory);

    function onViolationCleared(uint256 invariantId, uint256 epoch) external;
}

interface IGuardianRegistry {
    function getGuardianForInvariant(uint256 invariantId) external view returns (address);
}

contract MockEpochManager {

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────

    address public owner;
    IGuardianRegistry public guardianRegistry;

    uint256 public currentEpoch = 4821;
    uint256 public lastFinalizedEpoch = 0;

    struct EpochRecord {
        uint256 epoch;
        bool finalized;
        bool violated;
        uint256 invariantId;
        uint8 violationType;
        address suspectedAccount;
        uint256 estimatedLoss;
        bytes32 proofHash;
        address guardianFired;
        bool guardianResponse;
        string reason;
    }

    mapping(uint256 => EpochRecord) public epochRecords;

    // ─────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────

    event EpochFinalized(uint256 indexed epoch, bool violated);
    event GuardianFired(uint256 indexed epoch, address indexed guardian, bool success);
    event EpochRecorded(uint256 indexed epoch, uint256 invariantId, address suspectedAccount);

    // ─────────────────────────────────────────────────────────────────────
    // Errors
    // ─────────────────────────────────────────────────────────────────────

    error OnlyOwner();
    error EpochAlreadyFinalized();
    error GuardianNotFound();

    // ─────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────

    constructor(address _guardianRegistry) {
        owner = msg.sender;
        guardianRegistry = IGuardianRegistry(_guardianRegistry);
    }

    // ─────────────────────────────────────────────────────────────────────
    // Manual epoch finalization — YOU call this when you detect a violation
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Manually finalize an epoch and optionally fire Guardian.
     *
     * Call this when you detect a solvency breach in your monitoring loop.
     * You provide the violation details. We fire the Guardian callback.
     *
     * This simulates what EpochManager.finalize() would do after ZK proof.
     * For 30 days, you're the prover. You're manually attesting to violations.
     */
    function finalizeEpochManual(
        bool violated,
        uint256 invariantId,
        uint8 violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash,
        string calldata reason
    ) external onlyOwnerOrAdmin {
        if (epochRecords[currentEpoch].finalized) revert EpochAlreadyFinalized();

        // Record the epoch
        epochRecords[currentEpoch] = EpochRecord({
            epoch: currentEpoch,
            finalized: true,
            violated: violated,
            invariantId: invariantId,
            violationType: violationType,
            suspectedAccount: suspectedAccount,
            estimatedLoss: estimatedLoss,
            proofHash: proofHash,
            guardianFired: address(0),
            guardianResponse: false,
            reason: reason
        });

        emit EpochRecorded(currentEpoch, invariantId, suspectedAccount);

        // If violated, fire the Guardian callback
        if (violated) {
            address guardian = guardianRegistry.getGuardianForInvariant(invariantId);
            if (guardian == address(0)) revert GuardianNotFound();

            try IIVPGuardian(guardian).onViolation(
                invariantId,
                currentEpoch,
                violationType,
                suspectedAccount,
                estimatedLoss,
                proofHash
            ) returns (IIVPGuardian.GuardianResponse memory response) {
                epochRecords[currentEpoch].guardianFired = guardian;
                epochRecords[currentEpoch].guardianResponse = true;
                emit GuardianFired(currentEpoch, guardian, true);
            } catch {
                // Guardian callback failed — log but don't revert
                emit GuardianFired(currentEpoch, guardian, false);
            }
        }

        lastFinalizedEpoch = currentEpoch;
        emit EpochFinalized(currentEpoch, violated);

        // Advance to next epoch
        currentEpoch += 1;
    }

    /**
     * @notice Manually clear a violation (simulate successful dispute).
     * Calls Guardian.onViolationCleared() to unfreeze accounts.
     */
    function clearViolation(uint256 epochToClear, uint256 invariantId) external onlyOwnerOrAdmin {
        EpochRecord storage record = epochRecords[epochToClear];
        require(record.finalized && record.violated, "Epoch not violated or not finalized");

        address guardian = guardianRegistry.getGuardianForInvariant(invariantId);
        if (guardian == address(0)) revert GuardianNotFound();

        try IIVPGuardian(guardian).onViolationCleared(invariantId, epochToClear) {
            record.violated = false;
        } catch {
            // Silently fail if Guardian doesn't implement clearing
        }
    }

    // ─────────────────────────────────────────────────────────────────────
    // Getters
    // ─────────────────────────────────────────────────────────────────────

    function getEpochRecord(uint256 epoch) external view returns (EpochRecord memory) {
        return epochRecords[epoch];
    }

    function isEpochFinalized(uint256 epoch) external view returns (bool) {
        return epochRecords[epoch].finalized;
    }

    function getCurrentEpoch() external view returns (uint256) {
        return currentEpoch;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────────────────

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    function setGuardianRegistry(address _registry) external onlyOwnerOrAdmin {
        guardianRegistry = IGuardianRegistry(_registry);
    }

    function setCurrentEpoch(uint256 epoch) external onlyOwnerOrAdmin {
        currentEpoch = epoch;
    }
}
