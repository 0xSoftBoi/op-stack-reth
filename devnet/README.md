# OP Stack Devnet (Local Testing)

Quick local testing using Optimism's devnet.

## Setup

```bash
# Clone optimism monorepo
git clone https://github.com/ethereum-optimism/optimism.git
cd optimism

# Start devnet (includes L1 + L2 + all services)
make devnet-up

# This starts:
# - Local L1 (geth)
# - op-geth (L2 execution)
# - op-node (L2 consensus)
# - op-batcher
# - op-proposer
```

## Extract Genesis Files

Once devnet is running, extract the genesis files:

```bash
# From optimism directory
cp .devnet/genesis-l2.json ~/op-stack-reth/genesis.json
cp .devnet/rollup.json ~/op-stack-reth/rollup.json
cp .devnet/jwt.txt ~/op-stack-reth/jwt.hex
```

## Stop Devnet

```bash
make devnet-down
make devnet-clean  # removes all data
```
