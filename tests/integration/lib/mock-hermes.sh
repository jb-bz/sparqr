#!/usr/bin/env bash
# tests/integration/lib/mock-hermes.sh — Mock hermes for integration tests.
#
# Installed on PATH by setup_test_env in test-helpers.sh. Delegates
# every call to lib/record-replay-runner.sh which:
#   - In RECORD mode: runs the real hermes, captures the interaction
#     into the fixture file
#   - In REPLAY mode: returns the recorded response

# Forward env vars so the runner knows the mode and the fixture path
export RECORD_REPLAY_MODE
export RECORD_REPLAY_FIXTURES_DIR
export RECORD_REPLAY_CURRENT_FILE

# Find the real hermes on PATH, skipping this mock's own dir
# (mock is at <tmpdir>/bin, real hermes is elsewhere)
mock_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
real_hermes=""
IFS=':' read -ra path_parts <<< "$PATH"
for d in "${path_parts[@]}"; do
  [[ "$d" == "$mock_dir" ]] && continue
  [[ -x "$d/hermes" ]] && real_hermes="$d/hermes" && break
done

# Fall back to env override, then to whatever's on PATH
[[ -z "$real_hermes" ]] && real_hermes="${REAL_HERMES:-hermes}"

# Find the runner script. The runner sources record-replay.sh and
# calls sparc_rr_record_one with the right mode. The path is baked
# in by test-helpers.sh when installing this mock (so it doesn't
# depend on the original file location).
runner="@RUNNER_PATH@"

# Delegate everything to the runner. Args: <real-hermes-path> <original-args...>
exec "$runner" "$real_hermes" "$@"