#!/bin/bash

# IVP Guardian Deployment — Base Sepolia Testnet
# Stripped down. Minimal scope. Operational proof only.
#
# Usage:
#   ./scripts/deploy-guardian-first.sh
#
# Prerequisites:
#   - forge installed
#   - DEPLOYER_KEY exported (private key)
#   - RPC_URL set (Base Sepolia)

set -e

NETWORK="base_sepolia"
RPC_URL="${RPC_URL:-https://sepolia.base.org}"
DEPLOYER="${DEPLOYER_KEY}"

if [ -z "$DEPLOYER" ]; then
  echo "Error: DEPLOYER_KEY not set"
  echo "  export DEPLOYER_KEY=0x..."
  exit 1
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       IVP Guardian-First Deployment — Base Sepolia            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Network:       $NETWORK"
echo "RPC:           $RPC_URL"
echo "Deployer:      ${DEPLOYER:0:10}..."
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 1: Deploy IVPEscrow
# ─────────────────────────────────────────────────────────────────────

echo "[1/5] Deploying IVPEscrow..."
ESCROW=$(forge create contracts/IVPEscrow.sol:IVPEscrow \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER \
  --json | jq -r '.deployedTo')

if [ -z "$ESCROW" ]; then
  echo "Failed to deploy IVPEscrow"
  exit 1
fi

echo "      IVPEscrow: $ESCROW"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 2: Deploy IVPGuardian
# ─────────────────────────────────────────────────────────────────────

echo "[2/5] Deploying IVPGuardian (reference implementation)..."
GUARDIAN=$(forge create contracts/IVPGuardian.sol:IVPGuardian \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER \
  --constructor-args $ESCROW \
  --json | jq -r '.deployedTo')

if [ -z "$GUARDIAN" ]; then
  echo "Failed to deploy IVPGuardian"
  exit 1
fi

echo "      IVPGuardian: $GUARDIAN"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 3: Deploy IVPGuardianRegistry
# ─────────────────────────────────────────────────────────────────────

echo "[3/5] Deploying IVPGuardianRegistry..."
REGISTRY=$(forge create contracts/IVPGuardianRegistry.sol:IVPGuardianRegistry \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER \
  --json | jq -r '.deployedTo')

if [ -z "$REGISTRY" ]; then
  echo "Failed to deploy IVPGuardianRegistry"
  exit 1
fi

echo "      IVPGuardianRegistry: $REGISTRY"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 4: Deploy MockEpochManager
# ─────────────────────────────────────────────────────────────────────

echo "[4/5] Deploying MockEpochManager (manual trigger)..."
EPOCH_MGR=$(forge create contracts/MockEpochManager.sol:MockEpochManager \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER \
  --constructor-args $REGISTRY \
  --json | jq -r '.deployedTo')

if [ -z "$EPOCH_MGR" ]; then
  echo "Failed to deploy MockEpochManager"
  exit 1
fi

echo "      MockEpochManager: $EPOCH_MGR"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Step 5: Deploy SiloGuardianAdapter
# ─────────────────────────────────────────────────────────────────────

# For testnet, use mock Silo address (you'd point to real Silo on mainnet)
MOCK_SILO="0x0000000000000000000000000000000000000001"
MOCK_ORACLE="0x0000000000000000000000000000000000000002"

echo "[5/5] Deploying SiloGuardianAdapter..."
SILO_ADAPTER=$(forge create contracts/SiloGuardianAdapter.sol:SiloGuardianAdapter \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER \
  --constructor-args $MOCK_SILO $MOCK_ORACLE $ESCROW \
  --json | jq -r '.deployedTo')

if [ -z "$SILO_ADAPTER" ]; then
  echo "Failed to deploy SiloGuardianAdapter"
  exit 1
fi

echo "      SiloGuardianAdapter: $SILO_ADAPTER"
echo ""

# ─────────────────────────────────────────────────────────────────────
# Output deployment record
# ─────────────────────────────────────────────────────────────────────

cat > .deployment-$(date +%s).json <<EOF
{
  "network": "$NETWORK",
  "rpc": "$RPC_URL",
  "deployed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contracts": {
    "IVPEscrow": "$ESCROW",
    "IVPGuardian": "$GUARDIAN",
    "IVPGuardianRegistry": "$REGISTRY",
    "MockEpochManager": "$EPOCH_MGR",
    "SiloGuardianAdapter": "$SILO_ADAPTER"
  }
}
EOF

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              Deployment Successful                            ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "│ Escrow:              $ESCROW"
echo "│ Guardian:            $GUARDIAN"
echo "│ Registry:            $REGISTRY"
echo "│ EpochManager:        $EPOCH_MGR"
echo "│ SiloAdapter:         $SILO_ADAPTER"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "│                                                               │"
echo "│ Next steps:                                                   │"
echo "│ 1. Register Guardian with Registry:                          │"
echo "│    cast send $REGISTRY 'register(uint256,address)' 1 $GUARDIAN"
echo "│                                                               │"
echo "│ 2. Start monitoring (once Silo address is set):             │"
echo "│    node scripts/silo-state-reader.js \\                      │"
echo "│      --rpc $RPC_URL \\                                      │"
echo "│      --silo <SILO_ADDRESS> \\                               │"
echo "│      --oracle <ORACLE_ADDRESS> \\                           │"
echo "│      --epochManager $EPOCH_MGR                             │"
echo "│                                                               │"
echo "│ 3. When breach detected, manually call:                      │"
echo "│    cast send $EPOCH_MGR 'finalizeEpochManual(...)' \\        │"
echo "│      true 1 0 <ACCOUNT> <LOSS> <PROOF_HASH> 'reason'       │"
echo "│                                                               │"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Deployment record saved: .deployment-$(date +%s).json"
