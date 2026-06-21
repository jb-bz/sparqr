# lib/test-helpers.sh — Shared helpers for integration tests.
#
# Sourced by every test_*.sh in this directory. Provides:
#   - Setup/teardown of a clean test directory
#   - A mock hermes wrapper that uses record-replay
#   - Common assertions (file exists, content matches, etc.)
#
# Integration tests follow this pattern:
#   1. setup_test_env         (creates tempdir, configures hermes mock)
#   2. Run the thing under test (setup.sh, sparc pipeline, etc.)
#   3. Assert outcomes        (using helpers below)
#   4. teardown_test_env      (cleanup)

# No double-source guard: see lib/kanban.sh for the full reasoning.

# Locate the package root (three levels up from this file)
TEST_HELPERS_PKG_ROOT="${TEST_HELPERS_PKG_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# Source record-replay if not already loaded
if [[ -z "${SPARC_RECORD_REPLAY_LOADED:-}" ]]; then
  # shellcheck source=./record-replay.sh
  source "$TEST_HELPERS_PKG_ROOT/tests/integration/lib/record-replay.sh"
fi

# setup_test_env <test_name>
#
# Creates a tempdir, installs the mock hermes (record-replay-aware),
# and configures the test environment.
#
# The mock hermes delegates to lib/record-replay-runner.sh which
# handles both modes: in RECORD mode it runs the real hermes and
# captures the interaction; in REPLAY mode it returns the recorded
# response. The real hermes is found on PATH (skipping the mock dir).
setup_test_env() {
  local test_name="$1"
  TEST_HELPERS_TMPDIR=$(mktemp -d)
  export TEST_HELPERS_TMPDIR

  # Install the mock hermes (separate file, easier than heredoc quoting).
  # We bake the runner and real-hermes-search paths into the mock at
  # install time, since BASH_SOURCE inside the copied mock would point
  # to the tempdir (and the runner lives in the package, not the tempdir).
  mkdir -p "$TEST_HELPERS_TMPDIR/bin"
  sed -e "s|@RUNNER_PATH@|$TEST_HELPERS_PKG_ROOT/tests/integration/lib/record-replay-runner.sh|g" \
      "$TEST_HELPERS_PKG_ROOT/tests/integration/lib/mock-hermes.sh" \
    > "$TEST_HELPERS_TMPDIR/bin/hermes"
  chmod +x "$TEST_HELPERS_TMPDIR/bin/hermes"

  export PATH="$TEST_HELPERS_TMPDIR/bin:$PATH"
  export SPARC_HERMES_BIN="$TEST_HELPERS_TMPDIR/bin/hermes"

  # Initialize record-replay (sets fixture path, resets index)
  sparc_rr_init "$test_name"

  # Common test environment
  export SPARC_LOG_DIR="$TEST_HELPERS_TMPDIR/logs"
  mkdir -p "$SPARC_LOG_DIR"
  export SPARC_CONFIG="$TEST_HELPERS_TMPDIR/sparc.config.yaml"
}

# teardown_test_env
#
# Removes the tempdir. Tests should call this in a `trap` so it
# runs even on test failure.
teardown_test_env() {
  if [[ -n "${TEST_HELPERS_TMPDIR:-}" && -d "$TEST_HELPERS_TMPDIR" ]]; then
    rm -rf "$TEST_HELPERS_TMPDIR"
  fi
  unset TEST_HELPERS_TMPDIR SPARC_HERMES_BIN SPARC_LOG_DIR SPARC_CONFIG
}

# Helpers
# -------

# assert_file_exists <path>
assert_file_exists() {
  if [[ -f "$1" ]]; then
    echo "  ✓ file exists: $1"
    return 0
  else
    echo "  ✗ file missing: $1"
    return 1
  fi
}

# assert_file_contains <path> <substring>
assert_file_contains() {
  if grep -qF "$2" "$1" 2>/dev/null; then
    echo "  ✓ file contains '$2': $1"
    return 0
  else
    echo "  ✗ file missing '$2': $1"
    return 1
  fi
}

# assert_dir_exists <path>
assert_dir_exists() {
  if [[ -d "$1" ]]; then
    echo "  ✓ dir exists: $1"
    return 0
  else
    echo "  ✗ dir missing: $1"
    return 1
  fi
}

# Test counter
TEST_HELPERS_PASS=0
TEST_HELPERS_FAIL=0
test_pass() { echo "  ✓ $*"; TEST_HELPERS_PASS=$((TEST_HELPERS_PASS+1)); }
test_fail() { echo "  ✗ $*"; TEST_HELPERS_FAIL=$((TEST_HELPERS_FAIL+1)); }

# Summary
test_summary() {
  echo ""
  echo "══════════════════════════════════════════════════════"
  echo "  $TEST_HELPERS_PASS pass  ·  $TEST_HELPERS_FAIL fail"
  echo "══════════════════════════════════════════════════════"
  [[ $TEST_HELPERS_FAIL -eq 0 ]]
}