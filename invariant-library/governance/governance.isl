# IVP INVARIANT LIBRARY — GOVERNANCE, VAULTS, ORACLES, STAKING, PERPS

invariant TimelockDelayEnforced:
    forall(proposals, proposalId =>
        read(Timelock, mapping(proposalEta, proposalId)) == 0
        or
        read(Timelock, mapping(proposalEta, proposalId))
        >= read(Timelock, mapping(proposalTimestamp, proposalId))
        + read(Timelock, slot(minDelay))
    )

invariant SafeNonceMonotonic:
    delta(Safe, slot(nonce), 1) >= 0

invariant MultisigThresholdValid:
    read(Safe, slot(threshold)) > 0
    and
    read(Safe, slot(threshold)) <= read(Safe, slot(ownerCount))

invariant VaultExchangeRateMonotonic:
    delta(Vault, slot(pricePerShare), 1) >= 0

invariant VaultSolvency:
    read(Vault, slot(totalAssets))
    >= read(Vault, slot(totalSupply)) * read(Vault, slot(pricePerShare)) / 1000000000000000000

invariant OracleCircuitBreakerNotTripped:
    read(Oracle, slot(latestAnswer)) != read(Oracle, slot(minAnswer))
    and
    read(Oracle, slot(latestAnswer)) != read(Oracle, slot(maxAnswer))

invariant RewardPerTokenMonotonic:
    delta(Staking, slot(rewardPerTokenStored), 1) >= 0

invariant RewardsFunded:
    read(Staking, slot(totalRewardsDistributed))
    <= read(Staking, slot(totalRewardsFunded))

invariant OpenInterestBacked:
    read(Perps, slot(totalOpenInterest))
    <= read(Perps, slot(totalCollateral))

invariant FundingRateBounds:
    read(Perps, slot(fundingRate)) <= read(Perps, slot(maxFundingRate))

invariant InsuranceFundNonNegative:
    read(Perps, slot(insuranceFund)) >= 0

invariant MintCapRespected:
    read(Token, slot(totalSupply)) <= read(Token, slot(maxSupply))
