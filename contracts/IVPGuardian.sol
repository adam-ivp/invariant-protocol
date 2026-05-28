// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "./interfaces/IIVPGuardian.sol";

/// @title IVPGuardian
/// @notice Reference guardian implementation.
///         Fork this. Customize onViolation() for your protocol.
///         Deploy it. Register it. IVP does the rest.
///
///         What this does on violation (configurable):
///           1. Freezes the suspected account's withdrawals
///           2. Redirects pending withdrawals to IVP escrow
///           3. Emits an on-chain alert with full violation context
///           4. Optionally pauses the entire protocol
///
///         What the protocol needs to implement:
///           - _freezeAccount(address) — freeze withdrawals for one address
///           - _pauseProtocol() — pause the protocol
///           - _unpauseProtocol() — unpause when violation cleared
///
///         The rest is handled here.

abstract contract IVPGuardian is IIVPGuardian {

    // -------------------------------------------------------------------------
    // State
    // -------------------------------------------------------------------------

    address public immutable ivpGuardianRegistry;
    address public immutable protocolAdmin;

    bool    public paused;
    uint256 public lastViolationEpoch;
    uint256 public totalViolationsHandled;
    address public escrowAddress;

    /// account => frozen
    mapping(address => bool) public frozen;
    /// account => frozen amount
    mapping(address => uint256) public frozenAmount;
    /// invariantId => violationType => auto-pause threshold
    mapping(uint256 => mapping(uint8 => bool)) public autoPauseConfig;

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------

    event ViolationReceived(uint256 indexed invariantId, uint256 epoch, address suspectedAccount, uint256 estimatedLoss);
    event AccountFrozen(address indexed account, uint256 amount, uint256 epoch);
    event AccountUnfrozen(address indexed account);
    event ProtocolPaused(uint256 indexed invariantId, uint256 epoch);
    event ProtocolUnpaused(uint256 indexed invariantId, uint256 epoch);
    event EscrowRedirect(address indexed from, address indexed escrow, uint256 amount, uint256 epoch);

    // -------------------------------------------------------------------------
    // Modifiers
    // -------------------------------------------------------------------------

    modifier onlyIVP() {
        require(msg.sender == ivpGuardianRegistry, "Only IVP Guardian Registry");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == protocolAdmin, "Only admin");
        _;
    }

    modifier notFrozen(address account) {
        require(!frozen[account], "Account frozen by IVP Guardian");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Protocol paused by IVP Guardian");
        _;
    }

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------

    constructor(address _registry, address _admin, address _escrow) {
        ivpGuardianRegistry = _registry;
        protocolAdmin       = _admin;
        escrowAddress       = _escrow;
    }

    // -------------------------------------------------------------------------
    // IIVPGuardian implementation
    // -------------------------------------------------------------------------

    /// @notice Called by IVP when an invariant violation is confirmed.
    ///         Executes emergency response based on violation type and config.
    ///
    /// Override this in your protocol-specific guardian to customize behavior.
    /// The default implementation: freeze suspected account + emit alert.
    function onViolation(
        uint256 invariantId,
        uint256 epoch,
        uint8   violationType,
        address suspectedAccount,
        uint256 estimatedLoss,
        bytes32 proofHash
    ) external virtual override onlyIVP returns (GuardianResponse memory response) {
        lastViolationEpoch = epoch;
        totalViolationsHandled++;

        emit ViolationReceived(invariantId, epoch, suspectedAccount, estimatedLoss);

        // Determine response based on violation severity
        if (autoPauseConfig[invariantId][violationType]) {
            // Protocol-wide pause for configured violation types
            _executePause(invariantId, epoch);
            response = GuardianResponse({
                action:        GuardianAction.Paused,
                frozenAccount: address(0),
                frozenAmount:  0,
                escrowAddress: escrowAddress,
                paused:        true,
                reason:        "IVP Guardian: protocol paused on invariant violation"
            });
        } else if (suspectedAccount != address(0)) {
            // Freeze the suspected account
            uint256 frozenAmt = _executeFreezeAccount(suspectedAccount, estimatedLoss, epoch);
            response = GuardianResponse({
                action:        GuardianAction.AccountFrozen,
                frozenAccount: suspectedAccount,
                frozenAmount:  frozenAmt,
                escrowAddress: escrowAddress,
                paused:        false,
                reason:        "IVP Guardian: suspected account frozen pending proof finalization"
            });
        } else {
            // Alert only — no account to freeze
            response = GuardianResponse({
                action:        GuardianAction.AlertOnly,
                frozenAccount: address(0),
                frozenAmount:  0,
                escrowAddress: address(0),
                paused:        false,
                reason:        "IVP Guardian: violation alert fired"
            });
        }

        paused = response.paused;
        return response;
    }

    /// @notice Called by IVP when a violation is cleared (successful dispute).
    ///         Unpauses and unfreezes if we acted on the original violation.
    function onViolationCleared(
        uint256 invariantId,
        uint256 epoch
    ) external virtual override onlyIVP {
        if (paused) {
            _executeUnpause(invariantId, epoch);
            paused = false;
        }
    }

    function guardianStatus() external view override returns (GuardianStatus memory) {
        return GuardianStatus({
            active:                  true,
            paused:                  paused,
            lastViolationEpoch:      lastViolationEpoch,
            totalViolationsHandled:  totalViolationsHandled,
            escrowAddress:           escrowAddress
        });
    }

    // -------------------------------------------------------------------------
    // Admin configuration
    // -------------------------------------------------------------------------

    /// @notice Configure which violation types trigger a full protocol pause.
    ///         By default nothing auto-pauses — only account freezes.
    ///         Enable auto-pause for Solvency violations on critical invariants.
    function setAutoPause(
        uint256 invariantId,
        uint8   violationType,
        bool    enabled
    ) external onlyAdmin {
        autoPauseConfig[invariantId][violationType] = enabled;
    }

    function setEscrowAddress(address _escrow) external onlyAdmin {
        require(_escrow != address(0), "Zero escrow");
        escrowAddress = _escrow;
    }

    /// @notice Manual unfreeze — admin override if violation was false positive
    ///         before IVP dispute resolves.
    function manualUnfreeze(address account) external onlyAdmin {
        frozen[account]      = false;
        frozenAmount[account] = 0;
        emit AccountUnfrozen(account);
    }

    /// @notice Manual unpause — admin override.
    function manualUnpause() external onlyAdmin {
        paused = false;
    }

    // -------------------------------------------------------------------------
    // Internal — override these in your protocol-specific implementation
    // -------------------------------------------------------------------------

    function _executeFreezeAccount(
        address account,
        uint256 estimatedLoss,
        uint256 epoch
    ) internal virtual returns (uint256 frozenAmt) {
        frozen[account]      = true;
        frozenAmount[account] = estimatedLoss;
        frozenAmt            = estimatedLoss;

        // Redirect any pending withdrawals from this account to escrow
        if (escrowAddress != address(0) && estimatedLoss > 0) {
            _redirectToEscrow(account, estimatedLoss, epoch);
        }

        emit AccountFrozen(account, estimatedLoss, epoch);
    }

    function _executePause(uint256 invariantId, uint256 epoch) internal virtual {
        _pauseProtocol();
        emit ProtocolPaused(invariantId, epoch);
    }

    function _executeUnpause(uint256 invariantId, uint256 epoch) internal virtual {
        _unpauseProtocol();
        emit ProtocolUnpaused(invariantId, epoch);
    }

    /// @dev Override: freeze withdrawals for this account in your protocol.
    function _pauseProtocol() internal virtual;

    /// @dev Override: unpause your protocol.
    function _unpauseProtocol() internal virtual;

    /// @dev Override: redirect pending withdrawals to escrow.
    function _redirectToEscrow(address account, uint256 amount, uint256 epoch) internal virtual {
        // Default: emit event for off-chain handling
        // Override to implement on-chain redirection
        emit EscrowRedirect(account, escrowAddress, amount, epoch);
    }
}


// ============================================================================
// IVPEscrow
// ============================================================================
//
// Holds funds redirected by Guardian callbacks.
// Funds sit here until:
//   A) ZK proof finalizes as violated → released to victims
//   B) Dispute clears the violation → returned to original owner
//
// This is the "siphon hole" — funds redirected here cannot be
// withdrawn by the attacker. They can only go to victims or back
// to the protocol if the violation was a false positive.

contract IVPEscrow {

    address public immutable ivpGuardianRegistry;
    address public immutable epochManager;
    address public           admin;

    struct EscrowedFunds {
        address  token;
        uint256  amount;
        address  originalOwner;  // attacker address (for return if false positive)
        uint256  invariantId;
        uint256  epoch;
        bool     released;
        bool     returned;
    }

    uint256 public nextEscrowId = 1;
    mapping(uint256 => EscrowedFunds) public escrows;
    mapping(address => uint256[]) public escrowsByOwner;

    event FundsEscrowed(uint256 indexed escrowId, address indexed token, uint256 amount, address indexed originalOwner, uint256 epoch);
    event FundsReleasedToVictims(uint256 indexed escrowId, uint256 amount);
    event FundsReturnedToOwner(uint256 indexed escrowId, address owner, uint256 amount);

    constructor(address _registry, address _epochManager, address _admin) {
        ivpGuardianRegistry = _registry;
        epochManager        = _epochManager;
        admin               = _admin;
    }

    /// @notice Accept escrowed funds from a Guardian callback.
    function escrow(
        address token,
        uint256 amount,
        address originalOwner,
        uint256 invariantId,
        uint256 epoch
    ) external returns (uint256 escrowId) {
        require(msg.sender == ivpGuardianRegistry || msg.sender == admin, "Not authorized");

        escrowId = nextEscrowId++;
        escrows[escrowId] = EscrowedFunds({
            token:         token,
            amount:        amount,
            originalOwner: originalOwner,
            invariantId:   invariantId,
            epoch:         epoch,
            released:      false,
            returned:      false
        });

        escrowsByOwner[originalOwner].push(escrowId);
        emit FundsEscrowed(escrowId, token, amount, originalOwner, epoch);
    }

    /// @notice Release escrowed funds to victims.
    ///         Called after ZK proof finalizes and claim is settled.
    ///         Admin distributes to affected users based on their loss.
    function releaseToVictims(
        uint256   escrowId,
        address[] calldata victims,
        uint256[] calldata amounts
    ) external {
        require(msg.sender == admin, "Only admin");
        EscrowedFunds storage e = escrows[escrowId];
        require(!e.released && !e.returned, "Already settled");

        uint256 total;
        for (uint256 i = 0; i < amounts.length; i++) {
            total += amounts[i];
        }
        require(total <= e.amount, "Exceeds escrowed amount");

        e.released = true;

        for (uint256 i = 0; i < victims.length; i++) {
            IERC20(e.token).transfer(victims[i], amounts[i]);
        }

        emit FundsReleasedToVictims(escrowId, total);
    }

    /// @notice Return escrowed funds to original owner.
    ///         Called if dispute proves violation was a false positive.
    function returnToOwner(uint256 escrowId) external {
        require(msg.sender == epochManager || msg.sender == admin, "Not authorized");
        EscrowedFunds storage e = escrows[escrowId];
        require(!e.released && !e.returned, "Already settled");

        e.returned = true;
        IERC20(e.token).transfer(e.originalOwner, e.amount);

        emit FundsReturnedToOwner(escrowId, e.originalOwner, e.amount);
    }
}

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
