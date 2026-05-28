# IVP-001: eMode LTV Bitmap Desync in Aave V3 PoolConfigurator

**Protocol:** Aave V3  
**Severity:** Medium  
**Affected versions:** v3.6.0 (all deployments), v3.7 branch  
**Status:** Submitted — Immunefi ticket 9645  
**Bounty potential:** $10,000  
**Discovery:** Week 1, pre-IVP deployment  
**Category:** Governance function asymmetry — two functions, same intent, divergent side effects

---

## Summary

`PoolConfigurator` exposes two governance functions that both produce the effect of zeroing an asset's loan-to-value ratio. They are not equivalent. One function updates the `ltvZeroBitmap` for all eMode categories containing the asset. The other does not. The result: an eMode user holding the asset as collateral bypasses the LTV reduction entirely and continues borrowing at full eMode LTV, defeating the governance intent silently with no on-chain signal of the discrepancy.

---

## Background: Aave V3 eMode and LTV

Aave V3 introduced **Efficiency Mode (eMode)**, which allows users to access higher LTV ratios when their collateral and debt assets are correlated (e.g., stablecoins, ETH-correlated assets). Each eMode category defines its own LTV, liquidation threshold, and liquidation bonus — independent of the base reserve configuration.

The `ltvZeroBitmap` is a per-eMode bitmap that tracks which assets have had their effective LTV zeroed within that eMode category. When governance zeros an asset's LTV, the intention is to prevent new borrowing against that asset. The bitmap is the enforcement mechanism for eMode users.

---

## Root Cause

Two functions in `PoolConfigurator` both produce a base LTV of zero for the target asset:

**`setReserveFreeze(address asset, bool freeze)`**
```solidity
function setReserveFreeze(address asset, bool freeze) external onlyRiskOrEmergencyAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setFrozen(freeze);
    if (freeze) {
        currentConfig.setLtv(0);
        // Updates ltvZeroBitmap for every eMode containing this asset
        _updateLtvZeroBitmapForFreezeUnfreeze(asset, freeze);
    }
    _pool.setConfiguration(asset, currentConfig);
}
```

**`setReserveLtvZero(address asset, bool ltvzero)`**
```solidity
function setReserveLtvZero(address asset, bool ltvzero) external onlyRiskOrPoolAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setLtv(ltvzero ? 0 : _reservesBoundaries[asset].minBaseLtv);
    _pool.setConfiguration(asset, currentConfig);
    // ltvZeroBitmap is never updated
}
```

The asymmetry: `setReserveFreeze` calls `_updateLtvZeroBitmapForFreezeUnfreeze`, which propagates the LTV-zero state into every eMode category that includes the asset. `setReserveLtvZero` does not. The bitmap is the source of truth for eMode LTV enforcement. If it isn't updated, eMode users are unaffected.

---

## Impact

When a governance actor calls `setReserveLtvZero(asset, true)`:

1. Base reserve configuration reflects `ltv = 0`
2. `ltvZeroBitmap` for all eMode categories containing the asset is **not updated**
3. An eMode user with `asset` in their `collateralBitmap` calls `getUserAccountData` — effective LTV is computed using the **eMode LTV**, not the base LTV
4. The eMode LTV is unaffected
5. The user continues to open new borrowing positions at full eMode LTV

The governance intent — reducing protocol risk by zeroing an asset's LTV — is silently defeated. There is no event, no revert, no signal. The state appears correct from the base reserve perspective. Only an explicit check of the eMode effective LTV reveals the discrepancy.

**Severity rationale (Medium):** The path requires a governance actor to use `setReserveLtvZero` specifically (rather than `setReserveFreeze`) and for eMode users to hold that asset. Given that this is a governance-invoked function called specifically to reduce risk, the silent defeat of intent in a risk-management context is the core concern. The immediate financial loss vector requires governance to be actively trying to reduce exposure.

---

## Proof of Concept

The following demonstrates the discrepancy. Against a fork of Aave V3 mainnet (any deployment):

```solidity
// 1. As governance: zero the LTV of WBTC via setReserveLtvZero
IPoolConfigurator(CONFIGURATOR).setReserveLtvZero(WBTC, true);

// 2. Verify base config shows LTV = 0
DataTypes.ReserveConfigurationMap memory config = POOL.getConfiguration(WBTC);
assertEq(config.getLtv(), 0);

// 3. Check eMode bitmap for WBTC eMode category
// ltvZeroBitmap is NOT updated — bitmap still shows WBTC as valid collateral
uint256 bitmap = POOL_CONFIGURATOR_STORAGE.ltvZeroBitmap(WBTC_EMODE_CATEGORY);
assertEq(bitmap & WBTC_BIT, 0); // WBTC bit is NOT set in the bitmap

// 4. As eMode user: getUserAccountData still returns eMode LTV for WBTC
(,,,uint256 ltv,,) = POOL.getUserAccountData(EMODE_USER_WITH_WBTC);
assertGt(ltv, 0); // eMode LTV still active — governance intent defeated
```

---

## IVP Invariant

This finding is encoded directly in `invariant-library/lending/aave-v3.isl` as `emode_ltv_consistency`:

```
@invariant emode_ltv_consistency
@severity  Solvency

  @constraint ltv_zero_implies_emode_exclusion
    forall asset in ACTIVE_ASSETS:
      forall emode_id in ACTIVE_EMODE_CATEGORIES:
        implies(
          and(base_ltv == 0,
              collateral_bitmap[emode_id] & asset_bit(asset) != 0),
          in_bitmap != 0
        )
```

This constraint would fire on any epoch where `setReserveLtvZero` was called without the corresponding bitmap update. IVP catches this class of governance function asymmetry continuously, not retroactively.

---

## Recommended Fix

Apply the same bitmap update call in `setReserveLtvZero`:

```solidity
function setReserveLtvZero(address asset, bool ltvzero) external onlyRiskOrPoolAdmins {
    DataTypes.ReserveConfigurationMap memory currentConfig = _pool.getConfiguration(asset);
    currentConfig.setLtv(ltvzero ? 0 : _reservesBoundaries[asset].minBaseLtv);
    _pool.setConfiguration(asset, currentConfig);
    // Add: propagate to eMode bitmap
    if (ltvzero) {
        _updateLtvZeroBitmapForFreezeUnfreeze(asset, true);
    }
}
```

---

## Hunting pattern

This finding exemplifies the core asymmetry pattern: **two functions with the same governance intent that diverge in a single side effect**. The side effect that's missing (`_updateLtvZeroBitmapForFreezeUnfreeze`) is non-obvious — it's an internal call that appears to be an implementation detail of the freeze flow rather than a required invariant of LTV zeroing.

The correct mental model for auditing governance functions: any function that zeros, freezes, or otherwise restricts an asset must propagate that restriction to every access control surface that could bypass it. In Aave V3, eMode is that surface.

---

*IVP-001 · Invariant Protocol · invariantprotocol.xyz*
