# AXIOM INVARIANT LIBRARY — LENDING PROTOCOLS
# Covers: Aave, Compound, Euler, Morpho, Monolith, Spark, Fraxlend
# Apply by substituting slot references from your storage layout.

invariant BorrowShareGhostGuard:
    read(Protocol, slot(totalBorrowAssets)) == 0
    implies
    read(Protocol, slot(totalBorrowShares)) == 0

invariant SupplyShareGhostGuard:
    read(Protocol, slot(totalSupplyAssets)) == 0
    implies
    read(Protocol, slot(totalSupplyShares)) == 0

invariant BorrowShareSymmetry:
    read(Protocol, slot(totalBorrowShares)) == 0
    implies
    read(Protocol, slot(totalBorrowAssets)) == 0

invariant DualPathGhostParity:
    (read(Protocol, slot(totalBorrowAssetsA)) == 0
     implies read(Protocol, slot(totalBorrowSharesA)) == 0)
    and
    (read(Protocol, slot(totalBorrowAssetsB)) == 0
     implies read(Protocol, slot(totalBorrowSharesB)) == 0)

invariant ProtocolSolvency:
    read(Protocol, slot(totalBorrowAssets))
    <= read(Protocol, slot(totalCollateralValue))

invariant LiquidationThresholdAboveLTV:
    read(Protocol, slot(liquidationThreshold))
    >= read(Protocol, slot(ltvCeiling))

invariant CollateralFactorBounds:
    read(Protocol, slot(collateralFactor)) <= 10000
    and
    read(Protocol, slot(collateralFactor)) >= 0

invariant EModeLTVSync:
    forall(assets, asset =>
        read(ReserveData[asset], slot(ltv)) == 0
        implies
        read(EModeConfig, slot(ltvzeroBitmap[asset])) == 1
    )

invariant AccrualTimestampMonotonic:
    delta(Protocol, slot(lastAccrualTimestamp), 1) >= 0

invariant BorrowRateSanity:
    read(Protocol, slot(currBorrowRate))
    <= 10000000000000000000

invariant ReservesMonotonic:
    delta(Protocol, slot(accruedReserves), 1) >= 0

invariant MinDebtFloor:
    forall(borrowers, account =>
        read(Protocol, mapping(debt, account)) == 0
        or
        read(Protocol, mapping(debt, account)) >= read(Protocol, slot(minDebt))
    )

invariant OraclePriceFresh:
    read(Oracle, slot(updatedAt))
    >= read(Oracle, slot(currentTimestamp)) - read(Protocol, slot(stalenessThreshold))

invariant OraclePricePositive:
    read(Oracle, slot(latestAnswer)) > 0

invariant LTVCeiling:
    read(Protocol, slot(ltvCeiling)) <= 9500

invariant ReserveFactorCeiling:
    read(Protocol, slot(reserveFactor)) <= 5000
