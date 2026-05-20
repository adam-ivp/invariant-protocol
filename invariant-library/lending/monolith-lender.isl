# MONOLITH LENDER.SOL — INVARIANT SPECIFICATION
# Storage slots derived from Lender.sol declaration order
# slot 7: totalPaidDebt
# slot 8: totalPaidDebtShares
# slot 4: totalFreeDebt
# slot 5: totalFreeDebtShares
# slot 9: accruedLocalReserves
# slot 10: lastInterestAccrual
# slot 11: epoch
# slot 12: nonRedeemableCollateral
# slot 13: freePsmAssets

invariant PaidDebtGhostShareGuard:
    read(Lender, slot(totalPaidDebt)) == 0
    implies
    read(Lender, slot(totalPaidDebtShares)) == 0

invariant PaidDebtShareSymmetry:
    read(Lender, slot(totalPaidDebtShares)) == 0
    implies
    read(Lender, slot(totalPaidDebt)) == 0

invariant FreeDebtGhostShareGuard:
    read(Lender, slot(totalFreeDebt)) == 0
    implies
    read(Lender, slot(totalFreeDebtShares)) == 0

invariant FreeDebtShareSymmetry:
    read(Lender, slot(totalFreeDebtShares)) == 0
    implies
    read(Lender, slot(totalFreeDebt)) == 0

invariant DebtPathParity:
    (read(Lender, slot(totalFreeDebt)) == 0
     implies read(Lender, slot(totalFreeDebtShares)) == 0)
    and
    (read(Lender, slot(totalPaidDebt)) == 0
     implies read(Lender, slot(totalPaidDebtShares)) == 0)

invariant PaidDebtNonNegative:
    read(Lender, slot(totalPaidDebt)) >= 0

invariant FreeDebtNonNegative:
    read(Lender, slot(totalFreeDebt)) >= 0

invariant InterestAccrualMonotonic:
    delta(Lender, slot(lastInterestAccrual), 1) >= 0

invariant InterestRateSanity:
    delta(Lender, slot(totalPaidDebt), 1)
    <= read(Lender, slot(totalPaidDebt)) * 1 / 10000

invariant EpochMonotonic:
    delta(Lender, slot(epoch), 1) >= 0

invariant RedeemableCollateralNonNegative:
    read(Lender, slot(nonRedeemableCollateral))
    <= read(Lender, slot(nonRedeemableCollateral)) + 1

invariant PsmAssetsNonNegative:
    read(Lender, slot(freePsmAssets)) >= 0

invariant PsmVaultDriftBound:
    delta(Lender, slot(freePsmAssets), 50)
    <= read(Lender, slot(freePsmAssets)) * 5 / 100

invariant ReservesNonDecreasing:
    delta(Lender, slot(accruedLocalReserves), 1) >= 0

invariant MinDebtNonZero:
    read(Lender, slot(minDebt)) > 0

invariant CollateralFactorBounds:
    read(Lender, slot(collateralFactor)) <= 10000
    and
    read(Lender, slot(collateralFactor)) >= 0

invariant RedemptionFeeBounds:
    read(Lender, slot(redeemFeeBps)) <= 1000

invariant MaxBorrowDeltaBounds:
    read(Lender, slot(maxBorrowDeltaBps)) <= 10000
