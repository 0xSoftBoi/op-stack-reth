#!/bin/bash
# Devnet setup script for local testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
OPTIMISM_DIR="${OPTIMISM_DIR:-$HOME/optimism}"

echo "============================================"
echo "OP Stack Devnet Setup"
echo "============================================"

# Check if optimism repo exists
if [ ! -d "$OPTIMISM_DIR" ]; then
    echo "Cloning Optimism monorepo to $OPTIMISM_DIR..."
    git clone https://github.com/ethereum-optimism/optimism.git "$OPTIMISM_DIR"
else
    echo "Optimism repo found at $OPTIMISM_DIR"
fi

cd "$OPTIMISM_DIR"

# Check prerequisites
echo ""
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "ERROR: docker is required"
    exit 1
fi

if ! command -v go &> /dev/null; then
    echo "ERROR: go is required"
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo "WARNING: pnpm not found, installing..."
    npm install -g pnpm
fi

if ! command -v foundry &> /dev/null && ! command -v forge &> /dev/null; then
    echo "WARNING: foundry not found, installing..."
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
fi

echo "Prerequisites OK"

# Start devnet
echo ""
echo "Starting devnet..."
echo "This may take a few minutes on first run..."
make devnet-up

# Wait for devnet to be ready
echo ""
echo "Waiting for devnet to initialize..."
sleep 30

# Copy genesis files
echo ""
echo "Copying genesis files to $PROJECT_DIR..."

if [ -f ".devnet/genesis-l2.json" ]; then
    cp .devnet/genesis-l2.json "$PROJECT_DIR/genesis.json"
    echo "Copied genesis.json"
else
    echo "WARNING: genesis-l2.json not found"
fi

if [ -f ".devnet/rollup.json" ]; then
    cp .devnet/rollup.json "$PROJECT_DIR/rollup.json"
    echo "Copied rollup.json"
else
    echo "WARNING: rollup.json not found"
fi

echo ""
echo "============================================"
echo "Devnet Setup Complete!"
echo "============================================"
echo ""
echo "Devnet is running with:"
echo "  L1 RPC: http://localhost:8545"
echo "  L2 RPC: http://localhost:9545"
echo ""
echo "To use with your Reth setup:"
echo "  1. Stop the devnet's L2: docker stop op-geth op-node"
echo "  2. Update .env with L1_RPC_URL=http://host.docker.internal:8545"
echo "  3. Run: make up-sequencer"
echo ""
echo "To stop devnet completely:"
echo "  cd $OPTIMISM_DIR && make devnet-down"
echo ""
