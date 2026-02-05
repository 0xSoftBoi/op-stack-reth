#!/bin/bash
# Generate a JWT secret for op-node <-> reth communication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

JWT_FILE="$PROJECT_DIR/jwt.hex"

if [ -f "$JWT_FILE" ]; then
    echo "JWT secret already exists at $JWT_FILE"
    echo "Delete it first if you want to regenerate."
    exit 0
fi

# Generate 32 random bytes as hex
openssl rand -hex 32 > "$JWT_FILE"

echo "Generated JWT secret at $JWT_FILE"
echo "Content: $(cat "$JWT_FILE")"
