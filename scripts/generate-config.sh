#!/usr/bin/env bash
# Generate genesis.json + rollup.json (and deploy the L1 contracts) with op-deployer —
# the modern, self-contained replacement for the old "use the Optimism monorepo" step.
#
# Requires: Docker, an L1 RPC, and a DEPLOYER_PRIVATE_KEY funded on L1.
# Pinned to op-deployer v0.4.2 / op-contracts v4.0.0 (matches devnet/simple-devnet.yaml).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR" || exit 1

# Load .env (L1_RPC_URL, DEPLOYER_PRIVATE_KEY, chain ids) if present.
# shellcheck source=/dev/null
if [ -f .env ]; then set -a; . ./.env; set +a; fi

OP_DEPLOYER_IMAGE="${OP_DEPLOYER_IMAGE:-us-docker.pkg.dev/oplabs-tools-artifacts/images/op-deployer:v0.4.2}"
WORKDIR="${DEPLOYER_WORKDIR:-.deployer}"
L1_CHAIN_ID="${L1_CHAIN_ID:-11155111}"          # Sepolia by default
L2_CHAIN_ID="${L2_CHAIN_ID:-42069}"
CONTRACTS_LOCATOR="${L1_CONTRACTS_LOCATOR:-tag://op-contracts/v4.0.0}"

: "${L1_RPC_URL:?set L1_RPC_URL in .env}"
: "${DEPLOYER_PRIVATE_KEY:?set DEPLOYER_PRIVATE_KEY in .env (must be funded on L1)}"
command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required"; exit 1; }

mkdir -p "$WORKDIR"
dep() { docker run --rm -v "$PROJECT_DIR/$WORKDIR:/work" "$OP_DEPLOYER_IMAGE" "$@"; }

echo "[1/4] init intent  (L1=$L1_CHAIN_ID  L2=$L2_CHAIN_ID  contracts=$CONTRACTS_LOCATOR)"
if [ ! -f "$WORKDIR/intent.toml" ]; then
  dep init --l1-chain-id "$L1_CHAIN_ID" --l2-chain-ids "$L2_CHAIN_ID" --workdir /work
  echo "    -> review $WORKDIR/intent.toml (roles, funding, contractsLocator) before applying."
fi

echo "[2/4] apply  (deploys L1 contracts with DEPLOYER_PRIVATE_KEY)"
dep apply --workdir /work --l1-rpc-url "$L1_RPC_URL" --private-key "${DEPLOYER_PRIVATE_KEY#0x}"

echo "[3/4] inspect genesis -> genesis.json"
dep inspect genesis --workdir /work "$L2_CHAIN_ID" > genesis.json

echo "[4/4] inspect rollup  -> rollup.json"
dep inspect rollup --workdir /work "$L2_CHAIN_ID" > rollup.json

echo
echo "Done. genesis.json + rollup.json generated."
echo "Next: copy the deployed L2OutputOracle/DisputeGameFactory address into .env"
echo "      (see: scripts/generate-config.sh -> 'op-deployer inspect l1'), then 'make up-sequencer'."
