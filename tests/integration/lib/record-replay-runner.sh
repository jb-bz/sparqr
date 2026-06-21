#!/usr/bin/env bash
# tests/integration/lib/record-replay-runner.sh — Executable that
# wraps the record-replay harness so the mock hermes can `exec` it.
#
# Usage from the mock:
#   record-replay-runner.sh <real-hermes-path> <original-args...>
#
# In RECORD mode: runs the real hermes with the args, captures the
# interaction (request + response + exit code), appends it to the
# fixture file, echoes the captured stdout.
#
# In REPLAY mode: reads the next interaction from the fixture file,
# verifies the recorded args match the requested args, echoes the
# recorded stdout, returns the recorded exit code.
#
# This file is a thin executable wrapper; all the logic is in
# lib/record-replay.sh.

# Locate the record-replay library relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse args: first arg is the real-hermes path; rest are the original args
real_hermes="$1"
shift
original_args=("$@")

# shellcheck source=./record-replay.sh
source "$SCRIPT_DIR/record-replay.sh"

if [[ "${RECORD_REPLAY_MODE:-replay}" == "record" ]]; then
  # Run the real hermes, capture stdout/stderr/exit, save to fixture
  stdout=$("$real_hermes" "${original_args[@]}" 2>/tmp/sparc_rr_stderr_$$)
  rc=$?
  stderr=$(cat /tmp/sparc_rr_stderr_$$ 2>/dev/null || true)
  rm -f /tmp/sparc_rr_stderr_$$

  # Build the interaction JSON. Use printf to safely embed args (which
  # may contain quotes); jq would be cleaner but isn't always available.
  # The escape function handles backslashes and double quotes.
  json_escape() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
  }

  args_json="["
  first=true
  for a in "${original_args[@]}"; do
    if [[ "$first" != "true" ]]; then args_json+=","; fi
    first=false
    args_json+="\"$(json_escape "$a")\""
  done
  args_json+="]"

  interaction=$(python3 -c "
import json
print(json.dumps({
    'args': json.loads('''$args_json'''),
    'stdout': '''$(json_escape "$stdout")''',
    'stderr': '''$(json_escape "$stderr")''',
    'exit_code': $rc
}, indent=2))
")

  # Append to fixture file. We use python for atomic JSON-array
  # append because the interactions are multi-line JSON objects and
  # bash string manipulation is fragile with embedded quotes/newlines.
  fixture="$RECORD_REPLAY_CURRENT_FILE"
  python3 - "$fixture" <<PYEOF
import json, sys
fixture = sys.argv[1]
interaction = json.loads(r'''$interaction''')

try:
    with open(fixture) as f:
        data = json.load(f)
    if not isinstance(data, list):
        # Defensive: if the file has been corrupted, start fresh
        data = []
except (FileNotFoundError, json.JSONDecodeError):
    data = []

data.append(interaction)
with open(fixture, 'w') as f:
    json.dump(data, f, indent=2)
PYEOF

  # Echo captured stdout to caller (mirrors real hermes behavior)
  [[ -n "$stdout" ]] && printf '%s\n' "$stdout"
  exit $rc
fi

# REPLAY mode. The runner is a separate process from the test; the
# playback index lives in a file alongside the fixture so the state
# survives across the runner's exec'd children. Read the current
# index from the file before replaying.
RECORD_REPLAY_CURRENT_INDEX=$(cat "${RECORD_REPLAY_CURRENT_FILE}.idx" 2>/dev/null || echo 0)
export RECORD_REPLAY_CURRENT_INDEX

# Defer to the harness
sparc_rr_record_one "${original_args[@]}"
rc=$?

# Persist the (possibly-incremented) index back to the file so the
# next replay call starts from the right place.
printf '%s' "$RECORD_REPLAY_CURRENT_INDEX" > "${RECORD_REPLAY_CURRENT_FILE}.idx"
exit $rc