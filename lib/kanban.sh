# lib/kanban.sh — Thin wrapper around the Hermes Kanban CLI.
#
# Why a wrapper? Three reasons:
#   1. So the orchestrator doesn't have to know whether it's calling
#      `hermes kanban create` (the modern CLI verb) or `hermes kanban boards create`
#      (the board-management verb) — both are wrapped here.
#   2. So the package has one place to add batch atomicity, error handling,
#      and verb-versioning logic.
#   3. So the kanban CLI surface area is mockable for tests (see tests/test_kanban.sh).
#
# All functions return 0 on success, non-zero on failure. On failure, the
# underlying error is logged to stderr. Callers should check the return code.
#
# v0.2.0 — Hermes version compatibility (was story 2 "Kanban CLI compat shim",
# 8 pts; re-sized to 2 pts after design review):
#
#   The original shim design tried to detect-and-fall-back at every call
#   site, which made every function pass a list of candidate verbs.
#   That was the wrong abstraction: the shim added 100+ lines of bash
#   for a problem that's better solved by integration tests in CI.
#
#   The actual story: this file assumes a specific Hermes kanban CLI
#   verb set (see TESTED_AGAINST below). When Hermes renames a verb,
#   the call here breaks. Detection happens two ways:
#     1. Integration tests in tests/integration/ (v0.2.0 story 6) run
#        against real Hermes and catch the breakage on every PR.
#     2. The `set` → `update` dual-verb fallback in sparc_kanban_set_status
#        below covers the one known historical rename.
#
#   If you upgrade Hermes and a verb breaks, the fix is to update the
#   relevant function below. Don't add a shim; add a test case to
#   tests/integration/ that fails with the new verb and update the
#   code accordingly.
#
#   TESTED_AGAINST: Hermes Agent v0.17.0 (2026-06-19 build, upstream
#                   5a53e0f0). Verified by smoke test on 2026-06-19:
#                   board_init, create_task, link, claim (running),
#                   complete (done), block (with reason), promote
#                   (ready), archive, comment all work end-to-end.
#   Last verified: 2026-06-19.
#   Minimum compatible: Hermes v0.17.0 (this is the version we tested
#                    against). Earlier versions may use a different
#                    verb set; not verified.
#   Re-verification: when upgrading Hermes, re-run tests/integration/
#                    with RECORD_REPLAY_MODE=record. Update this comment
#                    only after the recordings succeed.

# No double-source guard: see commit history for the full reasoning.
# Short version: bin/sparc `exec`s subcommand scripts, and `exec`
# doesn't carry function definitions across processes — only env
# vars. The old guard made the child script's source a no-op, so it
# had env vars (SPARC_KANBAN_LOADED=1) but no function definitions.
# Removing the guard fixes `sparc init` failing with
# "sparc_kanban_board_init: command not found".
#
# Re-sourcing is idempotent for our lib files (they only define
# functions and set env vars; no side effects beyond that). If we
# ever add init code that shouldn't run twice, we'll guard that
# specific block, not the whole file.

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
#
# Real Hermes syntax: `kanban --board X create <title> [--parent Y]`
# - title is POSITIONAL, not a --title flag
# - new tasks default to `todo` status; no --status flag
# Creates a task on the board. Title is auto-prefixed with [STAGE].
# Stage name is uppercased and title-cased. Note: we use `awk` for the
# first-character uppercase because bash 3.2 (macOS default) doesn't
# reliably support GNU sed's `\U&` extension — it produces literal
# `\UREFINEMENT` instead of `UREFINEMENT`. The awk equivalent is
# portable across bash 3.2+ and 4+.
sparc_kanban_create_task() {
  local board="$1" stage="$2" title="$3" parent="${4:-}"
  local stage_label
  if [[ "$stage" == "spec" ]]; then
    stage_label="SPEC"
  else
    stage_label=$(echo "$stage" | tr '[:lower:]' '[:upper:]' | awk '{ print toupper(substr($0,1,1)) substr($0,2) }')
  fi
  local prefixed="[$stage_label] $title"
  local args=(kanban --board "$board" create "$prefixed")
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
  # Real Hermes output: "Created t_f64d3191  (ready, assignee=-)"
  # Extract the t_<id> token.
  echo "$out" | grep -oE '\bt_[A-Za-z0-9_-]+' | head -n1 \
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
#
#   Sets the task's status. Dispatches to the right real-Hermes verb:
#     ready    -> hermes kanban --board X promote TASK [reason]
#     done     -> hermes kanban --board X complete TASK
#     blocked  -> hermes kanban --board X block TASK [reason]
#     archived -> hermes kanban --board X archive TASK [reason]
#     running  -> hermes kanban --board X claim TASK (sets claim TTL)
#
#   The legacy `set`/`update --status` verbs do NOT exist on real Hermes.
#   They were placeholders that happened to pass the (also-placeholder)
#   mock layer in v0.1.0/v0.2.0. This dispatcher is the single point of
#   truth for status changes.
#
#   v0.2.0's lib/kanban.sh was written without running against real
#   Hermes; the `set`/`update` verbs were assumed to exist. They
#   don't. Real Hermes uses one verb per status transition.
sparc_kanban_set_status() {
  local board="$1" task="$2" status="$3"
  case "$status" in
    ready)
      "$SPARC_HERMES_BIN" kanban --board "$board" promote "$task" 2>&1
      ;;
    done)
      "$SPARC_HERMES_BIN" kanban --board "$board" complete "$task" 2>&1
      ;;
    blocked)
      "$SPARC_HERMES_BIN" kanban --board "$board" block "$task" "[BLOCKED by sparc-pipeline]" 2>&1
      ;;
    archived)
      "$SPARC_HERMES_BIN" kanban --board "$board" archive "$task" 2>&1
      ;;
    running)
      # Claim with default TTL (15 min). Real Hermes transitions to running
      # via `claim`. The TTL handles crash recovery automatically — if the
      # worker dies, the claim expires and the task goes back to ready.
      # This is BETTER than v0.2.0's hand-rolled PID-based reaper.
      "$SPARC_HERMES_BIN" kanban --board "$board" claim "$task" 2>&1
      ;;
    *)
      echo "sparc_kanban_set_status: unknown status: $status" >&2
      return 64  # EX_USAGE
      ;;
  esac
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

# sparc_kanban_watch_running <board>
# Echoes one line per task currently in "running" state. Format: <task_id>\t<title>
# Used by the reaper (v0.2.0 story 3) to find tasks whose agents may have crashed.
sparc_kanban_watch_running() {
  local board="$1"
  "$SPARC_HERMES_BIN" kanban --board "$board" list --status running 2>/dev/null \
    | awk -F'\t' 'NF>=3 {print $1 "\t" $3}'
}

# sparc_kanban_event_log <board> <task_id> [--limit N]
# Prints the recent event log for a task, oldest first.
# Each line: <id>\t<created_at_human>\t<kind>\t<payload_excerpt>
# Useful for "what just happened to this task?" debugging.
#
# Real Hermes stores task events in a SQLite DB. We find the path
# via `kanban boards show <slug>` (which prints `DB path:`) instead
# of parsing `boards list` output (which doesn't include paths).
sparc_kanban_event_log() {
  local board="$1" task_id="$2"
  local limit=50
  [[ "${3:-}" == "--limit" && -n "${4:-}" ]] && limit="$4"

  # Find the board's DB path via `boards show`
  local db_path
  db_path=$("$SPARC_HERMES_BIN" kanban boards show "$board" 2>/dev/null \
    | awk -F': *' '/^  DB path:/ { print $2; exit }')
  # Fallback: try the default-board layout
  if [[ -z "$db_path" || ! -f "$db_path" ]]; then
    db_path="$HOME/.hermes/kanban.db"
  fi
  [[ -f "$db_path" ]] || { echo "sparc_kanban_event_log: db not found for board '$board'" >&2; return 1; }

  # Read events for the task. We use sqlite3 directly because the events table
  # is internal to Hermes (not exposed via the kanban CLI verb surface).
  sqlite3 "$db_path" -header -column \
    "SELECT id, datetime(created_at, 'unixepoch') AS at, kind, substr(payload, 1, 80) AS payload
     FROM task_events
     WHERE task_id = '$task_id'
     ORDER BY id DESC
     LIMIT $limit;" 2>/dev/null
}

# sparc_kanban_list <board> <status>
# Echoes the raw kanban list output for the given board and status.
# Useful when callers need full task details (id, stage, title,
# assignee) — not just the tab-separated view that watch_* returns.
#
# Output format (verified 2026-06-20 against real Hermes v0.17.0):
#   Board: <slug> (N other boards ...)
#
#   ▶ t_<id>  ready     (unassigned)          [STAGE] title
#   ✓ t_<id>  done      (reviewer)            [STAGE] title
#   ⏸ t_<id>  blocked   (reviewer)            [STAGE] title
#
# Returns the raw output. Callers should parse it themselves; this
# function is intentionally thin so it can be used both for human
# display and for record-replay fixtures.
sparc_kanban_list() {
  local board="$1" status="${2:-}"
  local args=(kanban --board "$board" list)
  [[ -n "$status" ]] && args+=(--status "$status")
  "$SPARC_HERMES_BIN" "${args[@]}" 2>/dev/null
}

# sparc_kanban_boards_list
# Echoes one board per line, with the leading status marker
# (●/○) and any trailing counts intact. Format (verified
# 2026-06-20 against real Hermes v0.17.0):
#
#   SLUG                      NAME                          COUNTS
#   ●   default               Default                       ready=1
#       spike-test            Spike test                    archived=3
#
#   Current board: default
#   Switch boards with `hermes kanban boards switch <slug>`.
#
# Callers parse the slug out of the first whitespace-separated
# token on each non-header line.
sparc_kanban_boards_list() {
  "$SPARC_HERMES_BIN" kanban boards list 2>/dev/null
}
