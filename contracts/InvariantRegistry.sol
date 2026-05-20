// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @title InvariantRegistry
/// @notice Protocols register their formal invariants here before deploy.
///         Invariants are immutable once registered.
///         This is the source of truth for what IVP provers must verify.
contract InvariantRegistry {

    enum InvariantTier { Simple, Compound, Temporal }

    struct StorageSlot {
        address contractAddr;
        bytes32 slot;
        string label;
    }

    struct InvariantSpec {
        bytes32 constraintHash;
        InvariantTier tier;
        StorageSlot[] slots;
        bool active;
        uint256 registeredAt;
    }

    struct Protocol {
        address owner;
        address[] contracts;
        uint256 invariantCount;
        bool registered;
        uint256 registeredAt;
    }

    mapping(bytes32 => Protocol) public protocols;
    mapping(bytes32 => mapping(uint256 => InvariantSpec)) public invariants;
    uint256 public totalProtocols;

    event ProtocolRegistered(bytes32 indexed protocolId, address indexed owner, uint256 timestamp);
    event InvariantAdded(bytes32 indexed protocolId, uint256 indexed index, bytes32 constraintHash, InvariantTier tier);

    error AlreadyRegistered();
    error NotRegistered();
    error NotOwner();

    function registerProtocol(
        address[] calldata contracts,
        bytes32[] calldata constraintHashes,
        InvariantTier[] calldata tiers,
        StorageSlot[][] calldata slotSets
    ) external returns (bytes32 protocolId) {
        protocolId = keccak256(abi.encodePacked(msg.sender, contracts, block.timestamp));
        if (protocols[protocolId].registered) revert AlreadyRegistered();

        protocols[protocolId] = Protocol({
            owner: msg.sender,
            contracts: contracts,
            invariantCount: 0,
            registered: true,
            registeredAt: block.timestamp
        });

        totalProtocols++;
        emit ProtocolRegistered(protocolId, msg.sender, block.timestamp);

        for (uint256 i = 0; i < constraintHashes.length; i++) {
            _addInvariant(protocolId, constraintHashes[i], tiers[i], slotSets[i]);
        }
    }

    function addInvariant(
        bytes32 protocolId,
        bytes32 constraintHash,
        InvariantTier tier,
        StorageSlot[] calldata slots
    ) external {
        if (!protocols[protocolId].registered) revert NotRegistered();
        if (protocols[protocolId].owner != msg.sender) revert NotOwner();
        _addInvariant(protocolId, constraintHash, tier, slots);
    }

    function _addInvariant(
        bytes32 protocolId,
        bytes32 constraintHash,
        InvariantTier tier,
        StorageSlot[] calldata slots
    ) internal {
        uint256 idx = protocols[protocolId].invariantCount;
        InvariantSpec storage spec = invariants[protocolId][idx];
        spec.constraintHash = constraintHash;
        spec.tier = tier;
        spec.active = true;
        spec.registeredAt = block.timestamp;
        for (uint256 i = 0; i < slots.length; i++) {
            spec.slots.push(slots[i]);
        }
        protocols[protocolId].invariantCount++;
        emit InvariantAdded(protocolId, idx, constraintHash, tier);
    }

    function getInvariant(bytes32 protocolId, uint256 idx) external view returns (InvariantSpec memory) {
        return invariants[protocolId][idx];
    }

    function getProtocol(bytes32 protocolId) external view returns (Protocol memory) {
        return protocols[protocolId];
    }
}
