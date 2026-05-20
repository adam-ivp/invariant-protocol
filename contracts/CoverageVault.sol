// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/// @title CoverageVault
/// @notice Protocols stream premiums in. When a violation proof settles,
///         payout executes automatically. No committee. No review.
///         Math closes the claim.
contract CoverageVault {

    struct Coverage {
        bytes32 protocolId;
        address subscriber;
        address payoutAddress;
        uint256 premiumPerBlock;
        uint256 coverageAmount;
        uint256 reserveBalance;
        uint256 lastSettledBlock;
        bool active;
    }

    struct PendingPayout {
        bytes32 proofId;
        bytes32 protocolId;
        uint256 notifiedAt;
        bool executed;
    }

    uint256 public constant DISPUTE_WINDOW   = 256;
    uint256 public constant BLOCKS_PER_YEAR  = 2_628_000;
    uint256 public constant BASE_PREMIUM_BPS = 10;

    address public immutable proverRegistry;
    address public immutable treasury;

    mapping(bytes32 => Coverage) public coverages;
    mapping(bytes32 => PendingPayout) public pendingPayouts;

    uint256 public totalReserves;
    uint256 public totalPaidOut;

    event Subscribed(bytes32 indexed protocolId, address indexed subscriber, uint256 coverageAmount);
    event ViolationNotified(bytes32 indexed proofId, bytes32 indexed protocolId);
    event PayoutExecuted(bytes32 indexed proofId, address indexed recipient, uint256 amount);

    error NotAuthorized();
    error AlreadyExecuted();
    error DisputeWindowNotClosed();
    error InsufficientReserves();

    constructor(address _proverRegistry, address _treasury) {
        proverRegistry = _proverRegistry;
        treasury = _treasury;
    }

    function subscribe(
        bytes32 protocolId,
        address payoutAddress,
        uint256 coverageAmount,
        uint256 initialDeposit
    ) external payable {
        uint256 premiumPerBlock = (coverageAmount * BASE_PREMIUM_BPS) / (10000 * BLOCKS_PER_YEAR);

        coverages[protocolId] = Coverage({
            protocolId:       protocolId,
            subscriber:       msg.sender,
            payoutAddress:    payoutAddress,
            premiumPerBlock:  premiumPerBlock,
            coverageAmount:   coverageAmount,
            reserveBalance:   initialDeposit,
            lastSettledBlock: block.number,
            active:           true
        });

        totalReserves += initialDeposit;
        emit Subscribed(protocolId, msg.sender, coverageAmount);
    }

    function notifyViolation(bytes32 proofId, bytes32 protocolId) external {
        if (msg.sender != proverRegistry) revert NotAuthorized();

        pendingPayouts[proofId] = PendingPayout({
            proofId:     proofId,
            protocolId:  protocolId,
            notifiedAt:  block.number,
            executed:    false
        });

        emit ViolationNotified(proofId, protocolId);
    }

    /// @notice Permissionless settlement. Anyone can call after dispute window.
    function executePayout(bytes32 proofId) external {
        PendingPayout storage p = pendingPayouts[proofId];
        if (p.executed) revert AlreadyExecuted();
        if (block.number < p.notifiedAt + DISPUTE_WINDOW) revert DisputeWindowNotClosed();

        Coverage storage c = coverages[p.protocolId];
        uint256 amount = c.coverageAmount;
        if (amount > totalReserves) revert InsufficientReserves();

        p.executed = true;
        totalReserves -= amount;
        totalPaidOut  += amount;

        (bool ok,) = c.payoutAddress.call{value: amount}("");
        require(ok, "Transfer failed");

        emit PayoutExecuted(proofId, c.payoutAddress, amount);
    }
}
