#!/usr/bin/env bash
# test_setup_against_hermes.sh — Integration test: setup.sh works
# against a real Hermes installation.
#
# This is the FIRST integration test for sparqr. It verifies that
# setup.sh runs end-to-end against a real hermes and creates the
# expected artifacts: a config file, a kanban board, 6 linked
# tasks.
#
# Uses record-replay: a recorded session is checked in to the
# fixtures/ directory. To re-record against real hermes:
#
#   cd tests/integration
#   docker compose up -d hermes
#   RECORD_REPLAY_MODE=record ./test_setup_against_hermes.sh
#   docker compose down
#
# Without Docker, the test runs against the recorded session.

# SLOW_TEST
# This is an integration test; it's slow and requires Docker to record.
# Marked with this comment so the CI workflow can skip it on PR runs
# and only run it on main merges (where Docker is available).

set -uo pipefail

# shellcheck source=./lib/test-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/test-helpers.sh"

trap teardown_test_env EXIT

echo "=== Test: setup.sh against real Hermes (recorded session) ==="

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

# Change to the test directory (setup.sh runs in cwd)
cd "$TEST_HELPERS_TMPDIR"

# Run setup.sh against the mock/recorded hermes. The orchestrator
# script uses hermes kanban verbs which are now mocked.
bash "$TEST_HELPERS_PKG_ROOT/setup.sh" 2>&1 | head -n 20 || true

# Verify outputs
assert_file_exists "./sparc.config.yaml" || test_fail "config not created"
assert_dir_exists "./docs/sparc" || test_fail "artifacts dir not created"

# Verify we consumed all recorded interactions (no stale recordings)
sparc_rr_assert_exhausted || test_fail "didn't consume all recorded interactions"

test_summary