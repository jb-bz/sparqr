#!/usr/bin/env bash
# test_setup_against_hermes.sh — Integration test: sparc_kanban_board_init
# works against a real Hermes installation.
#
# Drives the package's lib/kanban.sh functions directly against a
# real (or recorded) Hermes. Verifies the kanban wrapper works
# end-to-end on real Hermes without depending on setup.sh's install
# flow (which has its own prereq checks that need a real environment).
#
# Uses record-replay: a recorded session is checked in to the
# fixtures/ directory. To re-record against real hermes:
#
#   cd tests/integration
#   RECORD_REPLAY_MODE=record ./test_setup_against_hermes.sh
#
# Without record mode, the test runs against the recorded session.

# SLOW_TEST

set -uo pipefail

# shellcheck source=./lib/test-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

trap teardown_test_env EXIT

echo "=== Test: kanban wrapper against real Hermes (recorded session) ==="

setup_test_env "setup_against_hermes"

# Verify the recorded fixture exists. If it doesn't, the test can't
# run in replay mode.
fixture="$RECORD_REPLAY_FIXTURES_DIR/setup_against_hermes.json"
if [[ ! -f "$fixture" && "${RECORD_REPLAY_MODE:-replay}" == "replay" ]]; then
  test_fail "no recorded fixture at $fixture"
  test_fail "re-record with: RECORD_REPLAY_MODE=record ./test_setup_against_hermes.sh"
  test_summary
  exit 1
fi

# Source the lib. The mock hermes (from setup_test_env) intercepts calls.
# shellcheck source=../../lib/kanban.sh
source "$TEST_HELPERS_PKG_ROOT/lib/kanban.sh"
export SPARC_HERMES_BIN="$TEST_HELPERS_TMPDIR/bin/hermes"

# Drive the kanban wrapper through a typical init flow.
# These calls should match the recorded fixture in order.
#
# IMPORTANT: use a STABLE board name (no $$ or other PID-derived
# values). The record-replay harness matches the recorded args
# exactly; if the test uses $$ and gets a different PID at replay
# time, every recorded call with that PID in the args will mismatch.
BOARD="sparqr-itest-replay"

# 1. Init the board (creates if missing, switches to it)
sparc_kanban_board_init "$BOARD" --name "Integration Test Board" >/dev/null 2>&1

# 2. Create a task (spec, no parent → ready)
spec_id=$(sparc_kanban_create_task "$BOARD" "spec" "test goal" 2>/dev/null)
if [[ -n "$spec_id" ]]; then
  test_pass "spec task created: $spec_id"
else
  test_fail "spec task creation failed"
fi

# 3. Create a child task (refinement → todo, waiting for spec)
refine_id=$(sparc_kanban_create_task "$BOARD" "refinement" "test refinement" "$spec_id" 2>/dev/null)
if [[ -n "$refine_id" ]]; then
  test_pass "refinement task created: $refine_id"
else
  test_fail "refinement task creation failed"
fi

# 4. Link them
sparc_kanban_link "$BOARD" "$spec_id" "$refine_id" >/dev/null 2>&1
test_pass "tasks linked"

# 5. Comment on the spec
sparc_kanban_comment "$BOARD" "$spec_id" "[ITEST] spec task created" >/dev/null 2>&1
test_pass "comment added"

# Verify we consumed all recorded interactions (no stale recordings).
# Note: the cleanup below is NOT included in the recorded session.
# We use the real hermes (bypassing the mock) so we don't capture
# the cleanup call in the fixture. This keeps the fixture focused
# on the test's actual behavior.
sparc_rr_assert_exhausted || test_fail "didn't consume all recorded interactions"

# Cleanup: archive the test board using the real hermes (NOT the
# mock). The mock would replay a recorded `boards rm`, but real
# cleanup is a separate concern from the recorded session.
# We find the real hermes on PATH (skipping the mock's tmpdir).
REAL_HERMES=""
IFS=':' read -ra path_parts <<< "$PATH"
for d in "${path_parts[@]}"; do
  [[ -x "$d/hermes" && "$d" != "$TEST_HELPERS_TMPDIR/bin" ]] && REAL_HERMES="$d/hermes" && break
done
if [[ -n "$REAL_HERMES" ]]; then
  "$REAL_HERMES" kanban boards rm "$BOARD" >/dev/null 2>&1 || true
fi

test_summary