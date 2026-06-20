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
# Test the function's detection of MISSING tools by temporarily
# stripping PATH so hermes isn't found. Restore PATH after.
# (We don't test the function against the dev env's actual state
# because that varies — hermes may or may not be installed. We test
# the function's behavior in a controlled missing-tool scenario.)

# Save current PATH, then strip down to a known-bare PATH that
# excludes any directory where hermes might be installed.
ORIG_PATH="$PATH"
# /usr/bin and /bin are always available; hermes wouldn't be there.
# We strip everything else to guarantee command -v hermes fails.
STRIPPED_PATH="/usr/bin:/bin"

# Run with stripped PATH so hermes check should fail
TMPOUT=$(mktemp)
PATH="$STRIPPED_PATH" sparc_preflight_check > "$TMPOUT" 2>&1 || true
PATH="$ORIG_PATH"
# Strip ANSI color codes for reliable matching
missing_count=$(sed -E 's/\x1b\[[0-9;]*m//g' "$TMPOUT" | grep -c "^  ✗" || true)
# In this scenario, hermes is missing AND bash 3.2 is too old, so
# at least 2 required prereqs are flagged as missing.
if [[ "$missing_count" -ge 2 ]]; then
  ok "preflight correctly reports $missing_count required prereqs as missing"
else
  fail "expected ≥ 2 missing prereqs (bash + hermes), got $missing_count"
fi

# The function should return non-zero
if ! PATH="$STRIPPED_PATH" sparc_preflight_check --quiet; then
  ok "preflight returns non-zero exit when required prereqs missing"
else
  fail "preflight should return non-zero when required prereqs missing"
fi

# Specific checks: bash 3.2 should be flagged, hermes not found should be reported.
TMPOUT2=$(mktemp)
PATH="$STRIPPED_PATH" sparc_preflight_check > "$TMPOUT2" 2>&1 || true
PATH="$ORIG_PATH"
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
rm -f "$TMPOUT" "$TMPOUT2"

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
