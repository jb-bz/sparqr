# lib/record-replay.sh — VCR-style recording harness for integration tests.
#
# Concept (similar to VCR for Ruby or pytest-vcr for Python):
#   - First run: tests call real Hermes via Docker. Every hermes CLI
#     call is captured (request + response) and saved to a fixture
#     file in tests/integration/fixtures/.
#   - Subsequent runs: tests use a mock hermes that replays the
#     captured responses. No Docker needed.
#   - Re-record: when Hermes changes, set RECORD=1 to re-capture.
#
# The fixture file format is a JSON array of "interactions":
#   [
#     {
#       "request":  {"args": ["kanban", "boards", "list"]},
#       "response": {"stdout": "...", "stderr": "", "exit_code": 0}
#     },
#     ...
#   ]
#
# Each test gets its own fixture file: tests/integration/fixtures/<test-name>.json
# The mock hermes reads the fixture, replays responses in order.

# This file is sourced by integration tests; it doesn't run on its own.

# No double-source guard: see lib/kanban.sh for the full reasoning.
# Same pattern applies here — the runner is `exec`'d by the mock
# hermes, and exec doesn't carry function definitions across
# processes. The sentinel-var pattern caused `sparc_rr_record_one:
# command not found` in the replayed runs.

# Internal state for the harness. Exported so child processes
# (the mock hermes -> record-replay-runner.sh) can read these.
# Use parameter-expansion-with-default to preserve env values that
# were set before sourcing this file; don't clobber them.
export RECORD_REPLAY_MODE="${RECORD_REPLAY_MODE:-replay}"  # "replay" or "record"
export RECORD_REPLAY_FIXTURES_DIR="${RECORD_REPLAY_FIXTURES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/fixtures}"
# Initialize the playback index to 0 (sourced by both parent shells and
# the runner's child shell). sparc_rr_init resets it when the test starts.
export RECORD_REPLAY_CURRENT_INDEX="${RECORD_REPLAY_CURRENT_INDEX:-0}"
# Don't overwrite CURRENT_FILE — sparc_rr_init sets it after source.
# But the runner (exec'd as a separate process) needs to read it;
# the parent's exported value carries through if we don't reset it.
# Leave uninitialized if not set; sparc_rr_init or the caller sets it.

# sparc_rr_init <test_name>
#
#   Initialize the harness for a test. Sets up the fixture file path
#   and resets the playback index. Must be called before any hermes
#   command is run in the test.
sparc_rr_init() {
  local test_name="$1"
  export RECORD_REPLAY_CURRENT_FILE="$RECORD_REPLAY_FIXTURES_DIR/${test_name}.json"
  # Reset the playback index. The runner reads the index from a file
  # alongside the fixture so the state survives across exec'd
  # processes. Resetting here ensures each test starts at index 0.
  printf '%s' 0 > "${RECORD_REPLAY_CURRENT_FILE}.idx"
  RECORD_REPLAY_CURRENT_INDEX=0
  # Create the fixtures dir if missing
  mkdir -p "$RECORD_REPLAY_FIXTURES_DIR" 2>/dev/null || true
}

# sparc_rr_record_one <args...>
#
#   Make a hermes call. In RECORD mode, capture the output and append
#   to the fixture file. In REPLAY mode, look up the next recorded
#   interaction and echo its captured output.
#
#   Returns the recorded exit code.
#
#   Usage:
#     sparc_rr_record_one kanban boards list
#     sparc_rr_record_one kanban --board foo create --title "bar"
#
#   The first arg becomes the fixture's interaction ID by index.
#   Subsequent calls increment the index.
sparc_rr_record_one() {
  if [[ "$RECORD_REPLAY_MODE" == "record" ]]; then
    sparc_rr_do_record "$@"
  else
    sparc_rr_do_replay "$@"
  fi
}

# sparc_rr_do_record <args...>
#
#   Execute the hermes command, capture stdout/stderr/exit, save to
#   fixture file.
sparc_rr_do_record() {
  local args=("$@")
  local stdout stderr rc interaction

  # Capture stdout/stderr/exit code
  stdout=$("$SPARC_HERMES_BIN" "${args[@]}" 2>/tmp/sparc_rr_stderr_$$)
  rc=$?
  stderr=$(cat /tmp/sparc_rr_stderr_$$ 2>/dev/null || true)
  rm -f /tmp/sparc_rr_stderr_$$

  # Build the interaction JSON
  interaction=$(python3 -c "
import json, sys
args = $(printf '%s\n' "${args[@]}" | python3 -c 'import json,sys; print(json.dumps([l.rstrip(\"\n\") for l in sys.stdin]))')
stdout = $(printf '%s' "$stdout" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
stderr = $(printf '%s' "$stderr" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
print(json.dumps({'args': args, 'stdout': stdout, 'stderr': stderr, 'exit_code': $rc}, indent=2))
")

  # Append to fixture file (start with [ if first interaction)
  if [[ ! -f "$RECORD_REPLAY_CURRENT_FILE" ]] || [[ ! -s "$RECORD_REPLAY_CURRENT_FILE" ]]; then
    echo "[" > "$RECORD_REPLAY_CURRENT_FILE"
    echo "$interaction" >> "$RECORD_REPLAY_CURRENT_FILE"
  else
    # Replace the trailing ] with ,interaction\n]
    sed -i.bak '$s/]/,/' "$RECORD_REPLAY_CURRENT_FILE" && rm -f "${RECORD_REPLAY_CURRENT_FILE}.bak"
    echo "$interaction" >> "$RECORD_REPLAY_CURRENT_FILE"
    echo "]" >> "$RECORD_REPLAY_CURRENT_FILE"
  fi

  # Echo stdout to caller (just like real hermes would)
  [[ -n "$stdout" ]] && printf '%s\n' "$stdout"
  return $rc
}

# sparc_rr_do_replay <args...>
#
#   Read the next interaction from the fixture file and echo its
#   captured stdout. Args are checked against the recorded request
#   to fail loud if the test is replaying in the wrong order.
sparc_rr_do_replay() {
  local args=("$@")

  if [[ ! -f "$RECORD_REPLAY_CURRENT_FILE" ]]; then
    echo "  ! fixture not found: $RECORD_REPLAY_CURRENT_FILE" >&2
    echo "  ! run with RECORD=1 to record this test" >&2
    return 1
  fi

  # Extract the interaction at index N (0-based). Pass the file path
  # and index as command-line args to avoid bash-interpolating empty
  # env vars into python source (which produces syntax errors).
  local interaction
  interaction=$(RECORD_REPLAY_CURRENT_INDEX="$RECORD_REPLAY_CURRENT_INDEX" \
               python3 - "$RECORD_REPLAY_CURRENT_FILE" <<'PYEOF'
import json, os, sys
fixture = sys.argv[1]
idx = int(os.environ.get('RECORD_REPLAY_CURRENT_INDEX', '0'))
with open(fixture) as f:
    interactions = json.load(f)
if idx >= len(interactions):
    print('EXHAUSTED', file=sys.stderr)
    sys.exit(1)
print(json.dumps(interactions[idx]))
PYEOF
)

  local rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "  ! no more recorded interactions for index $RECORD_REPLAY_CURRENT_INDEX" >&2
    return 1
  fi

  # Verify the recorded args match the requested args (fail loud on
  # mismatch — the test is calling in the wrong order)
  local recorded_args_str
  recorded_args_str=$(printf '%s' "$interaction" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(' '.join(d['args']))
")
  local requested_args_str="${args[*]}"
  if [[ "$recorded_args_str" != "$requested_args_str" ]]; then
    echo "  ! recorded args mismatch at index $RECORD_REPLAY_CURRENT_INDEX" >&2
    echo "  !   recorded:  $recorded_args_str" >&2
    echo "  !   requested: $requested_args_str" >&2
    echo "  ! re-record with RECORD=1" >&2
    return 1
  fi

  # Echo captured stdout
  local stdout
  stdout=$(printf '%s' "$interaction" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d['stdout'], end='')
")
  [[ -n "$stdout" ]] && printf '%s\n' "$stdout"

  # Get exit code
  local exit_code
  exit_code=$(printf '%s' "$interaction" | python3 -c "
import json, sys
print(json.load(sys.stdin)['exit_code'])
")

  # Persist the new index to a file alongside the fixture. The runner
  # is exec'd as a separate process; in-memory state doesn't survive.
  # The index file (".idx" suffix) is the source of truth for the
  # current playback position. sparc_rr_init resets it on test start.
  RECORD_REPLAY_CURRENT_INDEX=$((RECORD_REPLAY_CURRENT_INDEX + 1))
  printf '%s' "$RECORD_REPLAY_CURRENT_INDEX" > "${RECORD_REPLAY_CURRENT_FILE}.idx"
  return "$exit_code"
}

# sparc_rr_assert_exhausted
#
#   Call this at the end of a test. Verifies that all recorded
#   interactions were consumed. If not, the test is replaying
#   fewer calls than it recorded — likely a code path change.
sparc_rr_assert_exhausted() {
  if [[ "$RECORD_REPLAY_MODE" == "replay" && -f "$RECORD_REPLAY_CURRENT_FILE" ]]; then
    local total consumed_idx
    total=$(python3 -c "
import json
with open('$RECORD_REPLAY_CURRENT_FILE') as f:
    print(len(json.load(f)))
")
    # Read the actual consumed index from the file. The in-process
    # RECORD_REPLAY_CURRENT_INDEX variable may be stale if the test
    # ran subshells that updated the file but not the parent shell.
    consumed_idx=$(cat "${RECORD_REPLAY_CURRENT_FILE}.idx" 2>/dev/null || echo 0)
    if [[ "$consumed_idx" -lt "$total" ]]; then
      echo "  ! test consumed $consumed_idx of $total recorded interactions" >&2
      echo "  ! something changed in the code path; re-record with RECORD=1" >&2
      return 1
    fi
  fi
  return 0
}