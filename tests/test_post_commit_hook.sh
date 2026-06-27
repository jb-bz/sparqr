#!/usr/bin/env bash
# tests/test_post_commit_hook.sh — Tests for v0.4.1 story 4e
# (post-commit hook installer + template).

set -uo pipefail

PASS=0
FAIL=0
ok()   { echo "  ✓ $*"; PASS=$((PASS+1)); }
fail() { echo "  ✗ $*"; FAIL=$((FAIL+1)); }

PKG_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PKG_ROOT/templates/post-commit-hook.sh"

# ── 1. hook template exists and is executable
echo "── 1. hook template ──"
[[ -f "$HOOK" ]] && ok "post-commit-hook.sh exists" || fail "missing"
[[ -x "$HOOK" ]] && ok "executable" || fail "not executable"

# ── 2. hook has the sparqr marker
echo "── 2. content ──"
grep -q "sparqr reminder" "$HOOK" && ok "contains 'sparqr reminder' marker" || fail "no marker"
grep -q "sparc retro" "$HOOK" && ok "mentions sparc retro command" || fail "no retro mention"
grep -q "release tag detected" "$HOOK" && ok "explains the trigger" || fail "no trigger explanation"

# ── 3. hook fires on tag detection
echo "── 3. tag detection ──"
TESTDIR=$(mktemp -d -t sparqr-hook-test-XXXXXX)
cd "$TESTDIR"
git init -q .
git config user.email t@t.com
git config user.name T
echo "init" > initial.txt && git add initial.txt && git commit -qm "init"

# Without a tag, hook should NOT print reminder
out=$(bash "$HOOK" 2>&1)
[[ -z "$out" ]] && ok "no reminder when no tag" || fail "unexpected reminder: $out"

# Add a tag matching HEAD
git tag v0.4.0
out=$(bash "$HOOK" 2>&1)
echo "$out" | grep -q "sparqr reminder" && ok "reminder fires when tag at HEAD" || fail "no reminder: $out"
echo "$out" | grep -q "sparc retro v0.4.0" && ok "reminder names the tag" || fail "tag not in reminder"

# ── 4. hook detects version reference in commit message
echo "── 4. commit message detection ──"
echo "x" > x.txt && git add x.txt && git commit -qm "Shipped v0.5.0 — Make it adoptable"
git tag v0.5.0
out=$(bash "$HOOK" 2>&1)
echo "$out" | grep -q "sparqr reminder" && ok "reminder fires on tag" || fail "no reminder"

# ── 5. hook is non-blocking (always exits 0)
echo "── 5. non-blocking ──"
bash "$HOOK" > /dev/null 2>&1
[[ $? -eq 0 ]] && ok "exits 0 even when no tag" || fail "non-zero exit"

cd /
rm -rf "$TESTDIR"

# ── Summary
echo ""
echo "══════════════════════════════════════════════════════"
echo "  $PASS pass  ·  $FAIL fail"
echo "══════════════════════════════════════════════════════"
[[ $FAIL -eq 0 ]]