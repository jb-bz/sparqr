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

# Guard against double-sourcing
if [[ -n "${SPARC_TEST_HELPERS_LOADED:-}" ]]; then
  return 0
fi
export SPARC_TEST_HELPERS_LOADED=1

# Locate the package root (three levels up from this file:
# lib/test-helpers.sh -> lib/ -> integration/ -> tests/ -> <pkg_root>)
TEST_HELPERS_PKG_ROOT="${TEST_HELPERS_PKG_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# Source record-replay if not already loaded
if [[ -z "${SPARC_RECORD_REPLAY_LOADED:-}" ]]; then
  # shellcheck source=./record-replay.sh
  source "$TEST_HELPERS_PKG_ROOT/tests/integration/lib/record-replay.sh"
fi

# setup_test_env <test_name>
#
#   Creates a tempdir, sets SPARC_HERMES_BIN to a mock hermes that
#   uses record-replay, and configures the test environment.
#
#   The mock hermes is a small bash script that:
#     - On RECORD=1: exec the real hermes, capturing output
#     - On REPLAY=1: read from fixture, echo recorded output
#
#   Call from a test:
#     setup_test_env "my_test_name"
#     # ... do test things ...
#     teardown_test_env
setup_test_env() {
  local test_name="$1"
  TEST_HELPERS_TMPDIR=$(mktemp -d)
  export TEST_HELPERS_TMPDIR

  # Create a mock hermes binary on PATH that records or replays
  mkdir -p "$TEST_HELPERS_TMPDIR/bin"
  cat > "$TEST_HELPERS_TMPDIR/bin/hermes" <<MOCK_EOF
#!/usr/bin/env bash
# Mock hermes for integration tests. Delegates to record-replay.
# RECORD=1 runs the real hermes (which must be on PATH ahead of this
# mock) and captures output. Default mode replays from fixture.
if [[ "\${RECORD_REPLAY_MODE:-replay}" == "record" ]]; then
  # Find the real hermes (skip the mock dir)
  local real_hermes=""
  local p
  IFS=: read -ra p <<< "\$PATH"
  for d in "\${p[@]}"; do
    [[ "\$d" == "$TEST_HELPERS_TMPDIR/bin" ]] && continue
    [[ -x "\$d/hermes" ]] && { real_hermes="\$d/hermes"; break; }
  done
  if [[ -z "\$real_hermes" ]]; then
    # Fall back to PATH (PATH may have it via SPARC_HERMES_BIN env var)
    real_hermes="\${REAL_HERMES:-hermes}"
  fi
  exec "\$real_hermes" "\$@"
fi
# Replay mode: delegate to sparc_rr_record_one
exec "$TEST_HELPERS_PKG_ROOT/tests/integration/lib/record-replay-runner.sh" "\$@"
MOCK_EOF
  chmod +x "$TEST_HELPERS_TMPDIR/bin/hermes"
  export PATH="$TEST_HELPERS_TMPDIR/bin:$PATH"
  export SPARC_HERMES_BIN="$TEST_HELPERS_TMPDIR/bin/hermes"

  # Initialize record-replay
  sparc_rr_init "$test_name"

  # Common test environment
  export SPARC_LOG_DIR="$TEST_HELPERS_TMPDIR/logs"
  mkdir -p "$SPARC_LOG_DIR"
  export SPARC_CONFIG="$TEST_HELPERS_TMPDIR/sparc.config.yaml"
}

# teardown_test_env
#
#   Removes the tempdir. Tests should call this in a `trap` so it
#   runs even on test failure.
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