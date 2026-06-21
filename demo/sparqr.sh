#!/usr/bin/env bash
# demo/sparqr.sh — Hosted demo launcher (v0.4.0 story 2).
#
# Usage:
#   ./demo/sparqr.sh up       Bring up the demo stack
#   ./demo/sparqr.sh down     Tear it down
#   ./demo/sparqr.sh logs     Tail logs from both containers
#   ./demo/sparqr.sh status   Show stack status
#   ./demo/sparqr.sh shell    Open a shell in the sparqr container
#   ./demo/sparqr.sh reset    Down + remove all data, then up
#   ./demo/sparqr.sh help     This help
#
# Detects Docker / OrbStack automatically. OrbStack is faster on
# macOS and is the recommended runtime for local development.
# In CI / Codespaces, Docker is used.
#
# After `./demo/sparqr.sh up`:
#   - Hermes webui is at http://localhost:8787
#   - The demo pipeline runs once in the background; check
#     `./demo/sparqr.sh logs` to watch it

set -euo pipefail

DEMO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$DEMO_DIR/.." && pwd)"
COMPOSE_FILE="$DEMO_DIR/docker-compose.yml"

# ── Runtime detection ──────────────────────────────────────────────────
detect_runtime() {
  # OrbStack first (it's a drop-in Docker replacement with its own
  # binary called 'orb' but with the standard 'docker' CLI shim).
  # If both Docker and OrbStack are installed, prefer OrbStack.
  if command -v orb >/dev/null 2>&1 || [[ -d "$HOME/.orbstack" ]]; then
    echo "orbstack"
    return
  fi
  if command -v docker >/dev/null 2>&1; then
    # Check if Docker is actually OrbStack's docker shim
    if docker version 2>/dev/null | grep -qi "orbstack"; then
      echo "orbstack"
    else
      echo "docker"
    fi
    return
  fi
  echo ""
}

RUNTIME=$(detect_runtime)
COMPOSE_CMD=""

if [[ "$RUNTIME" == "orbstack" ]]; then
  # OrbStack: 'docker' is the shim, 'docker compose' works.
  COMPOSE_CMD="docker compose"
elif [[ "$RUNTIME" == "docker" ]]; then
  COMPOSE_CMD="docker compose"
else
  echo "demo/sparqr.sh: no container runtime found" >&2
  echo "  install Docker: https://docs.docker.com/engine/install/" >&2
  echo "  or OrbStack (macOS): https://orbstack.dev/" >&2
  exit 1
fi

# ── Subcommands ──────────────────────────────────────────────────────
cmd="${1:-help}"
shift || true

case "$cmd" in
  up)
    echo "  → runtime: $RUNTIME"
    echo "  → compose file: $COMPOSE_FILE"
    echo "  → building images (first run takes a few minutes)..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d --build
    echo ""
    echo "  ✓ demo stack is up"
    echo ""
    echo "  Open in browser:  http://localhost:8787"
    echo "  Tail logs:        ./demo/sparqr.sh logs"
    echo "  Shell in sparqr:  ./demo/sparqr.sh shell"
    echo "  Tear down:        ./demo/sparqr.sh down"
    ;;

  down)
    echo "  → stopping stack..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" down
    echo "  ✓ stopped"
    ;;

  logs)
    $COMPOSE_CMD -f "$COMPOSE_FILE" logs -f "${@:-}"
    ;;

  status)
    $COMPOSE_CMD -f "$COMPOSE_FILE" ps
    ;;

  shell)
    $COMPOSE_CMD -f "$COMPOSE_FILE" exec sparqr bash
    ;;

  reset)
    echo "  → tearing down + removing data volumes..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" down -v
    echo "  → bringing up fresh..."
    $COMPOSE_CMD -f "$COMPOSE_FILE" up -d --build
    ;;

  help|--help|-h)
    cat <<'EOF'
sparqr.sh — Hosted demo launcher

Usage:
  ./demo/sparqr.sh up       Bring up the demo stack
  ./demo/sparqr.sh down     Tear it down
  ./demo/sparqr.sh logs     Tail logs (pass service name to filter)
  ./demo/sparqr.sh status   Show stack status
  ./demo/sparqr.sh shell    Open a shell in the sparqr container
  ./demo/sparqr.sh reset    Down + remove all data, then up
  ./demo/sparqr.sh help     This help

Container runtimes:
  OrbStack  - macOS, faster than Docker. Recommended.
  Docker    - universal. Default in CI / Codespaces.

After 'up':
  http://localhost:8787     Hermes webui (kanban board)
  ./demo/sparqr.sh logs     Watch the pipeline run

Demo project mounted at demo/demo-project/. Edit files there and
the changes show up in the running container immediately.
EOF
    ;;

  *)
    echo "demo/sparqr.sh: unknown command: $cmd" >&2
    echo "  try: ./demo/sparqr.sh help" >&2
    exit 2
    ;;
esac
