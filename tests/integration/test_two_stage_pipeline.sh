#!/usr/bin/env bash
# test_two_stage_pipeline.sh — Integration test: two-stage pipeline
# with parent→child dependency, exercising the orchestrator's DAG
# pattern.
#
# Tests:
# - board init
# - parent task creation (spec)
# - child task creation (refinement) with --parent
# - explicit link (parent -> child)
# - comment on child task (simulating agent output)
# - mark child done (orchestrator's pass-2 completion)
# - mark parent done (orchestrator's pass-1 promotion)
#
# Uses record-replay. Re-record with:
#   cd tests/integration
#   RECORD_REPLAY_MODE=record bash test_two_stage_pipeline.sh

set -uo pipefail

# shellcheck source=./lib/test-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

trap teardown_test_env EXIT

echo "=== Test: two-stage pipeline (parent -> child) ==="

setup_test_env "two_stage_pipeline"

fixture="$RECORD_REPLAY_FIXTURES_DIR/two_stage_pipeline.json"
if [[ ! -f "$fixture" && "${RECORD_REPLAY_MODE:-replay}" == "replay" ]]; then
  test_fail "no recorded fixture at $fixture"
  test_fail "re-record with: RECORD_REPLAY_MODE=record bash test_two_stage_pipeline.sh"
  test_summary
  exit 1
fi

# Source the lib. The mock hermes (from setup_test_env) intercepts calls.
# shellcheck source=../../lib/kanban.sh
source "$TEST_HELPERS_PKG_ROOT/lib/kanban.sh"
export SPARC_HERMES_BIN="$TEST_HELPERS_TMPDIR/bin/hermes"

BOARD="sparqr-itest-pipeline"

# 1. Init the board
sparc_kanban_board_init "$BOARD" --name "Two-Stage Pipeline Test" >/dev/null 2>&1

# 2. Create the parent task (spec stage)
parent_id=$(sparc_kanban_create_task "$BOARD" "spec" "implement feature X" 2>/dev/null)
if [[ -n "$parent_id" ]]; then
  test_pass "parent task created: $parent_id"
else
  test_fail "parent task creation failed"
fi

# 3. Create the child task (refinement stage, depends on parent)
child_id=$(sparc_kanban_create_task "$BOARD" "refinement" "implement feature X" "$parent_id" 2>/dev/null)
if [[ -n "$child_id" ]]; then
  test_pass "child task created with parent: $child_id"
else
  test_fail "child task creation failed"
fi

# 4. Explicit link (in addition to --parent at creation)
sparc_kanban_link "$BOARD" "$parent_id" "$child_id" >/dev/null 2>&1
test_pass "parent->child link recorded"

# 5. Comment on the child (agent output simulation)
sparc_kanban_comment "$BOARD" "$child_id" "[REFINEMENT] feature X implemented in src/foo.py" >/dev/null 2>&1
test_pass "child comment added"

# 6. Mark child done
sparc_kanban_set_status "$BOARD" "$child_id" "done" 2>/dev/null

# 7. Mark parent done (after child)
sparc_kanban_set_status "$BOARD" "$parent_id" "done" 2>/dev/null
test_pass "parent marked done"

# 8. Verify all interactions consumed
sparc_rr_assert_exhausted || test_fail "didn't consume all recorded interactions"

# Cleanup
REAL_HERMES=""
IFS=':' read -ra path_parts <<< "$PATH"
for d in "${path_parts[@]}"; do
  [[ -x "$d/hermes" && "$d" != "$TEST_HELPERS_TMPDIR/bin" ]] && REAL_HERMES="$d/hermes" && break
done
if [[ -n "$REAL_HERMES" ]]; then
  "$REAL_HERMES" kanban boards rm "$BOARD" >/dev/null 2>&1 || true
fi

test_summary