# IVP INVARIANT LIBRARY — DECENTRALIZED EXCHANGES
# Covers: Uniswap V2/V3, Curve, Balancer, order books

invariant ConstantProductNonDecreasing:
    read(Pool, slot(reserve0)) * read(Pool, slot(reserve1))
    >= read(Pool, slot(kLast))

invariant ReservesNonZero:
    read(Pool, slot(reserve0)) > 0
    and
    read(Pool, slot(reserve1)) > 0

invariant ActiveLiquidityNonNegative:
    read(Pool, slot(liquidity)) >= 0

invariant CurrentTickBounds:
    read(Pool, slot(currentTick)) >= -887272
    and
    read(Pool, slot(currentTick)) <= 887272

invariant SqrtPriceNonZero:
    read(Pool, slot(sqrtPriceX96)) > 0

invariant FeeGrowthMonotonic:
    delta(Pool, slot(feeGrowthGlobal0X128), 1) >= 0
    and
    delta(Pool, slot(feeGrowthGlobal1X128), 1) >= 0

invariant AmplificationBounds:
    read(Pool, slot(A)) >= 1
    and
    read(Pool, slot(A)) <= 1000000

invariant OrderNonceMonotonic:
    forall(users, user =>
        delta(Exchange, mapping(nonces, user), 1) >= 0
    )

invariant FilledAmountMonotonic:
    forall(orders, orderHash =>
        delta(Exchange, mapping(filled, orderHash), 1) >= 0
    )

invariant FilledAmountCeiling:
    forall(orders, orderHash =>
        read(Exchange, mapping(filled, orderHash))
        <= read(Exchange, mapping(makerAmount, orderHash))
    )
EOF\
cat > invariant-library/dex/dex.isl << 'EOF'
# IVP INVARIANT LIBRARY — DECENTRALIZED EXCHANGES
# Covers: Uniswap V2/V3, Curve, Balancer, order books

invariant ConstantProductNonDecreasing:
    read(Pool, slot(reserve0)) * read(Pool, slot(reserve1))
    >= read(Pool, slot(kLast))

invariant ReservesNonZero:
    read(Pool, slot(reserve0)) > 0
    and
    read(Pool, slot(reserve1)) > 0

invariant ActiveLiquidityNonNegative:
    read(Pool, slot(liquidity)) >= 0

invariant CurrentTickBounds:
    read(Pool, slot(currentTick)) >= -887272
    and
    read(Pool, slot(currentTick)) <= 887272

invariant SqrtPriceNonZero:
    read(Pool, slot(sqrtPriceX96)) > 0

invariant FeeGrowthMonotonic:
    delta(Pool, slot(feeGrowthGlobal0X128), 1) >= 0
    and
    delta(Pool, slot(feeGrowthGlobal1X128), 1) >= 0

invariant AmplificationBounds:
    read(Pool, slot(A)) >= 1
    and
    read(Pool, slot(A)) <= 1000000

invariant OrderNonceMonotonic:
    forall(users, user =>
        delta(Exchange, mapping(nonces, user), 1) >= 0
    )

invariant FilledAmountMonotonic:
    forall(orders, orderHash =>
        delta(Exchange, mapping(filled, orderHash), 1) >= 0
    )

invariant FilledAmountCeiling:
    forall(orders, orderHash =>
        read(Exchange, mapping(filled, orderHash))
        <= read(Exchange, mapping(makerAmount, orderHash))
    )
