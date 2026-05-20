# IVP INVARIANT LIBRARY — STABLECOINS
# Covers: MakerDAO, FRAX, Liquity, crvUSD, GHO, Monolith, USDC

invariant GlobalCollateralizationRatio:
    read(Protocol, slot(totalCollateralValue))
    >= read(Coin, slot(totalSupply)) * read(Protocol, slot(minimumCR)) / 10000

invariant CoinSupplyBacked:
    read(Coin, slot(totalSupply))
    <= read(Protocol, slot(totalCollateralValue))

invariant PSMAssetBacking:
    read(Protocol, slot(freePsmAssets))
    <= read(PsmVault, slot(totalAssets)) + 1

invariant MintBurnSymmetry:
    read(Protocol, slot(totalMintedByPSM))
    + read(Protocol, slot(totalMintedByCDP))
    == read(Coin, slot(totalSupply))

invariant EpochRedeemedCollateralMonotonic:
    delta(Protocol, slot(epochRedeemedCollateral), 1) >= 0

invariant RedemptionFeeBounds:
    read(Protocol, slot(redeemFeeBps)) <= 1000

invariant DebtCeilingRespected:
    forall(collateralTypes, collateral =>
        read(Protocol, mapping(debtByCollateral, collateral))
        <= read(Protocol, mapping(debtCeiling, collateral))
    )

invariant SystemContractsNotBlacklisted:
    read(USDC, mapping(isBlacklisted, ProtocolAddress)) == 0
    and
    read(USDC, mapping(isBlacklisted, BridgeAddress)) == 0

invariant GasTokenAvailable:
    read(GasToken, slot(paused)) == 0
    and
    read(GasToken, mapping(isBlacklisted, GasPrecompile)) == 0
