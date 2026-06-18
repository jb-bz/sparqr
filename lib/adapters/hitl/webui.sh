# lib/adapters/hitl/webui.sh — Adapter for nesquena/hermes-webui on :8787.
#
# hermes-webui has a built-in kanban panel (see api/kanban_bridge.py, 1,297 lines).
# This adapter pushes the review request to the webui via its API and polls
# for a reply. If the webui is not running, the probe returns 1 and the
# setup wizard will not offer it.
#
# Reference: https://github.com/nesquena/hermes-webui

SPARC_HITL_ADAPTER_NAME="webui"

# Default URL. Override via SPARC_WEBUI_URL env var.
SPARC_HITL_WEBUI_URL="${SPARC_HITL_WEBUI_URL:-http://127.0.0.1:8787}"

hitl_webui_probe() {
  command -v curl >/dev/null || return 1
  curl -fsS --max-time 2 "$SPARC_HITL_WEBUI_URL/api/health" >/dev/null 2>&1 \
    || curl -fsS --max-time 2 "$SPARC_HITL_WEBUI_URL/health" >/dev/null 2>&1 \
    || curl -fsS --max-time 2 "$SPARC_HITL_WEBUI_URL/" >/dev/null 2>&1
}

hitl_webui_notify() {
  local board="$1" task="$2" stage="$3" artifact="$4"
  local payload
  payload=$(jq -nc \
    --arg board "$board" \
    --arg task "$task" \
    --arg stage "$stage" \
    --arg artifact "$artifact" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{board:$board, task:$task, stage:$stage, artifact:$artifact, timestamp:$ts, kind:"sparc_hitl_request"}')
  curl -fsS --max-time 5 -X POST \
    -H 'Content-Type: application/json' \
    -d "$payload" \
    "$SPARC_HITL_WEBUI_URL/api/kanban/hitl" 2>&1 || {
      echo "  ! webui: failed to POST to $SPARC_HITL_WEBUI_URL/api/kanban/hitl (fall back to terminal?)" >&2
      return 1
    }
  echo "  → webui: review request pushed to $SPARC_HITL_WEBUI_URL" >&2
}

hitl_webui_await_reply() {
  local board="$1" task="$2"
  echo "  → webui: polling $SPARC_HITL_WEBUI_URL/api/kanban/hitl/$task/reply (Ctrl-C to cancel)…" >&2
  while true; do
    local reply
    reply=$(curl -fsS --max-time 5 "$SPARC_HITL_WEBUI_URL/api/kanban/hitl/$task/reply" 2>/dev/null) || reply=""
    if [[ -n "$reply" && "$reply" != "null" ]]; then
      echo "$reply"
      # Tell webui we consumed it
      curl -fsS --max-time 5 -X DELETE "$SPARC_HITL_WEBUI_URL/api/kanban/hitl/$task/reply" >/dev/null 2>&1 || true
      return 0
    fi
    sleep 3
  done
}
