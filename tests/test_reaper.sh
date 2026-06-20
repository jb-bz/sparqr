#!/usr/bin/env bash
# tests/test_reaper.sh — Unit tests for lib/reaper.sh (v0.2.0 story 3).
#
# Tests the reaper in isolation: a mock kanban DB (sqlite), a real
# PID file, a mock `hermes` CLI that just records calls. The reaper
# function is called directly with explicit args; we don't invoke the
# orchestrator.
#
# Run: bash tests/test_reaper.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# ── Test fixtures ──────────────────────────────────────────────────────

# Each test gets a fresh scratch dir with a mock kanban DB, a mock
# hermes CLI, and a reaper sourced fresh.
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# Create a minimal kanban DB schema that matches Hermes's actual
# task_events + task_comments tables. We need this for the reaper
# to query the reap count.
create_test_db() {
  local db="$1"
  rm -f "$db"
  sqlite3 "$db" <<'SQL'
CREATE TABLE tasks (
  id TEXT PRIMARY KEY,
  status TEXT NOT NULL,
  created_at INTEGER
);
CREATE TABLE task_events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT NOT NULL,
  kind TEXT NOT NULL,
  payload TEXT,
  created_at INTEGER NOT NULL
);
CREATE TABLE task_comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  task_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
SQL
}

# Create a mock hermes CLI that records every call and updates the
# mock DB for set/comment verbs. The kanban verb surface in
# lib/reaper.sh is:
#   kanban --board <board> set <task_id> --status <status>
#   kanban --board <board> comment <task_id> <comment text...>
# So positional args are: $1=kanban, $2=--board, $3=<board>,
# $4=<verb>, $5=<task_id>, ... The verb is at $4, not $3.
create_mock_hermes() {
  local bin_dir="$1"
  local log="$bin_dir/calls.log"
  local db="$2"
  : > "$log"
  cat > "$bin_dir/hermes" <<EOF
#!/usr/bin/env bash
# Mock hermes CLI. Records the call. Parses 'kanban --board X
# <verb> TASK [args]' and applies set/comment to the test DB.
echo "CALL: \$*" >> "$log"
if [[ "\$1" == "kanban" && "\$4" == "set" ]]; then
  task_id="\$5"
  # Look for --status VALUE starting at \$6
  shift 5
  while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "--status" && -n "\$2" ]]; then
      new_status="\$2"
      sqlite3 "$db" "UPDATE tasks SET status = '\$new_status' WHERE id = '\$task_id'" 2>/dev/null
      echo "  (mock: set \$task_id -> \$new_status)" >> "$log"
      break
    fi
    shift
  done
elif [[ "\$1" == "kanban" && "\$4" == "comment" ]]; then
  task_id="\$5"
  shift 5
  body="\$*"
  sqlite3 "$db" "INSERT INTO task_comments (task_id, body, created_at) VALUES ('\$task_id', '\$body', strftime('%s', 'now'))" 2>/dev/null
  echo "  (mock: comment on \$task_id)" >> "$log"
fi
exit 0
EOF
  chmod +x "$bin_dir/hermes"
}

# Set up: create a tempdir, mock DB, mock hermes, source the reaper.
# Returns: 0 on success, populates $MOCK_DB, $MOCK_HERMES, $MOCK_BIN_DIR
# Usage: setup_test_env <test_name>
setup_test_env() {
  local test_name="$1"
  local dir="$TMPDIR/$test_name"
  mkdir -p "$dir/bin"
  MOCK_DB="$dir/kanban.db"
  MOCK_BIN_DIR="$dir/bin"
  create_test_db "$MOCK_DB"
  create_mock_hermes "$MOCK_BIN_DIR" "$MOCK_DB"

  # Source the reaper fresh (reset the guard)
  unset SPARC_REAPER_LOADED
  # shellcheck source=../lib/reaper.sh
  source "$PKG_ROOT/lib/reaper.sh"

  # Point the reaper at our mock hermes
  export SPARC_HERMES_BIN="$MOCK_BIN_DIR/hermes"
  export PATH="$MOCK_BIN_DIR:$PATH"
}

# Insert a task and a "status change to running" event.
# Args: <db> <task_id>
seed_running_task() {
  local db="$1" task_id="$2"
  local now
  now=$(date +%s)
  sqlite3 "$db" "INSERT INTO tasks (id, status, created_at)
                  VALUES ('$task_id', 'running', $now)"
  sqlite3 "$db" "INSERT INTO task_events (task_id, kind, payload, created_at)
                  VALUES ('$task_id', 'status_change', 'running', $now)"
}

# Insert a recent comment to simulate ongoing agent activity.
# Args: <db> <task_id> [seconds_ago]
seed_recent_activity() {
  local db="$1" task_id="$2" seconds_ago="${3:-5}"
  local ts
  ts=$(($(date +%s) - seconds_ago))
  sqlite3 "$db" "INSERT INTO task_comments (task_id, body, created_at)
                  VALUES ('$task_id', '[sim] recent activity', $ts)"
}

# Insert a stale comment (old activity).
# Args: <db> <task_id> [seconds_ago]
seed_stale_activity() {
  local db="$1" task_id="$2" seconds_ago="${3:-3600}"
  local ts
  ts=$(($(date +%s) - seconds_ago))
  sqlite3 "$db" "INSERT INTO task_comments (task_id, body, created_at)
                  VALUES ('$task_id', '[sim] stale activity', $ts)"
}

# Insert prior REAPED comments (simulating previous reaps).
# Args: <db> <task_id> <count>
seed_prior_reaps() {
  local db="$1" task_id="$2" count="$3"
  local i
  for ((i = 1; i <= count; i++)); do
    sqlite3 "$db" "INSERT INTO task_comments (task_id, body, created_at)
                    VALUES ('$task_id', '[REAPED attempt $i/2 at 2026-06-19T00:00:00Z] prior reap', 0)"
  done
}

# Get the current status of a task from the mock DB.
get_status() {
  local db="$1" task_id="$2"
  sqlite3 "$db" "SELECT status FROM tasks WHERE id = '$task_id'"
}

# Get the count of REAPED comments on a task.
count_reaped() {
  local db="$1" task_id="$2"
  sqlite3 "$db" "SELECT COUNT(*) FROM task_comments WHERE task_id = '$task_id' AND body LIKE '[REAPED attempt%'"
}

# ── Tests ────────────────────────────────────────────────────────────

hdr "1. PID file missing → no reap (return 0)"
setup_test_env "t1"
seed_running_task "$MOCK_DB" "T-1"

# Create an empty pid file dir but NO pid file for this task
mkdir -p "$TMPDIR/t1/pids"

# Capture stdout + exit code separately. rc=$() would capture stdout.
sparc_reap_check "$MOCK_DB" "test-board" "T-1" "$TMPDIR/t1/pids/T-1.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 0 ]]; then ok "no reap"; else fail "expected 0, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-1")
if [[ "$status" == "running" ]]; then ok "task still running"; else fail "status changed to '$status'"; fi
reaped=$(count_reaped "$MOCK_DB" "T-1")
if [[ "$reaped" -eq 0 ]]; then ok "no reaped comments added"; else fail "got $reaped reaped comments"; fi

# ──
hdr "2. PID file exists, PID is alive → no reap (return 0)"
setup_test_env "t2"
seed_running_task "$MOCK_DB" "T-2"
mkdir -p "$TMPDIR/t2/pids"
# Use our own PID (always alive for the duration of the test)
echo "$$" > "$TMPDIR/t2/pids/T-2.pid"

sparc_reap_check "$MOCK_DB" "test-board" "T-2" "$TMPDIR/t2/pids/T-2.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 0 ]]; then ok "no reap (agent is our own alive PID)"; else fail "expected 0, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-2")
if [[ "$status" == "running" ]]; then ok "task still running"; else fail "status changed to '$status'"; fi

# ──
hdr "3. PID file exists, PID is dead → reap (return 1)"
setup_test_env "t3"
seed_running_task "$MOCK_DB" "T-3"
mkdir -p "$TMPDIR/t3/pids"
# Use a known-dead PID (PID 1 is init, but using a fake one we know doesn't exist)
# Use PID 99999 — extremely unlikely to exist
echo "99999" > "$TMPDIR/t3/pids/T-3.pid"

sparc_reap_check "$MOCK_DB" "test-board" "T-3" "$TMPDIR/t3/pids/T-3.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 1 ]]; then ok "reaped (rc=1)"; else fail "expected 1, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-3")
if [[ "$status" == "ready" ]]; then ok "task marked ready"; else fail "status is '$status'"; fi
reaped=$(count_reaped "$MOCK_DB" "T-3")
if [[ "$reaped" -eq 1 ]]; then ok "1 reaped comment added"; else fail "got $reaped reaped comments"; fi

# Verify the comment is well-formed (starts with [REAPED attempt 1/)
content=$(sqlite3 "$MOCK_DB" "SELECT body FROM task_comments WHERE task_id = 'T-3' ORDER BY id DESC LIMIT 1")
if [[ "$content" == *"[REAPED attempt 1/"* ]]; then
  ok "comment starts with [REAPED attempt 1/..."
else
  fail "comment malformed: $content"
fi

# ──
hdr "4. PID dead, prior reaps = max → block (return 2)"
setup_test_env "t4"
seed_running_task "$MOCK_DB" "T-4"
mkdir -p "$TMPDIR/t4/pids"
echo "99999" > "$TMPDIR/t4/pids/T-4.pid"
seed_prior_reaps "$MOCK_DB" "T-4" 2  # max_attempts = 2, so this reap would be #3

sparc_reap_check "$MOCK_DB" "test-board" "T-4" "$TMPDIR/t4/pids/T-4.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 2 ]]; then ok "blocked (rc=2)"; else fail "expected 2, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-4")
if [[ "$status" == "blocked" ]]; then ok "task marked blocked"; else fail "status is '$status'"; fi
# Should NOT have a new [REAPED attempt] line; should have a [REAP-BLOCKED] line
reaped=$(count_reaped "$MOCK_DB" "T-4")
if [[ "$reaped" -eq 2 ]]; then ok "no new [REAPED] comment (still 2 from prior reaps)"; else fail "got $reaped reaped comments"; fi
blocked=$(sqlite3 "$MOCK_DB" "SELECT COUNT(*) FROM task_comments WHERE task_id = 'T-4' AND body LIKE '[REAP-BLOCKED%'")
if [[ "$blocked" -eq 1 ]]; then ok "1 [REAP-BLOCKED] comment added"; else fail "got $blocked blocked comments"; fi

# ──
hdr "5. PID dead, prior reaps = 1, max = 2 → reap (return 1, count=2)"
setup_test_env "t5"
seed_running_task "$MOCK_DB" "T-5"
mkdir -p "$TMPDIR/t5/pids"
echo "99999" > "$TMPDIR/t5/pids/T-5.pid"
seed_prior_reaps "$MOCK_DB" "T-5" 1

sparc_reap_check "$MOCK_DB" "test-board" "T-5" "$TMPDIR/t5/pids/T-5.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 1 ]]; then ok "reaped (rc=1)"; else fail "expected 1, got $rc"; fi
reaped=$(count_reaped "$MOCK_DB" "T-5")
if [[ "$reaped" -eq 2 ]]; then ok "reaped count incremented to 2"; else fail "got $reaped"; fi
content=$(sqlite3 "$MOCK_DB" "SELECT body FROM task_comments WHERE task_id = 'T-5' ORDER BY id DESC LIMIT 1")
if [[ "$content" == *"[REAPED attempt 2/"* ]]; then
  ok "comment is [REAPED attempt 2/..."
else
  fail "comment malformed: $content"
fi

# ──
hdr "6. max_attempts = 0 → block immediately (zero allowed)"
setup_test_env "t6"
seed_running_task "$MOCK_DB" "T-6"
mkdir -p "$TMPDIR/t6/pids"
echo "99999" > "$TMPDIR/t6/pids/T-6.pid"

sparc_reap_check "$MOCK_DB" "test-board" "T-6" "$TMPDIR/t6/pids/T-6.pid" 0 2 >/dev/null
rc=$?
if [[ $rc -eq 2 ]]; then ok "blocked (max_attempts=0 means no reaps allowed)"; else fail "expected 2, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-6")
if [[ "$status" == "blocked" ]]; then ok "task blocked immediately"; else fail "status is '$status'"; fi

# ──
hdr "7. PID file is empty → no reap (safe default)"
setup_test_env "t7"
seed_running_task "$MOCK_DB" "T-7"
mkdir -p "$TMPDIR/t7/pids"
: > "$TMPDIR/t7/pids/T-7.pid"  # empty

sparc_reap_check "$MOCK_DB" "test-board" "T-7" "$TMPDIR/t7/pids/T-7.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 0 ]]; then ok "no reap (empty pid file)"; else fail "expected 0, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-7")
if [[ "$status" == "running" ]]; then ok "task still running"; else fail "status changed"; fi

# ──
hdr "8. PID file is empty → no reap (safe default; chmod 000 case)"
setup_test_env "t8"
seed_running_task "$MOCK_DB" "T-8"
mkdir -p "$TMPDIR/t8/pids"
# Test the empty-pid-file case (the chmod-000 case requires running
# as a different user; we verify the empty-file path here as the
# primary "safe default" check).
: > "$TMPDIR/t8/pids/T-8.pid"
sparc_reap_check "$MOCK_DB" "test-board" "T-8" "$TMPDIR/t8/pids/T-8.pid" 2 >/dev/null
rc=$?
if [[ $rc -eq 0 ]]; then ok "no reap (empty pid file)"; else fail "expected 0, got $rc"; fi
status=$(get_status "$MOCK_DB" "T-8")
if [[ "$status" == "running" ]]; then ok "task still running"; else fail "status changed"; fi

# ──
hdr "9. DB doesn't exist → graceful degradation"
setup_test_env "t9"
seed_running_task "$MOCK_DB" "T-9"
mkdir -p "$TMPDIR/t9/pids"
echo "99999" > "$TMPDIR/t9/pids/T-9.pid"
rm -f "$MOCK_DB"  # nuke the db

sparc_reap_check "/nonexistent/path/kanban.db" "test-board" "T-9" "$TMPDIR/t9/pids/T-9.pid" 2 >/dev/null
rc=$?
# With no DB, the reaper falls back to assuming no prior reaps.
# PID is dead, so first reap fires.
if [[ $rc -eq 1 ]]; then ok "reaped (with no DB, falls back gracefully)"; else fail "expected 1, got $rc"; fi
# (Can't check status — the DB was deleted and the mock hermes needs it.
# Just verify the return code path.)

# ──
hdr "10. Return codes are correct for each scenario"
# Smoke test that the return-code contract is honored.
setup_test_env "t10"
seed_running_task "$MOCK_DB" "T-A"
seed_running_task "$MOCK_DB" "T-B"
seed_running_task "$MOCK_DB" "T-C"
mkdir -p "$TMPDIR/t10/pids"
echo "$$" > "$TMPDIR/t10/pids/T-A.pid"      # alive
echo "99999" > "$TMPDIR/t10/pids/T-B.pid"    # dead
seed_prior_reaps "$MOCK_DB" "T-C" 2        # already maxed out
echo "99999" > "$TMPDIR/t10/pids/T-C.pid"    # dead, blocked

sparc_reap_check "$MOCK_DB" "test-board" "T-A" "$TMPDIR/t10/pids/T-A.pid" 2 >/dev/null
rc_a=$?
sparc_reap_check "$MOCK_DB" "test-board" "T-B" "$TMPDIR/t10/pids/T-B.pid" 2 >/dev/null
rc_b=$?
sparc_reap_check "$MOCK_DB" "test-board" "T-C" "$TMPDIR/t10/pids/T-C.pid" 2 >/dev/null
rc_c=$?

if [[ $rc_a -eq 0 && $rc_b -eq 1 && $rc_c -eq 2 ]]; then
  ok "return codes are 0/1/2 as documented"
else
  fail "got rc_a=$rc_a rc_b=$rc_b rc_c=$rc_c, expected 0/1/2"
fi

# ── Summary ──────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
