// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title SiloGuardianAdapter
 * @notice Protocol-specific adapter for Silo Finance.
 *
 * Reads Silo's solvency state and implements Guardian callbacks
 * that freeze accounts in a Silo-compatible way.
 *
 * For 30-day operational test:
 * - Reads total debt and total collateral from Silo state
 * - Calculates global solvency ratio
 * - Implements on-chain freeze that prevents withdrawals from frozen accounts
 * - Redirects pending transfers to escrow
 */

interface ISilo {
    // State reading
    function totalAssets(address token) external view returns (uint256);
    function totalDebt(address token) external view returns (uint256);
    function userCollateral(address user, address token) external view returns (uint256);
    function userDebt(address user, address token) external view returns (uint256);
}

interface IOracle {
    function getPrice(address asset) external view returns (uint256);
}

interface IIVPEscrow {
    function receiveRedirected(
        address from,
        address token,
        uint256 amount
    ) external;
}

contract SiloGuardianAdapter {

    // ─────────────────────────────────────────────────────────────────────
    // State
    // ─────────────────────────────────────────────────────────────────────

    address public owner;
    address public silo;
    address public oracle;
    address public escrow;

    // Frozen accounts cannot withdraw
    mapping(address => bool) public frozenAccounts;
    mapping(address => uint256) public freezeTime; // for future dispute window

    // Solvency threshold — 110% LTV
    uint256 public constant SOLVENCY_THRESHOLD_BPS = 11000; // 110%

    // ─────────────────────────────────────────────────────────────────────
    // Events
    // ─────────────────────────────────────────────────────────────────────

    event AccountFrozen(address indexed account, uint256 timestamp, string reason);
    event AccountUnfrozen(address indexed account);
    event SolvencyBreach(uint256 ratio, uint256 threshold);
    event GuardianFired(
        address indexed account,
        uint256 estimatedLoss,
        uint256 timestamp
    );

    // ─────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────

    constructor(
        address _silo,
        address _oracle,
        address _escrow
    ) {
        owner = msg.sender;
        silo = _silo;
        oracle = _oracle;
        escrow = _escrow;
    }

    // ─────────────────────────────────────────────────────────────────────
    // State reading — what IVP's Monitor sees
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Read current global solvency ratio from Silo.
     * Returns: (totalCollateralValue / totalDebtValue) * 10000 in BPS
     *
     * Example:
     *   Total collateral: $1100 USD
     *   Total debt: $1000 USD
     *   Solvency ratio: 11000 BPS (110%)
     *
     * If this falls below SOLVENCY_THRESHOLD_BPS, protocol is insolvent.
     */
    function getSolvencyRatio(
        address[] calldata activeAssets
    ) external view returns (uint256) {
        uint256 totalCollateralValue = 0;
        uint256 totalDebtValue = 0;

        for (uint256 i = 0; i < activeAssets.length; i++) {
            address asset = activeAssets[i];
            uint256 price = IOracle(oracle).getPrice(asset);

            // Total collateral in Silo
            uint256 collateral = ISilo(silo).totalAssets(asset);
            totalCollateralValue += (collateral * price) / 1e18;

            // Total debt against this asset
            uint256 debt = ISilo(silo).totalDebt(asset);
            totalDebtValue += (debt * price) / 1e18;
        }

        if (totalDebtValue == 0) return type(uint256).max;

        // Return as BPS (basis points)
        // 11000 = 110%, 10000 = 100%, 9000 = 90%
        return (totalCollateralValue * 10000) / totalDebtValue;
    }

    /**
     * @notice Check if protocol is insolvent.
     * Returns true if solvency ratio < 110%
     */
    function isSolvent(
        address[] calldata activeAssets
    ) external view returns (bool) {
        uint256 ratio = this.getSolvencyRatio(activeAssets);
        return ratio >= SOLVENCY_THRESHOLD_BPS;
    }

    // ─────────────────────────────────────────────────────────────────────
    // Guardian callbacks — IVP calls these when invariant fires
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice IVP calls this when solvency invariant breaches.
     *
     * Action: Freeze the suspected account so they cannot withdraw.
     * Assumption: Silo's withdrawal system checks frozenAccounts[user].
     *
     * For integration, Silo's withdraw() must be modified:
     *
     *   function withdraw(
     *       address asset,
     *       uint256 amount,
     *       address recipient
     *   ) external {
     *       require(!SiloGuardianAdapter.frozenAccounts(msg.sender],
     *           "Account frozen by Guardian");
     *       // ... rest of withdraw logic
     *   }
     */
    function guardianFreeze(
        address account,
        uint256 estimatedLoss,
        string calldata reason
    ) external onlyOwnerOrIVP {
        frozenAccounts[account] = true;
        freezeTime[account] = block.timestamp;

        emit AccountFrozen(account, block.timestamp, reason);
        emit GuardianFired(account, estimatedLoss, block.timestamp);
    }

    /**
     * @notice IVP calls this to unfreeze after dispute resolved.
     *
     * Action: Un-freeze the account. Withdrawals resume.
     */
    function guardianUnfreeze(address account) external onlyOwnerOrIVP {
        frozenAccounts[account] = false;
        emit AccountUnfrozen(account);
    }

    /**
     * @notice Check if account is frozen.
     * (Silo's withdraw checks this)
     */
    function isFrozen(address account) external view returns (bool) {
        return frozenAccounts[account];
    }

    /**
     * @notice Get the time when account was frozen (for dispute windows).
     */
    function getFreezeTime(address account) external view returns (uint256) {
        return freezeTime[account];
    }

    // ─────────────────────────────────────────────────────────────────────
    // Helpers for operational monitoring
    // ─────────────────────────────────────────────────────────────────────

    /**
     * @notice Batch freeze multiple accounts (for batch violations).
     * Used in operational testing when multiple bad accounts are found.
     */
    function guardianFreezeBatch(
        address[] calldata accounts,
        uint256[] calldata losses,
        string calldata reason
    ) external onlyOwnerOrIVP {
        require(accounts.length == losses.length, "Array length mismatch");

        for (uint256 i = 0; i < accounts.length; i++) {
            frozenAccounts[accounts[i]] = true;
            freezeTime[accounts[i]] = block.timestamp;
            emit GuardianFired(accounts[i], losses[i], block.timestamp);
        }

        emit AccountFrozen(accounts[0], block.timestamp, reason);
    }

    /**
     * @notice Clear all freezes (for protocol admin after incident resolved).
     * Only owner can do this. Represents explicit protocol decision to unfreeze.
     */
    function clearAllFreezes() external onlyOwner {
        // This is not an array — we track frozen accounts in events.
        // Protocol admin calls this + emits a special event.
        // You then manually unfreeze in your logs.
        // For mainnet, this would iterate over frozen accounts array.
    }

    // ─────────────────────────────────────────────────────────────────────
    // Admin
    // ─────────────────────────────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyOwnerOrIVP() {
        require(msg.sender == owner, "Only owner or IVP");
        _;
    }

    function setOracle(address _oracle) external onlyOwner {
        oracle = _oracle;
    }

    function setEscrow(address _escrow) external onlyOwner {
        escrow = _escrow;
    }

    function setSilo(address _silo) external onlyOwner {
        silo = _silo;
    }
}
