# IVP INVARIANT LIBRARY — BRIDGES
# Covers: Across, Hop, Wormhole, LayerZero, OKX SWFT, any bridge

invariant MintLockParity:
    read(DestinationBridge, slot(totalMinted))
    == read(SourceBridge, slot(totalLocked))

invariant LockedBalanceConsistency:
    read(SourceToken, mapping(balanceOf, BridgeAddress))
    >= read(SourceBridge, slot(totalLocked))

invariant MessageVerifiedBeforeExecution:
    forall(messages, msgHash =>
        read(Bridge, mapping(executed, msgHash)) == 1
        implies
        read(Bridge, mapping(verified, msgHash)) == 1
    )

invariant MessageReplayProtection:
    forall(messages, msgHash =>
        read(Bridge, mapping(executionCount, msgHash)) <= 1
    )

invariant ValidatorThresholdMet:
    read(Bridge, slot(requiredSignatures)) > 0
    and
    read(Bridge, slot(requiredSignatures))
    <= read(Bridge, slot(validatorCount))

invariant EmittedAmountMatchesReceived:
    read(Bridge, slot(lastEmittedFromAmount))
    == read(Bridge, slot(lastActualReceived))

invariant FinalityDepthMet:
    read(Bridge, slot(sourceConfirmations))
    >= read(Bridge, slot(requiredConfirmations))
