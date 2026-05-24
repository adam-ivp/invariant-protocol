// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

interface IIVPGuardian {
    function onViolation(uint256 invariantId, uint256 epoch, uint8 violationType, address suspectedAccount, uint256 estimatedLoss, bytes32 proofHash) external returns (GuardianResponse memory response);
    function onViolationCleared(uint256 invariantId, uint256 epoch) external;
    function guardianStatus() external view returns (GuardianStatus memory);
}

struct GuardianResponse {
    GuardianAction action;
    address        frozenAccount;
    uint256        frozenAmount;
    address        escrowAddress;
    bool           paused;
    string         reason;
}

struct GuardianStatus {
    bool    active;
    bool    paused;
    uint256 lastViolationEpoch;
    uint256 totalViolationsHandled;
    address escrowAddress;
}

enum GuardianAction { None, Paused, AccountFrozen, WithdrawalBlocked, FundsEscrowed, AlertOnly }

library ViolationType {
    uint8 public constant SOLVENCY   = 0;
    uint8 public constant LIQUIDITY  = 1;
    uint8 public constant PEG        = 2;
    uint8 public constant BRIDGE     = 3;
    uint8 public constant GOVERNANCE = 4;
    uint8 public constant COMPOSITE  = 5;
}

interface IIVPGuardianRegistry {
    function registerGuardian(uint256 invariantId, address guardian) external;
    function removeGuardian(uint256 invariantId) external;
    function getGuardian(uint256 invariantId) external view returns (address);
    function hasGuardian(uint256 invariantId) external view returns (bool);
    function fireCallback(uint256 invariantId, uint256 epoch, uint8 violationType, address suspectedAccount, uint256 estimatedLoss, bytes32 proofHash) external returns (bool);

    event GuardianRegistered(uint256 indexed invariantId, address indexed guardian, address indexed owner);
    event GuardianRemoved(uint256 indexed invariantId);
    event GuardianCallbackFired(uint256 indexed invariantId, uint256 epoch, GuardianAction action);
    event GuardianCallbackFailed(uint256 indexed invariantId, uint256 epoch, bytes reason);
}
