.PHONY: help setup init jwt env build pull \
        up down restart \
        up-replica up-sequencer up-monitoring up-all \
        down-all stop \
        logs logs-reth logs-node logs-batcher logs-proposer \
        status sync-status health \
        shell-reth shell-node \
        clean clean-data clean-all \
        ps top

# Default target
help:
	@echo "OP Stack + Reth Deployment"
	@echo ""
	@echo "Setup:"
	@echo "  make setup          - Run full setup (jwt + env)"
	@echo "  make init           - Alias for setup"
	@echo "  make jwt            - Generate JWT secret"
	@echo "  make env            - Create .env from template"
	@echo "  make pull           - Pull latest Docker images"
	@echo ""
	@echo "Start/Stop:"
	@echo "  make up             - Start replica (reth + op-node)"
	@echo "  make up-replica     - Start replica mode"
	@echo "  make up-sequencer   - Start full sequencer stack"
	@echo "  make up-monitoring  - Start with monitoring (Prometheus + Grafana)"
	@echo "  make up-all         - Start everything"
	@echo "  make down           - Stop all services"
	@echo "  make restart        - Restart all services"
	@echo ""
	@echo "Logs:"
	@echo "  make logs           - Follow all logs"
	@echo "  make logs-reth      - Follow Reth logs"
	@echo "  make logs-node      - Follow op-node logs"
	@echo "  make logs-batcher   - Follow op-batcher logs"
	@echo "  make logs-proposer  - Follow op-proposer logs"
	@echo ""
	@echo "Status:"
	@echo "  make ps             - Show running containers"
	@echo "  make status         - Show container status"
	@echo "  make sync-status    - Check L2 sync status"
	@echo "  make health         - Check all service health"
	@echo "  make top            - Show container resource usage"
	@echo ""
	@echo "Debug:"
	@echo "  make shell-reth     - Open shell in Reth container"
	@echo "  make shell-node     - Open shell in op-node container"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Stop and remove containers"
	@echo "  make clean-data     - Remove all data volumes (DESTRUCTIVE)"
	@echo "  make clean-all      - Remove containers, volumes, and images"

# ============================================
# Setup
# ============================================

setup: jwt env
	@echo ""
	@echo "Setup complete!"
	@echo "Next steps:"
	@echo "  1. Edit .env with your configuration"
	@echo "  2. Add genesis.json and rollup.json"
	@echo "  3. Run 'make up-sequencer' to start"

init: setup

jwt:
	@if [ -f jwt.hex ]; then \
		echo "JWT secret already exists"; \
	else \
		openssl rand -hex 32 > jwt.hex; \
		echo "Generated jwt.hex"; \
	fi

env:
	@if [ -f .env ]; then \
		echo ".env already exists"; \
	else \
		cp .env.example .env; \
		echo "Created .env from .env.example"; \
		echo "IMPORTANT: Edit .env with your configuration!"; \
	fi

pull:
	docker compose pull

build:
	docker compose build

# ============================================
# Start Services
# ============================================

up: up-replica

up-replica:
	@echo "Starting replica mode (reth + op-node)..."
	docker compose up -d op-reth op-node

up-sequencer:
	@echo "Starting sequencer mode..."
	docker compose --profile sequencer up -d

up-monitoring:
	@echo "Starting with monitoring..."
	docker compose --profile sequencer --profile monitoring up -d

up-all: up-monitoring

# ============================================
# Stop Services
# ============================================

down:
	docker compose --profile sequencer --profile monitoring down

stop: down

restart: down up-sequencer

# ============================================
# Logs
# ============================================

logs:
	docker compose --profile sequencer --profile monitoring logs -f

logs-reth:
	docker compose logs -f op-reth

logs-node:
	docker compose logs -f op-node

logs-batcher:
	docker compose logs -f op-batcher

logs-proposer:
	docker compose logs -f op-proposer

# ============================================
# Status & Health
# ============================================

ps:
	docker compose --profile sequencer --profile monitoring ps

status: ps

sync-status:
	@echo "Checking L2 sync status..."
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' \
		http://localhost:8547 | jq . || echo "op-node not responding"

health:
	@echo "=== Service Health ==="
	@echo ""
	@echo "op-reth (8545):"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result // "NOT RESPONDING"' || echo "NOT RESPONDING"
	@echo ""
	@echo "op-node (8547):"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' \
		http://localhost:8547 | jq -r '.result.head_l2.number // "NOT RESPONDING"' || echo "NOT RESPONDING"
	@echo ""
	@echo "op-batcher (8548):"
	@curl -s http://localhost:8548/healthz && echo "OK" || echo "NOT RESPONDING"
	@echo ""
	@echo "op-proposer (8549):"
	@curl -s http://localhost:8549/healthz && echo "OK" || echo "NOT RESPONDING"

top:
	docker compose --profile sequencer --profile monitoring top

# ============================================
# Debug
# ============================================

shell-reth:
	docker compose exec op-reth /bin/sh

shell-node:
	docker compose exec op-node /bin/sh

# ============================================
# RPC Helpers
# ============================================

block-number:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs printf "%d\n"

chain-id:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs printf "%d\n"

gas-price:
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs printf "%d wei\n"

# ============================================
# Cleanup
# ============================================

clean:
	docker compose --profile sequencer --profile monitoring down --remove-orphans

clean-data:
	@echo "WARNING: This will delete all chain data!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose --profile sequencer --profile monitoring down -v

clean-all:
	@echo "WARNING: This will delete all data and images!"
	@read -p "Are you sure? [y/N] " confirm && [ "$$confirm" = "y" ] || exit 1
	docker compose --profile sequencer --profile monitoring down -v --rmi all
