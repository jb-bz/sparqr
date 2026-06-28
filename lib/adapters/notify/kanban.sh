# lib/adapters/notify/kanban.sh — Notify channel: post as a Hermes Kanban comment.
#
# Always-on (no credentials needed). Posts the notification to a
# special "sparqr-system" task on the same board, so users see it
# in their kanban client. If the system task doesn't exist, it's
# auto-created on first notify.
#
# Env vars (all optional):
#   SPARC_KANBAN_SYSTEM_TASK_PREFIX  — task name prefix for system
#                                      notifications. Default: "sparqr-".
#                                      The actual task name is
#                                      "<prefix><channel>" so users can
#                                      see "sparqr-discord".

# notify_kanban_probe
# Always returns 0.
notify_kanban_probe() {
  return 0
}

# notify_kanban_send <title> <body> [<url>]
# Posts the notification to a system task. Falls back to no-op if
# the kanban DB is unreachable (the HITL pipeline is the source
# of truth for stage transitions, not this adapter).
notify_kanban_send() {
  local title="$1" body="$2" url="${3:-}"
  # If SPARC_BOARD isn't set, we can't post; bail silently.
  if [[ -z "${SPARC_BOARD:-}" ]]; then
    return 0
  fi
  # Use Hermes CLI to post a comment. If the board doesn't exist,
  # Hermes will error; we don't try to create the system task here.
  if command -v hermes >/dev/null 2>&1; then
    local prefix="${SPARC_KANBAN_SYSTEM_TASK_PREFIX:-sparqr-}"
    local sys_task="${prefix}notify"
    local comment="$title: $body"
    [[ -n "$url" ]] && comment="$comment ($url)"
    hermes kanban --board "$SPARC_BOARD" comment "$sys_task" "$comment" 2>/dev/null || true
  fi
}
