# lib/adapters/hitl/tui.sh — Hermes TUI /kanban slash command adapter.
#
# When the user has a Hermes TUI session open in another terminal, they can
# review the blocked task by running /kanban there. This adapter:
#   1. Writes a marker file to ~/.hermes/sparc-package/hitl/<task>.request
#      that the TUI skill can pick up (if the user has the sparc-pipeline-orchestrator
#      skill loaded in that TUI session, it will print a banner).
#   2. Polls a corresponding .reply file written by the user.
#
# This is intentionally simple — the TUI is the user's primary chat surface
# and they'll have already seen the kanban state in /kanban output. The
# adapter's job is just to unblock the orchestrator when the user has decided.

SPARC_HITL_ADAPTER_NAME="tui"

SPARC_HITL_TUI_DIR="${SPARC_HITL_TUI_DIR:-$HOME/.hermes/sparc-package/hitl}"

hitl_tui_probe() {
  # Always available; user can always open a Hermes TUI to review.
  # We could probe for an active session, but that's racy. Just say yes.
  return 0
}

hitl_tui_notify() {
  local board="$1" task="$2" stage="$3" artifact="$4"
  mkdir -p "$SPARC_HITL_TUI_DIR"
  local reqfile="$SPARC_HITL_TUI_DIR/${task}.request"
  {
    echo "board=$board"
    echo "task=$task"
    echo "stage=$stage"
    echo "artifact=$artifact"
    echo "timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$reqfile"
  echo "  → tui: request written to $reqfile. Run /kanban in your Hermes TUI to review." >&2
  echo "  → tui: when ready, write APPROVE|REDIRECT|REJECT to $SPARC_HITL_TUI_DIR/${task}.reply" >&2
}

hitl_tui_await_reply() {
  local board="$1" task="$2"
  local replyfile="$SPARC_HITL_TUI_DIR/${task}.reply"
  echo "  → tui: waiting for $replyfile (Ctrl-C to cancel)…" >&2
  while [[ ! -f "$replyfile" ]]; do
    sleep 2
  done
  cat "$replyfile"
  rm -f "$replyfile" "${task}.request"
}
