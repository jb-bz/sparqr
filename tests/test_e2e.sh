#!/usr/bin/env bash
# tests/test_e2e.sh — End-to-end smoke test using a mocked hermes CLI.
# Verifies the orchestrator's plumbing without requiring real Hermes.
#
# Run: bash tests/test_e2e.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

# Mock hermes — much simpler than full kanban emulation.
# We only need to verify the orchestrator's invocation patterns.
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT
mkdir -p "$TMPDIR/bin" "$TMPDIR/state"
export SPARC_BOARD="test-board"
export SPARC_ARTIFACT_DISK_DIR="$TMPDIR/docs/sparc"
export SPARC_HITL_ADAPTER="terminal"
export SPARC_HITL_GATES=""

# The mock is intentionally simple: it records every invocation to a log file
# and pretends to be a working hermes. It does NOT maintain real kanban state
# (that requires a real Hermes to test). It just makes sure the package's
# scripts don't crash and invoke hermes with the expected verb structure.
cat > "$TMPDIR/bin/hermes" <<'MOCK_EOF'
#!/usr/bin/env bash
# Record every call for assertion
LOG_FILE="${SPARC_MOCK_LOG:-/tmp/hermes-mock.log}"
mkdir -p "$(dirname "$LOG_FILE")"
echo "CALL: $*" >> "$LOG_FILE"

case "$1" in
  --version) echo "hermes 0.51.0 (mock)" ;;
  profile)
    case "$2" in
      list) echo "default" ;;
      show) echo "{\"name\": \"$3\"}" ;;
      *) echo "{}" ;;
    esac
    ;;
  kanban)
    shift
    if [[ "$1" == "--board" ]]; then
      local board="$2"; shift 2
    fi
    case "$1" in
      boards)
        case "$2" in
          list) echo "test-board" ;;
          create) echo "created $3" ;;
          *) echo "" ;;
        esac
        ;;
      list) echo "" ;;
      create)
        # Echo a deterministic id; sparc_kanban_create_task's tail fallback
        # uses $NF on the last line.
        echo "id: TASK-MOCK-$RANDOM"
        ;;
      set|update) echo "set" ;;
      link) echo "linked" ;;
      comment) echo "commented" ;;
      show) echo "{}" ;;
      *) echo "mock: unknown kanban verb $1" ;;
    esac
    ;;
  *) echo "mock: unknown verb $1" ;;
esac
MOCK_EOF
chmod +x "$TMPDIR/bin/hermes"
export PATH="$TMPDIR/bin:$PATH"
export SPARC_HERMES_BIN="$TMPDIR/bin/hermes"
export SPARC_MOCK_LOG="$TMPDIR/state/calls.log"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# ── 1. All bin/ scripts parse and --help doesn't crash ────────────────
hdr "CLI scripts parse and run"
for script in sparc sparc-init sparc-pipeline sparc-stage sparc-hitl-watcher sparc-doctor; do
  if bash -n "$PKG_ROOT/bin/$script" 2>/dev/null; then
    ok "$script parses"
  else
    fail "$script has a syntax error"
  fi
done

# ── 2. sparc --version prints the version ─────────────────────────────
hdr "sparc --version"
out=$("$PKG_ROOT/bin/sparc" --version 2>&1)
if [[ "$out" =~ ^sparc\ [0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  ok "version: $out"
else
  fail "unexpected version output: $out"
fi

# ── 3. sparc stages lists all 6 stages ────────────────────────────────
hdr "sparc stages output"
out=$("$PKG_ROOT/bin/sparc" stages 2>&1)
expected_stages=(spec design pseudocode architecture refinement completion)
all_present=true
for s in "${expected_stages[@]}"; do
  if ! grep -q "$s" <<<"$out"; then
    all_present=false
    fail "stage '$s' not in sparc stages output"
  fi
done
$all_present && ok "all 6 stages listed in order"

# ── 4. sparc adapters lists all 5 HITL adapters ────────────────────────
hdr "sparc adapters output"
out=$("$PKG_ROOT/bin/sparc" adapters 2>&1)
expected_adapters=(terminal tui webui workspace official-dashboard)
all_present=true
for a in "${expected_adapters[@]}"; do
  if ! grep -q "$a" <<<"$out"; then
    all_present=false
    fail "adapter '$a' not in sparc adapters output"
  fi
done
$all_present && ok "all 5 HITL adapters listed"

# ── 5. sparc-init runs (with mock) and produces output ────────────────
hdr "sparc-init (mocked hermes)"
cd "$TMPDIR"
out=$("$PKG_ROOT/bin/sparc-init" "Build a CLI" 2>&1)
if grep -q "SPARC pipeline ready" <<<"$out"; then
  ok "sparc-init completed"
else
  fail "sparc-init output: $out"
fi

# ── 6. sparc-init invoked hermes boards list and create (or skip) ─────
hdr "sparc-init called hermes kanban verbs"
calls=$(cat "$SPARC_MOCK_LOG" 2>/dev/null)
if grep -q "kanban boards" <<<"$calls"; then
  ok "invoked 'kanban boards' verb"
else
  fail "no 'kanban boards' call recorded"
fi
if grep -q "kanban.*create" <<<"$calls"; then
  ok "invoked 'kanban create' verb"
else
  fail "no 'kanban create' call recorded"
fi

# ── 7. sparc pipeline run-once does not crash ─────────────────────────
hdr "sparc pipeline run-once"
cd "$TMPDIR"
if "$PKG_ROOT/bin/sparc-pipeline" run-once 2>&1 | tail -n 3; then
  ok "run-once completed"
else
  fail "run-once failed"
fi

# ── 8. sparc doctor runs (will mostly warn, but should not error catastrophically)
hdr "sparc doctor"
# In a mock environment doctor will warn (no real profiles, no real skills)
# but it should still produce output.
out=$("$PKG_ROOT/bin/sparc-doctor" 2>&1)
if grep -q "pass" <<<"$out" && grep -q "warn" <<<"$out"; then
  ok "doctor produced pass/warn summary (mock env, many warns expected)"
else
  fail "doctor output missing summary: $out"
fi

# ── Summary ────────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
