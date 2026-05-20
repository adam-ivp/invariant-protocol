// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @title ProverRegistry
/// @notice Provers stake IVP, submit state proofs each epoch,
///         get slashed for misses or false proofs.
contract ProverRegistry {

    uint256 public constant EPOCH_BLOCKS      = 50;
    uint256 public constant DISPUTE_WINDOW    = 256;
    uint256 public constant UNSTAKE_DELAY     = 7 days;
    uint256 public constant MIN_STAKE         = 10_000e18;
    uint256 public constant SLASH_FALSE_PROOF = 100;
    uint256 public constant SLASH_MISSED_VULN = 50;

    struct Prover {
        uint256 stake;
        uint256 stakedAt;
        uint256 unstakeRequestedAt;
        uint256 pendingUnstake;
        bool active;
        uint256 proofsSubmitted;
    }

    enum ProofStatus { Pending, Settled, Disputed, Rejected }

    struct Proof {
        address prover;
        bytes32 protocolId;
        uint256 epochId;
        bytes32 stateRoot;
        bool violated;
        uint256 violatingInvariant;
        bytes witness;
        uint256 submittedAt;
        ProofStatus status;
    }

    address public immutable ivpToken;
    address public immutable coverageVault;

    mapping(address => Prover) public provers;
    mapping(bytes32 => Proof) public proofs;
    mapping(bytes32 => bytes32) public epochProof;

    uint256 public totalStaked;

    event Staked(address indexed prover, uint256 amount);
    event ProofSubmitted(bytes32 indexed proofId, address indexed prover, bytes32 protocolId, bool violated);
    event ProofSettled(bytes32 indexed proofId);
    event ProverSlashed(address indexed prover, uint256 amount, string reason);

    error InsufficientStake();
    error NotActive();
    error AlreadySubmitted();
    error DisputeWindowOpen();

    constructor(address _ivpToken, address _coverageVault) {
        ivpToken = _ivpToken;
        coverageVault = _coverageVault;
    }

    function stake(uint256 amount) external {
        if (amount < MIN_STAKE) revert InsufficientStake();
        provers[msg.sender].stake += amount;
        provers[msg.sender].active = true;
        provers[msg.sender].stakedAt = block.timestamp;
        totalStaked += amount;
        emit Staked(msg.sender, amount);
    }

    function submitProof(
        bytes32 protocolId,
        uint256 epochId,
        bytes32 stateRoot,
        bool violated,
        uint256 violatingInvariant,
        bytes calldata witness
    ) external returns (bytes32 proofId) {
        if (!provers[msg.sender].active) revert NotActive();

        bytes32 epochKey = keccak256(abi.encodePacked(protocolId, epochId));
        if (epochProof[epochKey] != bytes32(0)) revert AlreadySubmitted();

        proofId = keccak256(abi.encodePacked(protocolId, epochId, msg.sender, block.number));

        proofs[proofId] = Proof({
            prover:              msg.sender,
            protocolId:          protocolId,
            epochId:             epochId,
            stateRoot:           stateRoot,
            violated:            violated,
            violatingInvariant:  violatingInvariant,
            witness:             witness,
            submittedAt:         block.number,
            status:              ProofStatus.Pending
        });

        epochProof[epochKey] = proofId;
        provers[msg.sender].proofsSubmitted++;

        emit ProofSubmitted(proofId, msg.sender, protocolId, violated);
    }

    function settleProof(bytes32 proofId) external {
        Proof storage proof = proofs[proofId];
        if (proof.status != ProofStatus.Pending) revert DisputeWindowOpen();
        if (block.number < proof.submittedAt + DISPUTE_WINDOW) revert DisputeWindowOpen();
        proof.status = ProofStatus.Settled;
        emit ProofSettled(proofId);
    }
}
