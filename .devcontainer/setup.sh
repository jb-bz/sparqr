#!/usr/bin/env bash
# .devcontainer/setup.sh — Run once after the Codespace is created.
# Installs sparqr's prerequisites (Hermes, jq, sqlite) into the
# dev container. The demo stack comes up via postStartCommand.

set -euo pipefail

echo "  → installing prerequisites..."
apt-get update
apt-get install -y --no-install-recommends \
    sqlite3 \
    jq \
    curl \
    ca-certificates \
    git

echo "  → installing Hermes CLI..."
# Hermes is required for sparqr. The official installer:
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash

echo "  → making demo stack executable..."
chmod +x ./demo/sparqr.sh
chmod +x ./demo/docker-compose.yml

echo ""
echo "  ✓ dev container ready"
echo "  → the demo stack will come up automatically via postStartCommand"
echo "  → open http://localhost:8787 once it's running"
