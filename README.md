# OP Stack + Reth Deployment

Docker Compose configuration for deploying an OP Stack rollup with Reth as the execution client.

## Components

| Service | Description | Port |
|---------|-------------|------|
| `op-reth` | Reth execution client (OP mode) | 8545 (HTTP), 8546 (WS) |
| `op-node` | OP consensus client | 8547 |
| `op-batcher` | Submits tx batches to L1 | 8548 |
| `op-proposer` | Proposes state roots to L1 | 8549 |
| `prometheus` | Metrics collection | 9090 |
| `grafana` | Metrics dashboard | 3000 |

## Prerequisites

1. L1 RPC endpoint (Alchemy, Infura, or self-hosted)
2. L1 Beacon node endpoint
3. Funded wallets for batcher and proposer on L1
4. Deploy L1 contracts using Optimism monorepo

## Quick Start

```bash
# 1. Run setup script
./scripts/setup.sh

# 2. Edit configuration
vim .env

# 3. Generate genesis files (see Optimism docs)
# Place genesis.json and rollup.json in this directory

# 4. Start the stack
docker compose --profile sequencer up -d
```

## Deployment Modes

### Replica Mode (Read-only)
```bash
docker compose up -d op-reth op-node
```

### Sequencer Mode (Full)
```bash
docker compose --profile sequencer up -d
```

### With Monitoring
```bash
docker compose --profile sequencer --profile monitoring up -d
```

## Generating Genesis Files

You need to generate `genesis.json` and `rollup.json` using the Optimism monorepo:

```bash
git clone https://github.com/ethereum-optimism/optimism.git
cd optimism

# Configure your chain in packages/contracts-bedrock/deploy-config/
# Then deploy contracts and generate genesis
```

See: https://docs.optimism.io/builders/chain-operators/tutorials/create-l2-rollup

## Configuration

Copy `.env.example` to `.env` and configure:

- `L1_RPC_URL` - Ethereum RPC endpoint
- `L1_BEACON_URL` - Beacon chain endpoint
- `BATCHER_PRIVATE_KEY` - Funded L1 wallet for batcher
- `PROPOSER_PRIVATE_KEY` - Funded L1 wallet for proposer
- `L2_OUTPUT_ORACLE_ADDRESS` - L2OutputOracle contract on L1

## Useful Commands

```bash
# View logs
docker compose logs -f op-reth
docker compose logs -f op-node

# Check sync status
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' \
  http://localhost:8547

# Stop all services
docker compose --profile sequencer --profile monitoring down

# Reset data (DESTRUCTIVE)
docker compose down -v
```

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                    L2 (Your Rollup)                 │
│  ┌─────────────┐    ┌─────────────┐                │
│  │   op-node   │◄──►│   op-reth   │                │
│  │ (consensus) │    │ (execution) │                │
│  └──────┬──────┘    └─────────────┘                │
│         │                                           │
│  ┌──────▼──────┐    ┌─────────────┐                │
│  │ op-batcher  │    │ op-proposer │                │
│  └──────┬──────┘    └──────┬──────┘                │
└─────────┼──────────────────┼───────────────────────┘
          │                  │
          ▼                  ▼
┌─────────────────────────────────────────────────────┐
│              L1 (Ethereum Mainnet/Sepolia)          │
└─────────────────────────────────────────────────────┘
```
