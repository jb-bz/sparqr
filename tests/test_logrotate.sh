#!/usr/bin/env bash
# tests/test_logrotate.sh — Unit tests for bin/sparc-logrotate (v0.3.0 story 7).
#
# Tests:
#   - parse_size (K, M, G suffixes)
#   - Rotation: file under threshold → no-op (exit 0)
#   - Rotation: file over threshold → creates .gz, truncates original (exit 2)
#   - Rotation: keep=N → oldest deleted when N+1 rotations would exist
#   - Multi-rotation: chain works (file becomes .1.gz, .1 becomes .2.gz)
#   - Missing log file → no error

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGSCRIPT="$PKG_ROOT/bin/sparc-logrotate"

TMPDIR_TEST=$(mktemp -d)
trap 'rm -rf "$TMPDIR_TEST"' EXIT

# Helper: write a log file of N bytes. The logrotate script always
# looks for "sparc-pipeline.log" in the given directory.
make_log() {
  local dir="$1" size="$2"
  head -c "$size" /dev/zero > "$dir/sparc-pipeline.log"
}

# Helper: count files matching a pattern in a dir
count_files() {
  local dir="$1" pattern="$2"
  # shellcheck disable=SC2086
  find "$dir" -maxdepth 1 -name "$pattern" 2>/dev/null | wc -l | tr -d ' '
}

# Helper: run logrotate with given args; capture stdout and exit code
run_logrotate() {
  local args=("$@")
  "$LOGSCRIPT" "${args[@]}" 2>&1
}

# ───────────────────────────────────────────────────────────────────────
# TEST 1: file under threshold → no rotation
# ───────────────────────────────────────────────────────────────────────
echo "── file under threshold ──"
LOG="$TMPDIR_TEST/small"
mkdir -p "$LOG"
make_log "$LOG" 1000  # 1K
out=$(run_logrotate "$LOG" --max-size 50K --keep 3)
rc=$?
[[ $rc -eq 0 ]] && ok "small file: exit 0" || fail "exit $rc"
[[ "$out" == *"no rotation"* ]] && ok "small file: 'no rotation' message" || fail "got '$out'"
[[ -f "$LOG/sparc-pipeline.log" ]] && ok "small file: log still exists" || fail "log was deleted"
[[ $(count_files "$LOG" "sparc-pipeline.log*") -eq 1 ]] && ok "small file: only 1 log file (no .gz)" || fail "extra files exist"

# ───────────────────────────────────────────────────────────────────────
# TEST 2: file over threshold → rotates
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── file over threshold ──"
LOG="$TMPDIR_TEST/large"
mkdir -p "$LOG"
make_log "$LOG" 100000  # ~100K
out=$(run_logrotate "$LOG" --max-size 50K --keep 3)
rc=$?
[[ $rc -eq 2 ]] && ok "large file: exit 2 (rotation signal)" || fail "exit $rc"
[[ -f "$LOG/sparc-pipeline.log.1.gz" ]] && ok "large file: created .1.gz" || fail "no .1.gz"
[[ ! -s "$LOG/sparc-pipeline.log" ]] && ok "large file: original truncated" || fail "original not empty"
[[ -s "$LOG/sparc-pipeline.log.1.gz" ]] && ok "large file: .1.gz has content" || fail ".1.gz is empty"
file "$LOG/sparc-pipeline.log.1.gz" 2>/dev/null | grep -q "gzip" && ok "large file: .1.gz is real gzip" || fail ".1.gz not gzip"

# ───────────────────────────────────────────────────────────────────────
# TEST 3: multi-rotation chain
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── multi-rotation chain ──"
LOG="$TMPDIR_TEST/multi"
mkdir -p "$LOG"
# Force 3 rotations by running logrotate 3 times
for i in 1 2 3; do
  make_log "$LOG" 100000
  run_logrotate "$LOG" --max-size 50K --keep 5 >/dev/null
done
[[ -f "$LOG/sparc-pipeline.log.1.gz" ]] && ok "rotation 1 exists" || fail "no .1.gz"
[[ -f "$LOG/sparc-pipeline.log.2.gz" ]] && ok "rotation 2 exists" || fail "no .2.gz"
[[ -f "$LOG/sparc-pipeline.log.3.gz" ]] && ok "rotation 3 exists" || fail "no .3.gz"

# ───────────────────────────────────────────────────────────────────────
# TEST 4: keep=N enforced (oldest deleted)
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── keep=N enforcement ──"
LOG="$TMPDIR_TEST/keep"
mkdir -p "$LOG"
# Run 5 times with keep=2. Should end up with .1.gz and .2.gz only.
for i in 1 2 3 4 5; do
  make_log "$LOG" 100000
  run_logrotate "$LOG" --max-size 50K --keep 2 >/dev/null
done
[[ -f "$LOG/sparc-pipeline.log.1.gz" ]] && ok "keep=2: .1.gz exists" || fail "no .1.gz"
[[ -f "$LOG/sparc-pipeline.log.2.gz" ]] && ok "keep=2: .2.gz exists" || fail "no .2.gz"
[[ ! -f "$LOG/sparc-pipeline.log.3.gz" ]] && ok "keep=2: .3.gz deleted (older)" || fail ".3.gz still exists"

# ───────────────────────────────────────────────────────────────────────
# TEST 5: missing log file → no error
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── missing log file ──"
EMPTYDIR="$TMPDIR_TEST/empty"
mkdir -p "$EMPTYDIR"
out=$(run_logrotate "$EMPTYDIR" --max-size 50K --keep 3)
rc=$?
[[ $rc -eq 0 ]] && ok "missing log: exit 0" || fail "exit $rc"
[[ "$out" == *"no log file"* ]] && ok "missing log: 'no log file' message" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# TEST 6: arg parsing (--max-size and --max-size=)
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── arg parsing ──"
LOG="$TMPDIR_TEST/args"
mkdir -p "$LOG"
# Both syntaxes should work
make_log "$LOG" 100000
out1=$(run_logrotate "$LOG" --max-size 50K --keep 3 2>&1)
make_log "$LOG" 100000  # need to re-fill (first run truncated)
out2=$(run_logrotate "$LOG" --max-size=50K --keep=3 2>&1)
[[ "$out1" == *"rotating"* && "$out2" == *"rotating"* ]] && ok "both --max-size and --max-size= work" || fail "out1: $out1 / out2: $out2"

# ───────────────────────────────────────────────────────────────────────
# TEST 7: size parsing (K, M, G suffixes)
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "── size parsing ──"
LOG="$TMPDIR_TEST/sizes"
mkdir -p "$LOG"
# Run with 100KB log, --max-size 1M → should NOT rotate
make_log "$LOG" 100000  # 100K
out=$(run_logrotate "$LOG" --max-size 1M --keep 3 2>&1)
[[ "$out" == *"no rotation"* ]] && ok "1M threshold on 100K file: no rotation" || fail "got '$out'"
# With --max-size 50K → should rotate
out=$(run_logrotate "$LOG" --max-size 50K --keep 3 2>&1)
[[ "$out" == *"rotating"* ]] && ok "50K threshold on 100K file: rotation" || fail "got '$out'"

# ───────────────────────────────────────────────────────────────────────
# Summary
# ───────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
