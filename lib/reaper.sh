# lib/reaper.sh — v0.2.0 story 3: Stale-task reaper.
#
# The orchestrator (bin/sparc-pipeline) marks a task `running` when it
# spawns a stage agent, and writes the agent's PID to a file under
# `~/.hermes/sparc-package/locks/<task-id>.pid`. The reaper checks
# each `running` task on every orchestrator tick:
#
#   - If the PID file is present and the PID is alive (`kill -0 $pid`):
#     the agent is working, just slow. Don't reap. 9-minute deploys are
#     safe because the PID is alive.
#   - If the PID file is present and the PID is dead: the agent
#     crashed (OOM, network, Ctrl-C). Reap. After `max_attempts`
#     reaps, block the task with a [REAP-BLOCKED] comment so the
#     human can intervene.
#   - If the PID file is missing (e.g. the orchestrator daemon was
#     restarted while an agent was running): the agent is no longer
#     under our control. Skip the reap; the next orchestrator tick
#     after the agent finishes will see the task is still `running`
#     and the user can manually intervene. This is the safe default;
#     v0.3.0 can add a time-since-last-activity fallback for this case.
#
# Per-task reap count is stored in the kanban comment thread: each
# reap adds a `[REAPED attempt N/M at T]` line. The reaper counts these
# lines to determine the current attempt number. No sidecar DB
# (consistent with the v0.2.0 story 2 design principle: avoid new
# persistent state outside the kanban when possible).

# Source dependencies. No double-source guard: see lib/kanban.sh for
# the full reasoning. Same pattern applies here.

# sparc_reap_check <db_path> <board> <task_id> <pid_file> <max_attempts>
#
#   See top-of-file comment for the full semantics.
#
#   Args:
#     db_path      — path to the kanban SQLite DB (used for the initial
#                   sanity check; the kanban CLI is used for state changes,
#                   not direct SQL)
#     board       — the kanban board slug
#     task_id     — the task to check
#     pid_file    — path to the file containing the agent's PID. Caller
#                   is responsible for naming the file; convention is
#                   `<pid_file_dir>/<task_id>.pid`
#     max_attempts — reap up to this many times before blocking
#
#   Returns:
#     0 — no reap (agent alive, or no PID file and task too young)
#     1 — reaped (marked ready, comment added)
#     2 — blocked (attempts exhausted)
#     3 — error (kanban CLI failed; caller should log and continue)
#
#   Side effects (only on returns 1 or 2):
#     - Calls `hermes kanban --board X set TASK --status ready|blocked`
#     - Calls `hermes kanban --board X comment TASK "[REAPED attempt N/M ...]"`
#
#   The reaper NEVER removes the PID file. The orchestrator's spawn
#   logic is responsible for cleanup (e.g. on task complete). This
#   keeps the reaper stateless.
sparc_reap_check() {
  local db_path="$1" board="$2" task_id="$3" pid_file="$4" max_attempts="$5"

  # ── Step 1: If PID file is missing, don't reap. ────────────────────
  # We don't have a reliable "is the agent still alive" signal in
  # this case (the orchestrator daemon may have been restarted). The
  # safe default is to leave the task alone and let the next tick
  # after the agent finishes (if it does) reveal a stuck `running`
  # task. The user can then manually intervene.
  if [[ ! -f "$pid_file" ]]; then
    return 0
  fi

  # ── Step 2: If PID is alive, don't reap. ────────────────────────────
  local pid
  pid=$(cat "$pid_file" 2>/dev/null) || {
    echo "  ! reaper: could not read pid_file '$pid_file'" >&2
    return 0  # safe default: don't reap on read error
  }
  if [[ -z "$pid" ]]; then
    return 0
  fi
  if kill -0 "$pid" 2>/dev/null; then
    # PID is alive. Agent is working. Don't reap.
    return 0
  fi

  # ── Step 3: PID is dead. Count previous reaps. ────────────────────
  # The reaper counts the number of [REAPED attempt N/M ...] comments
  # already on the task. The next attempt is N+1.
  #
  # We could use the kanban CLI to get the comments, but for counting
  # the cheaper approach is `grep -c` on the local SQLite. The DB
  # has the comments table; we read task_comments joined with the
  # comment_pattern.
  #
  # Why SQLite here: count() over task_comments is O(n) where n is
  # the number of comments on this task, which is small. The
  # alternative (CLI roundtrip per reap decision) is more expensive.
  local reap_count=0
  if [[ -f "$db_path" ]]; then
    reap_count=$(sqlite3 "$db_path" "SELECT COUNT(*) FROM task_comments
                                       WHERE task_id = '$task_id'
                                       AND body LIKE '[REAPED attempt%'" 2>/dev/null) || reap_count=0
    # shellcheck disable=SC2034  # reap_count is consumed below via $((...))
  fi

  # If the DB query didn't return a number (e.g. empty result or
  # sqlite3 not available), fall back to the kanban CLI.
  if ! [[ "$reap_count" =~ ^[0-9]+$ ]]; then
    reap_count=0
  fi

  # ── Step 4: Decide reap vs block. ─────────────────────────────────
  local next_attempt=$((reap_count + 1))

  if (( next_attempt > max_attempts )); then
    # We've reaped this task max_attempts times. Block it for human
    # intervention. The next orchestrator tick sees the `blocked`
    # status and surfaces the review.
    local block_msg
    block_msg=$(printf '[REAP-BLOCKED at %s] Reaper gave up after %d attempts. Agent PID %s was dead. Human intervention required.' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$max_attempts" "$pid")
    "$SPARC_HERMES_BIN" kanban --board "$board" set "$task_id" --status blocked 2>/dev/null \
      || return 3
    "$SPARC_HERMES_BIN" kanban --board "$board" comment "$task_id" "$block_msg" 2>/dev/null \
      || true
    echo "  ! reaper: blocked $task_id (pid=$pid) after $max_attempts attempts" >&2
    return 2
  fi

  # ── Step 5: Reap. Mark task ready and add a [REAPED] comment. ────
  local reap_msg
  reap_msg=$(printf '[REAPED attempt %d/%d at %s] Agent PID %s was dead. Re-queueing. (Reap count tracked via [REAPED attempt] lines in this comment thread.)' \
    "$next_attempt" "$max_attempts" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$pid")
  "$SPARC_HERMES_BIN" kanban --board "$board" set "$task_id" --status ready 2>/dev/null \
    || return 3
  "$SPARC_HERMES_BIN" kanban --board "$board" comment "$task_id" "$reap_msg" 2>/dev/null \
    || true
  echo "  ! reaper: reaped $task_id (pid=$pid), attempt $next_attempt/$max_attempts" >&2
  return 1
}
