# lib/adapters/hitl/workspace.sh — Adapter for outsourc-e/hermes-workspace on :3000.
#
# hermes-workspace has a Kanban TaskBoard with a "Reports + Inbox" surface
# designed for human decisions. Its Swarm Mode Conductor can be driven by
# external dispatchers. This adapter pushes HITL requests to the workspace
# inbox and polls for a decision.
#
# Reference: https://github.com/outsourc-e/hermes-workspace
# Requires: API_SERVER_ENABLED=true on the gateway (port 8642) for full
#           mission dispatch, but for plain HITL the workspace web inbox is
#           sufficient.

SPARC_HITL_ADAPTER_NAME="workspace"

# Default URLs. Override via SPARC_WORKSPACE_URL env var.
SPARC_HITL_WORKSPACE_URL="${SPARC_HITL_WORKSPACE_URL:-http://127.0.0.1:3000}"

hitl_workspace_probe() {
  command -v curl >/dev/null || return 1
  curl -fsS --max-time 2 "$SPARC_HITL_WORKSPACE_URL/api/health" >/dev/null 2>&1 \
    || curl -fsS --max-time 2 "$SPARC_HITL_WORKSPACE_URL/" >/dev/null 2>&1
}

hitl_workspace_notify() {
  local board="$1" task="$2" stage="$3" artifact="$4"
  local payload
  payload=$(jq -nc \
    --arg board "$board" \
    --arg task "$task" \
    --arg stage "$stage" \
    --arg artifact "$artifact" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{board:$board, task:$task, stage:$stage, artifact:$artifact, timestamp:$ts, kind:"hitl_review", lane:"review"}')
  curl -fsS --max-time 5 -X POST \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$SPARC_HITL_WORKSPACE_URL/api/inbox" 2>&1 || {
      echo "  ! workspace: failed to POST to $SPARC_HITL_WORKSPACE_URL/api/inbox" >&2
      return 1
    }
  echo "  → workspace: review request pushed to $SPARC_HITL_WORKSPACE_URL (inbox)" >&2
}

hitl_workspace_await_reply() {
  local board="$1" task="$2"
  echo "  → workspace: polling $SPARC_HITL_WORKSPACE_URL/api/inbox/$task/decision (Ctrl-C to cancel)…" >&2
  while true; do
    local reply
    reply=$(curl -fsS --max-time 5 "$SPARC_HITL_WORKSPACE_URL/api/inbox/$task/decision" 2>/dev/null) || reply=""
    if [[ -n "$reply" && "$reply" != "null" ]]; then
      echo "$reply"
      curl -fsS --max-time 5 -X DELETE "$SPARC_HITL_WORKSPACE_URL/api/inbox/$task/decision" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 3
  done
}
