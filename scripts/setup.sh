#!/bin/bash
# OP Stack + Reth Setup Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "OP Stack + Reth Setup"
echo "============================================"

# Generate JWT secret
echo ""
echo "[1/4] Generating JWT secret..."
bash "$SCRIPT_DIR/generate-jwt.sh"

# Copy .env file
echo ""
echo "[2/4] Setting up environment file..."
if [ ! -f "$PROJECT_DIR/.env" ]; then
    cp "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env"
    echo "Created .env file from .env.example"
    echo "IMPORTANT: Edit .env and fill in your configuration!"
else
    echo ".env file already exists, skipping..."
fi

# Check for genesis.json
echo ""
echo "[3/4] Checking for genesis.json..."
if [ ! -f "$PROJECT_DIR/genesis.json" ]; then
    echo "WARNING: genesis.json not found!"
    echo "Generate it with: make config   (op-deployer; see README)"
else
    echo "genesis.json found."
fi

# Check for rollup.json
echo ""
echo "[4/4] Checking for rollup.json..."
if [ ! -f "$PROJECT_DIR/rollup.json" ]; then
    echo "WARNING: rollup.json not found!"
    echo "Generate it with: make config   (op-deployer; see README)"
else
    echo "rollup.json found."
fi

echo ""
echo "============================================"
echo "Setup Complete!"
echo "============================================"
echo ""
echo "Next steps:"
echo "1. Edit .env with your L1 RPC URLs and private keys"
echo "2. Generate genesis.json and rollup.json: make config"
echo "3. Start the stack:"
echo ""
echo "   # Start replica (no sequencing)"
echo "   docker compose up -d op-reth op-node"
echo ""
echo "   # Start sequencer (with batcher + proposer)"
echo "   docker compose --profile sequencer up -d"
echo ""
echo "   # Start with monitoring"
echo "   docker compose --profile sequencer --profile monitoring up -d"
echo ""
