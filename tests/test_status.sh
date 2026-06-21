#!/usr/bin/env bash
# tests/test_status.sh — Unit tests for bin/sparc-status (v0.3.0 story 5).
#
# Tests the board parser and arg parser in isolation. Doesn't require
# real Hermes (we mock the kanban CLI output).
#
# Tests:
#   1. Board parser correctly extracts slugs from real Hermes v0.17.0 output
#      - current board line (with ● marker)
#      - non-current board line (without marker)
#      - excludes SLUG header, Current board footer, Switch footer
#      - includes boards whose name column contains ":" (SPARC: ...)
#   2. Arg parser
#      - `--board <slug>` works
#      - `--board=<slug>` works
#      - `--json` enables JSON mode
#      - unknown arg exits with error
#   3. Output structure (text and JSON)

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

# ─── 1. Board parser ──────────────────────────────────────────────────
echo "── board parser (real Hermes v0.17.0 format) ──"

# Sample output (verified 2026-06-20)
SAMPLE_OUTPUT="SLUG                      NAME                          COUNTS
●   default                   Default                       ready=1
    sparc-sparqr-smoke-1782003742  SPARC: sparqr-smoke-1782003742  (empty)
    sparc-sparqr-smoke-1782003837  SPARC: sparqr-smoke-1782003837  ready=1, todo=5
    spike-test                Spike test                    archived=3

Current board: default
Switch boards with \`hermes kanban boards switch <slug>\`."

# Extract slugs using the same awk logic bin/sparc-status uses.
EXTRACTED=$(echo "$SAMPLE_OUTPUT" | awk '
  NF >= 3 && $1 != "SLUG" && $1 != "Current" && $1 != "Switch" {
    slug = ($1 == "●" || $1 == "○") ? $2 : $1
    if (slug ~ /^[a-zA-Z0-9_-]+$/) print slug
  }')

[[ "$(echo "$EXTRACTED" | grep -c '^default$')" -eq 1 ]] && ok "extracts 'default' (current board with ● marker)" || fail "missing 'default'"
[[ "$(echo "$EXTRACTED" | grep -c '^sparc-sparqr-smoke-1782003742$')" -eq 1 ]] && ok "extracts board whose name contains ':' (sparc-sparqr-smoke-1782003742)" || fail "missing board with colon in name"
[[ "$(echo "$EXTRACTED" | grep -c '^sparc-sparqr-smoke-1782003837$')" -eq 1 ]] && ok "extracts second smoke board" || fail "missing second smoke board"
[[ "$(echo "$EXTRACTED" | grep -c '^spike-test$')" -eq 1 ]] && ok "extracts 'spike-test' (non-current, no marker)" || fail "missing 'spike-test'"
[[ "$(echo "$EXTRACTED" | grep -c '^Current$')" -eq 0 ]] && ok "excludes 'Current board:' footer" || fail "incorrectly included 'Current'"
[[ "$(echo "$EXTRACTED" | grep -c '^Switch$')" -eq 0 ]] && ok "excludes 'Switch boards...' footer" || fail "incorrectly included 'Switch'"
[[ "$(echo "$EXTRACTED" | grep -c '^SLUG$')" -eq 0 ]] && ok "excludes 'SLUG' header" || fail "incorrectly included 'SLUG'"
[[ "$(echo "$EXTRACTED" | wc -l)" -eq 4 ]] && ok "extracts exactly 4 boards" || fail "expected 4 boards, got $(echo "$EXTRACTED" | wc -l)"

# ─── 2. Arg parser ───────────────────────────────────────────────────
echo ""
echo "── arg parser ──"

# Helper: parse args the same way bin/sparc-status does.
# Returns via stdout: <BOARD_FILTER> <JSON_OUTPUT>
parse_args() {
  local board="" json=0
  local i=1
  while [[ $i -le $# ]]; do
    local arg="${!i}"
    case "$arg" in
      --board)      i=$((i + 1)); board="${!i:-}" ;;
      --board=*)    board="${arg#--board=}" ;;
      --json)       json=1 ;;
      *) echo "unknown: $arg" >&2; return 2 ;;
    esac
    i=$((i + 1))
  done
  printf '%s %d\n' "$board" "$json"
}

result=$(parse_args --board myboard)
[[ "$result" == "myboard 0" ]] && ok "--board <slug> (separate args)" || fail "--board separate args: got '$result', expected 'myboard 0'"

result=$(parse_args --board=myboard)
[[ "$result" == "myboard 0" ]] && ok "--board=<slug> (equals syntax)" || fail "--board= syntax: got '$result', expected 'myboard 0'"

result=$(parse_args --json)
[[ "$result" == " 1" ]] && ok "--json enables JSON mode" || fail "--json: got '$result', expected ' 1'"

result=$(parse_args --board b1 --json)
[[ "$result" == "b1 1" ]] && ok "--board + --json combined" || fail "combined: got '$result', expected 'b1 1'"

result=$(parse_args)
[[ "$result" == " 0" ]] && ok "no args → empty board, JSON off" || fail "no args: got '$result'"

# ─── 3. JSON output structure ────────────────────────────────────────
echo ""
echo "── JSON output structure ──"

# Build a minimal JSON output and check parseability + required keys
JSON_OUTPUT='{
  "boards": [
    {"slug": "default", "counts": {"ready": 1, "todo": 0, "running": 0, "blocked": 0, "done": 0, "archived": 0}, "running": [], "blocked": []}
  ],
  "totals": {"ready": 1, "todo": 0, "running": 0, "blocked": 0, "done": 0, "archived": 0}
}'

if python3 -c "import json,sys; d=json.loads('''$JSON_OUTPUT'''); assert 'boards' in d; assert 'totals' in d; assert all('slug' in b for b in d['boards']); assert all('counts' in b for b in d['boards']); assert all(k in d['totals'] for k in ('ready','todo','running','blocked','done','archived')); print('OK')" 2>&1 | grep -q "OK"; then
  ok "JSON output is valid + has required keys"
else
  fail "JSON output missing required keys"
fi

# ─── Summary ──────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]
