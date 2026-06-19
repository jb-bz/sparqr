#!/usr/bin/env bash
# tests/test_preflight.sh — Verify the prerequisites check function.
#
# Run: bash tests/test_preflight.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$TEST_DIR/.." && pwd)"

PASS=0
FAIL=0
ok()   { printf "  \033[32m✓\033[0m %s\n" "$*"; PASS=$((PASS+1)); }
fail() { printf "  \033[31m✗\033[0m %s\n" "$*"; FAIL=$((FAIL+1)); }
hdr()  { printf "\n\033[1m[%s]\033[0m\n" "$*"; }

# Source the function under test (clean env so the lib's guard doesn't short-circuit)
unset SPARC_PREFLIGHT_LOADED
# shellcheck source=../lib/preflight.sh
source "$PKG_ROOT/lib/preflight.sh"

# ── 1. Function exists and is callable ─────────────────────────────
hdr "preflight_check is exported and callable"
if declare -F sparc_preflight_check >/dev/null; then
  ok "sparc_preflight_check is defined"
else
  fail "sparc_preflight_check is NOT defined"
  exit 1
fi

# ── 2. _sparc_version_gte helper works correctly ─────────────────────
hdr "_sparc_version_gte helper"
if _sparc_version_gte "4.0" "4.0"; then
  ok "4.0 >= 4.0 (equal)"
else
  fail "4.0 should be >= 4.0"
fi
if _sparc_version_gte "5.2" "4.0"; then
  ok "5.2 >= 4.0"
else
  fail "5.2 should be >= 4.0"
fi
if _sparc_version_gte "3.2" "4.0"; then
  fail "3.2 should NOT be >= 4.0"
else
  ok "3.2 correctly returns 1 for 4.0"
fi
if _sparc_version_gte "4.5" "4.3"; then
  ok "4.5 >= 4.3 (minor upgrade)"
else
  fail "4.5 should be >= 4.3"
fi
if _sparc_version_gte "4.2" "4.3"; then
  fail "4.2 should NOT be >= 4.3"
else
  ok "4.2 correctly returns 1 for 4.3"
fi

# ── 3. --quiet flag suppresses output ────────────────────────────────
hdr "--quiet mode suppresses output"
out=$(sparc_preflight_check --quiet 2>&1)
# In quiet mode, no "✓" or "✗" lines, no "All prerequisites met" summary
if echo "$out" | grep -qE "✓|✗|All prerequisites|missing"; then
  fail "--quiet should suppress status output, but got: $out"
else
  ok "--quiet mode produces no status output"
fi

# ── 4. exit code reflects prerequisite state ───────────────────────
hdr "exit code reflects prereq state"
# The preflight should return non-zero if ANY required prereq is missing.
# In this test env, we expect bash (3.2 < 4.0) to fail (and probably hermes).
# We don't assert a specific return code; we assert the relationship between
# the env's actual state and the return code:
#   - If everything is present, return code is 0
#   - If anything is missing, return code is 1
# This catches the bug where the function always returns 0 (or always 1).
out=$(sparc_preflight_check --quiet 2>&1)
rc=$?
# Reconstruct: would the function return 0 if everything were present?
# Check each required prereq using `command -v` (mirrors the function's logic).
all_present=1
command -v sqlite3 >/dev/null 2>&1 || all_present=0
command -v curl >/dev/null 2>&1 || all_present=0
command -v jq >/dev/null 2>&1 || all_present=0
command -v "${HERMES_BIN:-hermes}" >/dev/null 2>&1 || all_present=0
# bash check via the function's own helper
source "$PKG_ROOT/lib/preflight.sh"
_sparc_version_gte "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}" "4.0" || all_present=0

# Expected return code: 0 if all present, 1 otherwise
expected_rc=$((1 - all_present))

if [[ "$rc" -eq "$expected_rc" ]]; then
  ok "preflight return code ($rc) matches env state (all_present=$all_present)"
else
  fail "preflight return code ($rc) does not match env state (expected $expected_rc for all_present=$all_present)"
fi

# ── 5. Forced failure: missing tool detection ─────────────────────────
hdr "missing tool detection"
# In the test env, bash (3.2 < 4.0) and hermes (not on PATH) are
# expected to be missing. Verify the function reports BOTH as ✗.
# We don't try to artificially construct a "sparse PATH" because that
# breaks bash builtins; instead, we test the function's detection of the
# actually-missing prereqs in THIS test env.

# Count missing prereqs in current env (should be ≥ 2: bash + hermes)
# Note: we don't use `out=$(cmd | grep ...)` because the pipefail setting
# can make this fragile. We use a temp file instead.
TMPOUT=$(mktemp)
sparc_preflight_check > "$TMPOUT" 2>&1 || true
# Strip ANSI color codes for reliable matching
missing_count=$(sed -E 's/\x1b\[[0-9;]*m//g' "$TMPOUT" | grep -c "^  ✗" || true)
rm -f "$TMPOUT"
if [[ "$missing_count" -ge 2 ]]; then
  ok "preflight correctly reports $missing_count required prereqs as missing"
else
  fail "expected ≥ 2 missing prereqs (bash + hermes), got $missing_count"
fi

# The function should return non-zero
if ! sparc_preflight_check --quiet; then
  ok "preflight returns non-zero exit when required prereqs missing"
else
  fail "preflight should return non-zero when required prereqs missing"
fi

# Specific checks: bash 3.2 should be flagged, hermes not found should be reported.
TMPOUT2=$(mktemp)
sparc_preflight_check > "$TMPOUT2" 2>&1 || true
if sed -E 's/\x1b\[[0-9;]*m//g' "$TMPOUT2" | grep -qE "bash.*too old.*need.*4.0"; then
  ok "bash 3.2 correctly flagged as too old"
else
  fail "bash 3.2 should be flagged as too old"
fi
if sed -E 's/\x1b\[[0-9;]*m//g' "$TMPOUT2" | grep -qE "hermes.*not found"; then
  ok "missing hermes correctly reported"
else
  fail "missing hermes should be reported"
fi
rm -f "$TMPOUT2"

# ── 6. Report format ───────────────────────────────────────────
hdr "report format"
# In normal mode, output should contain "✓" or "✗" lines
out=$(sparc_preflight_check 2>&1)
if echo "$out" | grep -qE "✓|✗"; then
  ok "report contains ✓ or ✗ status markers"
else
  fail "report missing status markers"
fi
# Summary line at the end
if echo "$out" | grep -qE "All prerequisites|missing|warning"; then
  ok "report has summary line"
else
  fail "report missing summary line. Output: $out"
fi

# ── 7. --pre-install flag on sparc doctor works ──────────────────
hdr "sparc doctor --pre-install"
out=$("$PKG_ROOT/bin/sparc-doctor" --pre-install 2>&1 || true)
if echo "$out" | grep -qE "pre-install prerequisites check"; then
  ok "sparc doctor --pre-install shows the right header"
else
  fail "sparc doctor --pre-install unexpected output: $out"
fi

# ── Summary ────────────────────────────────────────────────────────
printf "\n══════════════════════════════════════════════════════\n"
printf "  %d pass  ·  %d fail\n" "$PASS" "$FAIL"
printf "══════════════════════════════════════════════════════\n"

[[ "$FAIL" -eq 0 ]] || exit 1
