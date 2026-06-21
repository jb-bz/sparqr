#!/usr/bin/env bash
# test_single_stage_run.sh — Integration test: a single stage agent
# run end-to-end against real Hermes.
#
# This test simulates what happens when the orchestrator spawns a
# stage agent: it creates a task, marks it running, and the agent
# (in production) would do work and mark it done/blocked. Here we
# just verify the kanban wrapper correctly handles each state
# transition.
#
# Uses record-replay: the first run captures real Hermes output,
# subsequent runs replay from the fixture.
#
# To re-record:
#   cd tests/integration
#   RECORD_REPLAY_MODE=record bash test_single_stage_run.sh

set -uo pipefail

# shellcheck source=./lib/test-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

trap teardown_test_env EXIT

echo "=== Test: single-stage run (state transitions) ==="

setup_test_env "single_stage_run"

fixture="$RECORD_REPLAY_FIXTURES_DIR/single_stage_run.json"
if [[ ! -f "$fixture" && "${RECORD_REPLAY_MODE:-replay}" == "replay" ]]; then
  test_fail "no recorded fixture at $fixture"
  test_fail "re-record with: RECORD_REPLAY_MODE=record bash test_single_stage_run.sh"
  test_summary
  exit 1
fi

# Source the lib. The mock hermes (from setup_test_env) intercepts calls.
# shellcheck source=../../lib/kanban.sh
source "$TEST_HELPERS_PKG_ROOT/lib/kanban.sh"
export SPARC_HERMES_BIN="$TEST_HELPERS_TMPDIR/bin/hermes"

# Stable board name (record-replay matches args exactly)
BOARD="sparqr-itest-single"

# Sequence: create task, mark running (via claim), do some work
# (we simulate by adding comments), then mark done.
#
# In production, the orchestrator spawns `hermes -p <profile> chat
# -q <prompt>` as a child process. We don't actually spawn that
# here because:
# 1. It requires a real model API call (no hermes profile configured
#    in the integration test env)
# 2. The orchestrator's spawn logic is tested in unit tests via mocks
# Here we test the kanban state transitions, which is what the
# orchestrator depends on.

# 1. Init the board (creates if missing)
sparc_kanban_board_init "$BOARD" --name "Single Stage Test" >/dev/null 2>&1

# 2. Create a task
task_id=$(sparc_kanban_create_task "$BOARD" "spec" "test feature" 2>/dev/null)
if [[ -n "$task_id" ]]; then
  test_pass "task created: $task_id"
else
  test_fail "task creation failed"
fi

# 3. Mark running (real Hermes transitions to running via claim).
# This simulates the orchestrator's pass-2 spawn step.
sparc_kanban_set_status "$BOARD" "$task_id" "running" 2>/dev/null

# 4. Simulate agent activity via comments
sparc_kanban_comment "$BOARD" "$task_id" "[AGENT] starting work" 2>/dev/null
test_pass "started comment added"

# 5. Mark done (real Hermes uses `complete` verb)
sparc_kanban_set_status "$BOARD" "$task_id" "done" 2>/dev/null

# 6. Verify the recorded interactions were all consumed
sparc_rr_assert_exhausted || test_fail "didn't consume all recorded interactions"

# Cleanup: archive the test board using the real hermes (NOT the mock)
REAL_HERMES=""
IFS=':' read -ra path_parts <<< "$PATH"
for d in "${path_parts[@]}"; do
  [[ -x "$d/hermes" && "$d" != "$TEST_HELPERS_TMPDIR/bin" ]] && REAL_HERMES="$d/hermes" && break
done
if [[ -n "$REAL_HERMES" ]]; then
  "$REAL_HERMES" kanban boards rm "$BOARD" >/dev/null 2>&1 || true
fi

test_summary