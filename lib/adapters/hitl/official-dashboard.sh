# lib/adapters/hitl/official-dashboard.sh — Adapter for the built-in `hermes dashboard` on :9119.
#
# The first-party `hermes dashboard` (shipped via `pip install hermes-agent[web,pty]`)
# has a Kanban tab. It exposes an API on the same port.
#
# Reference: https://hermes-agent.nousresearch.com/docs/user-guide/features/web-dashboard

SPARC_HITL_ADAPTER_NAME="official-dashboard"

SPARC_HITL_DASHBOARD_URL="${SPARC_HITL_DASHBOARD_URL:-http://127.0.0.1:9119}"

hitl_official-dashboard_probe() {
  command -v curl >/dev/null || return 1
  curl -fsS --max-time 2 "$SPARC_HITL_DASHBOARD_URL/api/status" >/dev/null 2>&1 \
    || curl -fsS --max-time 2 "$SPARC_HITL_DASHBOARD_URL/" >/dev/null 2>&1
}

hitl_official-dashboard_notify() {
  local board="$1" task="$2" stage="$3" artifact="$4"
  local payload
  payload=$(jq -nc \
    --arg board "$board" \
    --arg task "$task" \
    --arg stage "$stage" \
    --arg artifact "$artifact" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{board:$board, task:$task, stage:$stage, artifact:$artifact, timestamp:$ts, kind:"sparc_hitl"}')
  curl -fsS --max-time 5 -X POST \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$SPARC_HITL_DASHBOARD_URL/api/kanban/hitl" 2>&1 || {
      echo "  ! dashboard: failed to POST to $SPARC_HITL_DASHBOARD_URL/api/kanban/hitl" >&2
      return 1
    }
  echo "  → dashboard: review request pushed to $SPARC_HITL_DASHBOARD_URL (kanban tab)" >&2
}

hitl_official-dashboard_await_reply() {
  local board="$1" task="$2"
  echo "  → dashboard: polling $SPARC_HITL_DASHBOARD_URL/api/kanban/hitl/$task/decision (Ctrl-C to cancel)…" >&2
  while true; do
    local reply
    reply=$(curl -fsS --max-time 5 "$SPARC_HITL_DASHBOARD_URL/api/kanban/hitl/$task/decision" 2>/dev/null) || reply=""
    if [[ -n "$reply" && "$reply" != "null" ]]; then
      echo "$reply"
      curl -fsS --max-time 5 -X DELETE "$SPARC_HITL_DASHBOARD_URL/api/kanban/hitl/$task/decision" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 3
  done
}
