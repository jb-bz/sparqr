# lib/kanban.sh — Thin wrapper around the Hermes Kanban CLI.
#
# Why a wrapper? Two reasons:
#   1. So the orchestrator doesn't have to know whether it's calling
#      `hermes kanban create` (the modern CLI verb) or `hermes kanban boards create`
#      (the board-management verb) — both are wrapped here.
#   2. So the package has one place to add batch atomicity, error handling,
#      and fallback behavior if a Hermes CLI verb changes.
#
# All functions return 0 on success, non-zero on failure. On failure, the
# underlying error is logged to stderr. Callers should check the return code.

# Guard against double-sourcing
if [[ -n "${SPARC_KANBAN_LOADED:-}" ]]; then
  return 0
fi
export SPARC_KANBAN_LOADED=1

# Path to the Hermes CLI. Override via SPARC_HERMES_BIN env var if needed.
SPARC_HERMES_BIN="${SPARC_HERMES_BIN:-hermes}"

# sparc_kanban_board_init <board-slug> [--name "Display Name"] [--icon "🎯"]
# Creates a board if it doesn't exist, then switches to it.
# Idempotent.
sparc_kanban_board_init() {
  local slug="$1"; shift
  local name="" icon="🎯"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --icon) icon="$2"; shift 2 ;;
      *)      shift ;;
    esac
  done
  [[ -z "$name" ]] && name="$slug"

  # Check if board already exists
  if "$SPARC_HERMES_BIN" kanban boards list 2>/dev/null | grep -qE "(^|[[:space:]])${slug}([[:space:]]|$)"; then
    echo "  ✓ board '$slug' already exists" >&2
    return 0
  fi

  echo "  → creating board '$slug'…" >&2
  "$SPARC_HERMES_BIN" kanban boards create "$slug" --name "$name" --icon "$icon" --switch
}

# sparc_kanban_create_task <board> <stage> <title> [parent_task_id]
# Creates a task on the board. Title is auto-prefixed with [STAGE].
# Returns the new task ID on stdout.
sparc_kanban_create_task() {
  local board="$1" stage="$2" title="$3" parent="${4:-}"
  local prefixed="[$([ "$stage" = "spec" ] && echo "SPEC" || echo "$(echo "$stage" | tr '[:lower:]' '[:upper:]' | sed 's/^./\U&/')")] $title"
  local args=(kanban --board "$board" create --title "$prefixed" --status todo)
  if [[ -n "$parent" ]]; then
    args+=(--parent "$parent")
  fi
  local out
  out=$("$SPARC_HERMES_BIN" "${args[@]}" 2>&1)
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "sparc_kanban_create_task: failed (rc=$rc): $out" >&2
    return $rc
  fi
  # The CLI prints the new task ID on the last line, prefixed with "id: " or
  # similar. Try a few common patterns.
  echo "$out" | grep -oE 'task[_ -]?id[: ]+[A-Za-z0-9_-]+' | head -n1 | awk '{print $NF}' \
    || echo "$out" | tail -n1
}

# sparc_kanban_link <board> <parent_task_id> <child_task_id>
# Records a parent→child dependency. Idempotent (kanban tolerates re-link).
sparc_kanban_link() {
  local board="$1" parent="$2" child="$3"
  "$SPARC_HERMES_BIN" kanban --board "$board" link "$parent" "$child" 2>&1 \
    || echo "  ! link may have already existed (rc=$?)" >&2
  return 0
}

# sparc_kanban_set_status <board> <task_id> <status>
# Sets the task's status. The hermes kanban CLI uses "set" or "update" depending
# on version; try set first, fall back to update.
sparc_kanban_set_status() {
  local board="$1" task="$2" status="$3"
  "$SPARC_HERMES_BIN" kanban --board "$board" set "$task" --status "$status" 2>/dev/null \
    || "$SPARC_HERMES_BIN" kanban --board "$board" update "$task" --status "$status" 2>&1
}

# sparc_kanban_comment <board> <task_id> <comment>
# Appends a comment to the task. Used by stage agents to attach artifacts and
# by the reviewer to attach decision notes.
sparc_kanban_comment() {
  local board="$1" task="$2" comment="$3"
  "$SPARC_HERMES_BIN" kanban --board "$board" comment "$task" "$comment" 2>&1
}

# sparc_kanban_block <board> <task_id> <reason>
# Sets status to blocked and records the reason. Used by the reviewer profile.
sparc_kanban_block() {
  local board="$1" task="$2" reason="$3"
  sparc_kanban_set_status "$board" "$task" "blocked"
  sparc_kanban_comment "$board" "$task" "[BLOCKED] $reason"
}

# sparc_kanban_unblock <board> <task_id> <resolution>
# Sets status back to done (gate passed) and records the resolution.
sparc_kanban_unblock() {
  local board="$1" task="$2" resolution="$3"
  sparc_kanban_set_status "$board" "$task" "done"
  sparc_kanban_comment "$board" "$task" "[UNBLOCKED] $resolution"
}

# sparc_kanban_complete <board> <task_id>
# Marks the task done. Used by stage agents.
sparc_kanban_complete() {
  local board="$1" task="$2"
  sparc_kanban_set_status "$board" "$task" "done"
}

# sparc_kanban_watch_ready <board>
# Echoes one line per task currently in "ready" state. Format: <task_id>\t<title>
# The orchestrator daemon polls this. (For high-frequency pipelines, replace
# with a kanban event subscription, but the kanban CLI doesn't expose one yet.)
sparc_kanban_watch_ready() {
  local board="$1"
  "$SPARC_HERMES_BIN" kanban --board "$board" list --status ready 2>/dev/null \
    | awk -F'\t' 'NF>=3 {print $1 "\t" $3}'
}

# sparc_kanban_watch_blocked <board>
# Echoes one line per task currently in "blocked" state. Format: <task_id>\t<title>
sparc_kanban_watch_blocked() {
  local board="$1"
  "$SPARC_HERMES_BIN" kanban --board "$board" list --status blocked 2>/dev/null \
    | awk -F'\t' 'NF>=3 {print $1 "\t" $3}'
}
